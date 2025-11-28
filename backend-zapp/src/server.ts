import { env } from './config/env';
import { connectDatabase } from './config/db';
import { createApp } from './app';

async function start() {
  try {
    await connectDatabase();
    const app = createApp();

    app.listen(env.PORT, () => {
      console.log(`[zapp-backend] Listening on port ${env.PORT}`);
    });
  } catch (error) {
    console.error('[zapp-backend] Failed to start server', error);
    process.exit(1);
  }
}

void start();
