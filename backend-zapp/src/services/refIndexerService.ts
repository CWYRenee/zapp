/**
 * RHEA Finance Indexer Service
 * Integrates with RHEA Finance indexer API for real pool data, prices, and user positions
 * 
 * API Docs: https://github.com/ref-finance/indexer-helper
 * Mainnet: https://indexer.ref.finance
 * Testnet: https://testnet-indexer.ref-finance.com
 */

import axios, { AxiosInstance } from 'axios';

// Indexer configuration
const MAINNET_INDEXER_URL = 'https://indexer.ref.finance';
const TESTNET_INDEXER_URL = 'https://testnet-indexer.ref-finance.com';
const NEAR_ENV = process.env.NEAR_ENV || 'mainnet';

// Cache configuration
const CACHE_TTL_MS = 60 * 1000; // 1 minute cache

// Types based on indexer response format
export interface RefPoolInfo {
  id: number;
  token_account_ids: string[];
  token_symbols: string[];
  amounts: string[];
  total_fee: number;
  shares_total_supply: string;
  tvl: string;
  token0_ref_price: string;
  share: string;
  update_time?: number;
  farming?: boolean;
}

export interface RefFarmInfo {
  farm_id: string;
  farm_kind: string;
  farm_status: string;
  seed_id: string;
  reward_token: string;
  start_at: number;
  reward_per_session: string;
  session_interval: number;
  total_reward: string;
  cur_round: number;
  last_round: number;
  claimed_reward: string;
  unclaimed_reward: string;
  beneficiary_reward: string;
  // Calculated APR/APY
  apr?: number;
}

export interface RefTokenPrice {
  price: string;
  decimal: number;
  symbol: string;
}

export interface RefUserLiquidityPool {
  pool_id: number;
  token_account_ids: string[];
  token_symbols: string[];
  amounts: string[];
  total_fee: number;
  shares_total_supply: string;
  user_shares: string;
  user_lp_amounts: string[];
  tvl: string;
}

export interface RefWhitelistedPool {
  id: number;
  token_account_ids: string[];
  token_symbols: string[];
  amounts: string[];
  total_fee: number;
  shares_total_supply: string;
  tvl: string;
  volume_24h?: string;
  apy_24h?: string;
  apy_7d?: string;
}

// Cache structure
interface CacheEntry<T> {
  data: T;
  timestamp: number;
}

export class RefIndexerService {
  private client: AxiosInstance;
  private cache: Map<string, CacheEntry<unknown>> = new Map();

  constructor() {
    const baseURL = NEAR_ENV === 'testnet' ? TESTNET_INDEXER_URL : MAINNET_INDEXER_URL;
    
    this.client = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
    
    console.log(`[RefIndexer] Initialized with ${NEAR_ENV} indexer: ${baseURL}`);
  }

  /**
   * Get cached data or fetch fresh
   */
  private async getCached<T>(key: string, fetcher: () => Promise<T>): Promise<T> {
    const cached = this.cache.get(key) as CacheEntry<T> | undefined;
    if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
      return cached.data;
    }
    
    const data = await fetcher();
    this.cache.set(key, { data, timestamp: Date.now() });
    return data;
  }

  /**
   * Get indexer version/status
   */
  async getStatus(): Promise<{ version?: string; timestamp?: number }> {
    try {
      const [welcomeRes, timestampRes] = await Promise.all([
        this.client.get('/'),
        this.client.get('/timestamp'),
      ]);
      return {
        version: welcomeRes.data,
        timestamp: timestampRes.data,
      };
    } catch (error) {
      console.error('[RefIndexer] Failed to get status:', error);
      return {};
    }
  }

  /**
   * Get top pools by liquidity for each token pair
   */
  async getTopPools(): Promise<RefPoolInfo[]> {
    return this.getCached('top-pools', async () => {
      try {
        const response = await this.client.get<RefPoolInfo[]>('/list-top-pools');
        return response.data || [];
      } catch (error) {
        console.error('[RefIndexer] Failed to fetch top pools:', error);
        return [];
      }
    });
  }

  /**
   * Get all pools
   */
  async getAllPools(): Promise<RefPoolInfo[]> {
    return this.getCached('all-pools', async () => {
      try {
        const response = await this.client.get<RefPoolInfo[]>('/list-pools');
        return response.data || [];
      } catch (error) {
        console.error('[RefIndexer] Failed to fetch all pools:', error);
        return [];
      }
    });
  }

  /**
   * Get specific pool by ID
   */
  async getPool(poolId: number): Promise<RefPoolInfo | null> {
    try {
      const response = await this.client.get<RefPoolInfo>('/get-pool', {
        params: { pool_id: poolId },
      });
      return response.data || null;
    } catch (error) {
      console.error(`[RefIndexer] Failed to fetch pool ${poolId}:`, error);
      return null;
    }
  }

  /**
   * Get pools by token pair
   */
  async getPoolsByTokens(token0: string, token1: string): Promise<RefPoolInfo[]> {
    const cacheKey = `pools-${token0}-${token1}`;
    return this.getCached(cacheKey, async () => {
      try {
        const response = await this.client.get<RefPoolInfo[]>('/list-pools-by-tokens', {
          params: { token0, token1 },
        });
        return response.data || [];
      } catch (error) {
        console.error('[RefIndexer] Failed to fetch pools by tokens:', error);
        return [];
      }
    });
  }

  /**
   * Get pools by IDs
   */
  async getPoolsByIds(ids: number[]): Promise<RefPoolInfo[]> {
    try {
      const idsParam = ids.join('|');
      const response = await this.client.get<RefPoolInfo[]>('/list-pools-by-ids', {
        params: { ids: idsParam },
      });
      return response.data || [];
    } catch (error) {
      console.error('[RefIndexer] Failed to fetch pools by IDs:', error);
      return [];
    }
  }

  /**
   * Get whitelisted active pools with volume and liquidity
   * Falls back to top pools if whitelisted endpoint fails
   */
  async getWhitelistedPools(): Promise<RefWhitelistedPool[]> {
    return this.getCached('whitelisted-pools', async () => {
      try {
        const response = await this.client.get<RefWhitelistedPool[]>('/whitelisted-active-pools');
        if (response.data && response.data.length > 0) {
          return response.data;
        }
        throw new Error('Empty response');
      } catch (error) {
        console.warn('[RefIndexer] Whitelisted pools unavailable, falling back to top pools');
        // Fall back to top pools
        try {
          const topPools = await this.getTopPools();
          // Convert to whitelisted pool format
          return topPools.map(pool => ({
            id: pool.id,
            token_account_ids: pool.token_account_ids,
            token_symbols: pool.token_symbols,
            amounts: pool.amounts,
            total_fee: pool.total_fee,
            shares_total_supply: pool.shares_total_supply,
            tvl: pool.tvl,
          }));
        } catch (fallbackError) {
          console.error('[RefIndexer] Fallback to top pools also failed:', fallbackError);
          return [];
        }
      }
    });
  }

  /**
   * Get all farms
   */
  async getAllFarms(): Promise<RefFarmInfo[]> {
    return this.getCached('all-farms', async () => {
      try {
        const response = await this.client.get<RefFarmInfo[]>('/list-farms');
        return response.data || [];
      } catch (error) {
        console.error('[RefIndexer] Failed to fetch farms:', error);
        return [];
      }
    });
  }

  /**
   * Get all token prices
   */
  async getTokenPrices(): Promise<Record<string, RefTokenPrice>> {
    return this.getCached('token-prices', async () => {
      try {
        const response = await this.client.get<Record<string, RefTokenPrice>>('/list-token-price');
        return response.data || {};
      } catch (error) {
        console.error('[RefIndexer] Failed to fetch token prices:', error);
        return {};
      }
    });
  }

  /**
   * Get specific token price
   */
  async getTokenPrice(tokenId: string): Promise<RefTokenPrice | null> {
    try {
      const response = await this.client.get<RefTokenPrice>('/get-token-price', {
        params: { token_id: tokenId },
      });
      return response.data || null;
    } catch (error) {
      console.error(`[RefIndexer] Failed to fetch price for ${tokenId}:`, error);
      return null;
    }
  }

  /**
   * Get all token metadata
   */
  async getTokenMetadata(): Promise<Record<string, unknown>[]> {
    return this.getCached('token-metadata', async () => {
      try {
        const response = await this.client.get<Record<string, unknown>[]>('/list-token');
        return response.data || [];
      } catch (error) {
        console.error('[RefIndexer] Failed to fetch token metadata:', error);
        return [];
      }
    });
  }

  /**
   * Get user's liquidity pools
   */
  async getUserLiquidityPools(accountId: string): Promise<RefUserLiquidityPool[]> {
    try {
      const response = await this.client.get<RefUserLiquidityPool[]>(`/liquidity-pools/${accountId}`);
      return response.data || [];
    } catch (error) {
      console.error(`[RefIndexer] Failed to fetch liquidity pools for ${accountId}:`, error);
      return [];
    }
  }

  /**
   * Get user's latest actions
   */
  async getUserLatestActions(accountId: string): Promise<Array<[string, string, string, string]>> {
    try {
      const response = await this.client.get<Array<[string, string, string, string]>>(`/latest-actions/${accountId}`);
      return response.data || [];
    } catch (error) {
      console.error(`[RefIndexer] Failed to fetch actions for ${accountId}:`, error);
      return [];
    }
  }

  // ============================================================================
  // COMPUTED HELPERS
  // ============================================================================

  /**
   * Calculate estimated APY for a pool based on trading fees and farm rewards
   */
  async calculatePoolApy(poolId: number): Promise<{
    tradingFeeApy: number;
    farmApy: number;
    totalApy: number;
  }> {
    const pool = await this.getPool(poolId);
    if (!pool) {
      return { tradingFeeApy: 0, farmApy: 0, totalApy: 0 };
    }

    // Get whitelisted pool data for volume info
    const whitelistedPools = await this.getWhitelistedPools();
    const whitelistedPool = whitelistedPools.find(p => p.id === poolId);

    // Calculate trading fee APY from 24h volume if available
    let tradingFeeApy = 0;
    if (whitelistedPool?.volume_24h && whitelistedPool.tvl) {
      const volume24h = parseFloat(whitelistedPool.volume_24h) || 0;
      const tvl = parseFloat(whitelistedPool.tvl) || 1;
      const feeRate = pool.total_fee / 10000; // Fee is in basis points
      const dailyFeeRevenue = volume24h * feeRate;
      tradingFeeApy = (dailyFeeRevenue / tvl) * 365 * 100;
    } else if (pool.tvl && parseFloat(pool.tvl) > 0) {
      // Estimate APY based on fee tier and TVL (typical DEX behavior)
      // Higher fee pools tend to have higher volume relative to TVL
      const feeRate = pool.total_fee / 10000;
      const tvl = parseFloat(pool.tvl);
      // Assume daily volume is ~5-20% of TVL for active pools
      const estimatedDailyVolumeRatio = tvl > 1000000 ? 0.15 : tvl > 100000 ? 0.10 : 0.05;
      tradingFeeApy = feeRate * estimatedDailyVolumeRatio * 365 * 100;
    }

    // Get farm APY if pool has farming
    let farmApy = 0;
    if (pool.farming) {
      const farms = await this.getAllFarms();
      const poolFarms = farms.filter(f => f.seed_id.includes(poolId.toString()));
      // Sum up APRs from active farms
      farmApy = poolFarms.reduce((sum, farm) => sum + (farm.apr || 0), 0);
    }

    // Cap APY at reasonable levels
    const totalApy = Math.min(tradingFeeApy + farmApy, 500);

    return {
      tradingFeeApy: Math.round(tradingFeeApy * 100) / 100,
      farmApy: Math.round(farmApy * 100) / 100,
      totalApy: Math.round(totalApy * 100) / 100,
    };
  }

  /**
   * Get top pools sorted by APY
   */
  async getTopPoolsByApy(limit: number = 10): Promise<Array<{
    pool: RefWhitelistedPool;
    apy: number;
    tvl: number;
  }>> {
    const whitelistedPools = await this.getWhitelistedPools();
    
    const poolsWithApy = await Promise.all(
      whitelistedPools.slice(0, 50).map(async pool => {
        const { totalApy } = await this.calculatePoolApy(pool.id);
        return {
          pool,
          apy: totalApy,
          tvl: parseFloat(pool.tvl) || 0,
        };
      })
    );

    return poolsWithApy
      .sort((a, b) => b.apy - a.apy)
      .slice(0, limit);
  }

  /**
   * Get total TVL across all pools
   */
  async getTotalTvl(): Promise<number> {
    try {
      const pools = await this.getWhitelistedPools();
      if (pools.length > 0) {
        return pools.reduce((sum, pool) => sum + (parseFloat(pool.tvl) || 0), 0);
      }
      // Fallback to top pools
      const topPools = await this.getTopPools();
      return topPools.reduce((sum, pool) => sum + (parseFloat(pool.tvl) || 0), 0);
    } catch (error) {
      console.error('[RefIndexer] Failed to get total TVL:', error);
      return 0;
    }
  }

  /**
   * Get average APY across top pools
   */
  async getAverageApy(topN: number = 10): Promise<number> {
    try {
      const topPools = await this.getTopPoolsByApy(topN);
      if (topPools.length === 0) {
        console.warn('[RefIndexer] No pools available for APY calculation, using fallback');
        return 8.5; // Fallback APY
      }
      
      const totalApy = topPools.reduce((sum, p) => sum + p.apy, 0);
      const avgApy = totalApy / topPools.length;
      
      // Return at least a minimum APY if calculation yields 0
      return avgApy > 0 ? Math.round(avgApy * 100) / 100 : 8.5;
    } catch (error) {
      console.error('[RefIndexer] Failed to get average APY:', error);
      return 8.5; // Fallback APY
    }
  }

  /**
   * Clear all cached data
   */
  clearCache(): void {
    this.cache.clear();
    console.log('[RefIndexer] Cache cleared');
  }
}

// Singleton instance
export const refIndexerService = new RefIndexerService();
export default RefIndexerService;
