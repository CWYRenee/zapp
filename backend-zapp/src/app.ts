import express, { type Request, type Response } from 'express';
import cors from 'cors';
import morgan from 'morgan';
import orderRoutes from './routes/orderRoutes';
import batchOrderRoutes from './routes/batchOrderRoutes';
import adminOrderRoutes from './routes/adminOrderRoutes';
import merchantAuthRoutes from './routes/merchantAuthRoutes';
import merchantRoutes from './routes/merchantRoutes';
import earnRoutes from './routes/earnRoutes';
import { notFoundHandler, errorHandler } from './middleware/errorHandler';

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
  app.use('/api/zapp/merchant', merchantAuthRoutes);
  app.use('/api/zapp/merchant', merchantRoutes);
  app.use('/api/zapp/earn', earnRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

export default createApp;
