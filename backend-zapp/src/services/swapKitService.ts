/**
 * SwapKit Service
 * Integrates with SwapKit API for cross-chain bridging via NEAR provider
 * 
 * This is a backward-compatible wrapper around the new modular SwapKit service.
 * For new code, prefer importing from './swapkit.js' directly.
 * 
 * Features:
 * - Mainnet: Uses SwapKit HTTP API (https://api.swapkit.dev)
 * - Testnet: Provides simulation mode for development testing (TAZ → NEAR testnet)
 */

import axios, { AxiosInstance } from 'axios';
import { getSwapService, isTestnet } from './swapkit/index.js';

// SwapKit API configuration
const SWAPKIT_BASE_URL = 'https://api.swapkit.dev';
const SWAPKIT_API_KEY = process.env.SWAPKIT_KEY || '';

// Token identifiers
const ZEC_IDENTIFIER = 'ZEC.ZEC';
const NEAR_PROVIDER = 'NEAR';

interface SwapKitToken {
  chain: string;
  chainId?: string;
  ticker?: string;
  identifier: string;
  symbol?: string;
  name?: string;
  decimals?: number;
  logoURI?: string;
  coingeckoId?: string;
}

interface QuoteRoute {
  providers: string[];
  expectedBuyAmount?: string;
  expectedBuyAmountMaxSlippage?: string;
  targetAddress?: string;
  inboundAddress?: string;
  memo?: string;
  estimatedTime?: {
    inbound?: number;
    swap?: number;
    outbound?: number;
    total?: number;
  };
  meta?: {
    tags?: string[];
    priceImpact?: number;
  };
  fees?: {
    [key: string]: {
      networkFee?: string;
      affiliateFee?: string;
      totalFee?: string;
    };
  };
}

interface QuoteResponse {
  routes: QuoteRoute[];
}

interface PriceResponseItem {
  identifier: string;
  price_usd: number;
}

export interface SwapQuoteResult {
  expectedBuyAmount: string;
  depositAddress: string;
  memo: string | undefined;
  estimatedTimeMinutes: number;
  priceImpact: number | undefined;
  /** Whether this is a simulated testnet address */
  isSimulated: boolean;
  /** Source of the quote/address */
  source: 'swapkit_api' | 'testnet_simulation' | 'fallback';
}

export class SwapKitService {
  private client: AxiosInstance;
  private testnetMode: boolean;

  constructor() {
    this.testnetMode = isTestnet();
    
    this.client = axios.create({
      baseURL: SWAPKIT_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': SWAPKIT_API_KEY,
      },
    });

    console.log(`[SwapKitService] Initialized in ${this.testnetMode ? 'TESTNET (simulation)' : 'MAINNET'} mode`);
  }

  /**
   * Check if SwapKit is configured
   * In testnet mode, returns true (simulation doesn't need API key)
   */
  isConfigured(): boolean {
    if (this.testnetMode) return true;
    return SWAPKIT_API_KEY.length > 0;
  }

  /**
   * Check if running in testnet/simulation mode
   */
  isTestnetMode(): boolean {
    return this.testnetMode;
  }

  /**
   * Get available tokens for NEAR provider
   */
  async getAvailableTokens(): Promise<SwapKitToken[]> {
    if (!this.isConfigured()) {
      console.warn('[SwapKit] API key not configured');
      return [];
    }

    try {
      const response = await this.client.get('/tokens', {
        params: { provider: NEAR_PROVIDER },
      });
      return response.data.tokens || [];
    } catch (error) {
      console.error('[SwapKit] Failed to fetch tokens:', error);
      return [];
    }
  }

  /**
   * Get ZEC price in USD
   */
  async getZecPrice(): Promise<number> {
    if (!this.isConfigured()) {
      throw new Error('SwapKit API key not configured');
    }

    try {
      const response = await this.client.post<PriceResponseItem[]>('/price', {
        tokens: [{ identifier: ZEC_IDENTIFIER }],
        metadata: true,
      });

      const zecPrice = response.data.find(item => item.identifier === ZEC_IDENTIFIER);
      if (!zecPrice || zecPrice.price_usd <= 0) {
        throw new Error('ZEC price unavailable');
      }

      return zecPrice.price_usd;
    } catch (error) {
      console.error('[SwapKit] Failed to fetch ZEC price:', error);
      throw error;
    }
  }

  /**
   * Get quote for ZEC swap to another asset
   * This is used to get the bridge deposit address
   * 
   * In testnet mode: Returns simulated quote for TAZ → NEAR testnet
   * In mainnet mode: Uses SwapKit API for real quotes
   */
  async getZecSwapQuote(params: {
    buyAsset: string;
    sellAmount: string;
    sourceZecAddress: string;
    destinationAddress: string;
    slippage?: number;
  }): Promise<SwapQuoteResult> {
    const { buyAsset, sellAmount, sourceZecAddress, destinationAddress, slippage = 3 } = params;

    // Use new modular service for testnet simulation
    if (this.testnetMode) {
      const swapService = getSwapService();
      const quote = await swapService.getZecToNearQuote({
        sellAmount,
        sourceZecAddress,
        destinationNearAddress: destinationAddress,
        slippage,
      });

      if (!quote.bestRoute || !quote.bestRoute.depositAddress) {
        throw new Error('No route available for swap');
      }

      return {
        expectedBuyAmount: quote.bestRoute.expectedBuyAmount,
        depositAddress: quote.bestRoute.depositAddress,
        memo: quote.bestRoute.memo,
        estimatedTimeMinutes: quote.bestRoute.estimatedTimeMinutes,
        priceImpact: quote.bestRoute.priceImpact,
        isSimulated: true,
        source: 'testnet_simulation',
      };
    }

    // Mainnet: use real API
    if (!this.isConfigured()) {
      throw new Error('SwapKit API key not configured');
    }

    try {
      const response = await this.client.post<QuoteResponse>('/quote', {
        sellAsset: ZEC_IDENTIFIER,
        buyAsset,
        sellAmount,
        providers: [NEAR_PROVIDER],
        sourceAddress: sourceZecAddress,
        destinationAddress,
        slippage,
        includeTx: false,
      });

      const route = this.selectBestRoute(response.data.routes);
      if (!route) {
        throw new Error('No route available for swap');
      }

      const depositAddress = route.targetAddress || route.inboundAddress;
      if (!depositAddress) {
        throw new Error('No deposit address in route');
      }

      return {
        expectedBuyAmount: route.expectedBuyAmount || '0',
        depositAddress,
        memo: route.memo,
        estimatedTimeMinutes: Math.ceil((route.estimatedTime?.total || 600) / 60),
        priceImpact: route.meta?.priceImpact,
        isSimulated: false,
        source: 'swapkit_api',
      };
    } catch (error) {
      console.error('[SwapKit] Failed to get quote:', error);
      throw error;
    }
  }

  /**
   * Get quote for swapping asset back to ZEC
   * Used for withdrawals
   * 
   * In testnet mode: Returns simulated quote for NEAR testnet → TAZ
   * In mainnet mode: Uses SwapKit API for real quotes
   */
  async getSwapToZecQuote(params: {
    sellAsset: string;
    sellAmount: string;
    sourceAddress: string;
    destinationZecAddress: string;
    slippage?: number;
  }): Promise<SwapQuoteResult> {
    const { sellAsset, sellAmount, sourceAddress, destinationZecAddress, slippage = 3 } = params;

    // Use new modular service for testnet simulation
    if (this.testnetMode) {
      const swapService = getSwapService();
      const quote = await swapService.getNearToZecQuote({
        sellAmount,
        sourceNearAddress: sourceAddress,
        destinationZecAddress,
        slippage,
      });

      if (!quote.bestRoute || !quote.bestRoute.depositAddress) {
        throw new Error('No route available for swap to ZEC');
      }

      return {
        expectedBuyAmount: quote.bestRoute.expectedBuyAmount,
        depositAddress: quote.bestRoute.depositAddress,
        memo: quote.bestRoute.memo,
        estimatedTimeMinutes: quote.bestRoute.estimatedTimeMinutes,
        priceImpact: quote.bestRoute.priceImpact,
        isSimulated: true,
        source: 'testnet_simulation',
      };
    }

    // Mainnet: use real API
    if (!this.isConfigured()) {
      throw new Error('SwapKit API key not configured');
    }

    try {
      const response = await this.client.post<QuoteResponse>('/quote', {
        sellAsset,
        buyAsset: ZEC_IDENTIFIER,
        sellAmount,
        providers: [NEAR_PROVIDER],
        sourceAddress,
        destinationAddress: destinationZecAddress,
        slippage,
        includeTx: false,
      });

      const route = this.selectBestRoute(response.data.routes);
      if (!route) {
        throw new Error('No route available for swap to ZEC');
      }

      const depositAddress = route.targetAddress || route.inboundAddress;
      if (!depositAddress) {
        throw new Error('No deposit address in route');
      }

      return {
        expectedBuyAmount: route.expectedBuyAmount || '0',
        depositAddress,
        memo: route.memo,
        estimatedTimeMinutes: Math.ceil((route.estimatedTime?.total || 600) / 60),
        priceImpact: route.meta?.priceImpact,
        isSimulated: false,
        source: 'swapkit_api',
      };
    } catch (error) {
      console.error('[SwapKit] Failed to get swap to ZEC quote:', error);
      throw error;
    }
  }

  /**
   * Select the best route from available routes
   */
  private selectBestRoute(routes: QuoteRoute[]): QuoteRoute | null {
    const nearRoutes = routes.filter(r => r.providers.includes(NEAR_PROVIDER));
    if (nearRoutes.length === 0) return null;

    // Prefer recommended route
    const recommended = nearRoutes.find(r => r.meta?.tags?.includes('RECOMMENDED'));
    if (recommended) return recommended;

    return nearRoutes[0];
  }
}

// Singleton instance
export const swapKitService = new SwapKitService();
export default SwapKitService;
