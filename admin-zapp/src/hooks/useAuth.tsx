import { createContext, useContext, useEffect, useState } from 'react';
import { apiFetch } from '@/lib/apiClient';
import type { Facilitator } from '@/types/facilitator';

// Demo mode: Uses a special token that the backend accepts without JWT validation
const DEMO_TOKEN = 'demo-token-no-auth';

interface ProfileResponse {
  success: boolean;
  facilitator: Facilitator;
}

interface AuthContextValue {
  token: string | null;
  facilitator: Facilitator | null;
  loading: boolean;
  requestOtp: (email: string) => Promise<void>;
  verifyOtp: (email: string, otp: string) => Promise<void>;
  loginAsDemo: (email: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  // Demo mode: Always use demo token, fetch real facilitator from backend
  const [facilitator, setMerchant] = useState<Facilitator | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch facilitator profile using demo token
    void (async () => {
      try {
        const data = await apiFetch<ProfileResponse>('/api/zapp/facilitator/profile', {
          method: 'GET',
          token: DEMO_TOKEN,
        });
        setMerchant(data.facilitator);
      } catch (err) {
        console.error('[Demo Mode] Failed to fetch facilitator profile:', err);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const requestOtp = async (_email: string): Promise<void> => {
    // No-op for demo
  };

  const verifyOtp = async (_email: string, _otp: string): Promise<void> => {
    // No-op for demo
  };

  const logout = () => {
    // No-op for demo - user stays logged in
    console.log('[Demo Mode] Logout disabled');
  };

  const loginAsDemo = async (_email: string): Promise<void> => {
    // No-op for demo - already logged in
  };

  const value: AuthContextValue = {
    token: DEMO_TOKEN,
    facilitator,
    loading,
    requestOtp,
    verifyOtp,
    loginAsDemo,
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
