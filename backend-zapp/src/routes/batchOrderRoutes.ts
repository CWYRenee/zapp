import { Router, type Request, type Response } from 'express';
import { BatchOrderService } from '../services/batchOrderService.js';
import type { BatchOrderItemInput, CreateBatchOrderInput } from '../types/order.js';
import type { PaymentRailType } from '../types/merchant.js';

const router = Router();

/**
 * Create a batch of orders (multi-recipient payment)
 * 
 * Orders are created as regular pending orders visible to merchants.
 * If one merchant can handle all payment rails, orders are grouped with 10-second timeout.
 * Otherwise, orders are created as individual pending orders.
 */
router.post('/', async (req: Request, res: Response) => {
  try {
    const {
      user_wallet_address,
      items,
      metadata,
    } = req.body;

    if (!user_wallet_address) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'Missing required field: user_wallet_address',
      });
    }

    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'Items array is required and must not be empty',
      });
    }

    // Validate and transform items
    const batchItems: BatchOrderItemInput[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (!item.merchant_code || !item.fiat_amount || !item.fiat_currency || !item.payment_rail) {
        return res.status(400).json({
          success: false,
          error: 'Bad Request',
          message: `Item ${i + 1} is missing required fields: merchant_code, fiat_amount, fiat_currency, payment_rail`,
        });
      }

      batchItems.push({
        merchantCode: String(item.merchant_code),
        merchantName: item.merchant_name ? String(item.merchant_name) : undefined,
        fiatAmount: Number(item.fiat_amount),
        fiatCurrency: String(item.fiat_currency),
        paymentRail: String(item.payment_rail) as PaymentRailType,
        scannedQRCodeData: item.scanned_qr_code_data ? String(item.scanned_qr_code_data) : undefined,
      });
    }

    const createInput: CreateBatchOrderInput = {
      userWalletAddress: String(user_wallet_address),
      items: batchItems,
      metadata,
    };

    const result = await BatchOrderService.createBatchOrder(createInput);

    return res.status(201).json({
      success: true,
      batchId: result.batchId,
      isGrouped: result.isGrouped,
      groupId: result.groupId,
      targetMerchantId: result.targetMerchantId,
      orders: result.orders.map(o => ({
        orderId: o.orderId,
        merchantCode: o.merchantCode,
        merchantName: o.merchantName,
        fiatAmount: o.fiatAmount,
        fiatCurrency: o.fiatCurrency,
        zecAmount: o.zecAmount,
        exchangeRate: o.exchangeRate,
        paymentRail: o.paymentRail,
        status: o.status,
        groupId: o.groupId,
        groupExpiresAt: o.groupExpiresAt,
        createdAt: o.createdAt,
      })),
      message: result.isGrouped
        ? 'Orders created as a group - merchant has 10 seconds to accept all together'
        : 'Orders created as individual pending orders',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to create batch order';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * Get orders for a batch by batch ID
 */
router.get('/:batchId', async (req: Request, res: Response) => {
  try {
    const { batchId } = req.params;
    const { user_wallet_address } = req.query;

    const userWallet = user_wallet_address && typeof user_wallet_address === 'string'
      ? user_wallet_address
      : undefined;

    const orders = await BatchOrderService.getBatchOrders(batchId, userWallet);

    if (orders.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'No orders found for this batch',
      });
    }

    const totalZecAmount = orders.reduce((sum, o) => sum + o.zecAmount, 0);

    return res.status(200).json({
      success: true,
      batchId,
      totalZecAmount,
      orders: orders.map(o => ({
        orderId: o.orderId,
        merchantCode: o.merchantCode,
        merchantName: o.merchantName,
        fiatAmount: o.fiatAmount,
        fiatCurrency: o.fiatCurrency,
        zecAmount: o.zecAmount,
        exchangeRate: o.exchangeRate,
        paymentRail: o.paymentRail,
        merchantId: o.merchantId,
        merchantZecAddress: o.merchantZecAddress,
        status: o.status,
        groupId: o.groupId,
        groupExpiresAt: o.groupExpiresAt,
        createdAt: o.createdAt,
        updatedAt: o.updatedAt,
      })),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch batch orders';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * Accept a group of orders (merchant accepting all orders in a group)
 */
router.post('/groups/:groupId/accept', async (req: Request, res: Response) => {
  try {
    const { groupId } = req.params;
    const { merchant_id, merchant_zec_address } = req.body;

    if (!merchant_id || !merchant_zec_address) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'Missing required fields: merchant_id, merchant_zec_address',
      });
    }

    const orders = await BatchOrderService.acceptGroup(
      groupId,
      String(merchant_id),
      String(merchant_zec_address)
    );

    return res.status(200).json({
      success: true,
      groupId,
      orders: orders.map(o => ({
        orderId: o.orderId,
        merchantCode: o.merchantCode,
        fiatAmount: o.fiatAmount,
        fiatCurrency: o.fiatCurrency,
        zecAmount: o.zecAmount,
        paymentRail: o.paymentRail,
        status: o.status,
      })),
      message: 'Group accepted successfully',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to accept group';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * Get grouped orders for a specific group
 */
router.get('/groups/:groupId', async (req: Request, res: Response) => {
  try {
    const { groupId } = req.params;

    const orders = await BatchOrderService.getGroupedOrders(groupId);

    if (orders.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'No pending orders found for this group (may have expired or been accepted)',
      });
    }

    const totalZecAmount = orders.reduce((sum, o) => sum + o.zecAmount, 0);
    const groupExpiresAt = orders[0].groupExpiresAt;
    const targetMerchantId = orders[0].targetMerchantId;

    return res.status(200).json({
      success: true,
      groupId,
      totalZecAmount,
      targetMerchantId,
      groupExpiresAt,
      orders: orders.map(o => ({
        orderId: o.orderId,
        merchantCode: o.merchantCode,
        merchantName: o.merchantName,
        fiatAmount: o.fiatAmount,
        fiatCurrency: o.fiatCurrency,
        zecAmount: o.zecAmount,
        paymentRail: o.paymentRail,
        status: o.status,
      })),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch grouped orders';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * Manually trigger split of expired groups (admin/maintenance endpoint)
 */
router.post('/maintenance/split-expired', async (_req: Request, res: Response) => {
  try {
    const count = await BatchOrderService.splitAllExpiredGroups();

    return res.status(200).json({
      success: true,
      splitCount: count,
      message: `Split ${count} expired grouped orders into individuals`,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to split expired groups';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

export default router;
