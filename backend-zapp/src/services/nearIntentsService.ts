/**
 * NEAR Intents Service
 * Handles Zcash  NEAR bridge address generation using SwapKit and internal
 * simulation helpers.
 * Integrates with RHEA Finance indexer/SDK for APY data and LP simulation.
 * 
 * Bridge sources (current implementation):
 * - SwapKit (mainnet / testnet simulation)
 * - Internal simulated data (development/testing)
 * 
 * Flow (current implementation): Zcash  simulated bridge  simulated nZEC
 * on NEAR  simulated RHEA LP.
 */

import { RefFinanceService } from './refFinanceService';
import { refIndexerService } from './refIndexerService';
import { swapKitService } from './swapKitService';
import type { 
  BridgeTransaction, 
  BridgeDepositInfo, 
  BridgeTxStatus, 
  LendingProtocolInfo,
  FinalizeDepositInput,
  FinalizeDepositResult,
} from '../types/earn';

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
   * Get bridge deposit address for ZEC  NEAR
   *
   * Uses SwapKit when configured (handles mainnet and testnet simulation) and
   * falls back to internal simulated data when unavailable.
   */
  static async getBridgeDepositAddress(
    userZcashAddress: string,
    zecAmount: number,
  ): Promise<BridgeDepositInfo> {
    const intentId = this.generateIntentId();
    
    // Use SwapKit when configured (handles mainnet and testnet simulation)
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
    
    // Final fallback to simulated data
    console.warn('[NEARIntents] Using fallback simulated bridge info');
    return this.getFallbackBridgeInfo(zecAmount, intentId);
  }
  
  /**
   * Finalize a deposit after ZEC has been sent and confirmed
   *
   * Reserved for future bridge implementations that require explicit
   * finalization. In the current simulation-only implementation this always
   * returns an error.
   *
   * @param input - The finalization input including userWalletAddress (Zcash)
   * @param depositArgs - The deposit args from the original deposit preparation
   */
  static async finalizeDeposit(_input: FinalizeDepositInput, _depositArgs: string): Promise<FinalizeDepositResult> {
    // In the current implementation we only support simulated deposits and do not
    // perform real on-chain bridge finalization.
    return {
      success: false,
      error: 'Deposit finalization is not supported in simulation mode',
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
    console.log(`[NEARIntents] (Simulated) Depositing ${amount} to RHEA Finance pool ${poolId} for account ${accountId}`);

    const protocolInfo = await this.getRefProtocolInfo();

    let poolApy = protocolInfo.currentApy;

    // Try to refine APY using pool-specific data when poolId is numeric
    try {
      const parsed = Number(poolId);
      if (!Number.isNaN(parsed)) {
        const apyInfo = await RefFinanceService.getPoolApyEstimate(parsed);
        poolApy = apyInfo.apy;
        console.log(`[NEARIntents] (Simulated) Pool ${poolId} APY estimate: ${poolApy}% (TVL: ${apyInfo.tvl})`);
      }
    } catch (error) {
      console.error('[NEARIntents] Failed to get pool APY estimate:', error);
    }

    // No real NEAR transaction is executed in the current implementation.
    const simulatedHash = `SIM-NEAR-${Date.now().toString(36).toUpperCase()}`;

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
