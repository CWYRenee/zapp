import { useState, useEffect } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from '@/hooks/useAuth';
import { apiFetch } from '@/lib/apiClient';
import type { Merchant, PaymentRailConfig, PaymentRailType } from '@/types/merchant';

interface ProfileResponse {
  success: boolean;
  merchant: Merchant;
}

interface UpdateProfileResponse {
  success: boolean;
  merchant: Merchant;
}

const PAYMENT_RAIL_TYPES: { value: PaymentRailType; label: string; placeholder?: string }[] = [
  { value: 'upi', label: 'UPI', placeholder: 'your-id@upi' },
  { value: 'alipay', label: 'Alipay', placeholder: 'your@email.com' },
  { value: 'wechat_pay', label: 'WeChat Pay', placeholder: 'WeChat ID' },
  { value: 'pix', label: 'PIX', placeholder: 'PIX ID' },
  { value: 'promptpay', label: 'PromptPay', placeholder: 'Phone or ID' },
];

export function ProfileForm() {
  const { token } = useAuth();
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['merchant', 'profile'],
    queryFn: async () => {
      if (!token) throw new Error('Not authenticated');
      const res = await apiFetch<ProfileResponse>('/api/zapp/merchant/profile', {
        method: 'GET',
        token,
      });
      return res.merchant;
    },
    enabled: Boolean(token),
  });

  const mutation = useMutation({
    mutationFn: async (payload: {
      display_name?: string;
      zec_address?: string;
      payment_rails?: PaymentRailConfig[];
    }) => {
      if (!token) throw new Error('Not authenticated');
      const res = await apiFetch<UpdateProfileResponse>('/api/zapp/merchant/profile', {
        method: 'PUT',
        token,
        body: payload,
      });
      return res.merchant;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['merchant', 'profile'] });
    },
  });

  const [localRails, setLocalRails] = useState<PaymentRailConfig[]>([]);
  const [displayName, setDisplayName] = useState('');
  const [zecAddress, setZecAddress] = useState('');
  const [showDropdown, setShowDropdown] = useState(false);

  const merchant = data;

  useEffect(() => {
    if (!merchant) return;
    setDisplayName(merchant.displayName ?? '');
    setZecAddress(merchant.zecAddress ?? '');
    if (merchant.paymentRails && merchant.paymentRails.length > 0) {
      setLocalRails(merchant.paymentRails);
    }
  }, [merchant]);

  const rails = localRails.length > 0 ? localRails : merchant?.paymentRails ?? [];

  const handleAddRail = (type: PaymentRailType) => {
    const next: PaymentRailConfig = {
      type,
      enabled: true,
    };
    setLocalRails([...rails, next]);
    setShowDropdown(false); // Close dropdown after selection
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    if (!showDropdown) return;

    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('[data-dropdown-container]')) {
        setShowDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [showDropdown]);

  const handleRailChange = (index: number, patch: Partial<PaymentRailConfig>) => {
    const next = rails.map((rail, i) => (i === index ? { ...rail, ...patch } : rail));
    setLocalRails(next);
  };

  const handleRemoveRail = (index: number) => {
    const next = rails.filter((_, i) => i !== index);
    setLocalRails(next);
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();

    const payload: {
      display_name?: string;
      zec_address?: string;
      payment_rails?: PaymentRailConfig[];
    } = {};

    if (displayName.trim()) payload.display_name = displayName.trim();
    if (zecAddress.trim()) payload.zec_address = zecAddress.trim();
    if (rails.length > 0) payload.payment_rails = rails;

    try {
      await mutation.mutateAsync(payload);
    } catch (err) {
      console.error('Failed to update profile', err);
    }
  };

  if (isLoading) {
    return <div className="text-gray-500 text-sm">Loading profile...</div>;
  }

  if (error) {
    return <div className="text-red-600 text-sm">Failed to load profile</div>;
  }

  const configuredRailTypes = new Set(rails.map((r) => r.type));
  const availableRailTypes = PAYMENT_RAIL_TYPES.filter((rt) => !configuredRailTypes.has(rt.value));

  return (
    <form onSubmit={handleSubmit} className="space-y-8 max-w-4xl">
      {/* Merchant Profile Section */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Merchant Profile</h2>
          <p className="text-sm text-gray-500 mt-1">Your basic merchant information</p>
        </div>
        <div className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              Display Name
            </label>
            <input
              type="text"
              className="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              placeholder="Your merchant name"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              ZEC Address
            </label>
            <input
              type="text"
              className="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 font-mono"
              value={zecAddress}
              onChange={(e) => setZecAddress(e.target.value)}
              placeholder="u1..."
            />
            <p className="text-xs text-gray-500 mt-1.5">
              Your Zcash unified address for receiving payments
            </p>
          </div>
        </div>
      </div>

      {/* Payment Methods Section */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Payment Methods</h2>
              <p className="text-sm text-gray-500 mt-1">
                Configure the payment rails you support
              </p>
            </div>
            {availableRailTypes.length > 0 && (
              <div className="relative" data-dropdown-container>
                <button
                  type="button"
                  onClick={() => setShowDropdown(!showDropdown)}
                  className="inline-flex items-center rounded-md bg-[#FF9417] px-3 py-1.5 text-sm font-medium text-white shadow-sm hover:bg-[#E68515] transition-colors"
                >
                  Add Payment Method
                  <svg
                    className={`ml-1.5 h-4 w-4 transition-transform ${showDropdown ? 'rotate-180' : ''}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                {showDropdown && (
                  <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg border border-gray-200 z-10 py-1">
                    {availableRailTypes.map((railType) => (
                      <button
                        key={railType.value}
                        type="button"
                        onClick={() => handleAddRail(railType.value)}
                        className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                      >
                        {railType.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        <div className="p-6">
          {rails.length === 0 ? (
            <div className="text-center py-12 text-gray-500">
              <svg
                className="mx-auto h-12 w-12 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 48 48"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M34 40h10v-4a6 6 0 00-10.712-3.714M34 40H14m20 0v-4a9.971 9.971 0 00-.712-3.714M14 40H4v-4a6 6 0 0110.713-3.714M14 40v-4c0-1.313.253-2.566.713-3.714m0 0A10.003 10.003 0 0124 26c4.21 0 7.813 2.602 9.288 6.286M30 14a6 6 0 11-12 0 6 6 0 0112 0z"
                />
              </svg>
              <p className="mt-4 text-sm">No payment methods configured yet</p>
              <p className="text-xs text-gray-400 mt-1">
                Add a payment method to start accepting orders
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-4">
              {rails.map((rail, index) => {
                const railInfo = PAYMENT_RAIL_TYPES.find((rt) => rt.value === rail.type);
                return (
                  <div
                    key={index}
                    className="rounded-lg border border-gray-200 bg-gray-50 p-4 space-y-3"
                  >
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        <div className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            checked={rail.enabled}
                            onChange={(e) => handleRailChange(index, { enabled: e.target.checked })}
                            className="h-4 w-4 rounded border-gray-300 text-[#FF9417] focus:ring-[#FF9417]"
                          />
                          <h3 className="text-sm font-semibold text-gray-900">
                            {railInfo?.label || rail.type}
                          </h3>
                        </div>
                        {!rail.enabled && (
                          <span className="inline-flex items-center rounded-full bg-gray-200 px-2 py-0.5 text-xs font-medium text-gray-600">
                            Disabled
                          </span>
                        )}
                        {rail.enabled && (
                          <span className="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700">
                            Active
                          </span>
                        )}
                      </div>
                      <button
                        type="button"
                        onClick={() => handleRemoveRail(index)}
                        className="text-sm text-red-600 hover:text-red-700 font-medium"
                      >
                        Remove
                      </button>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                      <input
                        type="text"
                        placeholder="Label (optional)"
                        className="rounded-md border border-gray-300 px-3 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
                        value={rail.label ?? ''}
                        onChange={(e) => handleRailChange(index, { label: e.target.value })}
                      />

                      {rail.type === 'upi' && (
                        <input
                          type="text"
                          placeholder={railInfo?.placeholder || 'UPI ID'}
                          className="rounded-md border border-gray-300 px-3 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
                          value={rail.upiId ?? ''}
                          onChange={(e) => handleRailChange(index, { upiId: e.target.value })}
                        />
                      )}
                      {rail.type === 'alipay' && (
                        <input
                          type="text"
                          placeholder={railInfo?.placeholder || 'Alipay ID'}
                          className="rounded-md border border-gray-300 px-3 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
                          value={rail.alipayId ?? ''}
                          onChange={(e) => handleRailChange(index, { alipayId: e.target.value })}
                        />
                      )}
                      {rail.type === 'wechat_pay' && (
                        <input
                          type="text"
                          placeholder={railInfo?.placeholder || 'WeChat ID'}
                          className="rounded-md border border-gray-300 px-3 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
                          value={rail.wechatId ?? ''}
                          onChange={(e) => handleRailChange(index, { wechatId: e.target.value })}
                        />
                      )}
                      {rail.type === 'pix' && (
                        <input
                          type="text"
                          placeholder={railInfo?.placeholder || 'PIX ID'}
                          className="rounded-md border border-gray-300 px-3 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
                          value={rail.paxId ?? ''}
                          onChange={(e) => handleRailChange(index, { paxId: e.target.value })}
                        />
                      )}
                      {rail.type === 'promptpay' && (
                        <input
                          type="text"
                          placeholder={railInfo?.placeholder || 'PromptPay ID'}
                          className="rounded-md border border-gray-300 px-3 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
                          value={rail.promptpayId ?? ''}
                          onChange={(e) => handleRailChange(index, { promptpayId: e.target.value })}
                        />
                      )}
                    </div>

                    <textarea
                      placeholder="Notes (optional)"
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:border-[#FF9417]"
                      rows={2}
                      value={rail.notes ?? ''}
                      onChange={(e) => handleRailChange(index, { notes: e.target.value })}
                    />
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Save Button */}
      <div className="flex items-center justify-end gap-3">
        {mutation.isSuccess && (
          <span className="text-sm text-green-600 font-medium">Profile saved successfully!</span>
        )}
        <button
          type="submit"
          disabled={mutation.isPending}
          className="inline-flex items-center rounded-md bg-[#FF9417] px-6 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-[#E68515] focus:outline-none focus:ring-2 focus:ring-[#FF9417] focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {mutation.isPending ? 'Saving...' : 'Save Changes'}
        </button>
      </div>
    </form>
  );
}
