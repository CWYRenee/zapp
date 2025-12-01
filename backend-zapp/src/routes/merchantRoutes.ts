import { Router, type Response } from 'express';
import { requireMerchantAuth, type AuthenticatedRequest } from '../middleware/merchantAuth.js';
import { ZapOrder } from '../models/ZapOrder.js';
import { OrderService } from '../services/orderService.js';
import type { PaymentRailConfig } from '../types/facilitator.js';
import type { ZapOrderStatus } from '../types/order.js';

const router = Router();

// All routes below require facilitator authentication
router.use(requireMerchantAuth);

// Get current facilitator profile
router.get('/profile', async (req: AuthenticatedRequest, res: Response) => {
  const facilitator = req.facilitator;

  if (!facilitator) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
      message: 'Facilitator not authenticated',
    });
  }

  return res.status(200).json({
    success: true,
    facilitator,
  });
});

// Update facilitator profile (display name, ZEC address, payment rails)
router.put('/profile', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const facilitator = req.facilitator;

    if (!facilitator) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not authenticated',
      });
    }

    const { display_name, zec_address, payment_rails } = req.body;

    if (typeof display_name === 'string') {
      const trimmed = display_name.trim();
      if (trimmed) {
        facilitator.displayName = trimmed;
      }
    }

    if (typeof zec_address === 'string') {
      const trimmedZec = zec_address.trim();
      if (trimmedZec) {
        facilitator.zecAddress = trimmedZec;
      }
    }

    if (Array.isArray(payment_rails)) {
      const rails: PaymentRailConfig[] = payment_rails
        .map((raw: any) => {
          const type = String(raw.type) as PaymentRailConfig['type'];
          if (!['upi', 'alipay', 'wechat_pay', 'pix', 'promptpay'].includes(type)) {
            return undefined;
          }

          const config: PaymentRailConfig = {
            type,
            enabled: Boolean(raw.enabled ?? true),
          };

          if (raw.label !== undefined) config.label = String(raw.label);
          if (raw.upiId !== undefined) config.upiId = String(raw.upiId);
          if (raw.alipayId !== undefined) config.alipayId = String(raw.alipayId);
          if (raw.wechatId !== undefined) config.wechatId = String(raw.wechatId);
          if (raw.paxId !== undefined) config.paxId = String(raw.paxId);
          if (raw.promptpayId !== undefined) config.promptpayId = String(raw.promptpayId);
          if (raw.notes !== undefined) config.notes = String(raw.notes);

          return config;
        })
        .filter((cfg: PaymentRailConfig | undefined): cfg is PaymentRailConfig => cfg !== undefined);

      facilitator.paymentRails = rails;
    }

    await facilitator.save();

    return res.status(200).json({
      success: true,
      facilitator,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update profile';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// List pending orders that any facilitator can accept
router.get('/orders/pending', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const facilitator = req.facilitator;

    if (!facilitator) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not authenticated',
      });
    }

    // Get facilitator's enabled payment rails
    const enabledRails = facilitator.paymentRails
      .filter((rail) => rail.enabled)
      .map((rail) => rail.type);

    const orders = await OrderService.listPendingOrders(50, 0, enabledRails);

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

// List active orders for the authenticated facilitator (orders the facilitator still needs to send fiat for)
router.get('/orders/active', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const facilitator = req.facilitator;

    if (!facilitator) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not authenticated',
      });
    }

    const orders = await ZapOrder.find({
      merchantId: facilitator.id,
      status: 'accepted',
    })
      .sort({ createdAt: -1 })
      .limit(50);

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

// List completed orders for the authenticated facilitator (fiat sent and fully completed orders)
router.get('/orders/completed', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const facilitator = req.facilitator;

    if (!facilitator) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not authenticated',
      });
    }

    const completedStatuses: ZapOrderStatus[] = ['fiat_sent', 'completed'];

    const orders = await ZapOrder.find({
      merchantId: facilitator.id,
      status: { $in: completedStatuses },
    })
      .sort({ createdAt: -1 })
      .limit(50);

    return res.status(200).json({
      success: true,
      orders,
      total: orders.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch completed orders';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

// Accept an order as the authenticated facilitator
router.post('/orders/:orderId/accept', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const facilitator = req.facilitator;

    if (!facilitator) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not authenticated',
      });
    }

    const { orderId } = req.params;
    const { zec_address } = req.body;

    const merchantZecAddress = (typeof zec_address === 'string' && zec_address.trim()) || facilitator.zecAddress;

    if (!merchantZecAddress) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'ZEC address is required to accept orders',
      });
    }

    const order = await OrderService.acceptOrder(orderId, facilitator.id, merchantZecAddress);

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

// Mark fiat as sent for an order
router.post('/orders/:orderId/mark-fiat-sent', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const facilitator = req.facilitator;

    if (!facilitator) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not authenticated',
      });
    }

    const { orderId } = req.params;
    const { payment_reference, notes } = req.body;

    const order = await OrderService.markFiatSent(
      orderId,
      facilitator.id,
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

// Mark ZEC as received for an order (user has paid)
router.post('/orders/:orderId/mark-zec-received', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const facilitator = req.facilitator;

    if (!facilitator) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not authenticated',
      });
    }

    const { orderId } = req.params;
    const { zec_tx_hash, notes } = req.body;

    const order = await OrderService.markZecReceived(
      orderId,
      facilitator.id,
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
