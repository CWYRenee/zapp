/**
 * RHEA Finance Service
 * Integrates with RHEA Finance SDK for token swaps and liquidity on NEAR
 * 
 * Based on: @ref-finance/ref-sdk
 * Docs: https://guide.ref.finance/developers/ref-sdk
 */

import {
  init_env,
  ftGetTokenMetadata,
  ftGetTokensMetadata,
  fetchAllPools,
  getStablePools,
  estimateSwap,
  getExpectedOutputFromSwapTodos,
  instantSwap,
  getConfig,
  toNonDivisibleNumber,
  getSignedTransactionsByMemoryKey,
  sendTransactionsByMemoryKey,
  type TokenMetadata,
  type Pool,
  type StablePool,
  type EstimateSwapView,
  type Transaction,
} from '@ref-finance/ref-sdk';

import { NearAccountService } from './nearAccountService';

// Initialize Ref SDK environment
const NEAR_ENV = process.env.NEAR_ENV || 'mainnet';
init_env(NEAR_ENV);

// Cache for pools to avoid repeated fetching
let poolsCache: {
  simplePools: Pool[];
  stablePools: Pool[];
  ratedPools: Pool[];
  stablePoolsDetail: StablePool[];
  lastFetched: number;
} | null = null;

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export class RefFinanceService {
  /**
   * Get current SDK configuration
   */
  static getConfig() {
    return getConfig(NEAR_ENV);
  }

  /**
   * Initialize SDK environment
   */
  static initEnvironment(env: 'mainnet' | 'testnet' = 'mainnet', indexerUrl?: string, nodeUrl?: string) {
    init_env(env, indexerUrl, nodeUrl);
  }

  // ============================================================================
  // TOKEN METADATA
  // ============================================================================

  /**
   * Get metadata for a single token
   */
  static async getTokenMetadata(tokenId: string): Promise<TokenMetadata> {
    return ftGetTokenMetadata(tokenId);
  }

  /**
   * Get metadata for multiple tokens
   */
  static async getTokensMetadata(
    tokenIds: string[],
    existingTokens: Record<string, TokenMetadata> = {}
  ): Promise<Record<string, TokenMetadata>> {
    return ftGetTokensMetadata(tokenIds, existingTokens);
  }

  // ============================================================================
  // POOLS
  // ============================================================================

  /**
   * Fetch all pools with caching
   */
  static async fetchAllPools(forceRefresh = false): Promise<{
    simplePools: Pool[];
    stablePools: Pool[];
    ratedPools: Pool[];
    stablePoolsDetail: StablePool[];
  }> {
    const now = Date.now();
    
    if (!forceRefresh && poolsCache && (now - poolsCache.lastFetched) < CACHE_TTL_MS) {
      return poolsCache;
    }

    console.log('[RefFinance] Fetching all pools...');
    const { ratedPools, unRatedPools, simplePools } = await fetchAllPools();
    
    // Combine rated and unrated pools as stable pools
    const stablePools = [...unRatedPools, ...ratedPools];
    const stablePoolsDetail = await getStablePools(stablePools);

    poolsCache = {
      simplePools,
      stablePools,
      ratedPools,
      stablePoolsDetail,
      lastFetched: now,
    };

    console.log(`[RefFinance] Fetched ${simplePools.length} simple pools, ${stablePools.length} stable pools`);
    return poolsCache;
  }

  /**
   * Find pools containing specific tokens
   */
  static async findPoolsForTokens(tokenA: string, tokenB: string): Promise<Pool[]> {
    const { simplePools, stablePools } = await this.fetchAllPools();
    const allPools = [...simplePools, ...stablePools];
    
    return allPools.filter(pool => 
      pool.tokenIds.includes(tokenA) && pool.tokenIds.includes(tokenB)
    );
  }

  static async getPoolInfo(poolId: number): Promise<Pool | null> {
    const { simplePools, stablePools } = await this.fetchAllPools();
    const allPools = [...simplePools, ...stablePools];
    const pool = allPools.find(p => p.id === poolId);
    return pool || null;
  }

  // ============================================================================
  // SWAP ESTIMATION
  // ============================================================================

  /**
   * Estimate swap output with smart routing
   */
  static async estimateSwap(params: {
    tokenIn: string;
    tokenOut: string;
    amountIn: string;
    enableSmartRouting?: boolean;
  }): Promise<{
    swapTodos: EstimateSwapView[];
    expectedOutput: string;
  }> {
    const { tokenIn, tokenOut, amountIn, enableSmartRouting = true } = params;

    // Get token metadata
    const [tokenInMeta, tokenOutMeta] = await Promise.all([
      this.getTokenMetadata(tokenIn),
      this.getTokenMetadata(tokenOut),
    ]);

    // Get pools
    const { simplePools, stablePools, stablePoolsDetail } = await this.fetchAllPools();

    // Estimate swap
    const swapParams = {
      tokenIn: tokenInMeta,
      tokenOut: tokenOutMeta,
      amountIn,
      simplePools,
    };

    const swapTodos = enableSmartRouting
      ? await estimateSwap({
          ...swapParams,
          options: {
            enableSmartRouting: true,
            stablePools,
            stablePoolsDetail,
          },
        })
      : await estimateSwap(swapParams);

    const expectedOutput = String(getExpectedOutputFromSwapTodos(swapTodos, tokenOut));

    return {
      swapTodos,
      expectedOutput,
    };
  }

  static toNonDivisibleAmount(decimals: number, amount: number): string {
    return toNonDivisibleNumber(decimals, amount.toString());
  }

  static async executeTransactionsWithAccount(params: {
    accountId: string;
    transactions: Transaction[];
  }): Promise<string[]> {
    const { accountId, transactions } = params;
    const keyPath = NearAccountService.getCredentialsPath(accountId);

    try {
      const signed = await getSignedTransactionsByMemoryKey({
        transactionsRef: transactions,
        AccountId: accountId,
        keyPath,
      });

      const results = await sendTransactionsByMemoryKey({
        signedTransactions: signed,
      });

      return (results || [])
        .map((result: unknown) => (result as { transaction?: { hash?: string } }).transaction?.hash)
        .filter((hash: unknown): hash is string => typeof hash === 'string' && hash.length > 0);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('[RefFinance] Failed to execute transactions with memory key:', error);
      throw error;
    }
  }

  static async createStableDepositTransactions(params: {
    poolId: number;
    nzecTokenId: string;
    amount: string;
  }): Promise<Transaction[]> {
    const { poolId, nzecTokenId, amount } = params;
    const pool = await this.getPoolInfo(poolId);

    if (!pool) {
      throw new Error(`Pool ${poolId} not found`);
    }

    const tokens = pool.tokenIds;

    if (!tokens.includes(nzecTokenId)) {
      throw new Error(`Pool ${poolId} does not contain token ${nzecTokenId}`);
    }

    const config = this.getConfig();
    const refContractId = config.REF_FI_CONTRACT_ID;

    const depositTx: Transaction = {
      receiverId: nzecTokenId,
      functionCalls: [
        {
          methodName: 'ft_transfer_call',
          args: {
            receiver_id: refContractId,
            amount,
            msg: '',
          },
          gas: '180000000000000',
          amount: '0.000000000000000000000001',
        },
      ],
    };

    const amounts = tokens.map(tokenId => (tokenId === nzecTokenId ? amount : '0'));

    const addLiquidityTx: Transaction = {
      receiverId: refContractId,
      functionCalls: [
        {
          methodName: 'add_stable_liquidity',
          args: {
            pool_id: poolId,
            amounts,
            min_shares: '0',
          },
          gas: '180000000000000',
          amount: '0.000000000000000000000001',
        },
      ],
    };

    return [depositTx, addLiquidityTx];
  }

  /**
   * Get quote for swap
   */
  static async getSwapQuote(params: {
    tokenIn: string;
    tokenOut: string;
    amountIn: string;
  }): Promise<{
    amountOut: string;
    priceImpact: number;
    route: string[];
    fee: number;
  }> {
    const { swapTodos, expectedOutput } = await this.estimateSwap(params);

    // Calculate route
    const route = swapTodos.length > 0 
      ? [params.tokenIn, ...swapTodos.map(t => t.outputToken).filter((t): t is string => !!t)]
      : [params.tokenIn, params.tokenOut];

    // Calculate total fee (sum of pool fees)
    const totalFee = swapTodos.reduce((sum, todo) => sum + (todo.pool?.fee || 0), 0);

    // Estimate price impact (simplified)
    const amountInNum = parseFloat(params.amountIn);
    const amountOutNum = parseFloat(expectedOutput);
    const priceImpact = amountInNum > 0 ? Math.abs(1 - (amountOutNum / amountInNum)) * 100 : 0;

    return {
      amountOut: expectedOutput,
      priceImpact,
      route,
      fee: totalFee / 10000, // Convert basis points to percentage
    };
  }

  // ============================================================================
  // SWAP TRANSACTIONS
  // ============================================================================

  /**
   * Create swap transaction
   */
  static async createSwapTransaction(params: {
    tokenIn: string;
    tokenOut: string;
    amountIn: string;
    slippageTolerance: number;
    accountId: string;
    referralId?: string;
  }): Promise<Transaction[]> {
    const { tokenIn, tokenOut, amountIn, slippageTolerance, accountId, referralId } = params;

    // Get token metadata
    const [tokenInMeta, tokenOutMeta] = await Promise.all([
      this.getTokenMetadata(tokenIn),
      this.getTokenMetadata(tokenOut),
    ]);

    // Estimate swap
    const { swapTodos } = await this.estimateSwap({
      tokenIn,
      tokenOut,
      amountIn,
    });

    // Create transactions
    const transactions = await instantSwap({
      tokenIn: tokenInMeta,
      tokenOut: tokenOutMeta,
      amountIn,
      swapTodos,
      slippageTolerance,
      AccountId: accountId,
      referralId,
    });

    return transactions;
  }

  // ============================================================================
  // LIQUIDITY POOL INFO (for earning yield)
  // ============================================================================

  /**
   * Get pool APY estimates based on trading volume and fees
   * Note: This is an estimate based on 24h volume
   */
  static async getPoolApyEstimate(poolId: number): Promise<{
    apy: number;
    fee: number;
    tvl: number;
    volume24h: number;
  }> {
    const { simplePools, stablePools } = await this.fetchAllPools();
    const allPools = [...simplePools, ...stablePools];
    
    const pool = allPools.find(p => p.id === poolId);
    
    if (!pool) {
      throw new Error(`Pool ${poolId} not found`);
    }

    // Get TVL from supplies
    const tvl = pool.tvl || 0;
    
    // Fee in basis points (e.g., 30 = 0.3%)
    const feePercent = pool.fee / 10000;
    
    // Estimate APY based on fee and volume (simplified)
    // In production, you'd want to query actual 24h volume from indexer
    const estimatedVolume24h = tvl * 0.1; // Assume 10% daily turnover
    const dailyFees = estimatedVolume24h * feePercent;
    const yearlyFees = dailyFees * 365;
    const apy = tvl > 0 ? (yearlyFees / tvl) * 100 : 0;

    return {
      apy,
      fee: feePercent * 100,
      tvl,
      volume24h: estimatedVolume24h,
    };
  }

  /**
   * Get top pools by TVL
   */
  static async getTopPools(limit = 10): Promise<Array<{
    id: number;
    tokenIds: string[];
    fee: number;
    tvl: number;
    shareSupply: string;
  }>> {
    const { simplePools } = await this.fetchAllPools();
    
    // Sort by TVL and return top pools
    const sorted = simplePools
      .filter(p => p.tvl && p.tvl > 0)
      .sort((a, b) => (b.tvl || 0) - (a.tvl || 0))
      .slice(0, limit);

    return sorted.map(pool => ({
      id: pool.id,
      tokenIds: pool.tokenIds,
      fee: pool.fee,
      tvl: pool.tvl || 0,
      shareSupply: pool.shareSupply,
    }));
  }

  // ============================================================================
  // WRAPPED NEAR UTILITIES
  // ============================================================================

  /**
   * Get wrapped NEAR contract ID for current network
   */
  static getWrappedNearId(): string {
    const config = this.getConfig();
    return config.WRAP_NEAR_CONTRACT_ID;
  }

  /**
   * Get REF token ID for current network
   */
  static getRefTokenId(): string {
    const config = this.getConfig();
    return config.REF_TOKEN_ID;
  }
}

export default RefFinanceService;
