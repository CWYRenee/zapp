import { useQuery } from '@tanstack/react-query';

// Supported fiat currencies (ordered by priority)
export const SUPPORTED_FIAT_CURRENCIES = [
  'USD',
  'INR',
  'CNY',
  'BRL',
  'EUR',
  'GBP',
  'JPY',
  'KRW',
  'THB',
] as const;
export type SupportedFiatCurrency = (typeof SUPPORTED_FIAT_CURRENCIES)[number];

export function useZecFiatRate(fiatCurrency: string) {
  const currency = fiatCurrency.toLowerCase();

  return useQuery<number>({
    queryKey: ['zec-fiat-rate', currency],
    queryFn: async () => {
      const url = `https://api.coingecko.com/api/v3/simple/price?ids=zcash&vs_currencies=${currency}`;
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error('Failed to fetch ZEC rate');
      }
      const json = (await res.json()) as { zcash?: Record<string, number> };
      const rate = json.zcash?.[currency];
      if (typeof rate !== 'number' || !Number.isFinite(rate)) {
        throw new Error('Invalid ZEC rate');
      }
      return rate;
    },
    staleTime: 60_000,
  });
}

export function useZecFiatRates(fiatCurrencies: string[]) {
  const vs = Array.from(
    new Set(fiatCurrencies.map((c) => c.toLowerCase())),
  ).sort();

  return useQuery<Record<string, number>>({
    queryKey: ['zec-fiat-rates', vs.join(',')],
    queryFn: async () => {
      if (vs.length === 0) {
        return {};
      }
      const url = `https://api.coingecko.com/api/v3/simple/price?ids=zcash&vs_currencies=${vs.join(',')}`;
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error('Failed to fetch ZEC rates');
      }
      const json = (await res.json()) as { zcash?: Record<string, number> };
      return json.zcash ?? {};
    },
    staleTime: 60_000,
    enabled: vs.length > 0,
  });
}
