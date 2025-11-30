import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { Merchant, type MerchantDocument } from '../models/Merchant.js';

interface AuthTokenPayload {
  sub: string;
  email: string;
  iat?: number;
  exp?: number;
}

export interface AuthenticatedRequest extends Request {
  merchant?: MerchantDocument;
}

// Demo token that bypasses JWT validation and uses first available merchant
const DEMO_TOKEN = 'demo-token-no-auth';

export async function requireMerchantAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const authHeader = req.header('Authorization');

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization header',
      });
      return;
    }

    const token = authHeader.substring('Bearer '.length).trim();

    // Demo mode: bypass JWT and use first merchant in database
    if (token === DEMO_TOKEN) {
      const demoMerchant = await Merchant.findOne();
      if (!demoMerchant) {
        res.status(401).json({
          success: false,
          error: 'Unauthorized',
          message: 'No merchant found for demo mode',
        });
        return;
      }
      console.log('[Demo Mode] Using merchant:', demoMerchant.email);
      req.merchant = demoMerchant;
      next();
      return;
    }

    let payload: AuthTokenPayload;
    try {
      payload = jwt.verify(token, env.MERCHANT_JWT_SECRET) as AuthTokenPayload;
    } catch {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Invalid or expired token',
      });
      return;
    }

    const merchant = await Merchant.findById(payload.sub);
    if (!merchant) {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Merchant not found',
      });
      return;
    }

    req.merchant = merchant;
    next();
  } catch (error) {
    console.error('[zapp-backend] Merchant auth error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to authenticate merchant',
    });
  }
}
