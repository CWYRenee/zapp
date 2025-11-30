import { Router, type Request, type Response } from 'express';
import { OrderService } from '../services/orderService.js';
import { requireAdmin } from '../middleware/adminAuth.js';

const router = Router();

// All routes below require admin auth
router.use(requireAdmin);

// List pending orders
router.get('/pending', async (req: Request, res: Response) => {
  try {
    const { limit = '50', skip = '0' } = req.query;
    const parsedLimit = Number(limit);
    const parsedSkip = Number(skip);

    const orders = await OrderService.listPendingOrders(
      Number.isFinite(parsedLimit) ? parsedLimit : 50,
      Number.isFinite(parsedSkip) ? parsedSkip : 0,
    );

    return res.status(200).json({
      success: true,
      orders,
      total: orders.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch pending orders';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

// List active orders (accepted, fiat sent)
router.get('/active', async (req: Request, res: Response) => {
  try {
    const { limit = '50', skip = '0' } = req.query;
    const parsedLimit = Number(limit);
    const parsedSkip = Number(skip);

    const orders = await OrderService.listActiveOrders(
      Number.isFinite(parsedLimit) ? parsedLimit : 50,
      Number.isFinite(parsedSkip) ? parsedSkip : 0,
    );

    return res.status(200).json({
      success: true,
      orders,
      total: orders.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch active orders';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

// Accept an order
router.post('/:orderId/accept', async (req: Request, res: Response) => {
  try {
    const { orderId } = req.params;
    const { merchant_id, merchant_zec_address } = req.body;

    if (!merchant_id || !merchant_zec_address) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'Missing required fields: merchant_id, merchant_zec_address',
      });
    }

    const order = await OrderService.acceptOrder(orderId, String(merchant_id), String(merchant_zec_address));

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
      message: 'Order accepted successfully',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to accept order';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// Mark fiat payment as sent for an order
router.post('/:orderId/mark-fiat-sent', async (req: Request, res: Response) => {
  try {
    const { orderId } = req.params;
    const { merchant_id, payment_reference, notes } = req.body;

    if (!merchant_id) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'merchant_id is required',
      });
    }

    const order = await OrderService.markFiatSent(
      orderId,
      String(merchant_id),
      payment_reference ? String(payment_reference) : undefined,
      notes ? String(notes) : undefined,
    );

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
      message: 'Order marked as fiat sent',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to mark fiat as sent';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// Mark ZEC received for an order (user has paid merchant)
router.post('/:orderId/mark-zec-received', async (req: Request, res: Response) => {
  try {
    const { orderId } = req.params;
    const { merchant_id, zec_tx_hash, notes } = req.body;

    if (!merchant_id) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'merchant_id is required',
      });
    }

    const order = await OrderService.markZecReceived(
      orderId,
      String(merchant_id),
      zec_tx_hash ? String(zec_tx_hash) : undefined,
      notes ? String(notes) : undefined,
    );

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
      message: 'Order marked as ZEC received and completed',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to mark ZEC as received';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

export default router;
