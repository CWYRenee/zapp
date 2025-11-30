/**
 * Zcash RPC Service
 * 
 * Connects directly to a Zcash node via JSON-RPC to perform operations
 * required for bridging. This replaces the need for an external Zcash API key.
 * 
 * Based on: https://github.com/zcash/zcash/blob/master/doc/payment-api.md
 * 
 * Required environment variables:
 * - ZCASH_RPC_URL: URL of the Zcash node (e.g., http://127.0.0.1:8232)
 * - ZCASH_RPC_USER: RPC username (optional, for authenticated nodes)
 * - ZCASH_RPC_PASSWORD: RPC password (optional, for authenticated nodes)
 */

// Use native fetch (Node 18+) or node-fetch
const fetch = globalThis.fetch || require('node-fetch');

// ============================================================================
// Configuration
// ============================================================================

const ZCASH_RPC_URL = process.env.ZCASH_RPC_URL || 'http://127.0.0.1:8232';
const ZCASH_RPC_USER = process.env.ZCASH_RPC_USER || '';
const ZCASH_RPC_PASSWORD = process.env.ZCASH_RPC_PASSWORD || '';

// Determine network from NEAR_ENV
const isTestnet = process.env.NEAR_ENV !== 'mainnet';

// ============================================================================
// Types
// ============================================================================

export interface RpcResponse<T> {
  result: T | null;
  error: RpcError | null;
  id: string | number;
}

export interface RpcError {
  code: number;
  message: string;
}

export interface TransactionInfo {
  txid: string;
  confirmations: number;
  blockhash?: string;
  blockindex?: number;
  blocktime?: number;
  time: number;
  timereceived: number;
  details: TransactionDetail[];
  hex: string;
}

export interface TransactionDetail {
  address?: string;
  category: 'send' | 'receive' | 'generate' | 'immature' | 'orphan';
  amount: number;
  vout: number;
  fee?: number;
}

export interface UnspentNote {
  txid: string;
  jsindex: number;
  jsoutindex: number;
  confirmations: number;
  address: string;
  amount: number;
  memo: string;
}

export interface OperationStatus {
  id: string;
  status: 'queued' | 'executing' | 'success' | 'failed' | 'cancelled';
  creation_time: number;
  result?: {
    txid?: string;
    [key: string]: unknown;
  };
  error?: {
    code: number;
    message: string;
  };
  method?: string;
  params?: unknown;
}

export interface SendManyRecipient {
  address: string;
  amount: number;
  memo?: string; // Hex-encoded memo for z-addresses
}

export interface BalanceInfo {
  transparent: number;
  private: number;
  total: number;
}

export interface ReceivedByAddress {
  txid: string;
  amount: number;
  memo: string;
  confirmations: number;
}

// ============================================================================
// RPC Client
// ============================================================================

let rpcRequestId = 0;

/**
 * Make an RPC call to the Zcash node
 */
async function rpcCall<T>(method: string, params: unknown[] = []): Promise<T> {
  const id = ++rpcRequestId;
  
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  
  // Add Basic Auth if credentials are provided
  if (ZCASH_RPC_USER && ZCASH_RPC_PASSWORD) {
    const auth = Buffer.from(`${ZCASH_RPC_USER}:${ZCASH_RPC_PASSWORD}`).toString('base64');
    headers['Authorization'] = `Basic ${auth}`;
  }
  
  const body = JSON.stringify({
    jsonrpc: '1.0',
    id: id.toString(),
    method,
    params,
  });
  
  try {
    const response = await fetch(ZCASH_RPC_URL, {
      method: 'POST',
      headers,
      body,
    });
    
    if (!response.ok) {
      throw new Error(`RPC request failed: ${response.status} ${response.statusText}`);
    }
    
    const data = await response.json() as RpcResponse<T>;
    
    if (data.error) {
      throw new Error(`RPC error ${data.error.code}: ${data.error.message}`);
    }
    
    return data.result as T;
  } catch (error) {
    if (error instanceof Error && error.message.includes('ECONNREFUSED')) {
      throw new Error(`Cannot connect to Zcash node at ${ZCASH_RPC_URL}. Ensure zcashd is running.`);
    }
    throw error;
  }
}

// ============================================================================
// Zcash RPC Service
// ============================================================================

export class ZcashRpcService {
  
  // ==========================================================================
  // Connection & Info
  // ==========================================================================
  
  /**
   * Check if the Zcash node is reachable
   */
  static async isConnected(): Promise<boolean> {
    try {
      await rpcCall<unknown>('getinfo');
      return true;
    } catch {
      return false;
    }
  }
  
  /**
   * Get blockchain info
   */
  static async getBlockchainInfo(): Promise<{
    chain: string;
    blocks: number;
    headers: number;
    difficulty: number;
  }> {
    return rpcCall('getblockchaininfo');
  }
  
  // ==========================================================================
  // Balance & Accounting
  // ==========================================================================
  
  /**
   * Get balance for a specific address (transparent or shielded)
   * 
   * @param address - taddr or zaddr
   * @param minconf - Minimum confirmations (default: 1)
   */
  static async getBalance(address: string, minconf: number = 1): Promise<number> {
    return rpcCall<number>('z_getbalance', [address, minconf]);
  }
  
  /**
   * Get total wallet balance (transparent + shielded)
   * 
   * @param minconf - Minimum confirmations (default: 1)
   */
  static async getTotalBalance(minconf: number = 1): Promise<BalanceInfo> {
    return rpcCall<BalanceInfo>('z_gettotalbalance', [minconf]);
  }
  
  // ==========================================================================
  // Address Management
  // ==========================================================================
  
  /**
   * Generate a new shielded address (z-address)
   */
  static async getNewZAddress(): Promise<string> {
    return rpcCall<string>('z_getnewaddress');
  }
  
  /**
   * List all shielded addresses in the wallet
   */
  static async listZAddresses(): Promise<string[]> {
    return rpcCall<string[]>('z_listaddresses');
  }
  
  /**
   * Validate a shielded address
   */
  static async validateZAddress(address: string): Promise<{
    isvalid: boolean;
    address?: string;
    type?: string;
    ismine?: boolean;
  }> {
    return rpcCall('z_validateaddress', [address]);
  }
  
  /**
   * Generate a new transparent address
   */
  static async getNewAddress(): Promise<string> {
    return rpcCall<string>('getnewaddress');
  }
  
  // ==========================================================================
  // Transaction Queries
  // ==========================================================================
  
  /**
   * Get transaction details by txid
   * 
   * @param txid - Transaction ID
   */
  static async getTransaction(txid: string): Promise<TransactionInfo> {
    return rpcCall<TransactionInfo>('gettransaction', [txid]);
  }
  
  /**
   * Get raw transaction (hex)
   * 
   * @param txid - Transaction ID
   * @param verbose - If true, return decoded transaction
   */
  static async getRawTransaction(txid: string, verbose: boolean = false): Promise<string | unknown> {
    return rpcCall('getrawtransaction', [txid, verbose ? 1 : 0]);
  }
  
  /**
   * List received by a shielded address
   * 
   * @param address - z-address
   * @param minconf - Minimum confirmations (default: 1)
   */
  static async listReceivedByZAddress(address: string, minconf: number = 1): Promise<ReceivedByAddress[]> {
    return rpcCall<ReceivedByAddress[]>('z_listreceivedbyaddress', [address, minconf]);
  }
  
  /**
   * List unspent shielded notes
   * 
   * @param minconf - Minimum confirmations (default: 1)
   * @param maxconf - Maximum confirmations (default: 9999999)
   * @param addresses - Filter by specific addresses (optional)
   */
  static async listUnspentNotes(
    minconf: number = 1,
    maxconf: number = 9999999,
    includeWatchonly: boolean = false,
    addresses?: string[]
  ): Promise<UnspentNote[]> {
    const params: unknown[] = [minconf, maxconf, includeWatchonly];
    if (addresses) {
      params.push(addresses);
    }
    return rpcCall<UnspentNote[]>('z_listunspent', params);
  }
  
  /**
   * Get the number of confirmations for a transaction
   * 
   * @param txid - Transaction ID
   */
  static async getConfirmations(txid: string): Promise<number> {
    try {
      const tx = await this.getTransaction(txid);
      return tx.confirmations;
    } catch (error) {
      // Transaction might not be in wallet, try raw transaction
      try {
        const rawTx = await this.getRawTransaction(txid, true) as { confirmations?: number };
        return rawTx.confirmations || 0;
      } catch {
        return 0;
      }
    }
  }
  
  // ==========================================================================
  // Sending Funds
  // ==========================================================================
  
  /**
   * Send funds from one address to multiple recipients
   * This is an async operation - returns an operation ID
   * 
   * @param fromAddress - Source address (taddr or zaddr)
   * @param recipients - Array of recipient addresses and amounts
   * @param minconf - Minimum confirmations for inputs (default: 1)
   * @param fee - Transaction fee in ZEC (default: 0.0001)
   */
  static async sendMany(
    fromAddress: string,
    recipients: SendManyRecipient[],
    minconf: number = 1,
    fee: number = 0.0001
  ): Promise<string> {
    // Format recipients for the RPC call
    const amounts = recipients.map(r => {
      const recipient: Record<string, unknown> = {
        address: r.address,
        amount: r.amount,
      };
      if (r.memo) {
        recipient.memo = r.memo;
      }
      return recipient;
    });
    
    // Returns an operation ID (opid-xxxx)
    return rpcCall<string>('z_sendmany', [fromAddress, amounts, minconf, fee]);
  }
  
  /**
   * Shield transparent coinbase funds to a shielded address
   * 
   * @param fromAddress - Source taddr or "*" for all
   * @param toAddress - Destination z-address
   * @param fee - Transaction fee (default: 0.0001)
   * @param limit - Max UTXOs to shield (default: 50)
   */
  static async shieldCoinbase(
    fromAddress: string,
    toAddress: string,
    fee: number = 0.0001,
    limit: number = 50
  ): Promise<{ operationid: string; shieldingUTXOs: number; remainingUTXOs: number }> {
    return rpcCall('z_shieldcoinbase', [fromAddress, toAddress, fee, limit]);
  }
  
  // ==========================================================================
  // Async Operation Management
  // ==========================================================================
  
  /**
   * Get status of async operations
   * 
   * @param operationIds - Optional array of operation IDs to filter
   */
  static async getOperationStatus(operationIds?: string[]): Promise<OperationStatus[]> {
    const params = operationIds ? [operationIds] : [];
    return rpcCall<OperationStatus[]>('z_getoperationstatus', params);
  }
  
  /**
   * Get result of completed operations and remove them from memory
   * 
   * @param operationIds - Optional array of operation IDs to filter
   */
  static async getOperationResult(operationIds?: string[]): Promise<OperationStatus[]> {
    const params = operationIds ? [operationIds] : [];
    return rpcCall<OperationStatus[]>('z_getoperationresult', params);
  }
  
  /**
   * List all operation IDs
   * 
   * @param state - Optional filter by state
   */
  static async listOperationIds(state?: 'queued' | 'executing' | 'success' | 'failed' | 'cancelled'): Promise<string[]> {
    const params = state ? [state] : [];
    return rpcCall<string[]>('z_listoperationids', params);
  }
  
  /**
   * Wait for an operation to complete (poll until done)
   * 
   * @param operationId - The operation ID to wait for
   * @param timeoutMs - Maximum time to wait (default: 5 minutes)
   * @param pollIntervalMs - Time between polls (default: 2 seconds)
   */
  static async waitForOperation(
    operationId: string,
    timeoutMs: number = 300000,
    pollIntervalMs: number = 2000
  ): Promise<OperationStatus> {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeoutMs) {
      const statuses = await this.getOperationStatus([operationId]);
      
      if (statuses.length === 0) {
        // Operation might have completed, check results
        const results = await this.getOperationResult([operationId]);
        if (results.length > 0) {
          return results[0];
        }
        throw new Error(`Operation ${operationId} not found`);
      }
      
      const status = statuses[0];
      
      if (status.status === 'success' || status.status === 'failed' || status.status === 'cancelled') {
        // Get final result (which also removes from memory)
        const results = await this.getOperationResult([operationId]);
        return results.length > 0 ? results[0] : status;
      }
      
      // Still pending, wait and retry
      await new Promise(resolve => setTimeout(resolve, pollIntervalMs));
    }
    
    throw new Error(`Operation ${operationId} timed out after ${timeoutMs}ms`);
  }
  
  // ==========================================================================
  // Bridge-Specific Helpers
  // ==========================================================================
  
  /**
   * Verify a deposit transaction has enough confirmations
   * 
   * @param txid - Transaction ID
   * @param requiredConfirmations - Number of confirmations required (default: 3)
   */
  static async verifyDepositConfirmations(txid: string, requiredConfirmations: number = 3): Promise<{
    confirmed: boolean;
    confirmations: number;
    required: number;
  }> {
    const confirmations = await this.getConfirmations(txid);
    return {
      confirmed: confirmations >= requiredConfirmations,
      confirmations,
      required: requiredConfirmations,
    };
  }
  
  /**
   * Get transaction output details (for bridge deposit verification)
   * 
   * @param txid - Transaction ID
   * @param vout - Output index
   */
  static async getTransactionOutput(txid: string, vout: number): Promise<{
    address?: string | undefined;
    amount: number;
    confirmations: number;
  } | null> {
    try {
      const tx = await this.getTransaction(txid);
      const detail = tx.details.find(d => d.vout === vout);
      
      if (!detail) {
        return null;
      }
      
      return {
        address: detail.address,
        amount: Math.abs(detail.amount), // Amount can be negative for 'send'
        confirmations: tx.confirmations,
      };
    } catch {
      return null;
    }
  }
  
  // ==========================================================================
  // Configuration
  // ==========================================================================
  
  /**
   * Get the configured RPC URL
   */
  static get rpcUrl(): string {
    return ZCASH_RPC_URL;
  }
  
  /**
   * Check if running on testnet
   */
  static get isTestnet(): boolean {
    return isTestnet;
  }
}

export default ZcashRpcService;
