import { Schema, model, type Document } from 'mongoose';
import {
  ZAP_ORDER_STATUSES,
  type ZapOrderStatus,
  type MerchantGroup,
} from '../types/order';
import type { PaymentRailType } from '../types/merchant';

export interface BatchOrderDocument extends Document {
  batchId: string;
  userWalletAddress: string;
  totalZecAmount: number;
  orderIds: string[];
  merchantGroups: MerchantGroup[];
  status: ZapOrderStatus;
  metadata?: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

const MerchantGroupSchema = new Schema<MerchantGroup>(
  {
    groupId: {
      type: String,
      required: true,
    },
    merchantId: {
      type: String,
      trim: true,
    },
    merchantZecAddress: {
      type: String,
      trim: true,
    },
    paymentRails: {
      type: [String],
      enum: ['upi', 'alipay', 'wechat_pay', 'pix', 'promptpay'] satisfies PaymentRailType[],
      required: true,
    },
    totalZecAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    orderIds: {
      type: [String],
      required: true,
    },
    status: {
      type: String,
      enum: ZAP_ORDER_STATUSES,
      required: true,
      default: 'pending',
    },
  },
  { _id: false }
);

const BatchOrderSchema = new Schema<BatchOrderDocument>(
  {
    batchId: {
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
    totalZecAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    orderIds: {
      type: [String],
      required: true,
    },
    merchantGroups: {
      type: [MerchantGroupSchema],
      default: [],
    },
    status: {
      type: String,
      enum: ZAP_ORDER_STATUSES,
      required: true,
      index: true,
    },
    metadata: {
      type: Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
    collection: 'zap_batch_orders',
  }
);

export const BatchOrder = model<BatchOrderDocument>('BatchOrder', BatchOrderSchema);
