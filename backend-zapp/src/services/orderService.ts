import { ZapOrder, type ZapOrderDocument } from '../models/ZapOrder.js';
import { RateService } from './rateService.js';
import {
  type CreateOrderInput,
  type ZapOrderStatus,
  type StatusHistoryEntry,
} from '../types/order.js';
import type { PaymentRailType } from '../types/facilitator.js';

export class OrderService {
  private static generateOrderId(): string {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `ORD-${timestamp}-${random}`;
  }

  private static appendStatus(order: ZapOrderDocument, status: ZapOrderStatus, note?: string): void {
    const entry: StatusHistoryEntry = {
      status,
      timestamp: new Date(),
    };

    if (note !== undefined) {
      entry.note = note;
    }

    order.statusHistory.push(entry);
  }

  static async createOrder(input: CreateOrderInput): Promise<ZapOrderDocument> {
    const userWalletAddress = input.userWalletAddress.trim();
    const merchantCode = input.merchantCode.trim();

    if (!userWalletAddress) {
      throw new Error('User wallet address is required');
    }

    if (!merchantCode) {
      throw new Error('Facilitator code is required');
    }

    if (!Number.isFinite(input.fiatAmount) || input.fiatAmount <= 0) {
      throw new Error('Fiat amount must be greater than zero');
    }

    const fiatCurrency = input.fiatCurrency.trim().toUpperCase();
    if (!fiatCurrency) {
      throw new Error('Fiat currency is required');
    }

    if (!input.paymentRail) {
      throw new Error('Payment rail is required');
    }

    // Compute ZEC amounts with 1% spread (0.5% facilitator, 0.5% platform)
    const spreadCalc = await RateService.computeZecAmountWithSpread(input.fiatAmount, fiatCurrency);

    // Get platform ZEC address from environment
    const platformZecAddress = process.env.PLATFORM_ZEC_ADDRESS?.trim() || '';
    if (!platformZecAddress) {
      console.warn('PLATFORM_ZEC_ADDRESS not set in environment. Platform spread will not be sent.');
    }

    const order = new ZapOrder({
      orderId: this.generateOrderId(),
      userWalletAddress,
      merchantCode,
      merchantName: input.merchantName?.trim() || undefined,
      fiatAmount: input.fiatAmount,
      fiatCurrency,
      paymentRail: input.paymentRail,
      // User's total payment amount
      zecAmount: spreadCalc.userZecAmount,
      // Base rate for backward compatibility
      exchangeRate: spreadCalc.baseExchangeRate,
      // Spread fields
      baseExchangeRate: spreadCalc.baseExchangeRate,
      userDisplayRate: spreadCalc.userDisplayRate,
      merchantDisplayRate: spreadCalc.merchantDisplayRate,
      merchantZecAmount: spreadCalc.merchantZecAmount,
      platformZecAmount: spreadCalc.platformZecAmount,
      platformZecAddress,
      // Raw QR code data scanned by user (for facilitator to scan and pay)
      scannedQRCodeData: input.scannedQRCodeData?.trim() || undefined,
      status: 'pending',
      statusHistory: [],
      metadata: input.metadata,
    });

    this.appendStatus(order, 'pending', 'Order created');

    return order.save();
  }

  static async getOrderForUser(orderId: string, userWalletAddress: string): Promise<ZapOrderDocument | null> {
    const wallet = userWalletAddress.trim();
    if (!wallet) {
      throw new Error('User wallet address is required');
    }

    return ZapOrder.findOne({ orderId, userWalletAddress: wallet });
  }

  static async listOrdersForUser(
    userWalletAddress: string,
    status?: ZapOrderStatus,
    limit = 50,
    skip = 0,
  ): Promise<ZapOrderDocument[]> {
    const wallet = userWalletAddress.trim();
    if (!wallet) {
      throw new Error('User wallet address is required');
    }

    const query: Record<string, unknown> = { userWalletAddress: wallet };
    if (status) {
      query.status = status;
    }

    return ZapOrder.find(query)
      .sort({ createdAt: -1 })
      .limit(limit)
      .skip(skip);
  }

  static async cancelOrder(
    orderId: string,
    userWalletAddress: string,
    reason?: string,
  ): Promise<ZapOrderDocument | null> {
    const wallet = userWalletAddress.trim();
    if (!wallet) {
      throw new Error('User wallet address is required');
    }

    const order = await ZapOrder.findOne({ orderId, userWalletAddress: wallet });
    if (!order) {
      return null;
    }

    const cancellableStatuses: ZapOrderStatus[] = ['pending'];

    if (!cancellableStatuses.includes(order.status)) {
      throw new Error(`Cannot cancel order in ${order.status} status`);
    }

    order.status = 'cancelled';
    this.appendStatus(order, 'cancelled', reason || 'Cancelled by user');

    return order.save();
  }

  // Admin queries
  static async listPendingOrders(
    limit = 50,
    skip = 0,
    allowedRails?: PaymentRailType[]
  ): Promise<ZapOrderDocument[]> {
    const query: Record<string, unknown> = { status: 'pending' };

    if (allowedRails && allowedRails.length > 0) {
      query.paymentRail = { $in: allowedRails };
    }

    return ZapOrder.find(query)
      .sort({ createdAt: 1 })
      .limit(limit)
      .skip(skip);
  }

  static async listActiveOrders(limit = 50, skip = 0): Promise<ZapOrderDocument[]> {
    const activeStatuses: ZapOrderStatus[] = ['accepted', 'fiat_sent'];

    return ZapOrder.find({ status: { $in: activeStatuses } })
      .sort({ createdAt: -1 })
      .limit(limit)
      .skip(skip);
  }

  static async acceptOrder(
    orderId: string,
    merchantId: string,
    merchantZecAddress: string,
  ): Promise<ZapOrderDocument | null> {
    const trimmedMerchantId = merchantId.trim();
    const trimmedZecAddress = merchantZecAddress.trim();

    if (!trimmedMerchantId) {
      throw new Error('merchant_id is required');
    }

    if (!trimmedZecAddress) {
      throw new Error('merchant_zec_address is required');
    }

    const order = await ZapOrder.findOne({ orderId });
    if (!order) {
      return null;
    }

    if (order.status !== 'pending') {
      throw new Error(`Cannot accept order in ${order.status} status`);
    }

    order.merchantId = trimmedMerchantId;
    order.merchantZecAddress = trimmedZecAddress;
    order.status = 'accepted';
    this.appendStatus(order, 'accepted', `Order accepted by facilitator ${trimmedMerchantId}`);

    return order.save();
  }

  static async markFiatSent(
    orderId: string,
    merchantId: string,
    paymentReference?: string,
    notes?: string,
  ): Promise<ZapOrderDocument | null> {
    const trimmedMerchantId = merchantId.trim();
    if (!trimmedMerchantId) {
      throw new Error('merchant_id is required');
    }

    const order = await ZapOrder.findOne({ orderId });
    if (!order) {
      return null;
    }

    if (order.merchantId && order.merchantId !== trimmedMerchantId) {
      throw new Error('Facilitator is not allowed to update this order');
    }

    if (order.status !== 'accepted') {
      throw new Error(`Cannot mark fiat sent for order in ${order.status} status`);
    }

    order.merchantId = trimmedMerchantId;

    if (paymentReference && paymentReference.trim()) {
      order.fiatPaymentReference = paymentReference.trim();
    }

    order.status = 'fiat_sent';
    this.appendStatus(order, 'fiat_sent', notes || 'Facilitator marked fiat as sent');

    return order.save();
  }

  static async markZecReceived(
    orderId: string,
    merchantId: string,
    zecTxHash?: string,
    notes?: string,
  ): Promise<ZapOrderDocument | null> {
    const trimmedMerchantId = merchantId.trim();
    if (!trimmedMerchantId) {
      throw new Error('merchant_id is required');
    }

    const order = await ZapOrder.findOne({ orderId });
    if (!order) {
      return null;
    }

    if (order.merchantId && order.merchantId !== trimmedMerchantId) {
      throw new Error('Facilitator is not allowed to update this order');
    }

    if (order.status !== 'fiat_sent') {
      throw new Error(`Cannot mark ZEC received for order in ${order.status} status`);
    }

    order.merchantId = trimmedMerchantId;

    if (zecTxHash && zecTxHash.trim()) {
      order.zecTxHash = zecTxHash.trim();
    }

    // Record that ZEC was sent
    order.status = 'zec_sent';
    this.appendStatus(order, 'zec_sent', notes || 'ZEC sent by user');

    // Immediately mark as completed for now
    order.status = 'completed';
    this.appendStatus(order, 'completed', 'Order completed');

    return order.save();
  }
}
