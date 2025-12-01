import { useCompletedOrders } from '@/hooks/useOrders';
import { useMemo, useState } from 'react';
import {
  SUPPORTED_FIAT_CURRENCIES,
  type SupportedFiatCurrency,
  useZecFiatRates,
} from '@/hooks/useZecFiatRate';

export function AnalyticsDashboard() {
  const { data: orders, isLoading } = useCompletedOrders();

  const [displayCurrency, setDisplayCurrency] = useState<SupportedFiatCurrency>('USD');
  const fiatCurrencies = useMemo(
    () =>
      Array.from(
        new Set(
          [
            ...(orders ?? []).map((order) => order.fiatCurrency),
            displayCurrency,
          ].map((code) => code.toLowerCase()),
        ),
      ),
    [orders, displayCurrency],
  );

  const { data: zecRates } = useZecFiatRates(fiatCurrencies);

  const zecRateDisplay =
    zecRates?.[displayCurrency.toLowerCase()] ?? null;

  const metrics = useMemo(() => {
    if (!orders || orders.length === 0) {
      return {
        totalVolume: 0,
        totalOrders: 0,
        avgCompletionTime: 0,
        totalEarnings: 0,
        volumeHistory: [] as Array<{ date: string; volume: number; dayLabel: string }>,
        earningsHistory: [] as Array<{ date: string; earnings: number; dayLabel: string }>,
        avgTimeHistory: [] as Array<{ date: string; avgMinutes: number }>,
        volumeByFiatCurrency: {} as Record<string, number>,
      };
    }

    const totalVolume = orders.reduce((sum, order) => sum + order.fiatAmount, 0);
    const totalOrders = orders.length;

    const volumeByFiatCurrency = orders.reduce((acc, order) => {
      acc[order.fiatCurrency] = (acc[order.fiatCurrency] || 0) + order.fiatAmount;
      return acc;
    }, {} as Record<string, number>);

    // Facilitator spread earnings: extra ZEC vs base FX
    const totalEarnings = orders.reduce((sum, order) => {
      if (order.merchantZecAmount && order.baseExchangeRate) {
        const earnings =
          order.merchantZecAmount - order.fiatAmount / order.baseExchangeRate;
        return sum + earnings;
      }
      return sum;
    }, 0);

    const totalDuration = orders.reduce((sum, order) => {
      const start = new Date(order.createdAt).getTime();
      const end = new Date(order.updatedAt).getTime();
      return sum + (end - start);
    }, 0);
    const avgCompletionTime = totalDuration / totalOrders / (1000 * 60);

    // Per-day average completion time (in minutes)
    const durationByDate = orders.reduce((acc, order) => {
      const date = new Date(order.updatedAt).toLocaleDateString('en-CA');
      const start = new Date(order.createdAt).getTime();
      const end = new Date(order.updatedAt).getTime();
      const minutes = (end - start) / (1000 * 60);

      const entry = acc[date] ?? { total: 0, count: 0 };
      entry.total += minutes;
      entry.count += 1;
      acc[date] = entry;
      return acc;
    }, {} as Record<string, { total: number; count: number }>);

    const today = new Date();
    const last7Days = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(today);
      d.setDate(d.getDate() - (6 - i));
      return d.toLocaleDateString('en-CA');
    });

    const volumeByDate = orders.reduce((acc, order) => {
      const date = new Date(order.updatedAt).toLocaleDateString('en-CA');
      const amount = Number.isFinite(order.fiatAmount)
        ? order.fiatAmount
        : 0;
      acc[date] = (acc[date] || 0) + amount;
      return acc;
    }, {} as Record<string, number>);

    const earningsByDate = orders.reduce((acc, order) => {
      const date = new Date(order.updatedAt).toLocaleDateString('en-CA');
      if (order.merchantZecAmount && order.baseExchangeRate) {
        const earnings =
          order.merchantZecAmount - order.fiatAmount / order.baseExchangeRate;
        acc[date] = (acc[date] || 0) + earnings;
      }
      return acc;
    }, {} as Record<string, number>);

    const volumeHistory = last7Days.map((date) => ({
      date,
      volume: volumeByDate[date] || 0,
      dayLabel: new Date(date).toLocaleDateString('en-US', {
        weekday: 'short',
        timeZone: 'UTC',
      }),
    }));

    const earningsHistory = last7Days.map((date) => ({
      date,
      earnings: earningsByDate[date] || 0,
      dayLabel: new Date(date).toLocaleDateString('en-US', {
        weekday: 'short',
        timeZone: 'UTC',
      }),
    }));

    const avgTimeHistory = last7Days.map((date) => {
      const entry = durationByDate[date];
      const avgMinutes = entry ? entry.total / entry.count : 0;
      return { date, avgMinutes };
    });

    return {
      totalVolume,
      totalOrders,
      avgCompletionTime,
      totalEarnings,
      volumeHistory,
      earningsHistory,
      avgTimeHistory,
      volumeByFiatCurrency,
    };
  }, [orders]);

  const baseFiatCurrency =
    orders && orders.length > 0 ? orders[0].fiatCurrency : 'USD';

  const totalEarningsFiat =
    zecRateDisplay != null ? metrics.totalEarnings * zecRateDisplay : null;

  const totalVolumeDisplay =
    zecRates && orders
      ? orders.reduce((sum, order) => {
          const underlying = order.fiatCurrency.toLowerCase();
          const rateDisplay = zecRates[displayCurrency.toLowerCase()];
          const rateUnderlying = zecRates[underlying];
          if (!rateDisplay || !rateUnderlying) {
            return sum;
          }
          const crossRate = rateDisplay / rateUnderlying;
          return sum + order.fiatAmount * crossRate;
        }, 0)
      : null;

  if (isLoading) {
    return <div className="text-sm text-gray-500">Loading analytics...</div>;
  }

  const maxVolume = metrics.volumeHistory.reduce((max, d) => {
    const v = Number.isFinite(d.volume) ? d.volume : 0;
    return v > max ? v : max;
  }, 0);
  const maxEarnings = Math.max(
    ...metrics.earningsHistory.map((d) => d.earnings),
    0.00000001,
  );

  // Format currency values for Y-axis labels
  const formatAxisValue = (value: number, currency: string) => {
    if (value >= 1000) {
      return `${(value / 1000).toFixed(1)}k`;
    }
    return value.toLocaleString(undefined, {
      style: 'currency',
      currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    });
  };

  // Generate Y-axis tick values for charts
  const getYAxisTicks = (maxValue: number, tickCount: number = 4) => {
    if (maxValue === 0) return [0];
    const step = maxValue / (tickCount - 1);
    return Array.from({ length: tickCount }, (_, i) => Math.round(step * i));
  };

  const volumeYTicks = getYAxisTicks(maxVolume);

  // Format ZEC values for Y-axis labels
  const formatZecAxisValue = (value: number) => {
    if (value === 0) return '0';
    if (value < 0.001) return value.toExponential(1);
    if (value < 1) return value.toFixed(4);
    return value.toFixed(2);
  };

  const getZecYAxisTicks = (maxValue: number, tickCount: number = 4) => {
    if (maxValue === 0) return [0];
    const step = maxValue / (tickCount - 1);
    return Array.from({ length: tickCount }, (_, i) => step * i);
  };

  const earningsYTicks = getZecYAxisTicks(maxEarnings);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-gray-900">Analytics</h2>
        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-500">Display currency</span>
          <select
            value={displayCurrency}
            onChange={(e) =>
              setDisplayCurrency(e.target.value as SupportedFiatCurrency)
            }
            className="rounded-md border border-gray-300 bg-white px-2 py-1 text-xs text-gray-700 shadow-sm focus:border-[#FF9417] focus:outline-none focus:ring-1 focus:ring-[#FF9417]"
          >
            {SUPPORTED_FIAT_CURRENCIES.map((code) => (
              <option key={code} value={code}>
                {code}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-medium text-gray-500">Total Volume</h3>
          <div className="mt-2 flex items-baseline">
            <span className="text-3xl font-semibold text-gray-900">
              {(totalVolumeDisplay ?? metrics.totalVolume).toLocaleString(
                undefined,
                {
                  style: 'currency',
                  currency:
                    totalVolumeDisplay != null ? displayCurrency : baseFiatCurrency,
                  minimumFractionDigits: 0,
                  maximumFractionDigits: 0,
                },
              )}
            </span>
            <span className="ml-2 text-sm text-gray-500">all time</span>
          </div>
          {Object.keys(metrics.volumeByFiatCurrency).length > 0 && (
            <div className="mt-1 space-y-0.5 text-xs text-gray-500">
              {Object.entries(metrics.volumeByFiatCurrency).map(
                ([currency, amount]) => (
                  <div key={currency}>
                    {amount.toLocaleString(undefined, {
                      style: 'currency',
                      currency,
                      minimumFractionDigits: 0,
                      maximumFractionDigits: 0,
                    })}
                  </div>
                ),
              )}
            </div>
          )}
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-medium text-gray-500">Total Orders</h3>
          <div className="mt-2 flex items-baseline">
            <span className="text-3xl font-semibold text-gray-900">
              {metrics.totalOrders}
            </span>
            <span className="ml-2 text-sm text-gray-500">completed</span>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-medium text-gray-500">Avg. Speed</h3>
          <div className="mt-2 flex items-baseline">
            <span className="text-3xl font-semibold text-gray-900">
              {Math.round(metrics.avgCompletionTime * 60)}
            </span>
            <span className="ml-2 text-sm text-gray-500">sec / order</span>
          </div>
        </div>

        <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-6 shadow-sm">
          <h3 className="text-sm font-medium text-emerald-700">Total Earnings</h3>
          <div className="mt-2 flex items-baseline">
            <span className="text-3xl font-semibold text-emerald-900">
              {metrics.totalEarnings.toFixed(6)}
            </span>
            <span className="ml-2 text-sm text-emerald-600">ZEC</span>
          </div>
          {totalEarningsFiat != null && (
            <div className="mt-1 text-xs text-emerald-700">
              ≈{' '}
              {totalEarningsFiat.toLocaleString(undefined, {
                style: 'currency',
                currency: displayCurrency,
                maximumFractionDigits: 2,
              })}
            </div>
          )}
          <div className="mt-1 text-xs text-emerald-600">from spread</div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-base font-semibold text-gray-900">
              Volume History
            </h3>
            <span className="text-xs text-gray-400">Last 7 days</span>
          </div>
          <div className="relative h-52">
            {metrics.volumeHistory.every((d) => d.volume === 0) ? (
              <div className="flex h-full w-full items-center justify-center text-sm text-gray-400">
                No volume in the last 7 days
              </div>
            ) : (
              <div className="flex h-full">
                {/* Y-axis labels */}
                <div className="flex flex-col justify-between pr-3 text-right h-[calc(100%-24px)]">
                  {[...volumeYTicks].reverse().map((tick, i) => (
                    <span key={i} className="text-[10px] text-gray-400 leading-none">
                      {formatAxisValue(tick, baseFiatCurrency)}
                    </span>
                  ))}
                </div>
                
                {/* Chart area */}
                <div className="flex-1 relative">
                  {/* Horizontal gridlines */}
                  <div className="absolute inset-x-0 top-0 bottom-6 flex flex-col justify-between pointer-events-none">
                    {volumeYTicks.map((_, i) => (
                      <div key={i} className="border-t border-gray-100 w-full" />
                    ))}
                  </div>
                  
                  {/* Bars */}
                  <div className="absolute inset-x-0 top-0 bottom-6 flex items-end justify-between gap-1 sm:gap-2">
                    {metrics.volumeHistory.map((day, index) => {
                      const barHeight =
                        day.volume <= 0 || maxVolume <= 0
                          ? 0
                          : Math.max((day.volume / maxVolume) * 100, 4);
                      const isFirst = index === 0;
                      const isLast = index === metrics.volumeHistory.length - 1;

                      return (
                        <div
                          key={day.date}
                          className="group relative flex flex-1 items-end justify-center"
                          style={{ height: '100%' }}
                        >
                          <div
                            className="relative w-full max-w-[48px] rounded-t bg-gradient-to-t from-[#FF9417] to-[#FFB347] shadow-sm transition-all duration-200 group-hover:from-[#E68515] group-hover:to-[#FF9417] group-hover:shadow-md"
                            style={{ height: `${barHeight}%` }}
                          >
                            {/* Tooltip */}
                            <div
                              className={`absolute bottom-full mb-2 z-20 whitespace-nowrap rounded-lg bg-gray-900/95 backdrop-blur-sm px-3 py-2 text-xs text-white opacity-0 transition-all duration-200 group-hover:opacity-100 shadow-lg ${
                                isFirst ? 'left-0' : isLast ? 'right-0' : 'left-1/2 -translate-x-1/2'
                              }`}
                            >
                              <div className="font-semibold text-sm">
                                {day.volume.toLocaleString(undefined, {
                                  style: 'currency',
                                  currency: baseFiatCurrency,
                                  minimumFractionDigits: 0,
                                })}
                              </div>
                              <div className="mt-1 text-[10px] text-gray-300">
                                {new Date(day.date).toLocaleDateString('en-US', {
                                  month: 'short',
                                  day: 'numeric',
                                  timeZone: 'UTC',
                                })}
                              </div>
                              {/* Tooltip arrow */}
                              <div
                                className={`absolute top-full border-4 border-transparent border-t-gray-900/95 ${
                                  isFirst ? 'left-4' : isLast ? 'right-4' : 'left-1/2 -translate-x-1/2'
                                }`}
                              />
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                  
                  {/* X-axis labels */}
                  <div className="absolute inset-x-0 bottom-0 flex justify-between gap-1 sm:gap-2">
                    {metrics.volumeHistory.map((day) => (
                      <span
                        key={day.date}
                        className="flex-1 text-center text-[10px] sm:text-xs font-medium text-gray-500"
                      >
                        {day.dayLabel}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="rounded-lg border border-emerald-200 bg-white p-6 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-base font-semibold text-emerald-900">
              Facilitator Earnings
            </h3>
            <span className="text-xs text-emerald-500">Last 7 days • ZEC</span>
          </div>
          <div className="relative h-52">
            {metrics.earningsHistory.every((d) => d.earnings === 0) ? (
              <div className="flex h-full w-full items-center justify-center text-sm text-gray-400">
                No earnings in the last 7 days
              </div>
            ) : (
              <div className="flex h-full">
                {/* Y-axis labels */}
                <div className="flex flex-col justify-between pr-3 text-right h-[calc(100%-24px)]">
                  {[...earningsYTicks].reverse().map((tick, i) => (
                    <span key={i} className="text-[10px] text-gray-400 leading-none">
                      {formatZecAxisValue(tick)}
                    </span>
                  ))}
                </div>
                
                {/* Chart area */}
                <div className="flex-1 relative">
                  {/* Horizontal gridlines */}
                  <div className="absolute inset-x-0 top-0 bottom-6 flex flex-col justify-between pointer-events-none">
                    {earningsYTicks.map((_, i) => (
                      <div key={i} className="border-t border-emerald-50 w-full" />
                    ))}
                  </div>
                  
                  {/* Bars */}
                  <div className="absolute inset-x-0 top-0 bottom-6 flex items-end justify-between gap-1 sm:gap-2">
                    {metrics.earningsHistory.map((day, index) => {
                      const barHeight =
                        day.earnings === 0
                          ? 0
                          : Math.max((day.earnings / maxEarnings) * 100, 4);
                      const isFirst = index === 0;
                      const isLast = index === metrics.earningsHistory.length - 1;

                      return (
                        <div
                          key={day.date}
                          className="group relative flex flex-1 items-end justify-center"
                          style={{ height: '100%' }}
                        >
                          <div
                            className="relative w-full max-w-[48px] rounded-t bg-gradient-to-t from-emerald-600 to-emerald-400 shadow-sm transition-all duration-200 group-hover:from-emerald-700 group-hover:to-emerald-500 group-hover:shadow-md"
                            style={{ height: `${barHeight}%` }}
                          >
                            {/* Tooltip */}
                            <div
                              className={`absolute bottom-full mb-2 z-20 whitespace-nowrap rounded-lg bg-gray-900/95 backdrop-blur-sm px-3 py-2 text-xs text-white opacity-0 transition-all duration-200 group-hover:opacity-100 shadow-lg ${
                                isFirst ? 'left-0' : isLast ? 'right-0' : 'left-1/2 -translate-x-1/2'
                              }`}
                            >
                              <div className="font-semibold text-sm text-emerald-300">
                                {day.earnings.toFixed(6)} ZEC
                              </div>
                              {zecRateDisplay != null && (
                                <div className="mt-0.5 text-[10px] text-gray-300">
                                  ≈ {(
                                    day.earnings * zecRateDisplay
                                  ).toLocaleString(undefined, {
                                    style: 'currency',
                                    currency: displayCurrency,
                                    maximumFractionDigits: 2,
                                  })}
                                </div>
                              )}
                              <div className="mt-1 text-[10px] text-gray-400">
                                {new Date(day.date).toLocaleDateString('en-US', {
                                  month: 'short',
                                  day: 'numeric',
                                  timeZone: 'UTC',
                                })}
                              </div>
                              {/* Tooltip arrow */}
                              <div
                                className={`absolute top-full border-4 border-transparent border-t-gray-900/95 ${
                                  isFirst ? 'left-4' : isLast ? 'right-4' : 'left-1/2 -translate-x-1/2'
                                }`}
                              />
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                  
                  {/* X-axis labels */}
                  <div className="absolute inset-x-0 bottom-0 flex justify-between gap-1 sm:gap-2">
                    {metrics.earningsHistory.map((day) => (
                      <span
                        key={day.date}
                        className="flex-1 text-center text-[10px] sm:text-xs font-medium text-gray-500"
                      >
                        {day.dayLabel}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
