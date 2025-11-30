# Zapp

Zapp is a Zcash mobile wallet with P2P fiat payments and DeFi integration. Users can send/receive ZEC, pay merchants using local payment rails (UPI, Alipay, PIX, etc.), and earn yield through NEAR-based DeFi protocols.

The project has three components:

| Component | Description |
|-----------|-------------|
| **Zapp** | iOS wallet app (SwiftUI) |
| **backend-zapp** | API server (Node.js/Express + MongoDB) |
| **admin-zapp** | Merchant dashboard (React + Vite) |

---

## Zapp (iOS App)

The mobile wallet for end users.

**Features:**
- Create/restore Zcash wallet
- Send and receive ZEC
- Pay merchants via P2P orders (scan QR → send ZEC → merchant sends fiat)
- Earn yield via NEAR DeFi (Ref Finance pools)
- Swap tokens via NEAR bridge

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

Handles merchant authentication, order management, and blockchain interactions.

**Features:**
- Merchant OTP authentication
- P2P order lifecycle (create → accept → fiat sent → complete)
- ZEC↔NEAR bridging via Omni Bridge SDK
- DeFi pool data from Ref Finance

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

## admin-zapp (Merchant Dashboard)

Web dashboard for merchants to manage their profile and orders.

**Features:**
- Configure payment rails (UPI, Alipay, WeChat Pay, PIX, PromptPay)
- View and accept pending orders
- Track order status and mark completion
- Analytics dashboard

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

The admin dashboard supports demo mode for testing without authentication. The backend accepts a special demo token and uses the first merchant in the database.

---

## License

MIT
