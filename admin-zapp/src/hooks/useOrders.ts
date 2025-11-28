import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/apiClient';
import { useAuth } from '@/hooks/useAuth';
import type { ZapOrder } from '@/types/order';

interface OrdersResponse {
  success: boolean;
  orders: ZapOrder[];
}

interface AcceptOrderResponse {
  success: boolean;
  order: ZapOrder;
}

interface UpdateOrderResponse {
  success: boolean;
  order: ZapOrder;
}

export function usePendingOrders() {
  const { token } = useAuth();

  return useQuery({
    queryKey: ['orders', 'pending'],
    queryFn: async () => {
      if (!token) return [] as ZapOrder[];
      const data = await apiFetch<OrdersResponse>('/api/zapp/merchant/orders/pending', {
        method: 'GET',
        token,
      });
      return data.orders;
    },
    enabled: Boolean(token),
    refetchInterval: 5000,
  });
}

export function useActiveOrders() {
  const { token } = useAuth();

  return useQuery({
    queryKey: ['orders', 'active'],
    queryFn: async () => {
      if (!token) return [] as ZapOrder[];
      const data = await apiFetch<OrdersResponse>('/api/zapp/merchant/orders/active', {
        method: 'GET',
        token,
      });
      return data.orders;
    },
    enabled: Boolean(token),
    refetchInterval: 5000,
  });
}

export function useCompletedOrders() {
  const { token } = useAuth();

  return useQuery({
    queryKey: ['orders', 'completed'],
    queryFn: async () => {
      if (!token) return [] as ZapOrder[];
      const data = await apiFetch<OrdersResponse>('/api/zapp/merchant/orders/completed', {
        method: 'GET',
        token,
      });
      return data.orders;
    },
    enabled: Boolean(token),
    refetchInterval: 10000,
  });
}

export function useAcceptOrder() {
  const { token } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ orderId, zecAddress }: { orderId: string; zecAddress?: string }) => {
      if (!token) throw new Error('Not authenticated');
      const data = await apiFetch<AcceptOrderResponse>(`/api/zapp/merchant/orders/${orderId}/accept`, {
        method: 'POST',
        token,
        body: zecAddress ? { zec_address: zecAddress } : {},
      });
      return data.order;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['orders'] });
    },
  });
}

export function useMarkFiatSent() {
  const { token } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      paymentReference,
      notes,
    }: {
      orderId: string;
      paymentReference?: string;
      notes?: string;
    }) => {
      if (!token) throw new Error('Not authenticated');
      const body: Record<string, string> = {};
      if (paymentReference) body.payment_reference = paymentReference;
      if (notes) body.notes = notes;

      const data = await apiFetch<UpdateOrderResponse>(`/api/zapp/merchant/orders/${orderId}/mark-fiat-sent`, {
        method: 'POST',
        token,
        body,
      });
      return data.order;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['orders'] });
    },
  });
}

export function useMarkZecReceived() {
  const { token } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      zecTxHash,
      notes,
    }: {
      orderId: string;
      zecTxHash?: string;
      notes?: string;
    }) => {
      if (!token) throw new Error('Not authenticated');
      const body: Record<string, string> = {};
      if (zecTxHash) body.zec_tx_hash = zecTxHash;
      if (notes) body.notes = notes;

      const data = await apiFetch<UpdateOrderResponse>(`/api/zapp/merchant/orders/${orderId}/mark-zec-received`, {
        method: 'POST',
        token,
        body,
      });
      return data.order;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['orders'] });
    },
  });
}

