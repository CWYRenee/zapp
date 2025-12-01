import express, { type Request, type Response } from 'express';
import cors from 'cors';
import morgan from 'morgan';
import orderRoutes from './routes/orderRoutes.js';
import batchOrderRoutes from './routes/batchOrderRoutes.js';
import adminOrderRoutes from './routes/adminOrderRoutes.js';
import merchantAuthRoutes from './routes/merchantAuthRoutes.js';
import merchantRoutes from './routes/merchantRoutes.js';
import earnRoutes from './routes/earnRoutes.js';
import { notFoundHandler, errorHandler } from './middleware/errorHandler.js';

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use(morgan('dev'));

  app.get('/health', (_req: Request, res: Response) => {
    res.json({ status: 'ok', service: 'zapp-backend' });
  });

  app.use('/api/zapp/orders', orderRoutes);
  app.use('/api/zapp/orders/batch', batchOrderRoutes);
  app.use('/api/zapp/admin/orders', adminOrderRoutes);
  app.use('/api/zapp/facilitator', merchantAuthRoutes);
  app.use('/api/zapp/facilitator', merchantRoutes);
  app.use('/api/zapp/earn', earnRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

export default createApp;
