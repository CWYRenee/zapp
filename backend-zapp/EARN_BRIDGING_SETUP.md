# Earn Feature: Real Zcash→NEAR Bridging Setup

This document describes how to configure real bridging from Zcash to NEAR for the Earn feature using the Omni Bridge SDK.

## Overview

The Earn feature allows users to:
1. Deposit ZEC from their Zcash wallet
2. Bridge ZEC to nZEC on NEAR via Omni Bridge
3. Deposit nZEC into RHEA Finance liquidity pools
4. Earn yield on their deposits
5. Withdraw back to ZEC

## Architecture

```
Zcash Wallet → Omni Bridge → nZEC on NEAR → RHEA Finance LP
```

## Bridge Modes

The system supports two modes:

### Simulated Mode (Default)
- Used when `ZCASH_API_KEY` is not set
- Falls back to SwapKit or internal simulation
- Safe for development and testing
- Does not require real funds

### Real Mode
- Enabled when `ZCASH_API_KEY` is configured
- Uses `omni-bridge-sdk` for actual Zcash↔NEAR bridging
- Requires a Zcash API key from Tatum or similar provider
- Creates real NEAR accounts for users via `near-cli-rs`

## Prerequisites

### 1. Install near-cli-rs
```bash
npm install -g near-cli-rs@latest
```

### 2. Get Zcash API Key
Get an API key from [Tatum](https://tatum.io/) or a similar Zcash node provider.

### 3. Install Backend Dependencies
```bash
cd backend-zapp
npm install
```

## Configuration

### Environment Variables

Add the following to your `.env` file:

```env
# Network (testnet for testing, mainnet for production)
NEAR_ENV=testnet

# REQUIRED for real bridging: Zcash API key
ZCASH_API_KEY=your-api-key-here

# Optional: Bridge mode override
BRIDGE_MODE=real
```

### Network Configuration

| Variable | Testnet | Mainnet |
|----------|---------|---------|
| `NEAR_ENV` | `testnet` | `mainnet` |
| NEAR RPC | `https://test.rpc.fastnear.com` | `https://free.rpc.fastnear.com` |
| Bridge Contract | `omni.n-bridge.testnet` | `omni.bridge.near` |
| nZEC Token | `nzcash.n-bridge.testnet` | `nzec.bridge.near` |

## How It Works

### Deposit Flow (Real Bridging)

1. **Prepare Deposit**
   - Backend creates a NEAR account for the user (derived from Zcash address)
   - Backend calls `omni-bridge-sdk` to get a deposit address
   - Returns deposit address and `depositArgs` for finalization

2. **Send ZEC**
   - User sends ZEC to the deposit address
   - Wait for 3+ confirmations on Zcash network

3. **Finalize Deposit**
   - User enters the Zcash transaction hash
   - Backend calls `finalizeUtxoDeposit()` to verify and mint nZEC
   - nZEC is deposited to user's NEAR account

4. **Earn Yield**
   - nZEC is deposited to RHEA Finance pool
   - User earns yield based on pool APY

### Withdrawal Flow

1. **Initiate Withdrawal**
   - Backend withdraws from RHEA Finance pool
   - Backend initiates NEAR→Zcash bridge transfer

2. **Finalize Withdrawal**
   - Backend signs and broadcasts the Zcash transaction
   - ZEC is sent back to user's shielded address

## API Endpoints

### Deposit Preparation
```
POST /api/zapp/earn/deposit/prepare
Body: { user_wallet_address, zec_amount }
Response: { deposit: { bridgeAddress, depositArgs, requiresFinalization, ... } }
```

### Deposit Finalization
```
POST /api/zapp/earn/deposit/finalize
Body: { position_id, user_wallet_address, zcash_tx_hash, vout, deposit_args }
Response: { nearTxHash, nZecAmount, explorerUrl }
```

### Bridge Health
```
GET /api/zapp/earn/bridge/health
Response: { bridge: { isOperational, mode, network, nZecToken } }
```

## Testing

### Testnet Testing

1. Set `NEAR_ENV=testnet`
2. Configure `ZCASH_API_KEY` for testnet
3. Use TAZ (testnet ZEC) for testing
4. Monitor transactions on:
   - Zcash testnet explorer
   - NEAR testnet explorer: https://testnet.nearblocks.io/

### Mainnet Deployment

1. Set `NEAR_ENV=mainnet`
2. Configure `ZCASH_API_KEY` for mainnet
3. Ensure NEAR accounts have sufficient balance
4. Test with small amounts first

## Troubleshooting

### NEAR Account Creation Failed
- Ensure `near-cli-rs` is installed: `near --version`
- Check credentials path: `~/.near-credentials/testnet/`
- For testnet, accounts are auto-funded via faucet

### Finalization Failed
- Verify Zcash TX has 3+ confirmations
- Check transaction hash format (64 hex characters)
- Verify `vout` index (usually 0 or 1)

### Bridge Not Available
- Check `ZCASH_API_KEY` is set correctly
- Verify network connectivity to Zcash RPC
- Check bridge health: `GET /api/zapp/earn/bridge/health`

## Security Notes

- Never commit `ZCASH_API_KEY` to version control
- NEAR credentials are stored in `~/.near-credentials/`
- Each user gets their own deterministic NEAR account
- Use testnet for development and testing
