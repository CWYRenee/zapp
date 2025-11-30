/**
 * SwapKit SDK Types
 * Type definitions for SwapKit integration
 */

// Environment configuration
export interface SwapKitEnvironment {
  isTestnet: boolean;
  apiKey: string | undefined;
  blockchairApiKey: string | undefined;
}

// Zcash address info
export interface ZcashAddressInfo {
  address: string;
  isValid: boolean;
  isTestnet: boolean;
  type: 'transparent' | 'shielded' | 'unknown';
}

// Balance response
export interface BalanceInfo {
  address: string;
  chain: string;
  balance: string;
  balanceUsd?: number;
}

// Fee rates
export interface FeeRates {
  average: number;
  fast: number;
  fastest: number;
}

// Fee estimate
export interface FeeEstimate {
  feeRate: number;
  estimatedFee: string;
  estimatedFeeUsd?: number;
}

// Swap quote request
export interface SwapQuoteRequest {
  sellAsset: string;
  buyAsset: string;
  sellAmount: string;
  sourceAddress: string;
  destinationAddress: string;
  slippage?: number;
  providers?: string[];
}

// Swap route info
export interface SwapRoute {
  providers: string[];
  expectedBuyAmount: string;
  expectedBuyAmountMaxSlippage: string | undefined;
  depositAddress: string | undefined;
  memo: string | undefined;
  estimatedTimeMinutes: number;
  priceImpact: number | undefined;
  fees: {
    networkFee?: string;
    affiliateFee?: string;
    totalFee?: string;
  } | undefined;
  isRecommended: boolean | undefined;
}

// Swap quote response
export interface SwapQuoteResponse {
  routes: SwapRoute[];
  bestRoute: SwapRoute | undefined;
  sellAsset: string;
  buyAsset: string;
  sellAmount: string;
}

/**
 * Bridge deposit info returned to client
 */
export interface BridgeDepositInfo {
  depositAddress: string | undefined;
  memo: string | undefined;
  expectedAmount: string;
  estimatedTimeMinutes: number;
  priceImpact: number | undefined;
  /** Indicates if this is a simulated address (testnet) vs live (mainnet) */
  isSimulated: boolean;
  /** Source of the deposit address */
  source: 'swapkit_api' | 'testnet_simulation' | 'fallback';
}

// Transaction status
export interface TransactionStatus {
  txHash: string;
  status: 'pending' | 'completed' | 'failed';
  chain: string;
  timestamp?: Date;
  details?: Record<string, unknown>;
}

// Supported assets
export const SUPPORTED_ASSETS = {
  // Zcash
  ZEC_MAINNET: 'ZEC.ZEC',
  ZEC_TESTNET: 'ZEC.ZEC', // Same identifier, network determined by SDK config
  
  // NEAR
  NEAR_MAINNET: 'NEAR.NEAR',
  NEAR_TESTNET: 'NEAR.NEAR',
  
  // Wrapped NEAR on Ref Finance
  WNEAR: 'NEAR.wrap.near',
} as const;

// Provider identifiers
export const SWAP_PROVIDERS = {
  NEAR: 'NEAR',
  NEAR_INTENTS: 'NEAR_INTENTS',
  THORCHAIN: 'THORCHAIN',
  CHAINFLIP: 'CHAINFLIP',
  MAYA: 'MAYA',
} as const;
