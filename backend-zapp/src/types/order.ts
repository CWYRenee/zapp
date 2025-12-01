import type { PaymentRailType } from './facilitator.js';

export const ZAP_ORDER_STATUSES = [
  'pending',
  'accepted',
  'fiat_sent',
  'zec_sent',
  'completed',
  'cancelled',
  'failed',
] as const;

export type ZapOrderStatus = (typeof ZAP_ORDER_STATUSES)[number];

export interface StatusHistoryEntry {
  status: ZapOrderStatus;
  timestamp: Date;
  note?: string;
}

export interface CreateOrderInput {
  userWalletAddress: string;
  merchantCode: string;
  merchantName?: string;
  fiatAmount: number;
  fiatCurrency: string;
  paymentRail: PaymentRailType;
  scannedQRCodeData?: string;
  metadata?: Record<string, unknown>;
}

export interface CancelOrderInput {
  orderId: string;
  userWalletAddress: string;
  reason?: string;
}

// Batch Order Types
export interface BatchOrderItemInput {
  merchantCode: string;
  merchantName?: string | undefined;
  fiatAmount: number;
  fiatCurrency: string;
  paymentRail: PaymentRailType;
  scannedQRCodeData?: string | undefined;
}

export interface CreateBatchOrderInput {
  userWalletAddress: string;
  items: BatchOrderItemInput[];
  metadata?: Record<string, unknown>;
}

export interface MerchantGroup {
  groupId: string;
  merchantId?: string;
  merchantZecAddress?: string;
  paymentRails: PaymentRailType[];
  totalZecAmount: number;
  orderIds: string[];
  status: ZapOrderStatus;
}
