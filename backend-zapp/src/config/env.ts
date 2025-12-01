import dotenv from 'dotenv';

dotenv.config();

const getEnv = (key: string, defaultValue?: string): string => {
  const value = process.env[key] ?? defaultValue;
  if (value === undefined) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
};

export const env = {
  NODE_ENV: process.env.NODE_ENV ?? 'development',
  PORT: parseInt(process.env.PORT ?? '4001', 10),
  MONGODB_URI: getEnv('MONGODB_URI'),
  ADMIN_API_KEY: getEnv('ZAP_ADMIN_API_KEY', 'changeme-admin-key'),
  MERCHANT_JWT_SECRET: getEnv('MERCHANT_JWT_SECRET', 'changeme-facilitator-secret'),
};
