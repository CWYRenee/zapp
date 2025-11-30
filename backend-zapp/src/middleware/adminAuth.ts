import type { NextFunction, Request, Response } from 'express';
import { env } from '../config/env.js';

export function requireAdmin(req: Request, res: Response, next: NextFunction): void {
  const adminKey = req.header('X-Admin-Key') ?? req.header('x-admin-key');

  if (!adminKey || adminKey !== env.ADMIN_API_KEY) {
    res.status(403).json({
      success: false,
      error: 'Forbidden',
      message: 'Admin access required',
    });
    return;
  }

  next();
}
