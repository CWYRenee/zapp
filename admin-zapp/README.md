# Zapp Admin Dashboard

A focused React admin dashboard for Zapp merchants to:

- Log in via email + OTP
- Configure payment rails (UPI, Alipay, bank transfer, other)
- View and accept pending Zapp P2P orders
- Mark fiat sent and ZEC received to complete orders

Backed by the `zapp-backend` merchant APIs.

## Setup

1. Install dependencies:

```bash
cd zapp-admin
npm install
```

2. Configure environment variables:

```bash
cp .env.example .env
```

Edit `.env` and set:

- `VITE_API_URL` – your `zapp-backend` API URL (default: `http://localhost:4001`)
- `VITE_DEFAULT_ADMIN_EMAIL` – optional default email prefilled in the login box

Make sure `zapp-backend` is running and reachable on this URL.

## Running in development

Start the Zapp backend (in another terminal):

```bash
cd ../zapp-backend
npm start
```

Then start the admin frontend:

```bash
cd ../zapp-admin
npm run dev
```

Open the URL printed by Vite (typically `http://localhost:5173`).

## Usage

1. **Login**
   - Enter a merchant email and click **Send OTP**.
   - The backend will generate an OTP and log it to the server console in development.
   - Enter the OTP and click **Verify OTP** to log in.

2. **Profile & payment rails**
   - Use the **Profile & payment rails** tab to set display name, ZEC address, and payment rails.
   - Rails support UPI IDs, Alipay IDs, and bank account + IFSC / routing codes.

3. **Orders**
   - Use the **Orders** tab to view:
     - **Pending** orders: global queue any merchant can accept.
     - **Active** orders: orders accepted by this merchant.
   - For each order you can:
     - **Accept** (from `pending`).
     - **Mark fiat sent** (from `accepted`).
     - **Mark ZEC received** (from `fiat_sent`, completing the order).

The dashboard polls the backend every 5 seconds for fresh order data.
