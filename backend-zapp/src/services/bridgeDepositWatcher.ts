/**
 * Bridge Deposit Watcher Service
 * 
 * Monitors pending bridge deposits and automatically:
 * 1. Detects when ZEC arrives at the bridge address
 * 2. Finalizes the deposit on NEAR (mints nZEC)
 * 3. Activates lending on RHEA Finance
 * 
 * This eliminates the need for users to manually enter TX hash and vout.
 */

import { EarnPosition, type EarnPositionDocument } from '../models/EarnPosition.js';
import { ZcashBlockchainService, type DetectedDeposit } from './zcashBlockchainService.js';
import { OmniBridgeService } from './omniBridgeService.js';
import { EarnService } from './earnService.js';
import type { BtcDepositArgs } from 'omni-bridge-sdk';

// Configuration
const WATCH_INTERVAL_MS = parseInt(process.env.DEPOSIT_WATCH_INTERVAL_MS || '30000', 10); // 30 seconds
const MAX_PENDING_AGE_HOURS = parseInt(process.env.MAX_PENDING_AGE_HOURS || '72', 10); // 3 days

/**
 * Pending deposit info stored in position metadata
 */
interface PendingDepositInfo {
  bridgeAddress: string;
  depositArgs: string;           // Base64 encoded BtcDepositArgs
  nearAccountId: string;
  minDepositZec: number;
  expectedAmount: number;
  createdAt: string;             // ISO date string
  watchStartedAt?: string;
  lastCheckedAt?: string;
  checkCount?: number;
}

/**
 * Result of processing a pending deposit
 */
interface ProcessResult {
  positionId: string;
  status: 'no_deposit' | 'pending_confirmations' | 'finalized' | 'lending_active' | 'error';
  deposit?: DetectedDeposit | undefined;
  nearTxHash?: string | undefined;
  error?: string | undefined;
}

/**
 * Watcher statistics
 */
export interface WatcherStats {
  isRunning: boolean;
  lastRunAt: Date | null;
  totalChecks: number;
  depositsDetected: number;
  depositsFinalized: number;
  errors: number;
  pendingPositions: number;
}

class BridgeDepositWatcherService {
  private isRunning = false;
  private intervalId: NodeJS.Timeout | null = null;
  private stats: WatcherStats = {
    isRunning: false,
    lastRunAt: null,
    totalChecks: 0,
    depositsDetected: 0,
    depositsFinalized: 0,
    errors: 0,
    pendingPositions: 0,
  };

  /**
   * Start the deposit watcher
   */
  start(): void {
    if (this.isRunning) {
      console.log('[DepositWatcher] Already running');
      return;
    }

    console.log('[DepositWatcher] Starting deposit watcher...');
    console.log(`[DepositWatcher]   Check interval: ${WATCH_INTERVAL_MS / 1000}s`);
    console.log(`[DepositWatcher]   Max pending age: ${MAX_PENDING_AGE_HOURS}h`);
    console.log(`[DepositWatcher]   Min confirmations: ${ZcashBlockchainService.getMinConfirmations()}`);

    this.isRunning = true;
    this.stats.isRunning = true;

    // Run immediately, then on interval
    this.checkPendingDeposits().catch(console.error);
    
    this.intervalId = setInterval(() => {
      this.checkPendingDeposits().catch(console.error);
    }, WATCH_INTERVAL_MS);

    console.log('[DepositWatcher] ✓ Deposit watcher started');
  }

  /**
   * Stop the deposit watcher
   */
  stop(): void {
    if (!this.isRunning) {
      return;
    }

    console.log('[DepositWatcher] Stopping deposit watcher...');

    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }

    this.isRunning = false;
    this.stats.isRunning = false;

    console.log('[DepositWatcher] ✓ Deposit watcher stopped');
  }

  /**
   * Get watcher statistics
   */
  getStats(): WatcherStats {
    return { ...this.stats };
  }

  /**
   * Check all pending deposits
   */
  private async checkPendingDeposits(): Promise<void> {
    this.stats.totalChecks++;
    this.stats.lastRunAt = new Date();

    try {
      // Find all positions waiting for bridge deposit
      const pendingPositions = await EarnPosition.find({
        status: 'pending_deposit',
        'metadata.pendingDeposit': { $exists: true },
      }).exec();

      this.stats.pendingPositions = pendingPositions.length;

      if (pendingPositions.length === 0) {
        return; // Nothing to check
      }

      console.log(`[DepositWatcher] Checking ${pendingPositions.length} pending deposits...`);

      for (const position of pendingPositions) {
        try {
          const result = await this.processPosition(position);
          
          if (result.status === 'lending_active' || result.status === 'finalized') {
            this.stats.depositsFinalized++;
            console.log(`[DepositWatcher] ✓ Position ${result.positionId} finalized`);
          } else if (result.deposit) {
            this.stats.depositsDetected++;
          }
          
          if (result.error) {
            this.stats.errors++;
          }
        } catch (error) {
          this.stats.errors++;
          const msg = error instanceof Error ? error.message : 'Unknown error';
          console.error(`[DepositWatcher] Error processing ${position.positionId}: ${msg}`);
        }
      }
    } catch (error) {
      this.stats.errors++;
      const msg = error instanceof Error ? error.message : 'Unknown error';
      console.error(`[DepositWatcher] Check failed: ${msg}`);
    }
  }

  /**
   * Process a single pending position
   */
  private async processPosition(position: EarnPositionDocument): Promise<ProcessResult> {
    const positionId = position.positionId;
    const pendingInfo = position.metadata?.pendingDeposit as PendingDepositInfo | undefined;

    if (!pendingInfo) {
      return { positionId, status: 'error', error: 'No pending deposit info' };
    }

    // Check if too old
    const createdAt = new Date(pendingInfo.createdAt);
    const ageHours = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);
    
    if (ageHours > MAX_PENDING_AGE_HOURS) {
      console.log(`[DepositWatcher] Position ${positionId} expired (${ageHours.toFixed(1)}h old)`);
      
      // Mark as cancelled due to timeout
      await this.updatePositionStatus(position, 'cancelled', 'Deposit timeout - no ZEC received');
      return { positionId, status: 'error', error: 'Deposit timeout' };
    }

    // Update check metadata
    await this.updateCheckMetadata(position, pendingInfo);

    // Detect deposits to the bridge address
    const deposits = await ZcashBlockchainService.detectDeposits(
      pendingInfo.bridgeAddress,
      pendingInfo.minDepositZec * 0.99, // Allow 1% variance for fees
    );

    if (deposits.length === 0) {
      return { positionId, status: 'no_deposit' };
    }

    // Find the first confirmed deposit
    const confirmedDeposit = deposits.find(d => d.isConfirmed);
    
    if (!confirmedDeposit) {
      // Found deposit but not enough confirmations yet
      const pending = deposits[0];
      console.log(`[DepositWatcher] Position ${positionId}: Deposit detected, ${pending.confirmations} confirmations (need ${ZcashBlockchainService.getMinConfirmations()})`);
      
      // Update status to bridging
      if (position.status === 'pending_deposit') {
        await this.updatePositionStatus(position, 'bridging_to_near', `ZEC deposit detected, awaiting confirmations (${pending.confirmations}/${ZcashBlockchainService.getMinConfirmations()})`);
      }
      
      return { positionId, status: 'pending_confirmations', deposit: pending };
    }

    // Deposit confirmed! Finalize it
    console.log(`[DepositWatcher] Position ${positionId}: Deposit confirmed!`);
    console.log(`[DepositWatcher]   TX: ${confirmedDeposit.txid}`);
    console.log(`[DepositWatcher]   Vout: ${confirmedDeposit.vout}`);
    console.log(`[DepositWatcher]   Amount: ${confirmedDeposit.amount} ZEC`);

    try {
      // Decode depositArgs
      const depositArgs = JSON.parse(
        Buffer.from(pendingInfo.depositArgs, 'base64').toString('utf-8')
      ) as BtcDepositArgs;

      // Finalize the deposit on NEAR
      const finalizeResult = await OmniBridgeService.finalizeDeposit(
        position.userWalletAddress,
        confirmedDeposit.txid,
        confirmedDeposit.vout,
        depositArgs,
      );

      if (!finalizeResult.success) {
        console.error(`[DepositWatcher] Finalization failed: ${finalizeResult.error}`);
        return { 
          positionId, 
          status: 'error', 
          deposit: confirmedDeposit,
          error: finalizeResult.error,
        };
      }

      console.log(`[DepositWatcher] ✓ Deposit finalized: ${finalizeResult.nearTxHash}`);

      // Update position with bridge tx info
      await this.updateBridgeTransaction(
        position,
        confirmedDeposit.txid,
        finalizeResult.nearTxHash || '',
        confirmedDeposit.amount,
      );

      // Activate lending (deposit to RHEA)
      try {
        const activatedPosition = await EarnService.activateLending(positionId);
        
        if (activatedPosition?.status === 'lending_active') {
          console.log(`[DepositWatcher] ✓ Lending activated for ${positionId}`);
          return { 
            positionId, 
            status: 'lending_active', 
            deposit: confirmedDeposit,
            nearTxHash: finalizeResult.nearTxHash,
          };
        }
      } catch (lendingError) {
        const msg = lendingError instanceof Error ? lendingError.message : 'Unknown error';
        console.warn(`[DepositWatcher] Lending activation failed: ${msg}`);
        // Position is still finalized, just lending didn't activate
      }

      return { 
        positionId, 
        status: 'finalized', 
        deposit: confirmedDeposit,
        nearTxHash: finalizeResult.nearTxHash,
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      console.error(`[DepositWatcher] Error finalizing ${positionId}: ${msg}`);
      return { positionId, status: 'error', deposit: confirmedDeposit, error: msg };
    }
  }

  /**
   * Update position status
   */
  private async updatePositionStatus(
    position: EarnPositionDocument,
    status: string,
    note: string,
  ): Promise<void> {
    position.status = status as any;
    position.statusHistory.push({
      status: status as any,
      timestamp: new Date(),
      note,
    });
    await position.save();
  }

  /**
   * Update check metadata
   */
  private async updateCheckMetadata(
    position: EarnPositionDocument,
    pendingInfo: PendingDepositInfo,
  ): Promise<void> {
    const metadata = position.metadata || {};
    metadata.pendingDeposit = {
      ...pendingInfo,
      lastCheckedAt: new Date().toISOString(),
      checkCount: (pendingInfo.checkCount || 0) + 1,
    };
    position.metadata = metadata;
    position.markModified('metadata');
    await position.save();
  }

  /**
   * Update bridge transaction info
   */
  private async updateBridgeTransaction(
    position: EarnPositionDocument,
    zcashTxHash: string,
    nearTxHash: string,
    amount: number,
  ): Promise<void> {
    position.depositBridgeTx = {
      bridgeTxId: `BRIDGE-${Date.now().toString(36).toUpperCase()}`,
      direction: 'zcash_to_near',
      status: 'completed',
      sourceAddress: position.userWalletAddress,
      destinationAddress: (position.metadata?.pendingDeposit as PendingDepositInfo | undefined)?.nearAccountId || '',
      zecAmount: amount,
      nearIntentId: position.nearIntentId || '',
      zcashTxHash,
      nearTxHash,
      createdAt: new Date(),
      completedAt: new Date(),
    };

    // Update amounts
    position.zecAmountDeposited = amount;
    position.currentValue = amount;

    // Clear pending deposit info since it's now finalized
    if (position.metadata) {
      delete (position.metadata as any).pendingDeposit;
      position.markModified('metadata');
    }

    await position.save();
  }

  /**
   * Manually trigger a check for a specific position
   * Useful for testing or forcing an immediate check
   */
  async checkPosition(positionId: string): Promise<ProcessResult> {
    const position = await EarnPosition.findOne({ positionId }).exec();
    
    if (!position) {
      return { positionId, status: 'error', error: 'Position not found' };
    }

    return this.processPosition(position);
  }
}

// Singleton instance
export const bridgeDepositWatcher = new BridgeDepositWatcherService();

export default bridgeDepositWatcher;
