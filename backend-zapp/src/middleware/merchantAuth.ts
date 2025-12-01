import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { Facilitator, type MerchantDocument } from '../models/Facilitator.js';

interface AuthTokenPayload {
  sub: string;
  email: string;
  iat?: number;
  exp?: number;
}

export interface AuthenticatedRequest extends Request {
  facilitator?: MerchantDocument;
}

// Demo token that bypasses JWT validation and uses first available facilitator
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

    // Demo mode: bypass JWT and use first facilitator in database
    if (token === DEMO_TOKEN) {
      const demoMerchant = await Facilitator.findOne();
      if (!demoMerchant) {
        res.status(401).json({
          success: false,
          error: 'Unauthorized',
          message: 'No facilitator found for demo mode',
        });
        return;
      }
      console.log('[Demo Mode] Using facilitator:', demoMerchant.email);
      req.facilitator = demoMerchant;
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

    const facilitator = await Facilitator.findById(payload.sub);
    if (!facilitator) {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Facilitator not found',
      });
      return;
    }

    req.facilitator = facilitator;
    next();
  } catch (error) {
    console.error('[zapp-backend] Facilitator auth error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to authenticate facilitator',
    });
  }
}
