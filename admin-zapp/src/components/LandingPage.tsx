import { Link } from 'react-router-dom';
import { ArrowRight, Shield, Repeat, Wallet, TrendingUp, Globe, Lock, Smartphone, BarChart3 } from 'lucide-react';

// Placeholder - replace with your actual TestFlight link once uploaded
const TESTFLIGHT_URL = 'https://testflight.apple.com/join/YOUR_CODE';

export function LandingPage() {
  const qrCodeUrl = `https://chart.googleapis.com/chart?cht=qr&chs=180x180&chl=${encodeURIComponent(TESTFLIGHT_URL)}&choe=UTF-8`;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      {/* Hero Section */}
      <header className="relative overflow-hidden">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-orange-500/20 via-transparent to-transparent" />
        
        <nav className="relative max-w-7xl mx-auto px-4 py-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img 
              src="/zapp_logo.svg" 
              alt="Zapp" 
              className="w-10 h-10 rounded-xl"
            />
            <span className="text-2xl font-bold text-white">Zapp</span>
          </div>
          <Link
            to="/dashboard"
            className="inline-flex items-center gap-2 text-sm text-gray-300 hover:text-white transition-colors bg-white/5 px-4 py-2 rounded-lg border border-white/10 hover:border-white/20"
          >
            Facilitator Dashboard
            <ArrowRight className="h-4 w-4" />
          </Link>
        </nav>

        <div className="relative max-w-7xl mx-auto px-4 py-16 md:py-24 text-center">
          <div className="inline-flex items-center gap-2 bg-orange-500/10 border border-orange-500/20 rounded-full px-4 py-1.5 mb-6">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-orange-500"></span>
            </span>
            <span className="text-sm text-orange-300">Live Demo Available</span>
          </div>
          
          <h1 className="text-4xl md:text-6xl font-bold text-white mb-6 leading-tight">
            Pay Anyone with ZEC.<br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#FF9417] to-orange-400">
              They Receive Local Fiat.
            </span>
          </h1>
          
          <p className="text-lg md:text-xl text-gray-400 max-w-3xl mx-auto mb-10">
            Zapp connects Zcash's shielded privacy with local payment rails like UPI, Alipay, and PIX.
            Send ZEC, your recipient gets fiat—privately and instantly through cross-chain P2P matching.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link
              to="/dashboard"
              className="inline-flex items-center gap-2 bg-gradient-to-r from-[#FF9417] to-orange-600 text-white px-8 py-3.5 rounded-xl font-semibold hover:opacity-90 transition-opacity shadow-lg shadow-orange-500/25"
            >
              Try Live Demo
              <ArrowRight className="h-5 w-5" />
            </Link>
            <a
              href="#how-it-works"
              className="inline-flex items-center gap-2 bg-white/10 text-white px-8 py-3.5 rounded-xl font-medium hover:bg-white/15 transition-colors border border-white/10"
            >
              See How It Works
            </a>
          </div>
        </div>
      </header>

      {/* How It Works - The Actual Flow */}
      <section id="how-it-works" className="max-w-7xl mx-auto px-4 py-20">
        <div className="text-center mb-16">
          <h2 className="text-3xl font-bold text-white mb-4">How Zapp Works</h2>
          <p className="text-gray-400 max-w-2xl mx-auto">
            A peer-to-peer bridge between Zcash privacy and local payment systems. 
            No centralized exchange, no KYC, complete transaction privacy.
          </p>
        </div>

        <div className="grid md:grid-cols-4 gap-6">
          <FlowStep 
            step="1" 
            title="Scan & Pay"
            description="User scans recipient's payment QR (UPI ID, Alipay, etc.) and enters fiat amount in the Zapp iOS wallet."
          />
          <FlowStep 
            step="2" 
            title="Order Matched"
            description="System matches with a facilitator who can fulfill the local payment. Order is created with ZEC amount."
          />
          <FlowStep 
            step="3" 
            title="Fiat Sent"
            description="Facilitator sends fiat to the recipient via local payment rail and marks the order as 'fiat sent'."
          />
          <FlowStep 
            step="4" 
            title="ZEC Settled"
            description="User's wallet automatically sends shielded ZEC to the facilitator. Transaction complete—privately."
          />
        </div>
      </section>

      {/* Key Features / Grant Topics */}
      <section className="bg-gray-800/30 border-y border-gray-700/50 py-20">
        <div className="max-w-7xl mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold text-white mb-4">Privacy-First Innovation</h2>
            <p className="text-gray-400 max-w-2xl mx-auto">
              Zapp combines cutting-edge privacy technology with real-world payment utility.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <FeatureCard
              icon={<Globe className="h-6 w-6" />}
              title="Cross-Chain Privacy"
              description="NEAR Intents enable seamless ZEC↔NEAR bridging while preserving Zcash's shielded transaction privacy across chains."
              tag="Cross-Chain Solutions"
            />
            <FeatureCard
              icon={<TrendingUp className="h-6 w-6" />}
              title="Private DeFi Yield"
              description="Earn yield on idle ZEC through RHEA Finance pools. Your positions and earnings remain private—no front-running possible."
              tag="Private DeFi"
            />
            <FeatureCard
              icon={<Wallet className="h-6 w-6" />}
              title="Self-Custody Wallet"
              description="Mobile-first iOS wallet with biometric auth, shielded transactions, and intuitive UX. Your keys, your coins."
              tag="Wallet Innovation"
            />
            <FeatureCard
              icon={<Repeat className="h-6 w-6" />}
              title="Private P2P Payments"
              description="Send ZEC, recipient gets fiat via UPI, Alipay, PIX, or PromptPay. No surveillance, no middlemen."
              tag="Private Payments"
            />
            <FeatureCard
              icon={<Shield className="h-6 w-6" />}
              title="Zero-Knowledge Infrastructure"
              description="Built on Zcash's proven zk-SNARKs. Complete transaction privacy with cryptographic guarantees."
              tag="Privacy Infrastructure"
            />
            <FeatureCard
              icon={<Lock className="h-6 w-6" />}
              title="Anonymous Remittance"
              description="Cross-border payments that hide sender, receiver, and amount. Send value globally without a trace."
              tag="Private Transactions"
            />
          </div>
        </div>
      </section>

      {/* Architecture */}
      <section className="max-w-7xl mx-auto px-4 py-20">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-bold text-white mb-4">Three Components</h2>
          <p className="text-gray-400">Open-source, modular architecture</p>
        </div>
        
        <div className="grid md:grid-cols-3 gap-6">
          <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 text-center">
            <div className="w-14 h-14 mx-auto mb-4 rounded-xl bg-blue-500/10 flex items-center justify-center">
              <Smartphone className="h-7 w-7 text-blue-400" />
            </div>
            <h3 className="text-lg font-semibold text-white mb-2">iOS Wallet</h3>
            <p className="text-sm text-gray-400 mb-3">
              SwiftUI native app with Zcash SDK integration. QR scanning, shielded sends, DeFi yield via NEAR bridge.
            </p>
            <span className="text-xs text-gray-500 bg-gray-700/50 px-2 py-1 rounded">Swift • Zcash SDK</span>
          </div>
          <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 text-center">
            <div className="w-14 h-14 mx-auto mb-4 rounded-xl bg-green-500/10 flex items-center justify-center">
              <svg className="h-7 w-7 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold text-white mb-2">Backend API</h3>
            <p className="text-sm text-gray-400 mb-3">
              Order matching, facilitator auth, NEAR Intents orchestration, and cross-chain bridge coordination.
            </p>
            <span className="text-xs text-gray-500 bg-gray-700/50 px-2 py-1 rounded">Node.js • MongoDB</span>
          </div>
          <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 text-center">
            <div className="w-14 h-14 mx-auto mb-4 rounded-xl bg-orange-500/10 flex items-center justify-center">
              <BarChart3 className="h-7 w-7 text-orange-400" />
            </div>
            <h3 className="text-lg font-semibold text-white mb-2">Facilitator Dashboard</h3>
            <p className="text-sm text-gray-400 mb-3">
              Accept orders, manage payment rails, track earnings, view analytics. Real-time order management.
            </p>
            <span className="text-xs text-gray-500 bg-gray-700/50 px-2 py-1 rounded">React • Vite</span>
          </div>
        </div>
      </section>

      {/* Download & CTA */}
      <section id="download" className="max-w-7xl mx-auto px-4 py-16">
        <div className="bg-gradient-to-br from-[#FF9417]/10 to-orange-600/5 rounded-2xl border border-[#FF9417]/20 p-8 md:p-12">
          <div className="grid md:grid-cols-2 gap-10 items-center">
            <div>
              <h2 className="text-3xl font-bold text-white mb-4">
                Try Zapp Today
              </h2>
              <p className="text-gray-400 mb-6">
                Test the complete flow on Zcash testnet. No real funds required.
              </p>
              
              <div className="space-y-4 mb-8">
                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 rounded-full bg-[#FF9417]/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <span className="text-[#FF9417] text-xs font-bold">1</span>
                  </div>
                  <div>
                    <p className="text-white font-medium">Download iOS App</p>
                    <p className="text-sm text-gray-400">Scan QR or visit TestFlight link</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 rounded-full bg-[#FF9417]/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <span className="text-[#FF9417] text-xs font-bold">2</span>
                  </div>
                  <div>
                    <p className="text-white font-medium">Create a Wallet</p>
                    <p className="text-sm text-gray-400">Get testnet ZEC from faucet</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 rounded-full bg-[#FF9417]/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <span className="text-[#FF9417] text-xs font-bold">3</span>
                  </div>
                  <div>
                    <p className="text-white font-medium">Make a Payment</p>
                    <p className="text-sm text-gray-400">Scan any UPI/Alipay QR and pay with ZEC</p>
                  </div>
                </div>
              </div>

              <Link
                to="/dashboard"
                className="inline-flex items-center gap-2 bg-[#FF9417] text-white px-6 py-3 rounded-xl font-semibold hover:bg-[#E68515] transition-colors"
              >
                <BarChart3 className="h-5 w-5" />
                Try Facilitator Dashboard
              </Link>
            </div>
            
            <div className="flex flex-col items-center">
              <div className="bg-white rounded-2xl p-4 shadow-2xl">
                <img
                  src={qrCodeUrl}
                  alt="Download Zapp on TestFlight"
                  width={180}
                  height={180}
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
                className="mt-3 text-sm text-[#FF9417] hover:underline"
              >
                Open TestFlight link →
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8">
        <div className="max-w-7xl mx-auto px-4 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-3 text-gray-500">
            <img src="/zapp_logo.svg" alt="Zapp" className="w-6 h-6 rounded" />
            <span className="text-sm">Zapp — Private P2P payments powered by Zcash</span>
          </div>
          <div className="flex items-center gap-4 text-sm text-gray-600">
            <span>Built with</span>
            <span className="text-gray-400">Zcash</span>
            <span>•</span>
            <span className="text-gray-400">NEAR Intents</span>
            <span>•</span>
            <span className="text-gray-400">RHEA Finance</span>
          </div>
        </div>
      </footer>
    </div>
  );
}

function FlowStep({ step, title, description }: { step: string; title: string; description: string }) {
  return (
    <div className="relative">
      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 h-full">
        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#FF9417] to-orange-600 flex items-center justify-center text-white font-bold mb-4">
          {step}
        </div>
        <h3 className="text-lg font-semibold text-white mb-2">{title}</h3>
        <p className="text-sm text-gray-400">{description}</p>
      </div>
    </div>
  );
}

function FeatureCard({ icon, title, description, tag }: { icon: React.ReactNode; title: string; description: string; tag: string }) {
  return (
    <div className="bg-gray-900/50 rounded-xl p-6 border border-gray-700 hover:border-[#FF9417]/30 transition-colors">
      <div className="flex items-start justify-between mb-4">
        <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-[#FF9417]/20 to-orange-600/10 flex items-center justify-center text-[#FF9417]">
          {icon}
        </div>
        <span className="text-[10px] text-gray-500 bg-gray-800 px-2 py-1 rounded-full">{tag}</span>
      </div>
      <h3 className="text-lg font-semibold text-white mb-2">{title}</h3>
      <p className="text-sm text-gray-400">{description}</p>
    </div>
  );
}
