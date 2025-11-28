import { ZapOrder, type ZapOrderDocument } from '../models/ZapOrder';
import { Merchant } from '../models/Merchant';
import { RateService } from './rateService';
import {
  type CreateBatchOrderInput,
  type BatchOrderItemInput,
  type ZapOrderStatus,
  type StatusHistoryEntry,
} from '../types/order';
import type { PaymentRailType } from '../types/merchant';

/** Timeout in milliseconds for grouped orders before they split into individuals */
const GROUP_TIMEOUT_MS = 10_000; // 10 seconds

interface BatchCreateResult {
  orders: ZapOrderDocument[];
  batchId: string;
  isGrouped: boolean;
  groupId?: string | undefined;
  targetMerchantId?: string | undefined;
}

/**
 * Simplified Batch Order Service
 * 
 * Flow:
 * 1. When batch order is created, check if ONE merchant can handle ALL payment rails
 * 2. If YES: Create grouped orders with 10-second timeout for that merchant
 * 3. If NO: Create as individual pending orders immediately
 * 4. After 10 seconds if grouped orders not accepted: Split into individual orders
 * 
 * Merchants see orders in their regular pending list, not as "batch orders"
 */
export class BatchOrderService {
  private static generateBatchId(): string {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `BATCH-${timestamp}-${random}`;
  }

  private static generateOrderId(): string {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `ORD-${timestamp}-${random}`;
  }

  private static generateGroupId(): string {
    const random = Math.random().toString(36).substring(2, 10).toUpperCase();
    return `GRP-${random}`;
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

  /**
   * Find a merchant that can handle ALL the given payment rails
   */
  private static async findMerchantForAllRails(rails: PaymentRailType[]): Promise<string | null> {
    if (rails.length === 0) return null;

    // Find merchants with all required rails enabled
    const merchants = await Merchant.find({
      zecAddress: { $exists: true, $ne: '' },
    });

    for (const merchant of merchants) {
      const enabledRails = merchant.paymentRails
        .filter((r: { enabled: boolean }) => r.enabled)
        .map((r: { type: PaymentRailType }) => r.type);

      const canHandleAll = rails.every(rail => enabledRails.includes(rail));
      if (canHandleAll) {
        return merchant._id.toString();
      }
    }

    return null;
  }

  /**
   * Create a batch of orders with intelligent merchant matching.
   * 
   * If one merchant can handle all payment rails -> group orders with timeout
   * Otherwise -> create individual pending orders
   */
  static async createBatchOrder(input: CreateBatchOrderInput): Promise<BatchCreateResult> {
    const userWalletAddress = input.userWalletAddress.trim();

    if (!userWalletAddress) {
      throw new Error('User wallet address is required');
    }

    if (!input.items || input.items.length === 0) {
      throw new Error('At least one recipient is required');
    }

    const batchId = this.generateBatchId();
    const platformZecAddress = process.env.PLATFORM_ZEC_ADDRESS?.trim() || '';

    // Extract unique payment rails from items
    const uniqueRails = [...new Set(input.items.map(item => item.paymentRail))];

    // Check if one merchant can handle all rails
    const targetMerchantId = await this.findMerchantForAllRails(uniqueRails);
    const isGrouped = targetMerchantId !== null;

    // Generate group info if grouped
    const groupId = isGrouped ? this.generateGroupId() : undefined;
    const groupExpiresAt = isGrouped ? new Date(Date.now() + GROUP_TIMEOUT_MS) : undefined;

    // Create individual orders
    const orders: ZapOrderDocument[] = [];

    for (const item of input.items) {
      const order = await this.createOrderFromItem(
        item,
        userWalletAddress,
        batchId,
        platformZecAddress,
        groupId,
        groupExpiresAt,
        targetMerchantId || undefined
      );
      orders.push(order);
    }

    // If grouped, schedule the split check after timeout
    if (isGrouped && groupId) {
      setTimeout(() => {
        void this.splitExpiredGroup(groupId);
      }, GROUP_TIMEOUT_MS + 500); // Add 500ms buffer
    }

    return {
      orders,
      batchId,
      isGrouped,
      groupId,
      targetMerchantId: targetMerchantId || undefined,
    };
  }

  /**
   * Create a single order from a batch item
   */
  private static async createOrderFromItem(
    item: BatchOrderItemInput,
    userWalletAddress: string,
    batchId: string,
    platformZecAddress: string,
    groupId?: string,
    groupExpiresAt?: Date,
    targetMerchantId?: string
  ): Promise<ZapOrderDocument> {
    const merchantCode = item.merchantCode.trim();

    if (!merchantCode) {
      throw new Error('Merchant code is required for each recipient');
    }

    if (!Number.isFinite(item.fiatAmount) || item.fiatAmount <= 0) {
      throw new Error('Fiat amount must be greater than zero');
    }

    const fiatCurrency = item.fiatCurrency.trim().toUpperCase();
    if (!fiatCurrency) {
      throw new Error('Fiat currency is required');
    }

    if (!item.paymentRail) {
      throw new Error('Payment rail is required');
    }

    // Compute ZEC amounts with spread
    const spreadCalc = await RateService.computeZecAmountWithSpread(item.fiatAmount, fiatCurrency);

    const order = new ZapOrder({
      orderId: this.generateOrderId(),
      userWalletAddress,
      merchantCode,
      merchantName: item.merchantName?.trim() || undefined,
      fiatAmount: item.fiatAmount,
      fiatCurrency,
      paymentRail: item.paymentRail,
      zecAmount: spreadCalc.userZecAmount,
      exchangeRate: spreadCalc.baseExchangeRate,
      baseExchangeRate: spreadCalc.baseExchangeRate,
      userDisplayRate: spreadCalc.userDisplayRate,
      merchantDisplayRate: spreadCalc.merchantDisplayRate,
      merchantZecAmount: spreadCalc.merchantZecAmount,
      platformZecAmount: spreadCalc.platformZecAmount,
      platformZecAddress,
      scannedQRCodeData: item.scannedQRCodeData?.trim() || undefined,
      batchId,
      groupId,
      groupExpiresAt,
      targetMerchantId,
      status: 'pending',
      statusHistory: [],
    });

    const note = groupId
      ? `Order created as part of grouped batch (expires: ${groupExpiresAt?.toISOString()})`
      : 'Order created as individual pending order';
    this.appendStatus(order, 'pending', note);
    await order.save();

    return order;
  }

  /**
   * Split expired grouped orders into individual orders.
   * Called automatically after GROUP_TIMEOUT_MS.
   * 
   * This removes the group association so orders become available to any merchant.
   */
  static async splitExpiredGroup(groupId: string): Promise<number> {
    const now = new Date();

    // Find grouped orders that have expired and are still pending
    const expiredOrders = await ZapOrder.find({
      groupId,
      groupExpiresAt: { $lte: now },
      status: 'pending',
    });

    if (expiredOrders.length === 0) {
      return 0;
    }

    // Remove group association to make them individual orders
    await ZapOrder.updateMany(
      {
        groupId,
        groupExpiresAt: { $lte: now },
        status: 'pending',
      },
      {
        $unset: { groupId: 1, groupExpiresAt: 1, targetMerchantId: 1 },
        $push: {
          statusHistory: {
            status: 'pending',
            timestamp: now,
            note: 'Group expired - order now available to all merchants',
          },
        },
      }
    );

    return expiredOrders.length;
  }

  /**
   * Get orders for a specific batch
   */
  static async getBatchOrders(batchId: string, userWalletAddress?: string): Promise<ZapOrderDocument[]> {
    const query: Record<string, unknown> = { batchId };

    if (userWalletAddress) {
      query.userWalletAddress = userWalletAddress.trim();
    }

    return ZapOrder.find(query).sort({ createdAt: 1 });
  }

  /**
   * Get grouped orders for a specific group (must accept all together)
   */
  static async getGroupedOrders(groupId: string): Promise<ZapOrderDocument[]> {
    return ZapOrder.find({ groupId, status: 'pending' }).sort({ createdAt: 1 });
  }

  /**
   * Accept all orders in a group (merchant accepting grouped batch)
   */
  static async acceptGroup(
    groupId: string,
    merchantId: string,
    merchantZecAddress: string
  ): Promise<ZapOrderDocument[]> {
    const trimmedMerchantId = merchantId.trim();
    const trimmedZecAddress = merchantZecAddress.trim();

    if (!trimmedMerchantId || !trimmedZecAddress) {
      throw new Error('Merchant ID and ZEC address are required');
    }

    // Find all orders in this group
    const orders = await ZapOrder.find({ groupId, status: 'pending' });

    if (orders.length === 0) {
      throw new Error('No pending orders found for this group');
    }

    // Verify merchant is the target (if set)
    const targetMerchant = orders[0].targetMerchantId;
    if (targetMerchant && targetMerchant !== trimmedMerchantId) {
      throw new Error('This group is reserved for a different merchant');
    }

    // Check if group has expired
    const groupExpiry = orders[0].groupExpiresAt;
    if (groupExpiry && new Date() > groupExpiry) {
      // Split the group first
      await this.splitExpiredGroup(groupId);
      throw new Error('Group has expired and orders are now available individually');
    }

    // Accept all orders in the group
    await ZapOrder.updateMany(
      { groupId, status: 'pending' },
      {
        $set: {
          merchantId: trimmedMerchantId,
          merchantZecAddress: trimmedZecAddress,
          status: 'accepted',
        },
        $push: {
          statusHistory: {
            status: 'accepted',
            timestamp: new Date(),
            note: `Accepted by merchant ${trimmedMerchantId} as group`,
          },
        },
      }
    );

    return ZapOrder.find({ groupId });
  }

  /**
   * Check and split any expired groups (can be called periodically)
   */
  static async splitAllExpiredGroups(): Promise<number> {
    const now = new Date();

    // Find all unique groupIds with expired orders
    const expiredGroups = await ZapOrder.distinct('groupId', {
      groupId: { $exists: true, $ne: null },
      groupExpiresAt: { $lte: now },
      status: 'pending',
    });

    let totalSplit = 0;
    for (const groupId of expiredGroups) {
      const count = await this.splitExpiredGroup(groupId);
      totalSplit += count;
    }

    return totalSplit;
  }
}
