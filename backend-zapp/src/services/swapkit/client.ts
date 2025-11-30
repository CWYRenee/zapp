/**
 * SwapKit Client Configuration
 * Manages environment-aware SwapKit API client
 * 
 * Note: @swapkit/sdk has browser-specific dependencies (CSS imports)
 * that don't work in Node.js. We use the HTTP API instead with
 * testnet simulation capabilities.
 */

import { isTestnetEnvironment, logSwapKitConfig } from './config';

// Supported chain identifiers
export const Chain = {
  Zcash: 'ZEC',
  Bitcoin: 'BTC',
  Ethereum: 'ETH',
  Near: 'NEAR',
  Avalanche: 'AVAX',
  Polygon: 'POL',
} as const;

export type ChainType = typeof Chain[keyof typeof Chain];

/**
 * Get current environment mode
 */
export function getEnvironmentMode(): 'testnet' | 'mainnet' {
  return isTestnetEnvironment() ? 'testnet' : 'mainnet';
}

/**
 * Check if running in testnet mode
 */
export function isTestnet(): boolean {
  return isTestnetEnvironment();
}

/**
 * Get supported chains for the current environment
 */
export function getSupportedChains(): ChainType[] {
  return [
    Chain.Zcash,
    Chain.Bitcoin,
    Chain.Ethereum,
    Chain.Near,
  ];
}

/**
 * Initialize and log the configuration
 */
export function initializeSwapKitClient(): void {
  logSwapKitConfig();
}

export default {
  Chain,
  getEnvironmentMode,
  isTestnet,
  getSupportedChains,
  initializeSwapKitClient,
};
