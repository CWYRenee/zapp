import { createContext, useContext, useEffect, useState } from 'react';
import { apiFetch } from '@/lib/apiClient';
import type { Merchant } from '@/types/merchant';

interface AuthContextValue {
  token: string | null;
  merchant: Merchant | null;
  loading: boolean;
  requestOtp: (email: string) => Promise<void>;
  verifyOtp: (email: string, otp: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const STORAGE_KEY = 'zap_admin_token';

interface VerifyOtpResponse {
  success: boolean;
  token: string;
  merchant: Merchant;
}

interface ProfileResponse {
  success: boolean;
  merchant: Merchant;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(null);
  const [merchant, setMerchant] = useState<Merchant | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const savedToken = window.localStorage.getItem(STORAGE_KEY);
    if (!savedToken) {
      setLoading(false);
      return;
    }

    setToken(savedToken);

    void (async () => {
      try {
        const data = await apiFetch<ProfileResponse>('/api/zapp/merchant/profile', {
          method: 'GET',
          token: savedToken,
        });
        setMerchant(data.merchant);
      } catch {
        window.localStorage.removeItem(STORAGE_KEY);
        setToken(null);
        setMerchant(null);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const requestOtp = async (email: string): Promise<void> => {
    await apiFetch('/api/zapp/merchant/auth/request-otp', {
      method: 'POST',
      body: { email },
    });
  };

  const verifyOtp = async (email: string, otp: string): Promise<void> => {
    const data = await apiFetch<VerifyOtpResponse>('/api/zapp/merchant/auth/verify-otp', {
      method: 'POST',
      body: { email, otp },
    });

    setToken(data.token);
    setMerchant(data.merchant);
    window.localStorage.setItem(STORAGE_KEY, data.token);
  };

  const logout = () => {
    setToken(null);
    setMerchant(null);
    window.localStorage.removeItem(STORAGE_KEY);
  };

  const value: AuthContextValue = {
    token,
    merchant,
    loading,
    requestOtp,
    verifyOtp,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return ctx;
}
