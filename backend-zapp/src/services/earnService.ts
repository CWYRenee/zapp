/**
 * Earn Service
 * Manages cross-chain Zcash earning positions via NEAR Intents + RHEA Finance
 * 
 * Flow: Zcash → NEAR Intents Bridge → RHEA Finance (LP/Swap) → Bridge → Shielded Zcash
 */

import { EarnPosition, type EarnPositionDocument } from '../models/EarnPosition.js';
import { NEARIntentsService } from './nearIntentsService.js';
import OmniBridgeService from './omniBridgeService.js';
import {
  type EarnPositionStatus,
  type EarnStatusHistoryEntry,
  type CreateEarnPositionInput,
  type InitiateWithdrawalInput,
  type EarnPositionSummary,
  type BridgeDepositInfo,
  type LendingProtocolInfo,
  type EarningsHistoryPoint,
  type UserEarnStats,
} from '../types/earn.js';

export class EarnService {
  /**
   * Generate a unique position ID
   */
  private static generatePositionId(): string {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `EARN-${timestamp}-${random}`;
  }

  /**
   * Append a status entry to position history
   */
  private static appendStatus(
    position: EarnPositionDocument,
    status: EarnPositionStatus,
    note?: string,
    txHash?: string,
  ): void {
    const entry: EarnStatusHistoryEntry = {
      status,
      timestamp: new Date(),
    };
    if (note) entry.note = note;
    if (txHash) entry.txHash = txHash;
    
    position.statusHistory.push(entry);
  }

  // ============================================================================
  // PROTOCOL INFO
  // ============================================================================

  /**
   * Get RHEA Finance protocol info with current APY
   */
  static async getProtocolInfo(): Promise<LendingProtocolInfo> {
    return NEARIntentsService.getRefProtocolInfo();
  }

  /**
   * Get APY history for charts
   */
  static async getApyHistory(days: number = 30): Promise<Array<{ timestamp: Date; apy: number }>> {
    return NEARIntentsService.getApyHistory(days);
  }

  // ============================================================================
  // DEPOSIT FLOW
  // ============================================================================

  /**
   * Get bridge deposit info for initiating a deposit
   * Returns the bridge address to send ZEC to
   */
  static async getBridgeDepositInfo(
    userZcashAddress: string,
    zecAmount: number,
  ): Promise<BridgeDepositInfo> {
    // Validate inputs
    if (!NEARIntentsService.isValidZcashAddress(userZcashAddress)) {
      throw new Error('Invalid Zcash address');
    }
    
    if (zecAmount <= 0) {
      throw new Error('Amount must be greater than zero');
    }
    
    // Get protocol info for min/max checks
    const protocolInfo = await NEARIntentsService.getRefProtocolInfo();
    if (zecAmount < protocolInfo.minDeposit) {
      throw new Error(`Minimum deposit is ${protocolInfo.minDeposit} ZEC`);
    }
    if (zecAmount > protocolInfo.maxDeposit) {
      throw new Error(`Maximum deposit is ${protocolInfo.maxDeposit} ZEC`);
    }
    
    // Get bridge deposit address from NEAR Intents
    return NEARIntentsService.getBridgeDepositAddress(userZcashAddress, zecAmount);
  }

  /**
   * Create a new earn position after user sends ZEC to bridge
   */
  static async createPosition(input: CreateEarnPositionInput): Promise<EarnPositionDocument> {
    const { userWalletAddress, zecAmount, metadata, poolId, bridgeInfo } = input;
    
    // Validate address
    if (!NEARIntentsService.isValidZcashAddress(userWalletAddress)) {
      throw new Error('Invalid Zcash wallet address');
    }
    if (zecAmount <= 0) {
      throw new Error('Amount must be greater than zero');
    }
    
    // Get current protocol info (for APY and min/max config)
    const protocolInfo = await NEARIntentsService.getRefProtocolInfo();
    
    // Reuse the bridge info provided by the frontend when available so that
    // the bridge address and NEAR intent exactly match what the wallet used
    // when sending ZEC/TAZ. Fallback to generating a new bridge address only
    // if no bridge info was provided (e.g. legacy clients).
    const effectiveBridgeInfo = bridgeInfo
      ?? await NEARIntentsService.getBridgeDepositAddress(userWalletAddress, zecAmount);
    
    // Build pending deposit info for the automated watcher
    // This is stored in metadata and used by bridgeDepositWatcher
    const pendingDeposit = {
      bridgeAddress: effectiveBridgeInfo.bridgeAddress,
      depositArgs: effectiveBridgeInfo.depositArgs || '',
      nearAccountId: effectiveBridgeInfo.nearAccountId || '',
      minDepositZec: effectiveBridgeInfo.minDepositZec || protocolInfo.minDeposit,
      expectedAmount: effectiveBridgeInfo.expectedAmount,
      createdAt: new Date().toISOString(),
    };
    
    // Merge metadata with selected pool information and pending deposit
    const mergedMetadata: Record<string, unknown> = {
      ...(metadata || {}),
      ...(poolId ? { selectedPoolId: poolId } : {}),
      // Store pending deposit info for the watcher
      pendingDeposit,
    };
    
    // Create position
    const positionId = this.generatePositionId();
    const position = new EarnPosition({
      positionId,
      userWalletAddress,
      zecAmountDeposited: zecAmount,
      nearAmount: 0,
      currentValue: 0,
      accruedInterest: 0,
      bridgeDepositAddress: effectiveBridgeInfo.bridgeAddress,
      nearIntentId: effectiveBridgeInfo.nearIntentId,
      depositApy: protocolInfo.currentApy,
      currentApy: protocolInfo.currentApy,
      status: 'pending_deposit',
      protocolName: 'RHEA Finance',
      // Use user-selected pool if provided, otherwise default protocol pool
      poolId: poolId || protocolInfo.poolId,
      depositInitiatedAt: new Date(),
      metadata: mergedMetadata,
    });
    
    this.appendStatus(position, 'pending_deposit', 'Position created, awaiting ZEC deposit');
    
    await position.save();
    
    console.log(`[EarnService] Created position ${positionId} for ${userWalletAddress}`);
    
    return position;
  }

  // ============================================================================
  // STATUS UPDATES (called by webhooks/automation)
  // ============================================================================

  /**
   * Mark that ZEC has been received at the bridge
   * Triggers automatic deposit to RHEA
   */
  static async markBridgeDepositReceived(
    positionId: string,
    zcashTxHash: string,
    nearAmountFromBridge?: number,
  ): Promise<EarnPositionDocument | null> {
    const position = await EarnPosition.findOne({ positionId });
    if (!position) return null;
    
    // Create bridge transaction record
    position.depositBridgeTx = {
      bridgeTxId: `BRIDGE-${Date.now().toString(36).toUpperCase()}`,
      direction: 'zcash_to_near',
      status: 'processing',
      sourceAddress: position.userWalletAddress,
      destinationAddress: 'rhea.near',
      zecAmount: position.zecAmountDeposited,
      // Record the actual minted nZEC amount from the bridge if available
      nearAmount: nearAmountFromBridge,
      nearIntentId: position.nearIntentId || '',
      zcashTxHash,
      createdAt: new Date(),
    };
    
    position.status = 'bridging_to_near';
    this.appendStatus(position, 'bridging_to_near', 'ZEC received, bridging to NEAR', zcashTxHash);
    
    await position.save();
    
    console.log(`[EarnService] Bridge deposit received for ${positionId}`);
    
    // Note: For real bridging, activateLending is called immediately after finalization
    // in earnRoutes.ts. The setTimeout below is only for simulated mode fallback.
    // In production, this would be handled by a webhook from NEAR Intents.
    
    return position;
  }

  /**
   * Activate earning on RHEA Finance after bridge completes
   */
  static async activateLending(positionId: string): Promise<EarnPositionDocument | null> {
    const position = await EarnPosition.findOne({ positionId });
    if (!position) return null;
    
    // Determine amount available on NEAR for lending
    // Prefer the actual minted nZEC amount from the bridge transaction if present,
    // otherwise fall back to an estimated amount based on bridge fee.
    let nearAmount: number;
    if (position.depositBridgeTx?.nearAmount && position.depositBridgeTx.nearAmount > 0) {
      nearAmount = position.depositBridgeTx.nearAmount;
    } else {
      const feeInfo = NEARIntentsService.estimateBridgeFee(position.zecAmountDeposited);
      nearAmount = feeInfo.netAmount;
    }
    
    // In the current implementation we simulate the LP deposit and do not use a real NEAR account.
    const accountId = position.userWalletAddress;
    const depositResult = await NEARIntentsService.depositToPool(
      accountId,
      nearAmount,
      position.poolId,
    );
    
    if (!depositResult.success) {
      position.status = 'failed';
      this.appendStatus(position, 'failed', 'Failed to deposit to RHEA Finance');
      await position.save();
      return position;
    }
    
    // Update position with RHEA Finance lending info
    position.nearAmount = nearAmount;
    position.currentValue = nearAmount;
    position.currentApy = depositResult.currentApy;
    position.lendingStartedAt = new Date();
    position.status = 'lending_active';
    
    position.lendingPosition = {
      nearAccountId: accountId,
      protocolName: 'RHEA Finance',
      poolId: position.poolId,
      principalAmount: nearAmount,
      currentAmount: nearAmount,
      accruedInterest: 0,
      apySnapshot: depositResult.currentApy,
      currentApy: depositResult.currentApy,
      depositedAt: new Date(),
      lastUpdatedAt: new Date(),
    };
    
    // Update bridge tx status
    if (position.depositBridgeTx) {
      position.depositBridgeTx.status = 'completed';
      position.depositBridgeTx.nearAmount = nearAmount;
      if (depositResult.nearTxHash) {
        position.depositBridgeTx.nearTxHash = depositResult.nearTxHash;
      }
      position.depositBridgeTx.completedAt = new Date();
    }
    
    this.appendStatus(
      position,
      'lending_active',
      `Deposited to RHEA Finance at ${depositResult.currentApy}% APY`,
      depositResult.nearTxHash,
    );
    
    await position.save();
    
    console.log(`[EarnService] Lending activated for ${positionId}`);
    
    return position;
  }

  /**
   * Update interest/earnings for a position
   * Called periodically to sync with RHEA Finance
   */
  static async updatePositionEarnings(positionId: string): Promise<EarnPositionDocument | null> {
    const position = await EarnPosition.findOne({ positionId });
    if (!position || position.status !== 'lending_active') return null;
    
    if (!position.lendingStartedAt || position.nearAmount <= 0) {
      return position;
    }
    
    // Simulate earnings growth based on current protocol APY and time elapsed
    const protocolInfo = await NEARIntentsService.getRefProtocolInfo();
    const now = Date.now();
    const startTime = position.lendingStartedAt.getTime();
    const dayMs = 24 * 60 * 60 * 1000;
    const daysElapsed = Math.max(0, (now - startTime) / dayMs);
    
    const principal = position.nearAmount;
    const dailyRate = protocolInfo.currentApy / 365 / 100;
    const earnings = principal * dailyRate * daysElapsed;
    const currentBalance = principal + earnings;
    
    position.currentValue = currentBalance;
    position.accruedInterest = earnings;
    position.currentApy = protocolInfo.currentApy;
    
    if (position.lendingPosition) {
      position.lendingPosition.currentAmount = currentBalance;
      position.lendingPosition.accruedInterest = earnings;
      position.lendingPosition.currentApy = protocolInfo.currentApy;
      position.lendingPosition.lastUpdatedAt = new Date();
    }
    
    await position.save();
    
    return position;
  }

  // ============================================================================
  // WITHDRAWAL FLOW
  // ============================================================================

  /**
   * Initiate withdrawal back to shielded Zcash (unified address)
   */
  static async initiateWithdrawal(input: InitiateWithdrawalInput): Promise<EarnPositionDocument | null> {
    const { positionId, userWalletAddress, withdrawToAddress, withdrawAll, partialAmount } = input;
    
    const position = await EarnPosition.findOne({ positionId, userWalletAddress });
    if (!position) return null;
    
    if (position.status !== 'lending_active') {
      throw new Error('Position is not active for withdrawal');
    }
    
    // Validate withdrawal address (supports unified addresses)
    if (!NEARIntentsService.isValidTransparentZcashAddress(withdrawToAddress)) {
      throw new Error('Invalid Zcash withdrawal address');
    }
    
    // Calculate withdrawal amount in ZEC
    const withdrawAmount = withdrawAll ? position.currentValue : (partialAmount || position.currentValue);
    
    if (withdrawAmount > position.currentValue) {
      throw new Error('Withdrawal amount exceeds available balance');
    }
    
    console.log(`[EarnService] Initiating withdrawal for ${positionId}:`);
    console.log(`  Amount: ${withdrawAmount} ZEC`);
    console.log(`  To: ${withdrawToAddress}`);
    
    // Step 1: Withdraw from RHEA Finance pool
    const refResult = await NEARIntentsService.withdrawFromPool(
      userWalletAddress,
      withdrawAmount,
    );
    
    if (!refResult.success) {
      throw new Error('Failed to withdraw from RHEA Finance pool');
    }
    
    // Step 2: Initiate bridge withdrawal via OmniBridge
    const amountZatoshis = BigInt(Math.floor(refResult.withdrawnAmount * 100_000_000));
    const bridgeResult = await OmniBridgeService.initiateWithdrawal(
      userWalletAddress,
      withdrawToAddress,
      amountZatoshis,
    );
    
    if (!bridgeResult.success) {
      throw new Error(`Failed to initiate bridge withdrawal: ${bridgeResult.error}`);
    }
    
    // Update position with withdrawal info
    const withdrawalTx: any = {
      bridgeTxId: bridgeResult.pendingId || `WD-${Date.now().toString(36)}`,
      direction: 'near_to_zcash',
      status: 'pending',
      sourceAddress: position.lendingPosition?.nearAccountId || userWalletAddress,
      destinationAddress: withdrawToAddress,
      zecAmount: refResult.withdrawnAmount,
      nearAmount: refResult.withdrawnAmount,
      nearIntentId: bridgeResult.pendingId || '',
      createdAt: new Date(),
    };
    if (bridgeResult.nearTxHash) {
      withdrawalTx.nearTxHash = bridgeResult.nearTxHash;
    }
    position.withdrawalBridgeTx = withdrawalTx;
    position.withdrawToAddress = withdrawToAddress;
    position.withdrawalInitiatedAt = new Date();
    position.status = 'bridging_to_zcash';
    
    // Store pending withdrawal info for watcher
    position.metadata = {
      ...(position.metadata || {}),
      pendingWithdrawal: {
        pendingId: bridgeResult.pendingId,
        nearTxHash: bridgeResult.nearTxHash,
        targetAddress: withdrawToAddress,
        amountZatoshis: amountZatoshis.toString(),
        initiatedAt: new Date().toISOString(),
        estimatedCompletionMinutes: bridgeResult.estimatedCompletionMinutes,
      },
    };
    
    this.appendStatus(
      position,
      'bridging_to_zcash',
      `Withdrawing ${withdrawAmount.toFixed(6)} ZEC to ${withdrawToAddress.slice(0, 20)}...`,
      bridgeResult.nearTxHash,
    );
    
    await position.save();
    
    console.log(`[EarnService] ✓ Withdrawal initiated for ${positionId}`);
    console.log(`  Pending ID: ${bridgeResult.pendingId}`);
    console.log(`  Est. completion: ${bridgeResult.estimatedCompletionMinutes} minutes`);
    
    return position;
  }

  /**
   * Process withdrawal signing and finalization (called by watcher or manually)
   */
  static async processWithdrawal(positionId: string): Promise<EarnPositionDocument | null> {
    const position = await EarnPosition.findOne({ positionId });
    if (!position) return null;
    
    if (position.status !== 'bridging_to_zcash') {
      return position;
    }
    
    const pendingWithdrawal = (position.metadata as any)?.pendingWithdrawal;
    if (!pendingWithdrawal?.nearTxHash) {
      console.warn(`[EarnService] No pending withdrawal data for ${positionId}`);
      return position;
    }
    
    try {
      // Finalize the withdrawal (bridge handles signing internally)
      const finalizeResult = await OmniBridgeService.finalizeWithdrawal(
        position.userWalletAddress,
        pendingWithdrawal.nearTxHash,
      );
      
      if (!finalizeResult.success) {
        console.warn(`[EarnService] Withdrawal finalization pending for ${positionId}: ${finalizeResult.error}`);
        return position;
      }
      
      // Mark as completed
      return await this.markCompleted(
        positionId,
        finalizeResult.zcashTxHash || '',
        position.withdrawalBridgeTx?.zecAmount,
      );
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      console.error(`[EarnService] Withdrawal processing failed for ${positionId}: ${msg}`);
      return position;
    }
  }

  /**
   * Mark position as completed (funds returned to Zcash)
   */
  static async markCompleted(
    positionId: string,
    zcashTxHash: string,
    actualZecReceived?: number,
  ): Promise<EarnPositionDocument | null> {
    const position = await EarnPosition.findOne({ positionId });
    if (!position) return null;
    
    position.status = 'completed';
    position.completedAt = new Date();
    
    if (position.withdrawalBridgeTx) {
      position.withdrawalBridgeTx.status = 'completed';
      position.withdrawalBridgeTx.zcashTxHash = zcashTxHash;
      position.withdrawalBridgeTx.completedAt = new Date();
      if (actualZecReceived) {
        position.withdrawalBridgeTx.zecAmount = actualZecReceived;
      }
    }
    
    this.appendStatus(
      position,
      'completed',
      `Funds returned to shielded wallet: ${actualZecReceived || position.currentValue} ZEC`,
      zcashTxHash,
    );
    
    await position.save();
    
    console.log(`[EarnService] Position ${positionId} completed`);
    
    return position;
  }

  // ============================================================================
  // QUERIES
  // ============================================================================

  /**
   * Get a position by ID
   */
  static async getPosition(positionId: string, userWalletAddress: string): Promise<EarnPositionDocument | null> {
    return EarnPosition.findOne({ positionId, userWalletAddress });
  }

  /**
   * Get all positions for a user
   */
  static async getPositionsForUser(
    userWalletAddress: string,
    status?: EarnPositionStatus,
    limit: number = 50,
    skip: number = 0,
  ): Promise<EarnPositionDocument[]> {
    const query: Record<string, unknown> = { userWalletAddress };
    if (status) query.status = status;
    
    return EarnPosition.find(query)
      .sort({ createdAt: -1 })
      .limit(limit)
      .skip(skip);
  }

  /**
   * Get position summary for API response
   */
  static getPositionSummary(position: EarnPositionDocument): EarnPositionSummary {
    return {
      positionId: position.positionId,
      status: position.status,
      zecDeposited: position.zecAmountDeposited,
      currentValue: position.currentValue,
      accruedEarnings: position.accruedInterest,
      currentApy: position.currentApy,
      depositedAt: position.lendingStartedAt,
      lastUpdatedAt: position.updatedAt,
      completedAt: position.completedAt,
      withdrawToAddress: position.withdrawToAddress,
    };
  }

  /**
   * Get user aggregate stats
   */
  static async getUserStats(userWalletAddress: string): Promise<UserEarnStats> {
    const positions = await EarnPosition.find({ userWalletAddress });
    
    const activePositions = positions.filter(p => p.status === 'lending_active');
    const completedPositions = positions.filter(p => p.status === 'completed');
    
    return {
      totalDeposited: positions.reduce((sum, p) => sum + p.zecAmountDeposited, 0),
      totalCurrentValue: activePositions.reduce((sum, p) => sum + p.currentValue, 0),
      totalEarnings: positions.reduce((sum, p) => sum + p.accruedInterest, 0),
      activePositions: activePositions.length,
      completedPositions: completedPositions.length,
    };
  }

  /**
   * Get earnings history for a position
   */
  static async getEarningsHistory(
    positionId: string,
    userWalletAddress: string,
    days: number = 30,
  ): Promise<EarningsHistoryPoint[]> {
    const position = await EarnPosition.findOne({ positionId, userWalletAddress });
    if (!position || !position.lendingStartedAt) {
      return [];
    }
    
    // Generate historical earnings data
    // In production, this would come from actual on-chain data
    const history: EarningsHistoryPoint[] = [];
    const now = Date.now();
    const startTime = position.lendingStartedAt.getTime();
    const dayMs = 24 * 60 * 60 * 1000;
    
    const principal = position.nearAmount;
    const dailyRate = position.currentApy / 365 / 100;
    
    for (let i = days; i >= 0; i--) {
      const timestamp = new Date(now - i * dayMs);
      if (timestamp.getTime() < startTime) continue;
      
      const daysElapsed = (timestamp.getTime() - startTime) / dayMs;
      const earnings = principal * dailyRate * daysElapsed;
      
      history.push({
        timestamp,
        balance: principal + earnings,
        earnings,
      });
    }
    
    return history;
  }
}
