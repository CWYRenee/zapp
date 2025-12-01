import { Schema, model, type Document } from 'mongoose';
import {
  ZAP_ORDER_STATUSES,
  type ZapOrderStatus,
  type StatusHistoryEntry,
} from '../types/order.js';
import type { PaymentRailType } from '../types/facilitator.js';

export interface ZapOrderDocument extends Document {
  orderId: string;
  userWalletAddress: string;
  merchantCode: string;
  merchantName?: string;
  fiatAmount: number;
  fiatCurrency: string;
  paymentRail: PaymentRailType;
  zecAmount: number;
  exchangeRate: number;
  // Spread-related fields
  baseExchangeRate?: number;
  userDisplayRate?: number;
  merchantDisplayRate?: number;
  merchantZecAmount?: number;
  platformZecAmount?: number;
  platformZecAddress?: string;
  merchantId?: string;
  merchantZecAddress?: string;
  fiatPaymentReference?: string;
  zecTxHash?: string;
  scannedQRCodeData?: string;
  // Batch/Group order fields
  batchId?: string;
  groupId?: string;              // Links orders that must be accepted together
  groupExpiresAt?: Date;         // When grouped orders split into individuals (10s timeout)
  targetMerchantId?: string;     // Facilitator who can handle all rails in the group
  status: ZapOrderStatus;
  statusHistory: StatusHistoryEntry[];
  metadata?: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

const StatusHistorySchema = new Schema<StatusHistoryEntry>(
  {
    status: {
      type: String,
      enum: ZAP_ORDER_STATUSES,
      required: true,
    },
    timestamp: {
      type: Date,
      required: true,
      default: Date.now,
    },
    note: {
      type: String,
      trim: true,
    },
  },
  { _id: false }
);

const ZapOrderSchema = new Schema<ZapOrderDocument>(
  {
    orderId: {
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
    merchantCode: {
      type: String,
      required: true,
      trim: true,
    },
    merchantName: {
      type: String,
      trim: true,
    },
    fiatAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    fiatCurrency: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    paymentRail: {
      type: String,
      enum: ['upi', 'alipay', 'wechat_pay', 'pix', 'promptpay'],
      required: true,
      index: true,
    },
    zecAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    exchangeRate: {
      type: Number,
      required: true,
      min: 0,
    },
    baseExchangeRate: {
      type: Number,
      min: 0,
    },
    userDisplayRate: {
      type: Number,
      min: 0,
    },
    merchantDisplayRate: {
      type: Number,
      min: 0,
    },
    merchantZecAmount: {
      type: Number,
      min: 0,
    },
    platformZecAmount: {
      type: Number,
      min: 0,
    },
    platformZecAddress: {
      type: String,
      trim: true,
    },
    merchantId: {
      type: String,
      trim: true,
      index: true,
    },
    merchantZecAddress: {
      type: String,
      trim: true,
    },
    fiatPaymentReference: {
      type: String,
      trim: true,
    },
    zecTxHash: {
      type: String,
      trim: true,
    },
    scannedQRCodeData: {
      type: String,
      trim: true,
    },
    batchId: {
      type: String,
      trim: true,
      index: true,
    },
    groupId: {
      type: String,
      trim: true,
      index: true,
    },
    groupExpiresAt: {
      type: Date,
      index: true,
    },
    targetMerchantId: {
      type: String,
      trim: true,
      index: true,
    },
    status: {
      type: String,
      enum: ZAP_ORDER_STATUSES,
      required: true,
      index: true,
    },
    statusHistory: {
      type: [StatusHistorySchema],
      default: [],
    },
    metadata: {
      type: Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
    collection: 'zap_orders',
  }
);

export const ZapOrder = model<ZapOrderDocument>('ZapOrder', ZapOrderSchema);
