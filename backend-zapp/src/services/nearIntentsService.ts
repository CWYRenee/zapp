/**
 * NEAR Intents Service
 * Handles Zcash <-> NEAR bridge address generation using:
 * 1. OmniBridgeService (real bridging via omni-bridge-sdk) when ZCASH_API_KEY is configured
 * 2. SwapKit (mainnet / testnet simulation) as fallback
 * 3. Internal simulated data (development/testing) as last resort
 * 
 * Integrates with RHEA Finance indexer/SDK for APY data and LP operations.
 * 
 * Flow: Zcash -> OmniBridge -> nZEC on NEAR -> RHEA Finance LP
 */

import { RefFinanceService } from './refFinanceService.js';
import { refIndexerService } from './refIndexerService.js';
import { swapKitService } from './swapKitService.js';
import { OmniBridgeService } from './omniBridgeService.js';
import type { 
  BridgeTransaction, 
  BridgeDepositInfo, 
  BridgeTxStatus, 
  LendingProtocolInfo,
  FinalizeDepositInput,
  FinalizeDepositResult,
} from '../types/earn.js';

// Configuration
const BRIDGE_FEE_PERCENT = 0.5;
const ESTIMATED_BRIDGE_TIME_MINUTES = 10;

export class NEARIntentsService {
  /**
   * Generate a unique bridge transaction ID
   */
  private static generateBridgeTxId(): string {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `BRIDGE-${timestamp}-${random}`;
  }

  /**
   * Generate a unique NEAR Intent ID
   */
  private static generateIntentId(): string {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 10).toUpperCase();
    return `INTENT-${timestamp}-${random}`;
  }

  // ============================================================================
  // BRIDGE OPERATIONS
  // ============================================================================

  /**
   * Get bridge deposit address for ZEC -> NEAR
   *
   * Priority order:
   * 1. OmniBridgeService (real bridging via omni-bridge-sdk) when ZCASH_API_KEY is configured
   * 2. SwapKit when configured (handles mainnet and testnet simulation)
   * 3. Internal simulated data (development/testing)
   */
  static async getBridgeDepositAddress(
    userZcashAddress: string,
    zecAmount: number,
  ): Promise<BridgeDepositInfo> {
    const intentId = this.generateIntentId();
    
    // Priority 1: Use OmniBridgeService for real bridging when configured
    if (OmniBridgeService.isConfigured()) {
      try {
        console.log('[NEARIntents] Using OmniBridgeService for real bridge deposit address');
        
        // Convert ZEC to zatoshis (1 ZEC = 100,000,000 zatoshis)
        const amountZatoshis = BigInt(Math.floor(zecAmount * 100_000_000));
        
        const result = await OmniBridgeService.getDepositAddress(
          userZcashAddress,
          amountZatoshis,
        );
        
        if (result.success && result.depositAddress) {
          const bridgeFee = result.bridgeFeeInfo 
            ? Number(result.bridgeFeeInfo.feeMin) / 100_000_000 
            : zecAmount * (BRIDGE_FEE_PERCENT / 100);
          const expectedAmount = zecAmount - bridgeFee;
          
          // Calculate min deposit in ZEC
          const minDepositZec = result.minDepositZatoshis 
            ? Number(result.minDepositZatoshis) / 100_000_000
            : 0.0001;
          
          console.log(`[NEARIntents] ✓ Got real bridge deposit address: ${result.depositAddress}`);
          console.log(`[NEARIntents]   NEAR Account: ${result.nearAccountId}`);
          console.log(`[NEARIntents]   Min Deposit: ${minDepositZec} ZEC`);
          
          return {
            bridgeAddress: result.depositAddress,
            expectedAmount,
            estimatedArrivalMinutes: ESTIMATED_BRIDGE_TIME_MINUTES,
            bridgeFeePercent: BRIDGE_FEE_PERCENT,
            nearIntentId: intentId,
            isSimulated: false,
            source: 'omni_bridge_sdk',
            // Include deposit args for finalization (base64 encoded)
            depositArgs: result.depositArgs 
              ? Buffer.from(JSON.stringify(result.depositArgs)).toString('base64')
              : undefined,
            minDepositZec,
            nearAccountId: result.nearAccountId,
          };
        } else {
          console.warn('[NEARIntents] OmniBridgeService failed:', result.error);
        }
      } catch (error) {
        console.error('[NEARIntents] OmniBridgeService error:', error);
      }
    }
    
    // Priority 2: Use SwapKit when configured (handles mainnet and testnet simulation)
    if (swapKitService.isConfigured()) {
      try {
        console.log('[NEARIntents] Using SwapKit for bridge deposit address');
        
        const quote = await swapKitService.getZecSwapQuote({
          buyAsset: 'NEAR.NEAR',
          sellAmount: zecAmount.toString(),
          sourceZecAddress: userZcashAddress,
          destinationAddress: 'ref-finance.near',
        });
        
        const isSimulated = quote.isSimulated ?? false;
        const source = quote.source ?? (isSimulated ? 'testnet_simulation' : 'swapkit_api');
        
        console.log(`[NEARIntents] Got SwapKit quote for ${zecAmount} ZEC -> NEAR (source: ${source})`);
        
        return {
          bridgeAddress: quote.depositAddress,
          expectedAmount: parseFloat(quote.expectedBuyAmount),
          estimatedArrivalMinutes: quote.estimatedTimeMinutes,
          bridgeFeePercent: BRIDGE_FEE_PERCENT,
          nearIntentId: intentId,
          isSimulated,
          source,
        };
      } catch (error) {
        console.error('[NEARIntents] SwapKit quote failed:', error);
      }
    }
    
    // Priority 3: Final fallback to simulated data
    console.warn('[NEARIntents] Using fallback simulated bridge info');
    return this.getFallbackBridgeInfo(zecAmount, intentId);
  }
  
  /**
   * Finalize a deposit after ZEC has been sent and confirmed
   *
   * For real bridging (OmniBridgeService), this verifies the Zcash transaction
   * and mints nZEC on NEAR.
   *
   * @param input - The finalization input including userWalletAddress (Zcash)
   * @param depositArgs - The deposit args from the original deposit preparation (base64 encoded)
   */
  static async finalizeDeposit(input: FinalizeDepositInput, depositArgs: string): Promise<FinalizeDepositResult> {
    // Check if real bridging is configured
    if (OmniBridgeService.isConfigured()) {
      try {
        console.log('[NEARIntents] Finalizing deposit via OmniBridgeService');
        console.log(`  User: ${input.userWalletAddress}`);
        console.log(`  TX Hash: ${input.zcashTxHash}`);
        console.log(`  Vout: ${input.vout}`);
        
        // Decode the deposit args from base64
        const decodedArgs = JSON.parse(Buffer.from(depositArgs, 'base64').toString('utf-8'));
        
        const result = await OmniBridgeService.finalizeDeposit(
          input.userWalletAddress,
          input.zcashTxHash,
          input.vout,
          decodedArgs,
        );
        
        if (result.success) {
          const network = OmniBridgeService.getNetwork();
          const explorerBase = network === 'testnet' 
            ? 'https://testnet.nearblocks.io/txns/'
            : 'https://nearblocks.io/txns/';
          
          return {
            success: true,
            nearTxHash: result.nearTxHash,
            nZecAmount: result.nZecAmount,
            explorerUrl: result.nearTxHash ? `${explorerBase}${result.nearTxHash}` : undefined,
          };
        } else {
          return {
            success: false,
            error: result.error || 'Finalization failed',
          };
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        console.error('[NEARIntents] Finalization error:', message);
        return {
          success: false,
          error: `Finalization failed: ${message}`,
        };
      }
    }
    
    // Fallback: simulation mode does not support finalization
    return {
      success: false,
      error: 'Deposit finalization requires ZCASH_API_KEY to be configured for real bridging',
    };
  }
  
  /**
   * Fallback bridge info when SwapKit is unavailable
   */
  private static getFallbackBridgeInfo(zecAmount: number, intentId: string): BridgeDepositInfo {
    const bridgeFee = zecAmount * (BRIDGE_FEE_PERCENT / 100);
    const expectedAmount = zecAmount - bridgeFee;
    
    // Generate a placeholder address (won't work for real transactions)
    const bridgeAddressPrefix = 't1';
    const randomPart = Array.from({ length: 32 }, () => 
      Math.floor(Math.random() * 16).toString(16)
    ).join('');
    const bridgeAddress = `${bridgeAddressPrefix}${randomPart.substring(0, 33)}`;
    
    console.warn(`[NEARIntents] Using fallback bridge address (not real!)`);
    
    return {
      bridgeAddress,
      expectedAmount,
      estimatedArrivalMinutes: ESTIMATED_BRIDGE_TIME_MINUTES,
      bridgeFeePercent: BRIDGE_FEE_PERCENT,
      nearIntentId: intentId,
      isSimulated: true,
      source: 'fallback',
    };
  }

  /**
   * Create bridge transaction record for ZEC → NEAR
   */
  static async initiateBridgeToNear(
    zcashSourceAddress: string,
    zecAmount: number,
    nearIntentId: string,
  ): Promise<BridgeTransaction> {
    const bridgeFee = zecAmount * (BRIDGE_FEE_PERCENT / 100);
    const nearAmount = zecAmount - bridgeFee;
    
    const bridgeTx: BridgeTransaction = {
      bridgeTxId: this.generateBridgeTxId(),
      direction: 'zcash_to_near',
      status: 'pending',
      sourceAddress: zcashSourceAddress,
      destinationAddress: 'ref-finance.near',
      zecAmount,
      nearAmount,
      nearIntentId,
      createdAt: new Date(),
    };
    
    console.log(`[NEARIntents] Initiated bridge to NEAR: ${bridgeTx.bridgeTxId}`);
    return bridgeTx;
  }

  /**
   * Create bridge transaction for NEAR → Zcash
   */
  static async initiateBridgeToZcash(
    zcashDestination: string,
    nearAmount: number,
  ): Promise<BridgeTransaction> {
    const intentId = this.generateIntentId();
    const bridgeFee = nearAmount * (BRIDGE_FEE_PERCENT / 100);
    const zecAmount = nearAmount - bridgeFee;
    
    const bridgeTx: BridgeTransaction = {
      bridgeTxId: this.generateBridgeTxId(),
      direction: 'near_to_zcash',
      status: 'pending',
      sourceAddress: 'ref-finance.near',
      destinationAddress: zcashDestination,
      zecAmount,
      nearAmount,
      nearIntentId: intentId,
      createdAt: new Date(),
    };
    
    console.log(`[NEARIntents] Initiated bridge to Zcash: ${bridgeTx.bridgeTxId}`);
    return bridgeTx;
  }

  /**
   * Check bridge transaction status
   */
  static async getBridgeStatus(_bridgeTxId: string): Promise<{
    status: BridgeTxStatus;
    zcashTxHash?: string;
    nearTxHash?: string;
    completedAt?: Date;
  }> {
    // TODO: Query actual NEAR Intents API
    return { status: 'pending' };
  }

  /**
   * Estimate bridge fees
   */
  static estimateBridgeFee(amount: number): {
    feePercent: number;
    feeAmount: number;
    netAmount: number;
  } {
    const feeAmount = amount * (BRIDGE_FEE_PERCENT / 100);
    return {
      feePercent: BRIDGE_FEE_PERCENT,
      feeAmount,
      netAmount: amount - feeAmount,
    };
  }

  /**
   * Validate Zcash address format
   * Supports:
   * - t1: mainnet transparent
   * - t3: testnet transparent  
   * - tm: testnet transparent (alternate)
   * - zs: sapling shielded
   * - ztestsapling: testnet sapling
   * - u1: mainnet unified address
   * - utest1: testnet unified address
   */
  static isValidZcashAddress(address: string): boolean {
    if (!address || address.length < 20) return false;
    const validPrefixes = ['t1', 't3', 'zs', 'tm', 'ztestsapling', 'u1', 'utest1'];
    return validPrefixes.some(prefix => address.startsWith(prefix));
  }

  static isValidTransparentZcashAddress(address: string): boolean {
    if (!this.isValidZcashAddress(address)) return false;
    const base58Regex = /^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+$/;
    return base58Regex.test(address);
  }

  /**
   * Get bridge health status
   */
  static async getBridgeHealth(): Promise<{
    isOperational: boolean;
    estimatedDelayMinutes: number;
    message?: string;
  }> {
    return {
      isOperational: true,
      estimatedDelayMinutes: ESTIMATED_BRIDGE_TIME_MINUTES,
    };
  }

  // ============================================================================
  // REF FINANCE INTEGRATION
  // ============================================================================

  /**
   * Get RHEA Finance protocol info from indexer
   */
  static async getRefProtocolInfo(): Promise<LendingProtocolInfo> {
    try {
      // Get real data from RHEA Finance indexer
      const [avgApy, totalTvl] = await Promise.all([
        refIndexerService.getAverageApy(10),
        refIndexerService.getTotalTvl(),
      ]);
      
      console.log(`[NEARIntents] RHEA Finance - APY: ${avgApy}%, TVL: $${totalTvl.toLocaleString()}`);

      return {
        protocolName: 'RHEA Finance',
        poolId: 'ref-finance-lp',
        currentApy: avgApy,
        totalValueLocked: totalTvl,
        minDeposit: 0.001,
        maxDeposit: 1000,
        withdrawalFeePercent: 0.1,
        isActive: true,
      };
    } catch (error) {
      console.error('[NEARIntents] Failed to get Ref protocol info:', error);
      // Return fallback data
      return {
        protocolName: 'RHEA Finance',
        poolId: 'ref-finance-lp',
        currentApy: 8.5, // Fallback APY
        totalValueLocked: 0,
        minDeposit: 0.001,
        maxDeposit: 1000,
        withdrawalFeePercent: 0.1,
        isActive: true,
      };
    }
  }

  /**
   * Get APY history from RHEA Finance indexer
   * Note: Indexer doesn't provide historical APY, so we fetch current and estimate history
   */
  static async getApyHistory(days: number = 30): Promise<Array<{ timestamp: Date; apy: number }>> {
    const history: Array<{ timestamp: Date; apy: number }> = [];
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    
    try {
      // Get current APY from indexer
      const currentApy = await refIndexerService.getAverageApy(10);
      
      // Generate historical data based on current APY with small variations
      // In production, this should come from a historical data store
      for (let i = days; i >= 0; i--) {
        // Small daily variation (+/- 0.5%)
        const variation = (Math.sin(i * 0.5) * 0.5) + (Math.random() * 0.2 - 0.1);
        history.push({
          timestamp: new Date(now - i * dayMs),
          apy: Math.max(0, currentApy + variation),
        });
      }
    } catch (error) {
      console.error('[NEARIntents] Failed to get APY history:', error);
      // Fallback to estimated data
      const baseApy = 8;
      for (let i = days; i >= 0; i--) {
        history.push({
          timestamp: new Date(now - i * dayMs),
          apy: baseApy + (Math.random() * 2 - 1),
        });
      }
    }
    
    return history;
  }

  /**
   * Swap tokens via RHEA Finance
   */
  static async swapTokens(params: {
    tokenIn: string;
    tokenOut: string;
    amountIn: string;
    slippageTolerance: number;
    accountId: string;
  }) {
    const { tokenIn, tokenOut, amountIn, slippageTolerance, accountId } = params;
    
    // Get swap quote
    const quote = await RefFinanceService.getSwapQuote({
      tokenIn,
      tokenOut,
      amountIn,
    });
    
    // Create swap transaction
    const transactions = await RefFinanceService.createSwapTransaction({
      tokenIn,
      tokenOut,
      amountIn,
      slippageTolerance,
      accountId,
    });
    
    return {
      quote,
      transactions,
    };
  }

  /**
   * Deposit funds to earn yield on RHEA Finance pools
   * 
   * In real bridging mode, this executes the actual NEAR transaction to deposit
   * nZEC into the selected RHEA Finance pool.
   */
  static async depositToPool(
    accountId: string,
    amount: number,
    poolId: string,
  ): Promise<{
    success: boolean;
    nearTxHash?: string;
    depositedAmount: number;
    currentApy: number;
  }> {
    const isRealBridging = OmniBridgeService.isConfigured();
    const network = OmniBridgeService.getNetwork();
    
    console.log(`[NEARIntents] Depositing ${amount} to RHEA Finance pool ${poolId}`);
    console.log(`[NEARIntents]   Account: ${accountId}`);
    console.log(`[NEARIntents]   Mode: ${isRealBridging ? 'REAL' : 'SIMULATED'}`);

    const protocolInfo = await this.getRefProtocolInfo();
    let poolApy = protocolInfo.currentApy;

    // Try to refine APY using pool-specific data when poolId is numeric
    try {
      const parsed = Number(poolId);
      if (!Number.isNaN(parsed)) {
        const apyInfo = await RefFinanceService.getPoolApyEstimate(parsed);
        poolApy = apyInfo.apy;
        console.log(`[NEARIntents]   Pool ${poolId} APY: ${poolApy.toFixed(2)}%`);
      }
    } catch (error) {
      console.error('[NEARIntents] Failed to get pool APY estimate:', error);
    }

    // Real bridging: Execute actual NEAR transaction
    if (isRealBridging) {
      try {
        // Convert amount to zatoshis (nZEC has 8 decimals like ZEC)
        const amountZatoshis = BigInt(Math.floor(amount * 100_000_000));
        
        // Parse pool ID
        const poolIdNum = Number(poolId);
        if (Number.isNaN(poolIdNum)) {
          throw new Error(`Invalid pool ID: ${poolId}`);
        }
        
        console.log(`[NEARIntents]   Executing real RHEA Finance deposit...`);
        
        // Execute the actual NEAR transactions to deposit to RHEA Finance
        const result = await OmniBridgeService.depositToRheaPool(
          accountId, // This is the Zcash address, will be mapped to NEAR account
          poolIdNum,
          amountZatoshis,
        );
        
        if (!result.success) {
          throw new Error(result.error || 'RHEA deposit failed');
        }
        
        // Get the last transaction hash (the add_liquidity tx)
        const txHash = result.txHashes[result.txHashes.length - 1] || 
          `RHEA-${network.toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;
        
        console.log(`[NEARIntents] ✓ RHEA Finance deposit complete!`);
        console.log(`[NEARIntents]   TX Hashes: ${result.txHashes.join(', ')}`);
        
        return {
          success: true,
          nearTxHash: txHash,
          depositedAmount: amount,
          currentApy: poolApy,
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        console.error(`[NEARIntents] ✗ RHEA deposit failed: ${message}`);
        return {
          success: false,
          depositedAmount: 0,
          currentApy: poolApy,
        };
      }
    }

    // Simulated mode: No real NEAR transaction
    const simulatedHash = `SIM-NEAR-${Date.now().toString(36).toUpperCase()}`;
    console.log(`[NEARIntents] (Simulated) Deposit hash: ${simulatedHash}`);

    return {
      success: true,
      nearTxHash: simulatedHash,
      depositedAmount: amount,
      currentApy: poolApy,
    };
  }

  /**
   * Withdraw funds from RHEA Finance pools
   */
  static async withdrawFromPool(
    nearAccountId: string,
    amount: number,
  ): Promise<{
    success: boolean;
    nearTxHash?: string;
    withdrawnAmount: number;
  }> {
    console.log(`[NEARIntents] Withdrawing ${amount} from RHEA Finance for NEAR account ${nearAccountId}`);

    // TODO: Execute actual LP withdrawal via RHEA Finance SDK

    return {
      success: true,
      nearTxHash: `NEAR-${Date.now().toString(36).toUpperCase()}`,
      withdrawnAmount: amount,
    };
  }

  /**
   * Get current balance and earnings from RHEA Finance
   * Uses indexer to query user's liquidity positions
   */
  static async getPoolBalance(nearAccountId: string): Promise<{
    principal: number;
    currentBalance: number;
    earnings: number;
    currentApy: number;
  }> {
    console.log(`[NEARIntents] Getting RHEA Finance balance for NEAR account ${nearAccountId}`);
    
    try {
      // Try to get user's actual LP positions from indexer
      const userPools = await refIndexerService.getUserLiquidityPools(nearAccountId);
      
      if (userPools.length > 0) {
        // Calculate total value from user's LP positions
        let totalValue = 0;
        for (const pool of userPools) {
          totalValue += parseFloat(pool.tvl) * 
            (parseFloat(pool.user_shares) / parseFloat(pool.shares_total_supply));
        }
        
        const protocolInfo = await this.getRefProtocolInfo();
        // Estimate earnings based on time (would need actual deposit tracking)
        const estimatedEarnings = totalValue * 0.02; // ~2% estimated earnings
        
        return {
          principal: totalValue - estimatedEarnings,
          currentBalance: totalValue,
          earnings: estimatedEarnings,
          currentApy: protocolInfo.currentApy,
        };
      }
    } catch (error) {
      console.error('[NEARIntents] Failed to get pool balance from indexer:', error);
    }
    
    // Fallback: simulate based on protocol APY
    const protocolInfo = await this.getRefProtocolInfo();
    const principal = 1.0;
    const dailyRate = protocolInfo.currentApy / 365 / 100;
    const daysActive = 7;
    const earnings = principal * dailyRate * daysActive;
    
    return {
      principal,
      currentBalance: principal + earnings,
      earnings,
      currentApy: protocolInfo.currentApy,
    };
  }
}

export default NEARIntentsService;
