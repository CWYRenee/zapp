/**
 * Earn Service
 * Manages cross-chain Zcash earning positions via NEAR Intents + RHEA Finance
 * 
 * Flow: Zcash → NEAR Intents Bridge → RHEA Finance (LP/Swap) → Bridge → Shielded Zcash
 */

import { EarnPosition, type EarnPositionDocument } from '../models/EarnPosition';
import { NEARIntentsService } from './nearIntentsService';
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
} from '../types/earn';

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
    const { userWalletAddress, zecAmount, metadata, poolId } = input;
    
    // Validate address
    if (!NEARIntentsService.isValidZcashAddress(userWalletAddress)) {
      throw new Error('Invalid Zcash wallet address');
    }
    if (zecAmount <= 0) {
      throw new Error('Amount must be greater than zero');
    }
    
    // Get current protocol info
    const protocolInfo = await NEARIntentsService.getRefProtocolInfo();
    
    // Get bridge deposit info (SwapKit / simulated fallback)
    const bridgeInfo = await NEARIntentsService.getBridgeDepositAddress(userWalletAddress, zecAmount);
    
    // Merge metadata with selected pool information (if provided)
    const mergedMetadata: Record<string, unknown> | undefined = metadata || poolId
      ? {
          ...(metadata || {}),
          ...(poolId ? { selectedPoolId: poolId } : {}),
        }
      : metadata;
    
    // Create position
    const positionId = this.generatePositionId();
    const position = new EarnPosition({
      positionId,
      userWalletAddress,
      zecAmountDeposited: zecAmount,
      nearAmount: 0,
      currentValue: 0,
      accruedInterest: 0,
      bridgeDepositAddress: bridgeInfo.bridgeAddress,
      nearIntentId: bridgeInfo.nearIntentId,
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
    
    // Automatically trigger lending activation after bridge completes
    // In production, this would be handled by a webhook from NEAR Intents
    setTimeout(async () => {
      await this.activateLending(positionId);
    }, 5000); // Simulate bridge delay
    
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
   * Initiate withdrawal back to shielded Zcash
   */
  static async initiateWithdrawal(input: InitiateWithdrawalInput): Promise<EarnPositionDocument | null> {
    const { positionId, userWalletAddress, withdrawToAddress, withdrawAll, partialAmount } = input;
    
    const position = await EarnPosition.findOne({ positionId, userWalletAddress });
    if (!position) return null;
    
    if (position.status !== 'lending_active') {
      throw new Error('Position is not active for withdrawal');
    }
    
    // Validate withdrawal address
    if (!NEARIntentsService.isValidZcashAddress(withdrawToAddress)) {
      throw new Error('Invalid withdrawal address');
    }
    
    // Calculate withdrawal amount
    const withdrawAmount = withdrawAll ? position.currentValue : (partialAmount || position.currentValue);
    
    if (withdrawAmount > position.currentValue) {
      throw new Error('Withdrawal amount exceeds available balance');
    }
    
    // In the current implementation we simulate LP withdrawals and do not use a real NEAR account.
    const accountId = position.userWalletAddress;
    const refResult = await NEARIntentsService.withdrawFromPool(
      accountId,
      withdrawAmount,
    );
    
    if (!refResult.success) {
      throw new Error('Failed to withdraw from RHEA Finance');
    }
    
    // Create withdrawal bridge transaction
    const bridgeTx = await NEARIntentsService.initiateBridgeToZcash(
      withdrawToAddress,
      refResult.withdrawnAmount,
    );
    
    position.withdrawalBridgeTx = bridgeTx;
    position.withdrawToAddress = withdrawToAddress;
    position.withdrawalInitiatedAt = new Date();
    position.status = 'bridging_to_zcash';
    
    this.appendStatus(
      position,
      'bridging_to_zcash',
      `Withdrawing ${withdrawAmount} ZEC to shielded wallet`,
      refResult.nearTxHash,
    );
    
    await position.save();
    
    console.log(`[EarnService] Withdrawal initiated for ${positionId}`);
    
    // Simulate bridge completion
    setTimeout(async () => {
      await this.markCompleted(positionId, `ZEC-${Date.now().toString(36).toUpperCase()}`, withdrawAmount);
    }, 5000);
    
    return position;
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
