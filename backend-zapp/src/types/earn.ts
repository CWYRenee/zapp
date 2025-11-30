/**
 * Earn Feature Types
 * Types for Zcash lending via NEAR Intents + RHEA
 * 
 * Flow: Zcash (lightwalletd) → NEAR Intents Bridge → RHEA Lending
 */

// Earn Position Statuses
export const EARN_POSITION_STATUSES = [
  'pending_deposit',      // User initiated deposit, awaiting ZEC at bridge
  'bridging_to_near',     // ZEC sent to bridge, waiting for NEAR tokens
  'lending_active',       // Funds actively earning on RHEA
  'pending_withdrawal',   // User initiated withdrawal
  'bridging_to_zcash',    // Funds sent back through bridge to Zcash
  'completed',            // Funds returned to shielded Zcash
  'failed',               // Transaction failed
  'cancelled',            // User cancelled
] as const;

export type EarnPositionStatus = (typeof EARN_POSITION_STATUSES)[number];

// Bridge Transaction Status
export const BRIDGE_TX_STATUSES = [
  'pending',
  'processing',
  'completed',
  'failed',
] as const;

export type BridgeTxStatus = (typeof BRIDGE_TX_STATUSES)[number];

// NEAR Transaction Status
export const NEAR_TX_STATUSES = [
  'pending',
  'included',
  'executed',
  'failed',
] as const;

export type NearTxStatus = (typeof NEAR_TX_STATUSES)[number];

/**
 * Status history entry for position state changes
 */
export interface EarnStatusHistoryEntry {
  status: EarnPositionStatus;
  timestamp: Date;
  note?: string;
  txHash?: string;
}

/**
 * Bridge transaction record (NEAR Intents)
 */
export interface BridgeTransaction {
  bridgeTxId: string;
  direction: 'zcash_to_near' | 'near_to_zcash';
  status: BridgeTxStatus;
  sourceAddress: string;
  destinationAddress: string;
  zecAmount: number;
  nearAmount?: number | undefined;            // Equivalent NEAR/token amount
  nearIntentId: string;
  zcashTxHash?: string;
  nearTxHash?: string;
  createdAt: Date;
  completedAt?: Date;
}

/**
 * Lending position on RHEA (RHEA Finance)
 */
export interface LendingPosition {
  nearAccountId: string;          // NEAR account for lending
  protocolName: string;           // "RHEA" or "RHEA Finance"
  poolId: string;
  principalAmount: number;        // Amount deposited
  currentAmount: number;          // Principal + accrued interest
  accruedInterest: number;
  apySnapshot: number;            // APY at time of deposit
  currentApy: number;             // Current live APY
  depositedAt: Date;
  lastUpdatedAt: Date;
}

/**
 * Input for creating a new earn position
 */
export interface CreateEarnPositionInput {
  userWalletAddress: string;      // Zcash shielded address
  zecAmount: number;              // Amount in ZEC to deposit
  /** Optional RHEA pool ID selected by the user */
  poolId?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Input for initiating withdrawal
 */
export interface InitiateWithdrawalInput {
  positionId: string;
  userWalletAddress: string;
  withdrawToAddress: string;      // Zcash shielded address for withdrawal
  withdrawAll: boolean;           // Withdraw full balance including interest
  partialAmount?: number | undefined;
}

/**
 * Earn position summary for API responses
 */
export interface EarnPositionSummary {
  positionId: string;
  status: EarnPositionStatus;
  zecDeposited: number;
  currentValue: number;           // Current value in ZEC equivalent
  accruedEarnings: number;
  currentApy: number;
  depositedAt?: Date | undefined;
  lastUpdatedAt: Date;
}

/**
 * Bridge deposit info returned to user
 */
export interface BridgeDepositInfo {
  bridgeAddress: string;          // Zcash address to send funds
  expectedAmount: number;         // Expected amount after fees
  estimatedArrivalMinutes: number;
  bridgeFeePercent: number;
  nearIntentId: string;
  /** Whether this is a simulated testnet address (not real) */
  isSimulated: boolean;
  /** Source of the bridge address (SwapKit, testnet simulation, or fallback) */
  source: 'swapkit_api' | 'testnet_simulation' | 'fallback';
  /** 
   * Optional opaque payload reserved for future bridge finalization.
   * Not used in the current simulation-only implementation.
   */
  depositArgs?: string;
  /** Minimum deposit amount in ZEC */
  minDepositZec?: number;
}

/**
 * Input for finalizing a bridge deposit
 */
export interface FinalizeDepositInput {
  /** Position ID to finalize */
  positionId: string;
  /** User's wallet address */
  userWalletAddress: string;
  /** Zcash transaction hash */
  zcashTxHash: string;
  /** Output index in the Zcash transaction (usually 0 or 1) */
  vout: number;
}

/**
 * Result from finalizing a deposit
 */
export interface FinalizeDepositResult {
  /** Whether finalization was successful */
  success: boolean;
  /** NEAR transaction hash */
  nearTxHash?: string;
  /** Amount of nZEC received */
  nZecAmount?: string;
  /** Error message if failed */
  error?: string;
  /** Explorer URL for NEAR tx */
  explorerUrl?: string;
}

/**
 * RHEA Protocol lending info
 */
export interface LendingProtocolInfo {
  protocolName: string;           // "RHEA"
  poolId: string;
  currentApy: number;
  totalValueLocked: number;
  minDeposit: number;
  maxDeposit: number;
  withdrawalFeePercent: number;
  isActive: boolean;
}

/**
 * NEAR Intents bridge health
 */
export interface BridgeHealth {
  isOperational: boolean;
  estimatedDelayMinutes: number;
  message?: string;
}

/**
 * APY history point for charts
 */
export interface ApyHistoryPoint {
  timestamp: Date;
  apy: number;
}

/**
 * Earnings history for a position
 */
export interface EarningsHistoryPoint {
  timestamp: Date;
  balance: number;
  earnings: number;
}

/**
 * User aggregate stats
 */
export interface UserEarnStats {
  totalDeposited: number;
  totalCurrentValue: number;
  totalEarnings: number;
  activePositions: number;
  completedPositions: number;
}
