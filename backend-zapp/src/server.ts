import { env } from './config/env.js';
import { connectDatabase } from './config/db.js';
import { createApp } from './app.js';
import { startJobs, stopJobs } from './jobs/index.js';

async function start() {
  try {
    await connectDatabase();
    const app = createApp();

    app.listen(env.PORT, () => {
      console.log(`[zapp-backend] Listening on port ${env.PORT}`);
      
      // Start background jobs after server is ready
      startJobs();
    });

    // Graceful shutdown
    const shutdown = () => {
      console.log('[zapp-backend] Shutting down...');
      stopJobs();
      process.exit(0);
    };

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
  } catch (error) {
    console.error('[zapp-backend] Failed to start server', error);
    process.exit(1);
  }
}

void start();
