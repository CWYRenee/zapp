import { useState, useMemo } from 'react';
import { Check, Copy, X, Users } from 'lucide-react';
import type { ZapOrder } from '@/types/order';
import { useAcceptOrder, useActiveOrders, useCompletedOrders, useMarkFiatSent, useMarkZecReceived, usePendingOrders } from '@/hooks/useOrders';
import { QRCodeDisplay } from './QRCodeDisplay';

// Group orders by groupId for display
interface OrderGroup {
  groupId: string | null;
  orders: ZapOrder[];
  totalZec: number;
  isGroup: boolean;
  groupExpiresAt?: string;
}

function groupOrders(orders: ZapOrder[]): OrderGroup[] {
  const grouped = new Map<string | null, ZapOrder[]>();
  
  for (const order of orders) {
    const key = order.groupId ?? null;
    if (!grouped.has(key)) {
      grouped.set(key, []);
    }
    grouped.get(key)!.push(order);
  }

  const result: OrderGroup[] = [];
  
  for (const [groupId, groupOrders] of grouped) {
    result.push({
      groupId,
      orders: groupOrders,
      totalZec: groupOrders.reduce((sum, o) => sum + o.zecAmount, 0),
      isGroup: groupId !== null && groupOrders.length > 1,
      groupExpiresAt: groupOrders[0]?.groupExpiresAt,
    });
  }

  // Sort: groups first (by expiry), then individual orders by created date
  return result.sort((a, b) => {
    if (a.isGroup && !b.isGroup) return -1;
    if (!a.isGroup && b.isGroup) return 1;
    return new Date(a.orders[0].createdAt).getTime() - new Date(b.orders[0].createdAt).getTime();
  });
}

export function OrdersTable() {
  const pending = usePendingOrders();
  const active = useActiveOrders();
  const completed = useCompletedOrders();
  const acceptMutation = useAcceptOrder();
  const fiatMutation = useMarkFiatSent();
  const zecMutation = useMarkZecReceived();

  const [showCompleted, setShowCompleted] = useState(true);
  const [dismissedPendingIds, setDismissedPendingIds] = useState<Set<string>>(() => new Set());
  const [dismissedGroupIds, setDismissedGroupIds] = useState<Set<string>>(() => new Set());

  const pendingOrders = pending.data ?? [];
  const activeOrders = active.data ?? [];
  const completedOrders = completed.data ?? [];
  
  // Filter out dismissed orders and groups
  const visiblePendingOrders = pendingOrders.filter((order) => {
    if (dismissedPendingIds.has(order._id)) return false;
    if (order.groupId && dismissedGroupIds.has(order.groupId)) return false;
    return true;
  });

  // Group pending orders
  const groupedPendingOrders = useMemo(() => groupOrders(visiblePendingOrders), [visiblePendingOrders]);

  const handleAccept = async (order: ZapOrder) => {
    await acceptMutation.mutateAsync({ orderId: order.orderId });
  };

  // Accept all orders in a group
  const handleAcceptGroup = async (group: OrderGroup) => {
    // Accept each order in the group sequentially
    for (const order of group.orders) {
      await acceptMutation.mutateAsync({ orderId: order.orderId });
    }
  };

  const handleReject = (order: ZapOrder) => {
    setDismissedPendingIds((prev) => {
      const next = new Set(prev);
      next.add(order._id);
      return next;
    });
  };

  const handleRejectGroup = (groupId: string) => {
    setDismissedGroupIds((prev) => {
      const next = new Set(prev);
      next.add(groupId);
      return next;
    });
  };

  const handleMarkFiat = async (order: ZapOrder) => {
    await fiatMutation.mutateAsync({ orderId: order.orderId });
  };

  const handleMarkZec = async (order: ZapOrder) => {
    await zecMutation.mutateAsync({ orderId: order.orderId });
  };

  const handleCopy = async (value: string) => {
    if (typeof navigator === 'undefined' || !navigator.clipboard) return;
    try {
      await navigator.clipboard.writeText(value);
    } catch (error) {
      console.error('Failed to copy to clipboard', error);
    }
  };

  const renderOrderCards = (
    isLoading: boolean,
    orders: ZapOrder[],
    emptyLabel: string,
    variant: 'pending' | 'active' | 'completed',
  ) => {
    if (isLoading && orders.length === 0) {
      return <div className="text-sm text-gray-500">Loading orders...</div>;
    }

    if (orders.length === 0) {
      return (
        <div className="rounded-md border border-dashed border-gray-300 bg-gray-50 px-4 py-6 text-center text-sm text-gray-500">
          {emptyLabel}
        </div>
      );
    }

    return (
      <div className="space-y-3">
        {orders.map((order) => (
          <div
            key={order._id}
            className="rounded-md border border-gray-200 bg-white p-3 shadow-sm flex flex-col gap-2"
          >
            <div className="flex items-start justify-between gap-3">
              <div className="space-y-1 text-xs text-gray-700">
                <div className="font-mono text-[11px] break-all text-gray-900">{order.orderId}</div>
                <div className="text-[11px] text-gray-500">Created {new Date(order.createdAt).toLocaleString()}</div>
                {variant === 'completed' && (
                  <div className="text-[11px] text-gray-500">Completed {new Date(order.updatedAt).toLocaleString()}</div>
                )}
              </div>
              <div className="space-y-1 text-xs text-right">
                <div className="flex items-center justify-end gap-1">
                  <span className="text-[11px] text-gray-500">Send fiat</span>
                  <button
                    type="button"
                    onClick={() => void handleCopy(`${order.fiatAmount} ${order.fiatCurrency}`)}
                    className="inline-flex items-center rounded-full border border-gray-200 bg-white p-0.5 text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  >
                    <Copy className="h-3 w-3" aria-hidden="true" />
                  </button>
                </div>
                <div className="text-xs font-medium text-gray-900">
                  {order.fiatAmount.toLocaleString()} {order.fiatCurrency}
                </div>

                {/* Show facilitator ZEC amount and spread earnings */}
                {order.merchantZecAmount && order.baseExchangeRate && (
                  <>
                    <div className="flex items-center justify-end gap-1 mt-1">
                      <span className="text-[11px] text-gray-500">ZEC to pay</span>
                    </div>
                    <div className="text-xs font-medium text-gray-900">
                      {order.merchantZecAmount.toFixed(8)} ZEC
                    </div>
                    <div className="text-[10px] text-emerald-600">
                      +{((order.merchantZecAmount - order.fiatAmount / order.baseExchangeRate)).toFixed(8)} ZEC spread
                    </div>
                  </>
                )}

                <div className="flex items-center justify-end gap-1 mt-1">
                  <span className="text-[11px] text-gray-500">Facilitator</span>
                  <button
                    type="button"
                    onClick={() => void handleCopy(order.merchantName || order.merchantCode)}
                    className="inline-flex items-center rounded-full border border-gray-200 bg-white p-0.5 text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  >
                    <Copy className="h-3 w-3" aria-hidden="true" />
                  </button>
                </div>
                <div className="text-[11px] text-gray-800 truncate">
                  {order.merchantName || order.merchantCode}
                </div>
              </div>
            </div>

            {variant === 'pending' && (
              <div className="mt-2 flex items-center justify-end gap-2 border-t border-gray-100 pt-2">
                <button
                  type="button"
                  onClick={() => handleReject(order)}
                  className="inline-flex items-center gap-1 rounded-md border border-gray-200 px-2 py-1 text-[11px] font-medium text-gray-700 hover:bg-gray-50"
                >
                  <X className="h-3 w-3" aria-hidden="true" />
                  <span>Reject</span>
                </button>
                <button
                  type="button"
                  onClick={() => void handleAccept(order)}
                  disabled={acceptMutation.isPending}
                  className="inline-flex items-center gap-1 rounded-md bg-[#FF9417] px-2 py-1 text-[11px] font-medium text-white hover:bg-[#E68515] disabled:opacity-50"
                >
                  <Check className="h-3 w-3" aria-hidden="true" />
                  <span>Accept</span>
                </button>
              </div>
            )}

            {variant === 'active' && (
              <div className="mt-2 border-t border-gray-100 pt-2">
                {/* Show QR code for facilitator to scan and pay */}
                {order.scannedQRCodeData && (
                  <div className="mb-3 flex justify-center">
                    <QRCodeDisplay
                      data={order.scannedQRCodeData}
                      size={100}
                      label="Scan to pay facilitator"
                    />
                  </div>
                )}
                <div className="flex items-center justify-end gap-2">
                  <button
                    type="button"
                    onClick={() => void handleMarkFiat(order)}
                    disabled={fiatMutation.isPending}
                    className="inline-flex items-center gap-1 rounded-md bg-amber-600 px-2 py-1 text-[11px] font-medium text-white hover:bg-amber-700 disabled:opacity-50"
                  >
                    <Check className="h-3 w-3" aria-hidden="true" />
                    <span>Mark fiat sent</span>
                  </button>
                </div>
              </div>
            )}

            {variant === 'completed' && order.status === 'fiat_sent' && (
              <div className="mt-2 flex items-center justify-end gap-2 border-t border-gray-100 pt-2">
                <button
                  type="button"
                  onClick={() => void handleMarkZec(order)}
                  disabled={zecMutation.isPending}
                  className="inline-flex items-center gap-1 rounded-md bg-emerald-600 px-2 py-1 text-[11px] font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
                >
                  <Check className="h-3 w-3" aria-hidden="true" />
                  <span>Mark ZEC received</span>
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    );
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex items-center gap-2">
          <div className="text-sm font-medium text-gray-800">Live Zapp orders</div>
          <button
            type="button"
            onClick={() => setShowCompleted((prev) => !prev)}
            className="text-xs text-[#FF9417] hover:text-[#E68515]"
          >
            {showCompleted ? 'Hide completed history' : 'Show completed history'}
          </button>
        </div>
      </div>

      <div className={`grid grid-cols-1 gap-4 ${showCompleted ? 'lg:grid-cols-3' : 'lg:grid-cols-2'}`}>
        <div className="flex flex-col rounded-md border border-gray-200 bg-gray-50 p-3">
          <div className="mb-2 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-gray-800">
              Pending
              <span className="ml-1 text-xs font-normal text-gray-500">({visiblePendingOrders.length})</span>
            </h2>
          </div>
          <div className="flex-1 min-h-0">
            {pending.isLoading && groupedPendingOrders.length === 0 ? (
              <div className="text-sm text-gray-500">Loading orders...</div>
            ) : groupedPendingOrders.length === 0 ? (
              <div className="rounded-md border border-dashed border-gray-300 bg-gray-50 px-4 py-6 text-center text-sm text-gray-500">
                No pending orders.
              </div>
            ) : (
              <div className="space-y-3">
                {groupedPendingOrders.map((group) => (
                  group.isGroup ? (
                    // Grouped orders - must accept all together
                    <div
                      key={group.groupId}
                      className="rounded-md border-2 border-amber-300 bg-amber-50 p-3 shadow-sm"
                    >
                      <div className="flex items-center gap-2 mb-2">
                        <Users className="h-4 w-4 text-amber-600" />
                        <span className="text-xs font-semibold text-amber-700">
                          Grouped Order ({group.orders.length} recipients)
                        </span>
                        {group.groupExpiresAt && (
                          <span className="text-[10px] text-amber-600">
                            Accept all together
                          </span>
                        )}
                      </div>
                      
                      <div className="space-y-2 mb-3">
                        {group.orders.map((order) => (
                          <div key={order._id} className="rounded bg-white p-2 text-xs">
                            <div className="flex justify-between">
                              <span className="text-gray-600">{order.merchantName || order.merchantCode}</span>
                              <span className="font-medium">{order.fiatAmount} {order.fiatCurrency}</span>
                            </div>
                            <div className="text-[10px] text-gray-400">{order.paymentRail}</div>
                          </div>
                        ))}
                      </div>

                      <div className="flex items-center justify-between border-t border-amber-200 pt-2">
                        <div className="text-xs">
                          <span className="text-gray-500">Total ZEC: </span>
                          <span className="font-medium text-gray-900">{group.totalZec.toFixed(8)}</span>
                        </div>
                        <div className="flex gap-2">
                          <button
                            type="button"
                            onClick={() => group.groupId && handleRejectGroup(group.groupId)}
                            className="inline-flex items-center gap-1 rounded-md border border-gray-200 px-2 py-1 text-[11px] font-medium text-gray-700 hover:bg-gray-50"
                          >
                            <X className="h-3 w-3" />
                            <span>Reject All</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => void handleAcceptGroup(group)}
                            disabled={acceptMutation.isPending}
                            className="inline-flex items-center gap-1 rounded-md bg-[#FF9417] px-2 py-1 text-[11px] font-medium text-white hover:bg-[#E68515] disabled:opacity-50"
                          >
                            <Check className="h-3 w-3" />
                            <span>Accept All</span>
                          </button>
                        </div>
                      </div>
                    </div>
                  ) : (
                    // Individual orders - render normally
                    group.orders.map((order) => (
                      <div
                        key={order._id}
                        className="rounded-md border border-gray-200 bg-white p-3 shadow-sm flex flex-col gap-2"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="space-y-1 text-xs text-gray-700">
                            <div className="font-mono text-[11px] break-all text-gray-900">{order.orderId}</div>
                            <div className="text-[11px] text-gray-500">Created {new Date(order.createdAt).toLocaleString()}</div>
                          </div>
                          <div className="space-y-1 text-xs text-right">
                            <div className="flex items-center justify-end gap-1">
                              <span className="text-[11px] text-gray-500">Send fiat</span>
                              <button
                                type="button"
                                onClick={() => void handleCopy(`${order.fiatAmount} ${order.fiatCurrency}`)}
                                className="inline-flex items-center rounded-full border border-gray-200 bg-white p-0.5 text-gray-500 hover:text-gray-700 hover:border-gray-300"
                              >
                                <Copy className="h-3 w-3" />
                              </button>
                            </div>
                            <div className="text-xs font-medium text-gray-900">
                              {order.fiatAmount.toLocaleString()} {order.fiatCurrency}
                            </div>
                            <div className="flex items-center justify-end gap-1 mt-1">
                              <span className="text-[11px] text-gray-500">Facilitator</span>
                            </div>
                            <div className="text-[11px] text-gray-800 truncate">
                              {order.merchantName || order.merchantCode}
                            </div>
                          </div>
                        </div>
                        <div className="mt-2 flex items-center justify-end gap-2 border-t border-gray-100 pt-2">
                          <button
                            type="button"
                            onClick={() => handleReject(order)}
                            className="inline-flex items-center gap-1 rounded-md border border-gray-200 px-2 py-1 text-[11px] font-medium text-gray-700 hover:bg-gray-50"
                          >
                            <X className="h-3 w-3" />
                            <span>Reject</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => void handleAccept(order)}
                            disabled={acceptMutation.isPending}
                            className="inline-flex items-center gap-1 rounded-md bg-[#FF9417] px-2 py-1 text-[11px] font-medium text-white hover:bg-[#E68515] disabled:opacity-50"
                          >
                            <Check className="h-3 w-3" />
                            <span>Accept</span>
                          </button>
                        </div>
                      </div>
                    ))
                  )
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="flex flex-col rounded-md border border-gray-200 bg-gray-50 p-3">
          <div className="mb-2 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-gray-800">
              Active
              <span className="ml-1 text-xs font-normal text-gray-500">({activeOrders.length})</span>
            </h2>
          </div>
          <div className="flex-1 min-h-0">
            {renderOrderCards(active.isLoading, activeOrders, 'No active orders.', 'active')}
          </div>
        </div>

        {showCompleted && (
          <div className="flex flex-col rounded-md border border-gray-200 bg-gray-50 p-3">
            <div className="mb-2 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-gray-800">
                Completed history
                <span className="ml-1 text-xs font-normal text-gray-500">({completedOrders.length})</span>
              </h2>
            </div>
            <div className="flex-1 min-h-0">
              {renderOrderCards(completed.isLoading, completedOrders, 'No completed orders yet.', 'completed')}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
