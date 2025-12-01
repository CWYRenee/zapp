# Zapp

Zapp is a privacy-first mobile wallet that bridges **Zcash shielded transactions** with local fiat payment rails through peer-to-peer matching, powered by **NEAR Intents** for cross-chain DeFi.

**Pay anyone with ZEC—they receive local fiat (UPI, Alipay, PIX, etc.) privately and instantly.**

## What Zapp Enables

- **Private P2P Payments**: Send ZEC to pay anyone's local payment account (UPI ID, Alipay, etc.) without revealing transaction details
- **Cross-Chain Privacy**: NEAR Intents handle ZEC↔NEAR bridging while preserving Zcash's shielded transaction privacy
- **Private DeFi Yield**: Earn yield on idle ZEC through RHEA Finance pools without exposing positions
- **Self-Custody Wallet**: Mobile-first iOS wallet with biometric auth and intuitive UX—your keys, your coins
- **Anonymous Remittance**: Cross-border payments that hide sender, receiver, and amount

## Grant Categories Addressed

| Category | How Zapp Addresses It |
|----------|----------------------|
| **Cross-Chain Privacy Solutions** | NEAR Intents bridge ZEC↔NEAR while maintaining shielded transaction privacy |
| **Private DeFi & Trading** | Yield earning via RHEA Finance pools with hidden positions and no front-running |
| **Self-Custody & Wallet Innovation** | Mobile-first iOS wallet with biometric auth, shielded sends, and clean UX |
| **Private Payments & Transactions** | P2P fiat payments via local rails (UPI, Alipay, PIX) with complete privacy |
| **Privacy Infrastructure** | Zcash SDK integration, order matching system, cross-chain bridge coordination |

## Architecture

| Component | Description |
|-----------|-------------|
| **Zapp** | iOS wallet app (SwiftUI + Zcash SDK) |
| **backend-zapp** | API server (Node.js/Express + MongoDB) |
| **admin-zapp** | Facilitator dashboard (React + Vite) |

## Hosted demo (recommended)

This repo includes a **testnet demo** that uses a live backend, MongoDB Atlas database, and hosted facilitator dashboard. You can build the iOS app on your own device and it will connect to this live stack by default.

- **Backend (API)**: `https://zapp-backend-ik5q.onrender.com`
- **Facilitator dashboard**: `https://zapp-demo.vercel.app/`
- **Network**: testnet only with test funds

### 1. Run the iOS wallet connected to the live backend

Requirements:

- macOS with Xcode 15+
- An iPhone or iOS simulator
- Git

Steps:

```bash
git clone https://github.com/CWYRenee/zapp.git
cd zapp/Zapp
cp .env.example .env        # keeps ZAPP_API_URL pointing at the hosted backend
open Zapp.xcodeproj
```

Then in Xcode:

1. Select a device or simulator.
2. Build & Run.

The wallet will:

- Use the hosted backend and shared Atlas demo database
- Operate on **testnet** (no real ZEC required)

### 2. Open the live facilitator dashboard

Open:

```text
https://zapp-demo.vercel.app/
```

This dashboard:

- Shows the **facilitator view** for the demo
- Auto-logs into a shared demo facilitator (no email/password UI in this demo)
- May take **30–60 seconds to respond after inactivity** because the free Render backend spins down; if it seems stuck, wait a bit and refresh

### 3. Facilitators and QR payment rails

In Zapp’s design:

- **App users** pay with ZEC from the mobile wallet
- **Recipients** only need a local payment QR (UPI, Alipay, PIX, PromptPay, etc.)
- **Facilitators** sit in the middle:
  - They sign in to the admin dashboard
  - They see pending ZEC→fiat orders from app users
  - They send fiat via local rails by scanning the same QR code
  - They receive ZEC on-chain in return

Think of facilitators as a **human / operational layer on top of QR payment rails**, making the fiat payments on users’ behalf.

For this **demo**:

- A single shared facilitator account is preconfigured in the backend
- The dashboard auto-logs into that account for convenience

In a **production deployment**:

- Facilitators would **sign up** and log in with their own credentials (email + password or similar)
- Each facilitator would only see and manage **their own** orders, rails configuration, and earnings
- The admin dashboard would be a multi-tenant system rather than a shared demo view

## Local development setup (optional)

If you prefer to run everything locally instead of using the hosted demo:

- Run MongoDB (or Atlas)
- Start `backend-zapp` on `http://localhost:4001`
- Point `admin-zapp` at that URL via `VITE_API_URL`
- Point the iOS app at that URL via `ZAPP_API_URL`

Detailed step‑by‑step instructions are in the sections below:

- **Zapp (iOS App)**
- **backend-zapp (API Server)**
- **admin-zapp (Facilitator Dashboard)**
- **Quick Start (All Components)**

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│  1. SCAN & PAY        2. ORDER MATCHED      3. FIAT SENT    4. ZEC SETTLED │
│  ─────────────        ────────────────      ────────────    ──────────────│
│  User scans           System matches        Facilitator     User's wallet  │
│  recipient's          with facilitator      sends fiat      sends shielded │
│  UPI/Alipay QR        who can fulfill       to recipient    ZEC to         │
│  and enters           the local payment     via local       facilitator    │
│  fiat amount                                payment rail                   │
└─────────────────────────────────────────────────────────────────────────┘
```

**Result**: User pays with ZEC, recipient receives local fiat—privately, with no centralized exchange.

---

## Zapp (iOS App)

The mobile wallet for end users.

**Features:**
- Create/restore Zcash shielded wallet
- Send and receive ZEC with full transaction privacy
- Pay anyone by scanning their payment QR (UPI, Alipay, PIX, PromptPay)
- Earn yield via NEAR Intents (deposit ZEC → auto-bridge to NEAR → stake in RHEA Finance pools)
- Biometric authentication for transactions

**Setup:**

1. Open the project in Xcode:
   ```bash
   cd Zapp
   open Zapp.xcodeproj
   ```

2. Create environment file:
   ```bash
   cp .env.example .env
   ```

3. Configure `.env` with your backend API URL

4. Build and run on simulator or device (requires Xcode 15+)

---

## backend-zapp (API Server)

Handles facilitator authentication, order management, and blockchain interactions.

**Features:**
- Facilitator OTP authentication
- P2P order lifecycle (create → accept → fiat sent → complete)
- **NEAR Intents integration** via Omni Bridge SDK for ZEC↔NEAR bridging
- DeFi pool data from RHEA Finance
- Intent-based execution: users specify desired outcome, backend orchestrates cross-chain flow

**Requirements:**
- Node.js 16+
- MongoDB
- (Optional) Zcash node for real transactions

**Setup:**

1. Install dependencies:
   ```bash
   cd backend-zapp
   npm install
   ```

2. Create environment file:
   ```bash
   cp .env.example .env
   ```

3. Configure `.env`:
   ```
   MONGODB_URI=mongodb://localhost:27017/zapp
   MERCHANT_JWT_SECRET=your-secret-key
   ZAP_ADMIN_API_KEY=your-admin-key
   ```

4. Start the server:
   ```bash
   npm run dev
   ```

   Server runs on `http://localhost:4001`

---

## admin-zapp (Facilitator Dashboard)

Web dashboard for facilitators to manage orders and earn spread on P2P transactions.

**Features:**
- View and accept pending orders in real-time
- Scan recipient QR codes to send fiat payments
- Configure supported payment rails (UPI, Alipay, WeChat Pay, PIX, PromptPay)
- Track earnings and order history with analytics dashboard
- Batch order support for multiple recipients

**Setup:**

1. Install dependencies:
   ```bash
   cd admin-zapp
   npm install
   ```

2. Create environment file:
   ```bash
   cp .env.example .env
   ```

3. Configure `.env`:
   ```
   VITE_API_URL=http://localhost:4001
   ```

4. Start the dev server:
   ```bash
   npm run dev
   ```

   Dashboard runs on `http://localhost:5173`

---

## Quick Start (All Components)

1. **Start MongoDB** (if not running):
   ```bash
   mongod
   ```

2. **Start backend**:
   ```bash
   cd backend-zapp
   npm install
   cp .env.example .env
   # Edit .env with your MongoDB URI
   npm run dev
   ```

3. **Start admin dashboard**:
   ```bash
   cd admin-zapp
   npm install
   cp .env.example .env
   npm run dev
   ```

4. **Run iOS app**:
   ```bash
   cd Zapp
   open Zapp.xcodeproj
   # Build and run in Xcode
   ```

---

## Demo Mode

The admin dashboard supports demo mode for testing without authentication. The backend accepts a special demo token and uses the first facilitator in the database.

---

## License

MIT
