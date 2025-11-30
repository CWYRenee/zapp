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
} from './config';

// Client utilities
export {
  Chain,
  getEnvironmentMode,
  isTestnet,
  getSupportedChains,
  initializeSwapKitClient,
} from './client';

export type { ChainType } from './client';

// Swap service
export {
  SwapService,
  getSwapService,
  resetSwapService,
} from './swapService';

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
} from './types';

export {
  SUPPORTED_ASSETS,
  SWAP_PROVIDERS,
} from './types';
