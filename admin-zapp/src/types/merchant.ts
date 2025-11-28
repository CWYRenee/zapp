export type PaymentRailType = 'upi' | 'alipay' | 'wechat_pay' | 'pix' | 'promptpay';

export interface PaymentRailConfig {
  type: PaymentRailType;
  enabled: boolean;
  label?: string;
  upiId?: string;
  alipayId?: string;
  wechatId?: string;
  paxId?: string;
  promptpayId?: string;
  notes?: string;
}

export interface Merchant {
  _id: string;
  email: string;
  displayName?: string;
  zecAddress?: string;
  paymentRails: PaymentRailConfig[];
  createdAt: string;
  updatedAt: string;
}
