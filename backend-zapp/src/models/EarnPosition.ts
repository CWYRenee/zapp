import { Schema, model, type Document } from 'mongoose';
import {
  EARN_POSITION_STATUSES,
  BRIDGE_TX_STATUSES,
  type EarnPositionStatus,
  type EarnStatusHistoryEntry,
  type BridgeTransaction,
  type LendingPosition,
} from '../types/earn.js';

/**
 * Earn Position Document
 * Tracks a user's lending position via NEAR Intents + RHEA
 */
export interface EarnPositionDocument extends Document {
  positionId: string;
  userWalletAddress: string;           // Zcash shielded address
  
  // Amounts
  zecAmountDeposited: number;          // Original ZEC deposited
  nearAmount: number;                  // Amount on NEAR/RHEA
  currentValue: number;                // Current value including interest (in ZEC equivalent)
  accruedInterest: number;             // Interest earned
  
  // Bridge transactions (NEAR Intents)
  depositBridgeTx?: BridgeTransaction;
  withdrawalBridgeTx?: BridgeTransaction;
  
  // Lending position on RHEA
  lendingPosition?: LendingPosition;
  
  // Addresses for the flow
  bridgeDepositAddress?: string;       // Where user sends ZEC (NEAR Intents bridge)
  withdrawToAddress?: string;          // Where to return ZEC (shielded)
  nearIntentId?: string;               // NEAR Intent tracking ID
  
  // APY tracking
  depositApy: number;                  // APY at deposit time
  currentApy: number;                  // Live APY from RHEA
  
  // Status
  status: EarnPositionStatus;
  statusHistory: EarnStatusHistoryEntry[];
  
  // Protocol info
  protocolName: string;                // "RHEA"
  poolId: string;
  
  // Metadata
  metadata?: Record<string, unknown>;
  
  // Timestamps
  depositInitiatedAt?: Date;
  lendingStartedAt?: Date;
  withdrawalInitiatedAt?: Date;
  completedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const BridgeTransactionSchema = new Schema<BridgeTransaction>(
  {
    bridgeTxId: { type: String, required: true },
    direction: {
      type: String,
      enum: ['zcash_to_near', 'near_to_zcash'],
      required: true,
    },
    status: {
      type: String,
      enum: BRIDGE_TX_STATUSES,
      required: true,
    },
    sourceAddress: { type: String, required: true },
    destinationAddress: { type: String, required: true },
    zecAmount: { type: Number, required: true, min: 0 },
    nearAmount: { type: Number, min: 0 },
    nearIntentId: { type: String, required: true },
    zcashTxHash: { type: String },
    nearTxHash: { type: String },
    createdAt: { type: Date, required: true, default: Date.now },
    completedAt: { type: Date },
  },
  { _id: false }
);

const LendingPositionSchema = new Schema<LendingPosition>(
  {
    nearAccountId: { type: String, required: true },
    protocolName: { type: String, required: true },
    poolId: { type: String, required: true },
    principalAmount: { type: Number, required: true, min: 0 },
    currentAmount: { type: Number, required: true, min: 0 },
    accruedInterest: { type: Number, required: true, min: 0, default: 0 },
    apySnapshot: { type: Number, required: true, min: 0 },
    currentApy: { type: Number, required: true, min: 0 },
    depositedAt: { type: Date, required: true },
    lastUpdatedAt: { type: Date, required: true },
  },
  { _id: false }
);

const StatusHistorySchema = new Schema<EarnStatusHistoryEntry>(
  {
    status: {
      type: String,
      enum: EARN_POSITION_STATUSES,
      required: true,
    },
    timestamp: {
      type: Date,
      required: true,
      default: Date.now,
    },
    note: { type: String, trim: true },
    txHash: { type: String, trim: true },
  },
  { _id: false }
);

const EarnPositionSchema = new Schema<EarnPositionDocument>(
  {
    positionId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    userWalletAddress: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    zecAmountDeposited: {
      type: Number,
      required: true,
      min: 0,
    },
    nearAmount: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    currentValue: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    accruedInterest: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    depositBridgeTx: BridgeTransactionSchema,
    withdrawalBridgeTx: BridgeTransactionSchema,
    lendingPosition: LendingPositionSchema,
    bridgeDepositAddress: {
      type: String,
      trim: true,
    },
    withdrawToAddress: {
      type: String,
      trim: true,
    },
    nearIntentId: {
      type: String,
      trim: true,
    },
    depositApy: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    currentApy: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    status: {
      type: String,
      enum: EARN_POSITION_STATUSES,
      required: true,
      index: true,
    },
    statusHistory: {
      type: [StatusHistorySchema],
      default: [],
    },
    protocolName: {
      type: String,
      required: true,
      default: 'RHEA Finance',
    },
    poolId: {
      type: String,
      required: true,
      default: 'zec-lending-pool',
    },
    metadata: {
      type: Schema.Types.Mixed,
    },
    depositInitiatedAt: Date,
    lendingStartedAt: Date,
    withdrawalInitiatedAt: Date,
    completedAt: Date,
  },
  {
    timestamps: true,
    collection: 'earn_positions',
  }
);

// Compound indexes for common queries
EarnPositionSchema.index({ userWalletAddress: 1, status: 1 });
EarnPositionSchema.index({ nearIntentId: 1 });
EarnPositionSchema.index({ status: 1, createdAt: -1 });

export const EarnPosition = model<EarnPositionDocument>('EarnPosition', EarnPositionSchema);
