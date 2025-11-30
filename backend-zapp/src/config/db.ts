import mongoose from 'mongoose';
import { env } from './env.js';

export async function connectDatabase(): Promise<void> {
  try {
    await mongoose.connect(env.MONGODB_URI);
    console.log('[zapp-backend] Connected to MongoDB');
  } catch (error) {
    console.error('[zapp-backend] Failed to connect to MongoDB', error);
    process.exit(1);
  }
}
