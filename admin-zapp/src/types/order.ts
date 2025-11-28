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

export type PaymentRailType = 'upi' | 'alipay' | 'wechat_pay' | 'pix' | 'promptpay';

export interface ZapOrder {
  _id: string;
  orderId: string;
  userWalletAddress: string;
  merchantCode: string;
  merchantName?: string;
  fiatAmount: number;
  fiatCurrency: string;
  paymentRail?: PaymentRailType;
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
  groupId?: string;
  groupExpiresAt?: string;
  targetMerchantId?: string;
  status: ZapOrderStatus;
  statusHistory: Array<{
    status: ZapOrderStatus;
    timestamp: string;
    note?: string;
  }>;
  metadata?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}
