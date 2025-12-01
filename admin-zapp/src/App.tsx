import { useAuth } from '@/hooks/useAuth';
import { LoginPanel } from '@/components/LoginPanel';
import { ProfileForm } from '@/components/ProfileForm';
import { OrdersTable } from '@/components/OrdersTable';
import { AnalyticsDashboard } from '@/components/AnalyticsDashboard';
import { useState } from 'react';

const DEFAULT_EMAIL = import.meta.env.VITE_DEFAULT_ADMIN_EMAIL;

function App() {
  const { loading, token, facilitator } = useAuth();
  const [activeTab, setActiveTab] = useState<'orders' | 'profile' | 'analytics'>('orders');

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8 flex items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Zapp Facilitator Admin</h1>
            <p className="text-xs text-gray-500">
              Manage facilitator profile, payment rails, and live Zapp P2P orders.
            </p>
          </div>
          <LoginPanel defaultEmail={typeof DEFAULT_EMAIL === 'string' ? DEFAULT_EMAIL : undefined} />
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8 space-y-6">
        {loading ? (
          <div className="text-sm text-gray-500">Loading session...</div>
        ) : !token || !facilitator ? (
          <div className="rounded-md border border-dashed border-gray-300 bg-white px-4 py-6 text-sm text-gray-600">
            Enter your facilitator email and OTP above to access the dashboard.
          </div>
        ) : (
          <>
            <div className="flex items-center justify-between">
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setActiveTab('orders')}
                  className={`px-4 py-2 text-sm rounded-md border ${activeTab === 'orders'
                    ? 'bg-[#FF9417] text-white border-[#FF9417]'
                    : 'bg-white text-gray-700 border-gray-300 hover:border-[#FF9417] hover:text-[#FF9417]'
                    }`}
                >
                  Orders
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab('profile')}
                  className={`px-4 py-2 text-sm rounded-md border ${activeTab === 'profile'
                    ? 'bg-[#FF9417] text-white border-[#FF9417]'
                    : 'bg-white text-gray-700 border-gray-300 hover:border-[#FF9417] hover:text-[#FF9417]'
                    }`}
                >
                  Profile & payment rails
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab('analytics')}
                  className={`px-4 py-2 text-sm rounded-md border ${activeTab === 'analytics'
                    ? 'bg-[#FF9417] text-white border-[#FF9417]'
                    : 'bg-white text-gray-700 border-gray-300 hover:border-[#FF9417] hover:text-[#FF9417]'
                    }`}
                >
                  Analytics
                </button>
              </div>
              <div className="text-xs text-gray-500">
                Backend API: {import.meta.env.VITE_API_URL ?? 'http://localhost:4001'}
              </div>
            </div>

            <div className="rounded-lg border border-gray-200 bg-white p-4">
              {activeTab === 'orders' ? (
                <OrdersTable />
              ) : activeTab === 'profile' ? (
                <ProfileForm />
              ) : (
                <AnalyticsDashboard />
              )}
            </div>
          </>
        )}
      </main>
    </div>
  );
}

export default App;
