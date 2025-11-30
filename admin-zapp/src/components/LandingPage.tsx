import { Link } from 'react-router-dom';
import { Smartphone, ShieldCheck, Zap, ArrowRight, Wallet, Store, BarChart3 } from 'lucide-react';

// Placeholder - replace with your actual TestFlight link once uploaded
const TESTFLIGHT_URL = 'https://testflight.apple.com/join/YOUR_CODE';

export function LandingPage() {
  const qrCodeUrl = `https://chart.googleapis.com/chart?cht=qr&chs=200x200&chl=${encodeURIComponent(TESTFLIGHT_URL)}&choe=UTF-8`;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      {/* Hero Section */}
      <header className="relative overflow-hidden">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-orange-500/20 via-transparent to-transparent" />
        
        <nav className="relative max-w-7xl mx-auto px-4 py-6 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#FF9417] to-orange-600 flex items-center justify-center">
              <Zap className="h-6 w-6 text-white" />
            </div>
            <span className="text-2xl font-bold text-white">Zapp</span>
          </div>
          <Link
            to="/dashboard"
            className="text-sm text-gray-300 hover:text-white transition-colors"
          >
            Admin Dashboard →
          </Link>
        </nav>

        <div className="relative max-w-7xl mx-auto px-4 py-20 text-center">
          <div className="inline-flex items-center gap-2 bg-orange-500/10 border border-orange-500/20 rounded-full px-4 py-1.5 mb-6">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-orange-500"></span>
            </span>
            <span className="text-sm text-orange-300">Testnet Demo Available</span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-bold text-white mb-6 leading-tight">
            Private Payments.<br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#FF9417] to-orange-400">
              Powered by Zcash.
            </span>
          </h1>
          
          <p className="text-xl text-gray-400 max-w-2xl mx-auto mb-10">
            Zapp enables merchants to accept private Zcash payments with instant fiat settlement 
            through DeFi liquidity pools. No middlemen, no surveillance.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link
              to="/dashboard"
              className="inline-flex items-center gap-2 bg-gradient-to-r from-[#FF9417] to-orange-600 text-white px-8 py-3 rounded-lg font-medium hover:opacity-90 transition-opacity shadow-lg shadow-orange-500/25"
            >
              Try Admin Dashboard
              <ArrowRight className="h-4 w-4" />
            </Link>
            <a
              href="#download"
              className="inline-flex items-center gap-2 bg-white/10 text-white px-8 py-3 rounded-lg font-medium hover:bg-white/20 transition-colors border border-white/10"
            >
              <Smartphone className="h-4 w-4" />
              Download iOS App
            </a>
          </div>
        </div>
      </header>

      {/* Features */}
      <section className="max-w-7xl mx-auto px-4 py-20">
        <div className="text-center mb-16">
          <h2 className="text-3xl font-bold text-white mb-4">How Zapp Works</h2>
          <p className="text-gray-400 max-w-xl mx-auto">
            A complete ecosystem for private commerce—from mobile wallet to merchant dashboard.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          <FeatureCard
            icon={<Wallet className="h-6 w-6" />}
            title="Mobile Wallet"
            description="iOS app with shielded Zcash support. Send private payments by scanning merchant QR codes. Earn yield on idle funds through DeFi integration."
          />
          <FeatureCard
            icon={<Store className="h-6 w-6" />}
            title="Merchant Dashboard"
            description="Accept Zcash payments and receive instant fiat settlement. Manage orders, set payment rails, and track analytics in real-time."
          />
          <FeatureCard
            icon={<ShieldCheck className="h-6 w-6" />}
            title="Privacy First"
            description="Zcash shielded transactions ensure complete payment privacy. No transaction surveillance, no data harvesting."
          />
        </div>
      </section>

      {/* Architecture */}
      <section className="bg-gray-800/50 border-y border-gray-700">
        <div className="max-w-7xl mx-auto px-4 py-20">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-white mb-4">Architecture Overview</h2>
          </div>
          
          <div className="grid md:grid-cols-3 gap-6 text-center">
            <div className="bg-gray-900/50 rounded-xl p-6 border border-gray-700">
              <div className="text-4xl mb-3">📱</div>
              <h3 className="text-lg font-semibold text-white mb-2">iOS App (Swift)</h3>
              <p className="text-sm text-gray-400">
                Native wallet using Zcash SDK. Shielded transactions, QR payments, DeFi yield earning via NEAR/Ref Finance bridge.
              </p>
            </div>
            <div className="bg-gray-900/50 rounded-xl p-6 border border-gray-700">
              <div className="text-4xl mb-3">⚡</div>
              <h3 className="text-lg font-semibold text-white mb-2">Backend (Express)</h3>
              <p className="text-sm text-gray-400">
                RESTful API handling merchant auth, order management, blockchain monitoring, and bridge coordination.
              </p>
            </div>
            <div className="bg-gray-900/50 rounded-xl p-6 border border-gray-700">
              <div className="text-4xl mb-3">🖥️</div>
              <h3 className="text-lg font-semibold text-white mb-2">Admin Dashboard (React)</h3>
              <p className="text-sm text-gray-400">
                Merchant portal for managing profiles, tracking orders, configuring payment rails, and viewing analytics.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="max-w-7xl mx-auto px-4 py-20">
        <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl border border-gray-700 p-8 md:p-12">
          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-3xl font-bold text-white mb-4">
                Try the iOS App
              </h2>
              <p className="text-gray-400 mb-6">
                Scan the QR code with your iPhone camera to download Zapp via TestFlight. 
                Experience private payments firsthand on the Zcash testnet.
              </p>
              <ul className="space-y-3 text-sm text-gray-300">
                <li className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-green-500/20 flex items-center justify-center">
                    <span className="text-green-400 text-xs">✓</span>
                  </div>
                  Shielded Zcash wallet
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-green-500/20 flex items-center justify-center">
                    <span className="text-green-400 text-xs">✓</span>
                  </div>
                  QR code payments to merchants
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-green-500/20 flex items-center justify-center">
                    <span className="text-green-400 text-xs">✓</span>
                  </div>
                  DeFi yield earning
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-green-500/20 flex items-center justify-center">
                    <span className="text-green-400 text-xs">✓</span>
                  </div>
                  Testnet mode (no real funds needed)
                </li>
              </ul>
            </div>
            
            <div className="flex flex-col items-center">
              <div className="bg-white rounded-2xl p-4 shadow-2xl">
                <img
                  src={qrCodeUrl}
                  alt="Download Zapp on TestFlight"
                  width={200}
                  height={200}
                  className="rounded-lg"
                />
              </div>
              <p className="text-sm text-gray-500 mt-4 text-center">
                Scan with iPhone camera
              </p>
              <a
                href={TESTFLIGHT_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="mt-4 text-sm text-[#FF9417] hover:underline"
              >
                Or open TestFlight link directly →
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="max-w-7xl mx-auto px-4 py-20 text-center">
        <h2 className="text-3xl font-bold text-white mb-4">
          Ready to explore the merchant side?
        </h2>
        <p className="text-gray-400 mb-8 max-w-xl mx-auto">
          The admin dashboard is pre-configured with a demo merchant account. 
          See how merchants manage orders and receive payments.
        </p>
        <Link
          to="/dashboard"
          className="inline-flex items-center gap-2 bg-gradient-to-r from-[#FF9417] to-orange-600 text-white px-8 py-3 rounded-lg font-medium hover:opacity-90 transition-opacity shadow-lg shadow-orange-500/25"
        >
          <BarChart3 className="h-4 w-4" />
          Open Admin Dashboard
        </Link>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8">
        <div className="max-w-7xl mx-auto px-4 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2 text-gray-500">
            <Zap className="h-5 w-5" />
            <span className="text-sm">Zapp — Private payments for everyone</span>
          </div>
          <div className="text-sm text-gray-600">
            Built with Zcash • NEAR • Ref Finance
          </div>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 hover:border-[#FF9417]/50 transition-colors">
      <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-[#FF9417]/20 to-orange-600/20 flex items-center justify-center text-[#FF9417] mb-4">
        {icon}
      </div>
      <h3 className="text-lg font-semibold text-white mb-2">{title}</h3>
      <p className="text-sm text-gray-400">{description}</p>
    </div>
  );
}
