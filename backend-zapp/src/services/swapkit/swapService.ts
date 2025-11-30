/**
 * SwapKit Swap Service
 * Handles cross-chain swap quotes and execution
 * 
 * For mainnet: Uses SwapKit HTTP API (https://api.swapkit.dev)
 * For testnet: Provides simulation mode for development testing
 */

import axios, { AxiosInstance } from 'axios';
import { getSwapKitEnvironment } from './config.js';
import type { SwapQuoteRequest, SwapQuoteResponse, SwapRoute, BridgeDepositInfo } from './types.js';
import { SWAP_PROVIDERS } from './types.js';

// SwapKit API configuration
const SWAPKIT_API_URL = 'https://api.swapkit.dev';

/**
 * SwapKit Swap Service
 * Environment-aware service for cross-chain swaps
 */
export class SwapService {
  private client: AxiosInstance;
  private isTestnet: boolean;
  private apiKey: string | undefined;

  constructor() {
    const env = getSwapKitEnvironment();
    this.isTestnet = env.isTestnet;
    this.apiKey = env.apiKey;

    this.client = axios.create({
      baseURL: SWAPKIT_API_URL,
      headers: {
        'Content-Type': 'application/json',
        ...(this.apiKey ? { 'x-api-key': this.apiKey } : {}),
      },
    });

    console.log(`[SwapService] Initialized in ${this.isTestnet ? 'TESTNET' : 'MAINNET'} mode`);
  }

  /**
   * Check if the service is properly configured
   */
  isConfigured(): boolean {
    return Boolean(this.apiKey);
  }

  /**
   * Get a swap quote for ZEC → NEAR
   * In testnet mode, tries real API first, then falls back to simulation
   */
  async getZecToNearQuote(params: {
    sellAmount: string;
    sourceZecAddress: string;
    destinationNearAddress: string;
    slippage?: number;
  }): Promise<SwapQuoteResponse> {
    const { sellAmount, sourceZecAddress, destinationNearAddress, slippage = 3 } = params;
    
    // For testnet, try real API first (SwapKit may support stagenet)
    if (this.isTestnet) {
      // First try the real API with stagenet configuration
      if (this.isConfigured()) {
        try {
          console.log('[SwapService] Testnet: Trying real SwapKit API with stagenet...');
          const quote = await this.getQuoteWithStagenet({
            sellAsset: 'ZEC.ZEC',
            buyAsset: 'NEAR.NEAR',
            sellAmount,
            sourceAddress: sourceZecAddress,
            destinationAddress: destinationNearAddress,
            slippage,
            providers: [SWAP_PROVIDERS.NEAR],
          });
          
          if (quote.bestRoute?.depositAddress) {
            console.log('[SwapService] ✓ Got real testnet quote from SwapKit API');
            return quote;
          }
        } catch (error) {
          console.log('[SwapService] SwapKit API does not support testnet bridging, using simulation');
        }
      }
      
      // Fall back to simulation
      return this.getTestnetSimulatedQuote({
        sellAsset: 'ZEC.ZEC',
        buyAsset: 'NEAR.NEAR',
        sellAmount,
        sourceAddress: sourceZecAddress,
        destinationAddress: destinationNearAddress,
      });
    }

    // Mainnet: use real API
    return this.getQuote({
      sellAsset: 'ZEC.ZEC',
      buyAsset: 'NEAR.NEAR',
      sellAmount,
      sourceAddress: sourceZecAddress,
      destinationAddress: destinationNearAddress,
      slippage,
      providers: [SWAP_PROVIDERS.NEAR],
    });
  }
  
  /**
   * Try getting a quote with stagenet/testnet configuration
   */
  private async getQuoteWithStagenet(request: SwapQuoteRequest): Promise<SwapQuoteResponse> {
    const response = await this.client.post('/quote', {
      sellAsset: request.sellAsset,
      buyAsset: request.buyAsset,
      sellAmount: request.sellAmount,
      sourceAddress: request.sourceAddress,
      destinationAddress: request.destinationAddress,
      slippage: request.slippage || 3,
      providers: request.providers || [SWAP_PROVIDERS.NEAR],
      includeTx: false,
      // Try stagenet flag for testnet support
      stagenet: true,
    });

    const routes = this.parseRoutes(response.data.routes || []);
    const bestRoute = this.selectBestRoute(routes, SWAP_PROVIDERS.NEAR);

    return {
      routes,
      bestRoute: bestRoute || undefined,
      sellAsset: request.sellAsset,
      buyAsset: request.buyAsset,
      sellAmount: request.sellAmount,
    };
  }

  /**
   * Get a swap quote for NEAR → ZEC (withdrawal)
   */
  async getNearToZecQuote(params: {
    sellAmount: string;
    sourceNearAddress: string;
    destinationZecAddress: string;
    slippage?: number;
  }): Promise<SwapQuoteResponse> {
    const { sellAmount, sourceNearAddress, destinationZecAddress, slippage = 3 } = params;

    // For testnet, return simulated quote
    if (this.isTestnet) {
      return this.getTestnetSimulatedQuote({
        sellAsset: 'NEAR.NEAR',
        buyAsset: 'ZEC.ZEC',
        sellAmount,
        sourceAddress: sourceNearAddress,
        destinationAddress: destinationZecAddress,
      });
    }

    // Mainnet: use real API
    return this.getQuote({
      sellAsset: 'NEAR.NEAR',
      buyAsset: 'ZEC.ZEC',
      sellAmount,
      sourceAddress: sourceNearAddress,
      destinationAddress: destinationZecAddress,
      slippage,
      providers: [SWAP_PROVIDERS.NEAR],
    });
  }

  /**
   * Get bridge deposit info for ZEC → NEAR
   * Returns the deposit address and memo for the Zcash transaction
   */
  async getBridgeDepositInfo(params: {
    sellAmount: string;
    sourceZecAddress: string;
    destinationNearAddress: string;
  }): Promise<BridgeDepositInfo> {
    const quote = await this.getZecToNearQuote(params);
    
    if (!quote.bestRoute) {
      throw new Error('No route available for bridge');
    }

    const route = quote.bestRoute;
    
    if (!route.depositAddress) {
      throw new Error('No deposit address in route');
    }

    // Determine if this is simulated or from real API
    const isSimulated = this.isTestnet;
    const source = this.isTestnet ? 'testnet_simulation' : 'swapkit_api';

    return {
      depositAddress: route.depositAddress,
      memo: route.memo,
      expectedAmount: route.expectedBuyAmount,
      estimatedTimeMinutes: route.estimatedTimeMinutes,
      priceImpact: route.priceImpact,
      isSimulated,
      source,
    };
  }

  /**
   * Get a generic swap quote from the API
   */
  private async getQuote(request: SwapQuoteRequest): Promise<SwapQuoteResponse> {
    if (!this.isConfigured()) {
      throw new Error('SwapKit API key not configured');
    }

    try {
      const response = await this.client.post('/quote', {
        sellAsset: request.sellAsset,
        buyAsset: request.buyAsset,
        sellAmount: request.sellAmount,
        sourceAddress: request.sourceAddress,
        destinationAddress: request.destinationAddress,
        slippage: request.slippage || 3,
        providers: request.providers || [SWAP_PROVIDERS.NEAR],
        includeTx: false,
      });

      const routes = this.parseRoutes(response.data.routes || []);
      const bestRoute = this.selectBestRoute(routes, SWAP_PROVIDERS.NEAR);

      return {
        routes,
        bestRoute: bestRoute || undefined,
        sellAsset: request.sellAsset,
        buyAsset: request.buyAsset,
        sellAmount: request.sellAmount,
      };
    } catch (error) {
      console.error('[SwapService] Failed to get quote:', error);
      throw error;
    }
  }

  /**
   * Parse API routes into our format
   */
  private parseRoutes(apiRoutes: unknown[]): SwapRoute[] {
    return (apiRoutes as Array<{
      providers?: string[];
      expectedBuyAmount?: string;
      expectedBuyAmountMaxSlippage?: string;
      targetAddress?: string;
      inboundAddress?: string;
      memo?: string;
      estimatedTime?: { total?: number };
      meta?: { tags?: string[]; priceImpact?: number };
      fees?: Record<string, { networkFee?: string; affiliateFee?: string; totalFee?: string }>;
    }>).map(route => ({
      providers: route.providers || [],
      expectedBuyAmount: route.expectedBuyAmount || '0',
      expectedBuyAmountMaxSlippage: route.expectedBuyAmountMaxSlippage,
      depositAddress: route.targetAddress || route.inboundAddress,
      memo: route.memo,
      estimatedTimeMinutes: Math.ceil((route.estimatedTime?.total || 600) / 60),
      priceImpact: route.meta?.priceImpact,
      fees: route.fees ? Object.values(route.fees)[0] : undefined,
      isRecommended: route.meta?.tags?.includes('RECOMMENDED'),
    }));
  }

  /**
   * Select the best route for a given provider
   */
  private selectBestRoute(routes: SwapRoute[], preferredProvider: string): SwapRoute | null {
    const providerRoutes = routes.filter(r => r.providers.includes(preferredProvider));
    
    if (providerRoutes.length === 0) {
      return routes[0] || null;
    }

    // Prefer recommended route
    const recommended = providerRoutes.find(r => r.isRecommended);
    if (recommended) return recommended;

    return providerRoutes[0];
  }

  /**
   * Generate simulated quote for testnet development
   * This allows testing the flow without real SwapKit API calls
   * 
   * NOTE: The simulated address is NOT monitored by any bridge infrastructure.
   * Funds sent to this address will NOT be bridged. This is for UI/flow testing only.
   */
  private getTestnetSimulatedQuote(params: {
    sellAsset: string;
    buyAsset: string;
    sellAmount: string;
    sourceAddress: string;
    destinationAddress: string;
  }): SwapQuoteResponse {
    const { sellAsset, buyAsset, sellAmount, sourceAddress, destinationAddress } = params;
    
    // Simulated exchange rates (approximate based on recent prices)
    const rates: Record<string, Record<string, number>> = {
      'ZEC.ZEC': { 'NEAR.NEAR': 8.5 },    // 1 ZEC ≈ 8.5 NEAR (simulated)
      'NEAR.NEAR': { 'ZEC.ZEC': 0.118 },  // 1 NEAR ≈ 0.118 ZEC (simulated)
    };

    const rate = rates[sellAsset]?.[buyAsset] || 1;
    const sellAmountNum = parseFloat(sellAmount);
    const expectedBuyAmount = (sellAmountNum * rate * 0.995).toFixed(6); // 0.5% simulated fee

    // Generate a simulated testnet deposit address
    // For simulation, reuse the user's source Zcash address so it is always a syntactically valid
    // address for the current network, allowing the wallet to accept it while still marking it
    // as a simulated bridge target.
    const simulatedDepositAddress = sourceAddress;

    const simulatedRoute: SwapRoute = {
      providers: [SWAP_PROVIDERS.NEAR],
      expectedBuyAmount,
      expectedBuyAmountMaxSlippage: (parseFloat(expectedBuyAmount) * 0.97).toFixed(6),
      depositAddress: simulatedDepositAddress,
      memo: `SIMULATED_BRIDGE:${destinationAddress}`,
      estimatedTimeMinutes: 15,
      priceImpact: 0.5,
      fees: {
        networkFee: '0.001',
        affiliateFee: '0',
        totalFee: '0.001',
      },
      isRecommended: true,
    };

    console.log('[SwapService] ⚠️  Generated SIMULATED testnet quote (no real bridging):', {
      sellAsset,
      buyAsset,
      sellAmount,
      expectedBuyAmount,
      depositAddress: simulatedDepositAddress,
      warning: 'This address is NOT monitored. Funds will NOT be bridged.',
    });

    return {
      routes: [simulatedRoute],
      bestRoute: simulatedRoute,
      sellAsset,
      buyAsset,
      sellAmount,
    };
  }
  
}

// Singleton instance
let swapServiceInstance: SwapService | null = null;

/**
 * Get the SwapService singleton instance
 */
export function getSwapService(): SwapService {
  if (!swapServiceInstance) {
    swapServiceInstance = new SwapService();
  }
  return swapServiceInstance;
}

/**
 * Reset the service instance (useful for testing)
 */
export function resetSwapService(): void {
  swapServiceInstance = null;
}

export default SwapService;
