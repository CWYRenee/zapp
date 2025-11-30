import { Router, type Request, type Response } from 'express';
import { OrderService } from '../services/orderService.js';
import type { ZapOrderStatus, CreateOrderInput } from '../types/order.js';

const router = Router();

// Create a new order
router.post('/', async (req: Request, res: Response) => {
  try {
    const {
      user_wallet_address,
      merchant_code,
      merchant_name,
      fiat_amount,
      fiat_currency,
      payment_rail,
      scanned_qr_code_data,
      metadata,
    } = req.body;

    if (!user_wallet_address || !merchant_code || !fiat_amount || !fiat_currency || !payment_rail) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'Missing required fields: user_wallet_address, merchant_code, fiat_amount, fiat_currency, payment_rail',
      });
    }

    const fiatAmountNumber = Number(fiat_amount);

    const createInput: CreateOrderInput = {
      userWalletAddress: String(user_wallet_address),
      merchantCode: String(merchant_code),
      fiatAmount: fiatAmountNumber,
      fiatCurrency: String(fiat_currency),
      paymentRail: String(payment_rail) as CreateOrderInput['paymentRail'],
      metadata,
    };

    if (merchant_name !== undefined && merchant_name !== null && merchant_name !== '') {
      createInput.merchantName = String(merchant_name);
    }

    if (scanned_qr_code_data !== undefined && scanned_qr_code_data !== null && scanned_qr_code_data !== '') {
      createInput.scannedQRCodeData = String(scanned_qr_code_data);
    }

    const order = await OrderService.createOrder(createInput);

    return res.status(201).json({
      success: true,
      order,
      message: 'Order created successfully',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to create order';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// Get all orders for a user
router.get('/user/:walletAddress', async (req: Request, res: Response) => {
  try {
    const { walletAddress } = req.params;
    const { status, limit = '50', skip = '0' } = req.query;

    const parsedLimit = Number(limit);
    const parsedSkip = Number(skip);

    const orders = await OrderService.listOrdersForUser(
      walletAddress,
      status ? String(status) as ZapOrderStatus : undefined,
      Number.isFinite(parsedLimit) ? parsedLimit : 50,
      Number.isFinite(parsedSkip) ? parsedSkip : 0,
    );

    return res.status(200).json({
      success: true,
      orders,
      total: orders.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch orders';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// Get a single order for a user
router.get('/:orderId', async (req: Request, res: Response) => {
  try {
    const { orderId } = req.params;
    const { user_wallet_address } = req.query;

    if (!user_wallet_address || typeof user_wallet_address !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'user_wallet_address query parameter is required',
      });
    }

    const order = await OrderService.getOrderForUser(orderId, user_wallet_address);

    if (!order) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Order not found',
      });
    }

    return res.status(200).json({
      success: true,
      order,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch order';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// Cancel an order for a user
router.post('/:orderId/cancel', async (req: Request, res: Response) => {
  try {
    const { orderId } = req.params;
    const { user_wallet_address, reason } = req.body;

    if (!user_wallet_address || typeof user_wallet_address !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'user_wallet_address is required',
      });
    }

    const order = await OrderService.cancelOrder(orderId, user_wallet_address, reason);

    if (!order) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Order not found',
      });
    }

    return res.status(200).json({
      success: true,
      order,
      message: 'Order cancelled successfully',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to cancel order';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

export default router;
