/**
 * Zcash Blockchain Service
 * 
 * Queries the Zcash blockchain for transaction information.
 * Used by the deposit watcher to detect incoming bridge deposits.
 * 
 * Uses Tatum JSON-RPC Gateway for Zcash (mainnet and testnet).
 * Docs: https://docs.tatum.io/docs/rpc/zcash
 */

import axios from 'axios';

// Configuration
const isTestnet = process.env.NEAR_ENV !== 'mainnet';
const NETWORK = isTestnet ? 'testnet' : 'mainnet';

// Tatum API key from environment
const TATUM_API_KEY = process.env.ZCASH_API_KEY || '';

// Tatum JSON-RPC Gateway URLs
const TATUM_RPC_URL = isTestnet
  ? 'https://zcash-testnet.gateway.tatum.io'
  : 'https://zcash-mainnet.gateway.tatum.io';

// Log configuration
console.log(`[ZcashBlockchain] Initialized:`);
console.log(`[ZcashBlockchain]   Network: ${NETWORK}`);
console.log(`[ZcashBlockchain]   RPC URL: ${TATUM_RPC_URL}`);
console.log(`[ZcashBlockchain]   Tatum API: ${TATUM_API_KEY ? '✓ Configured' : '✗ Not set'}`);

// Minimum confirmations required before considering a deposit confirmed
const MIN_CONFIRMATIONS = isTestnet ? 1 : 3;

// Cache for address transaction lookups (to avoid hammering the API)
const txCache = new Map<string, { data: AddressTransactions; timestamp: number }>();
const CACHE_TTL_MS = 30_000; // 30 seconds

/**
 * Transaction output (UTXO)
 */
export interface TransactionOutput {
  index: number;       // vout index
  address: string;     // Recipient address
  value: number;       // Amount in ZEC
  spent: boolean;      // Whether this output has been spent
}

/**
 * Transaction info
 */
export interface TransactionInfo {
  txid: string;
  blockHeight: number | null;  // null if unconfirmed
  confirmations: number;
  timestamp: Date | null;
  outputs: TransactionOutput[];
  totalValue: number;          // Total output value
}

/**
 * Address transaction history
 */
export interface AddressTransactions {
  address: string;
  transactions: TransactionInfo[];
  balance: number;
}

/**
 * Deposit detection result
 */
export interface DetectedDeposit {
  txid: string;
  vout: number;
  amount: number;
  confirmations: number;
  blockHeight: number | null;
  timestamp: Date | null;
  isConfirmed: boolean;
}

// JSON-RPC request ID counter
let rpcRequestId = 0;

/**
 * Make a JSON-RPC call to Tatum gateway
 */
async function rpcCall<T>(method: string, params: any[] = []): Promise<T> {
  const response = await axios.post(
    TATUM_RPC_URL,
    {
      jsonrpc: '2.0',
      id: ++rpcRequestId,
      method,
      params,
    },
    {
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': TATUM_API_KEY,
      },
      timeout: 15000,
    }
  );

  if (response.data.error) {
    throw new Error(response.data.error.message || 'RPC error');
  }

  return response.data.result;
}

export class ZcashBlockchainService {
  /**
   * Get transactions for an address using Tatum SDK
   */
  static async getAddressTransactions(address: string): Promise<AddressTransactions | null> {
    // Check cache first
    const cached = txCache.get(address);
    if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
      return cached.data;
    }

    if (!TATUM_API_KEY) {
      console.warn('[ZcashBlockchain] No Tatum API key configured');
      return this.getFallbackAddressTransactions(address);
    }

    try {
      // Use Tatum Data API to get address transactions
      // Tatum provides address balance and transaction history via their indexer
      const balanceResult = await this.getAddressBalance(address);
      const transactions = await this.getAddressTransactionHistory(address);
      
      const result: AddressTransactions = {
        address,
        transactions,
        balance: balanceResult,
      };

      // Cache the result
      txCache.set(address, { data: result, timestamp: Date.now() });

      return result;
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      console.error(`[ZcashBlockchain] Error fetching transactions for ${address}: ${msg}`);
      return this.getFallbackAddressTransactions(address);
    }
  }

  /**
   * Get address balance using Zcash RPC
   * Note: Zcash RPC doesn't have a direct address balance method for transparent addresses
   * We need to scan UTXOs or use an indexer. For bridge addresses, we track via tx history.
   */
  private static async getAddressBalance(_address: string): Promise<number> {
    // Zcash RPC doesn't support direct address balance queries
    // The balance is calculated from UTXOs, which requires wallet support
    // For our use case (bridge deposits), we track via transaction verification
    return 0;
  }

  /**
   * Get address transaction history
   * Note: Zcash RPC requires the address to be in the wallet for getaddresstxids
   * For bridge deposits, we verify individual transactions instead
   */
  private static async getAddressTransactionHistory(_address: string): Promise<TransactionInfo[]> {
    // Standard Zcash RPC doesn't support address transaction indexing
    // without the address being imported into the wallet
    // The deposit watcher verifies individual transactions by txid instead
    return [];
  }

  /**
   * Get transaction details using Tatum JSON-RPC Gateway
   * Uses getrawtransaction RPC method
   */
  static async getTransactionDetails(txid: string): Promise<TransactionInfo | null> {
    if (!TATUM_API_KEY) {
      console.warn('[ZcashBlockchain] No Tatum API key configured');
      return null;
    }

    try {
      // Use getrawtransaction with verbose=1 to get decoded transaction
      const tx = await rpcCall<any>('getrawtransaction', [txid, 1]);
      
      if (!tx) {
        return null;
      }

      const outputs: TransactionOutput[] = (tx.vout || []).map((out: any) => ({
        index: out.n,
        address: out.scriptPubKey?.addresses?.[0] || out.scriptPubKey?.address || '',
        value: out.value || 0,
        spent: false,
      }));

      return {
        txid: tx.txid,
        blockHeight: tx.height || null,
        confirmations: tx.confirmations || 0,
        timestamp: tx.time ? new Date(tx.time * 1000) : null,
        outputs,
        totalValue: outputs.reduce((sum, o) => sum + o.value, 0),
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      console.warn(`[ZcashBlockchain] Failed to get tx details for ${txid}: ${msg}`);
      return null;
    }
  }

  /**
   * Get current blockchain info (block height, etc.)
   */
  static async getBlockchainInfo(): Promise<{ blocks: number; bestblockhash: string } | null> {
    if (!TATUM_API_KEY) {
      return null;
    }

    try {
      return await rpcCall<{ blocks: number; bestblockhash: string }>('getblockchaininfo');
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      console.warn(`[ZcashBlockchain] Failed to get blockchain info: ${msg}`);
      return null;
    }
  }

  /**
   * Validate a Zcash address
   */
  static async validateAddress(address: string): Promise<boolean> {
    if (!TATUM_API_KEY) {
      // Basic validation without RPC
      return address.startsWith('t') || address.startsWith('zs') || address.startsWith('u');
    }

    try {
      const result = await rpcCall<{ isvalid: boolean }>('validateaddress', [address]);
      return result.isvalid;
    } catch (error) {
      return false;
    }
  }

  /**
   * Fallback when Tatum is not available
   */
  private static async getFallbackAddressTransactions(address: string): Promise<AddressTransactions | null> {
    console.log(`[ZcashBlockchain] Using fallback for address ${address}`);
    return {
      address,
      transactions: [],
      balance: 0,
    };
  }

  /**
   * Detect deposits to a specific address
   * Returns all transactions that pay to this address with sufficient confirmations
   */
  static async detectDeposits(
    bridgeAddress: string,
    minAmount: number = 0,
  ): Promise<DetectedDeposit[]> {
    const addressTxs = await this.getAddressTransactions(bridgeAddress);
    if (!addressTxs) {
      return [];
    }

    const deposits: DetectedDeposit[] = [];

    for (const tx of addressTxs.transactions) {
      // Find outputs that pay to the bridge address
      for (const output of tx.outputs) {
        if (output.address === bridgeAddress && output.value >= minAmount) {
          deposits.push({
            txid: tx.txid,
            vout: output.index,
            amount: output.value,
            confirmations: tx.confirmations,
            blockHeight: tx.blockHeight,
            timestamp: tx.timestamp,
            isConfirmed: tx.confirmations >= MIN_CONFIRMATIONS,
          });
        }
      }
    }

    return deposits;
  }

  /**
   * Check if a specific transaction output exists and is confirmed
   */
  static async verifyDeposit(
    txid: string,
    vout: number,
    expectedAddress: string,
    minAmount: number = 0,
  ): Promise<DetectedDeposit | null> {
    try {
      // Use unified getTransactionDetails method (works for both testnet and mainnet via Tatum)
      const txInfo = await this.getTransactionDetails(txid);

      if (!txInfo) {
        return null;
      }

      // Find the specific output
      const output = txInfo.outputs.find(o => o.index === vout);
      if (!output) {
        return null;
      }

      // Verify it pays to the expected address with sufficient amount
      if (output.address !== expectedAddress || output.value < minAmount) {
        return null;
      }

      return {
        txid: txInfo.txid,
        vout: output.index,
        amount: output.value,
        confirmations: txInfo.confirmations,
        blockHeight: txInfo.blockHeight,
        timestamp: txInfo.timestamp,
        isConfirmed: txInfo.confirmations >= MIN_CONFIRMATIONS,
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      console.error(`[ZcashBlockchain] Error verifying deposit ${txid}:${vout}: ${msg}`);
      return null;
    }
  }

  /**
   * Get minimum confirmations required
   */
  static getMinConfirmations(): number {
    return MIN_CONFIRMATIONS;
  }

  /**
   * Get current network
   */
  static getNetwork(): 'testnet' | 'mainnet' {
    return NETWORK;
  }

  /**
   * Clear the transaction cache (useful for testing)
   */
  static clearCache(): void {
    txCache.clear();
  }
}

export default ZcashBlockchainService;
