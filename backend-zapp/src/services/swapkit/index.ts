/**
 * SwapKit Service Module
 * 
 * Environment-aware SwapKit integration for cross-chain swaps
 * Supports both mainnet (via SwapKit HTTP API) and testnet (simulation mode)
 */

// Configuration
export {
  isTestnetEnvironment,
  getSwapKitEnvironment,
  getSwapKitConfig,
  getZcashConfig,
  getNearConfig,
  logSwapKitConfig,
} from './config.js';

// Client utilities
export {
  Chain,
  getEnvironmentMode,
  isTestnet,
  getSupportedChains,
  initializeSwapKitClient,
} from './client.js';

export type { ChainType } from './client.js';

// Swap service
export {
  SwapService,
  getSwapService,
  resetSwapService,
} from './swapService.js';

// Types
export type {
  SwapKitEnvironment,
  ZcashAddressInfo,
  BalanceInfo,
  FeeRates,
  FeeEstimate,
  SwapQuoteRequest,
  SwapRoute,
  SwapQuoteResponse,
  BridgeDepositInfo,
  TransactionStatus,
} from './types.js';

export {
  SUPPORTED_ASSETS,
  SWAP_PROVIDERS,
} from './types.js';
