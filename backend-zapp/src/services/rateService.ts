import axios from 'axios';

interface CoingeckoResponse {
  zcash: Record<string, number>;
}

export class RateService {
  private static cache: Record<string, { rate: number; timestamp: number }> = {};
  private static CACHE_TTL = 60 * 1000; // 1 minute

  /**
   * Get the fiat price for 1 ZEC.
   * Fetches from Coingecko API.
   */
  static async getZecToFiatRate(fiatCurrency: string): Promise<number> {
    const currency = fiatCurrency.toLowerCase();

    // Check cache
    const cached = this.cache[currency];
    if (cached && Date.now() - cached.timestamp < this.CACHE_TTL) {
      return cached.rate;
    }

    try {
      const url = `https://api.coingecko.com/api/v3/simple/price?ids=zcash&vs_currencies=${currency}`;
      const response = await axios.get<CoingeckoResponse>(url);

      const rate = response.data.zcash?.[currency];

      if (!rate) {
        // Fallback to env var if API fails or currency not found
        console.warn(`Rate not found for ${currency}, using fallback`);
        return this.fallbackRate();
      }

      this.cache[currency] = { rate, timestamp: Date.now() };
      return rate;
    } catch (error) {
      console.error('Error fetching rate:', error);
      return this.fallbackRate();
    }
  }

  private static fallbackRate(): number {
    const raw = process.env.ZEC_FIAT_RATE ?? '50';
    const rate = Number(raw);
    return Number.isFinite(rate) && rate > 0 ? rate : 50;
  }

  /**
   * Compute ZEC amount and exchange rate from a fiat amount.
   */
  static async computeZecAmount(fiatAmount: number, fiatCurrency: string): Promise<{ zecAmount: number; exchangeRate: number }> {
    const rate = await this.getZecToFiatRate(fiatCurrency);
    const zecAmountRaw = fiatAmount / rate;

    const zecAmount = Number(zecAmountRaw.toFixed(8));

    return {
      zecAmount,
      exchangeRate: rate,
    };
  }

  /**
   * Compute ZEC amounts with 1% spread (0.5% to merchant, 0.5% to platform).
   * 
   * The spread works by reducing the effective exchange rate so users pay more ZEC.
   * - User pays at effective rate of (baseRate / 1.01)
   * - Merchant receives at effective rate of (baseRate / 1.005)
   * - Platform receives the difference (0.5% of fiat value in ZEC)
   */
  static async computeZecAmountWithSpread(
    fiatAmount: number,
    fiatCurrency: string
  ): Promise<{
    baseExchangeRate: number;
    userDisplayRate: number;
    merchantDisplayRate: number;
    userZecAmount: number;
    merchantZecAmount: number;
    platformZecAmount: number;
  }> {
    const baseRate = await this.getZecToFiatRate(fiatCurrency);

    // Apply spread by reducing effective rate (lower rate = more ZEC needed)
    // User pays 1% more ZEC than base rate would indicate
    const userDisplayRate = baseRate / 1.01;

    // Merchant pays out 0.5% more ZEC than base rate (half the spread)
    const merchantDisplayRate = baseRate / 1.005;

    // Calculate ZEC amounts
    const userZecAmountRaw = fiatAmount / userDisplayRate;
    const merchantZecAmountRaw = fiatAmount / merchantDisplayRate;
    const platformZecAmountRaw = userZecAmountRaw - merchantZecAmountRaw;

    // Round to 8 decimal places (standard for ZEC)
    const userZecAmount = Number(userZecAmountRaw.toFixed(8));
    const merchantZecAmount = Number(merchantZecAmountRaw.toFixed(8));
    const platformZecAmount = Number(platformZecAmountRaw.toFixed(8));

    return {
      baseExchangeRate: baseRate,
      userDisplayRate,
      merchantDisplayRate,
      userZecAmount,
      merchantZecAmount,
      platformZecAmount,
    };
  }
}
