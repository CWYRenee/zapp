/**
 * SwapKit SDK Configuration
 * Handles testnet/mainnet configuration based on environment variables
 */

import type { SwapKitEnvironment } from './types.js';

// Environment variables
const NEAR_ENV = process.env.NEAR_ENV || 'testnet';
const SWAPKIT_API_KEY = process.env.SWAPKIT_KEY || '';
const BLOCKCHAIR_API_KEY = process.env.BLOCKCHAIR_KEY || '';

/**
 * Determine if we're running in testnet mode
 */
export function isTestnetEnvironment(): boolean {
  return NEAR_ENV === 'testnet';
}

/**
 * Get the current SwapKit environment configuration
 */
export function getSwapKitEnvironment(): SwapKitEnvironment {
  const isTestnet = isTestnetEnvironment();
  
  console.log(`[SwapKit] Initializing in ${isTestnet ? 'TESTNET (stagenet)' : 'MAINNET'} mode`);
  
  return {
    isTestnet,
    apiKey: SWAPKIT_API_KEY || undefined,
    blockchairApiKey: BLOCKCHAIR_API_KEY || undefined,
  };
}

/**
 * Get SwapKit SDK configuration object
 * This is used when initializing createSwapKit()
 */
export function getSwapKitConfig() {
  const env = getSwapKitEnvironment();
  
  const config: {
    apiKeys: Record<string, string>;
    envs: {
      isDev: boolean;
      isStagenet: boolean;
    };
  } = {
    apiKeys: {},
    envs: {
      isDev: env.isTestnet,
      isStagenet: env.isTestnet, // This is the key flag for testnet
    },
  };
  
  // Add API keys if available
  if (env.apiKey) {
    config.apiKeys.swapKit = env.apiKey;
  }
  if (env.blockchairApiKey) {
    config.apiKeys.blockchair = env.blockchairApiKey;
  }
  
  return config;
}

/**
 * Get Zcash-specific configuration
 */
export function getZcashConfig() {
  const isTestnet = isTestnetEnvironment();
  
  return {
    isTestnet,
    // Address prefixes
    addressPrefix: isTestnet ? 'tm' : 't1',
    // Derivation path (same for both networks, network determined by config)
    derivationPath: "m/44'/133'/0'/0/0",
    // Asset identifier (same, network determined by isStagenet)
    assetIdentifier: 'ZEC.ZEC',
  };
}

/**
 * Get NEAR-specific configuration
 */
export function getNearConfig() {
  const isTestnet = isTestnetEnvironment();
  
  return {
    isTestnet,
    networkId: isTestnet ? 'testnet' : 'mainnet',
    // NEAR asset identifier
    assetIdentifier: 'NEAR.NEAR',
    // Wrapped NEAR for Ref Finance
    wrappedNearIdentifier: 'NEAR.wrap.near',
  };
}

/**
 * Log current configuration (for debugging)
 */
export function logSwapKitConfig(): void {
  const env = getSwapKitEnvironment();
  const zcash = getZcashConfig();
  const near = getNearConfig();
  
  console.log('[SwapKit] Configuration:');
  console.log(`  - Environment: ${env.isTestnet ? 'TESTNET' : 'MAINNET'}`);
  console.log(`  - SwapKit API Key: ${env.apiKey ? '✓ configured' : '✗ not set'}`);
  console.log(`  - Blockchair API Key: ${env.blockchairApiKey ? '✓ configured' : '✗ not set'}`);
  console.log(`  - Zcash address prefix: ${zcash.addressPrefix}`);
  console.log(`  - NEAR network: ${near.networkId}`);
}

export default {
  isTestnetEnvironment,
  getSwapKitEnvironment,
  getSwapKitConfig,
  getZcashConfig,
  getNearConfig,
  logSwapKitConfig,
};
