import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { ProfileForm } from '@/components/ProfileForm';
import { OrdersTable } from '@/components/OrdersTable';
import { AnalyticsDashboard } from '@/components/AnalyticsDashboard';
import { ArrowLeft, User } from 'lucide-react';

const DEMO_EMAIL = 'test@email.com';

export function Dashboard() {
  const { loading, token, facilitator, loginAsDemo, logout } = useAuth();
  const [activeTab, setActiveTab] = useState<'orders' | 'profile' | 'analytics'>('orders');
  const [demoLoading, setDemoLoading] = useState(false);

  // Auto-login as demo user on mount
  useEffect(() => {
    if (!loading && !token) {
      setDemoLoading(true);
      loginAsDemo(DEMO_EMAIL).finally(() => setDemoLoading(false));
    }
  }, [loading, token, loginAsDemo]);

  const isLoading = loading || demoLoading;

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <Link
                to="/"
                className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-[#FF9417] transition-colors"
              >
                <ArrowLeft className="h-4 w-4" />
                Back to Home
              </Link>
              <div className="h-6 w-px bg-gray-200" />
              <div>
                <h1 className="text-2xl font-bold text-gray-900">Zapp Facilitator Admin</h1>
                <p className="text-xs text-gray-500">
                  Manage facilitator profile, payment rails, and live Zapp P2P orders.
                </p>
              </div>
            </div>
            
            {/* Demo user indicator */}
            {facilitator && (
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-2 bg-orange-50 border border-orange-200 rounded-lg px-3 py-1.5">
                  <User className="h-4 w-4 text-[#FF9417]" />
                  <div className="text-sm">
                    <span className="text-gray-600">Demo: </span>
                    <span className="font-medium text-gray-900">{facilitator.email}</span>
                  </div>
                </div>
                <button
                  onClick={logout}
                  className="text-xs text-gray-500 hover:text-red-600 transition-colors"
                >
                  Logout
                </button>
              </div>
            )}
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8 space-y-6">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#FF9417] mb-4"></div>
            <div className="text-sm text-gray-500">Loading demo session...</div>
          </div>
        ) : !token || !facilitator ? (
          <div className="rounded-md border border-dashed border-gray-300 bg-white px-4 py-6 text-sm text-gray-600 text-center">
            <p className="mb-4">Unable to connect to demo account.</p>
            <button
              onClick={() => {
                setDemoLoading(true);
                loginAsDemo(DEMO_EMAIL).finally(() => setDemoLoading(false));
              }}
              className="inline-flex items-center gap-2 bg-[#FF9417] text-white px-4 py-2 rounded-md text-sm hover:bg-[#e8850f] transition-colors"
            >
              Retry Demo Login
            </button>
          </div>
        ) : (
          <>
            <div className="flex items-center justify-between">
              <div className="flex gap-2">
                <TabButton
                  active={activeTab === 'orders'}
                  onClick={() => setActiveTab('orders')}
                >
                  Orders
                </TabButton>
                <TabButton
                  active={activeTab === 'analytics'}
                  onClick={() => setActiveTab('analytics')}
                >
                  Analytics
                </TabButton>
                <TabButton
                  active={activeTab === 'profile'}
                  onClick={() => setActiveTab('profile')}
                >
                  Profile & Payment Rails
                </TabButton>
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

function TabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`px-4 py-2 text-sm rounded-md border ${
        active
          ? 'bg-[#FF9417] text-white border-[#FF9417]'
          : 'bg-white text-gray-700 border-gray-300 hover:border-[#FF9417] hover:text-[#FF9417]'
      }`}
    >
      {children}
    </button>
  );
}
