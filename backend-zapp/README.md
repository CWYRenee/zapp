# Zapp Backend

Node.js/Express API server for the Zapp P2P payment system. Handles facilitator authentication, order management, cross-chain bridging (NEAR Intents), and DeFi yield operations.

## Features

- **Facilitator Auth** — Email + OTP login with JWT tokens
- **P2P Order Flow** — Create, accept, and complete ZEC↔fiat orders
- **Batch Orders** — Support for multi-recipient payments
- **DeFi Earn** — Deposit/withdraw ZEC to NEAR-based yield pools (RHEA Finance)
- **Cross-Chain Bridge** — ZEC↔NEAR bridging via Omni Bridge SDK

## Quick Start

```bash
# Install dependencies
npm install

# Copy environment config
cp .env.example .env

# Start development server
npm run dev
```

Server runs at `http://localhost:4001`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MONGODB_URI` | MongoDB connection string | Required |
| `MERCHANT_JWT_SECRET` | Secret for signing facilitator JWTs | Required |
| `ZEC_FIAT_RATE` | Fiat price for 1 ZEC | `50` |
| `NEAR_ENV` | NEAR network (`testnet` or `mainnet`) | `testnet` |
| `ZCASH_RPC_URL` | Zcash node RPC URL | `http://127.0.0.1:8232` |
| `BRIDGE_MODE` | `real` or `simulated` bridging | `simulated` |

See `.env.example` for full configuration options.

## API Endpoints

### Health Check

```
GET /health
```

### Facilitator Auth

```
POST /api/zapp/facilitator/auth/request-otp
POST /api/zapp/facilitator/auth/verify-otp
```

### Facilitator Profile & Orders

All endpoints require `Authorization: Bearer <token>` header.

```
GET  /api/zapp/facilitator/profile
PUT  /api/zapp/facilitator/profile

GET  /api/zapp/facilitator/orders/pending
GET  /api/zapp/facilitator/orders/active
GET  /api/zapp/facilitator/orders/completed

POST /api/zapp/facilitator/orders/:orderId/accept
POST /api/zapp/facilitator/orders/:orderId/mark-fiat-sent
POST /api/zapp/facilitator/orders/:orderId/mark-zec-received
```

### User Orders (iOS App)

```
POST /api/zapp/orders              # Create order
GET  /api/zapp/orders/:orderId     # Get order status
GET  /api/zapp/orders/user/:addr   # List user's orders

POST /api/zapp/orders/batch        # Create batch order
GET  /api/zapp/orders/batch/:id    # Get batch order
```

### DeFi Earn

```
POST /api/zapp/earn/deposit
POST /api/zapp/earn/withdraw
GET  /api/zapp/earn/positions/:walletAddress
GET  /api/zapp/earn/pools
```

## Project Structure

```
src/
├── app.ts              # Express app setup
├── server.ts           # Server entry point
├── config/             # Environment config
├── middleware/         # Auth & error handlers
├── models/             # Mongoose schemas
│   ├── Facilitator.ts  # Facilitator profile
│   ├── ZapOrder.ts     # P2P orders
│   ├── BatchOrder.ts   # Multi-recipient orders
│   └── EarnPosition.ts # DeFi positions
├── routes/             # API route handlers
├── services/           # Business logic
│   ├── orderService.ts
│   ├── merchantAuthService.ts
│   ├── bridgeService.ts
│   └── earnService.ts
├── jobs/               # Background workers
└── types/              # TypeScript definitions
```

## Order Flow

```
1. User creates order     →  status: "pending"
2. Facilitator accepts    →  status: "accepted"
3. Facilitator sends fiat →  status: "fiat_sent"
4. User sends ZEC         →  status: "completed"
```

## Demo Mode

For testing without real OTP delivery:
- Use OTP `000000` to bypass verification
- Demo facilitator: `demo@zapp.com`

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start with hot reload (tsx) |
| `npm run build` | Compile TypeScript |
| `npm start` | Run compiled JS |
| `npm run clean` | Remove dist folder |

## Dependencies

- **Express** — Web framework
- **Mongoose** — MongoDB ODM
- **jsonwebtoken** — JWT auth
- **omni-bridge-sdk** — ZEC↔NEAR bridging
- **@ref-finance/ref-sdk** — NEAR DEX integration
