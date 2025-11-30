import { Schema, model, type Document } from 'mongoose';
import type { PaymentRailConfig, PaymentRailType } from '../types/merchant.js';

export interface MerchantDocument extends Document {
  email: string;
  displayName?: string;
  zecAddress?: string;
  paymentRails: PaymentRailConfig[];
  otpCode?: string | null;
  otpExpiresAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const PaymentRailSchema = new Schema<PaymentRailConfig>(
  {
    type: {
      type: String,
      enum: ['upi', 'alipay', 'wechat_pay', 'pix', 'promptpay'] satisfies PaymentRailType[],
      required: true,
    },
    enabled: {
      type: Boolean,
      required: true,
      default: true,
    },
    label: {
      type: String,
      trim: true,
    },
    upiId: {
      type: String,
      trim: true,
    },
    alipayId: {
      type: String,
      trim: true,
    },
    wechatId: {
      type: String,
      trim: true,
    },
    paxId: {
      type: String,
      trim: true,
    },
    promptpayId: {
      type: String,
      trim: true,
    },
    notes: {
      type: String,
      trim: true,
    },
  },
  { _id: false }
);

const MerchantSchema = new Schema<MerchantDocument>(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    displayName: {
      type: String,
      trim: true,
    },
    zecAddress: {
      type: String,
      trim: true,
    },
    paymentRails: {
      type: [PaymentRailSchema],
      default: [],
    },
    otpCode: {
      type: String,
    },
    otpExpiresAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
    collection: 'zap_merchants',
  }
);

export const Merchant = model<MerchantDocument>('Merchant', MerchantSchema);
