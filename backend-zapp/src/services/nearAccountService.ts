/**
 * NEAR Account Service
 * 
 * Manages NEAR account creation and credentials for users.
 * Each user gets their own NEAR account derived from their Zcash wallet address.
 * 
 * Uses near-cli-rs for account creation:
 * - Testnet: Creates accounts via faucet
 * - Mainnet: Requires manual funding
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

const execAsync = promisify(exec);

// Network configuration
const isTestnet = process.env.NEAR_ENV !== 'mainnet';
const NETWORK = isTestnet ? 'testnet' : 'mainnet';
const NEAR_SUFFIX = isTestnet ? '.testnet' : '.near';

// Credentials path
const CREDENTIALS_BASE_PATH = process.env.NEAR_CREDENTIALS_PATH || 
  path.join(process.env.HOME || '~', '.near-credentials');
const CREDENTIALS_PATH = path.join(CREDENTIALS_BASE_PATH, NETWORK);

// In-memory cache for account lookups (can be replaced with DB)
const accountCache = new Map<string, NearAccountInfo>();

/**
 * NEAR account information
 */
export interface NearAccountInfo {
  accountId: string;
  zcashAddress: string;
  createdAt: Date;
  network: 'testnet' | 'mainnet';
  credentialsPath: string;
  publicKey?: string | undefined;
}

/**
 * Account creation result
 */
export interface AccountCreationResult {
  success: boolean;
  accountId?: string;
  error?: string;
  alreadyExists?: boolean;
}

/**
 * Generate a deterministic NEAR account ID from a Zcash address
 * Format: zapp-{hash}.testnet or zapp-{hash}.near
 */
export function generateAccountId(zcashAddress: string): string {
  // Create a short hash from the Zcash address
  const hash = crypto
    .createHash('sha256')
    .update(zcashAddress)
    .digest('hex')
    .substring(0, 16)
    .toLowerCase();
  
  return `zapp-${hash}${NEAR_SUFFIX}`;
}

/**
 * Check if near-cli-rs is installed
 */
export async function isNearCliInstalled(): Promise<boolean> {
  try {
    await execAsync('near --version');
    return true;
  } catch {
    return false;
  }
}

/**
 * Check if credentials exist for an account
 */
export function credentialsExist(accountId: string): boolean {
  const credFile = path.join(CREDENTIALS_PATH, `${accountId}.json`);
  return fs.existsSync(credFile);
}

/**
 * Get credentials path for an account
 */
export function getCredentialsPath(accountId: string): string {
  return path.join(CREDENTIALS_PATH, `${accountId}.json`);
}

/**
 * Read account credentials
 */
export function readCredentials(accountId: string): { account_id: string; public_key: string; private_key: string } | null {
  const credFile = getCredentialsPath(accountId);
  if (!fs.existsSync(credFile)) {
    return null;
  }
  
  try {
    const content = fs.readFileSync(credFile, 'utf-8');
    return JSON.parse(content);
  } catch {
    return null;
  }
}

/**
 * Create a new NEAR account for a user
 * Uses near-cli-rs with faucet for testnet
 */
export async function createNearAccount(zcashAddress: string): Promise<AccountCreationResult> {
  const accountId = generateAccountId(zcashAddress);
  
  // Check if account already exists locally
  if (credentialsExist(accountId)) {
    console.log(`[NearAccount] Account ${accountId} already exists locally`);
    return {
      success: true,
      accountId,
      alreadyExists: true,
    };
  }
  
  // Check if near-cli is installed
  const cliInstalled = await isNearCliInstalled();
  if (!cliInstalled) {
    console.error('[NearAccount] near-cli-rs is not installed');
    return {
      success: false,
      error: 'near-cli-rs is not installed. Run: npm install -g near-cli-rs@latest',
    };
  }
  
  // Ensure credentials directory exists
  if (!fs.existsSync(CREDENTIALS_PATH)) {
    fs.mkdirSync(CREDENTIALS_PATH, { recursive: true });
  }
  
  try {
    console.log(`[NearAccount] Creating account: ${accountId}`);
    
    if (isTestnet) {
      // Testnet: Use faucet service to create and fund account (free on testnet)
      const cmd = `near account create-account sponsor-by-faucet-service ${accountId} autogenerate-new-keypair save-to-legacy-keychain network-config testnet create`;
      console.log('[NearAccount] Running:', cmd);
      
      const { stdout, stderr } = await execAsync(cmd, { timeout: 60000 });
      
      console.log('[NearAccount] CLI output:', stdout);
      if (stderr) {
        console.warn('[NearAccount] CLI stderr:', stderr);
      }
    } else {
      // Mainnet: Create implicit account (fund later)
      const cmd = `near account create-account fund-later autogenerate-new-keypair save-to-legacy-keychain network-config mainnet create`;
      console.log('[NearAccount] Running:', cmd);
      
      const { stdout, stderr } = await execAsync(cmd, { timeout: 30000 });
      
      console.log('[NearAccount] CLI output:', stdout);
      if (stderr) {
        console.warn('[NearAccount] CLI stderr:', stderr);
      }
    }
    
    // Verify credentials were created
    if (!credentialsExist(accountId)) {
      // Try alternative credentials location (legacy)
      const legacyPath = path.join(process.env.HOME || '~', '.near-credentials', NETWORK, `${accountId}.json`);
      if (fs.existsSync(legacyPath) && !fs.existsSync(getCredentialsPath(accountId))) {
        // Copy to our credentials path
        fs.copyFileSync(legacyPath, getCredentialsPath(accountId));
      }
    }
    
    if (!credentialsExist(accountId)) {
      return {
        success: false,
        error: 'Account created but credentials not found. Check near-cli configuration.',
      };
    }
    
    // Cache the account info
    const accountInfo: NearAccountInfo = {
      accountId,
      zcashAddress,
      createdAt: new Date(),
      network: NETWORK as 'testnet' | 'mainnet',
      credentialsPath: getCredentialsPath(accountId),
    };
    accountCache.set(zcashAddress, accountInfo);
    
    console.log(`[NearAccount] ✓ Account created successfully: ${accountId}`);
    
    return {
      success: true,
      accountId,
    };
    
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('[NearAccount] ✗ Failed to create account:', message);
    
    // Check for specific error cases
    if (message.includes('already exists')) {
      return {
        success: true,
        accountId,
        alreadyExists: true,
      };
    }
    
    return {
      success: false,
      error: `Failed to create NEAR account: ${message}`,
    };
  }
}

/**
 * Get or create a NEAR account for a user
 */
export async function getOrCreateNearAccount(zcashAddress: string): Promise<NearAccountInfo | null> {
  // Check cache first
  const cached = accountCache.get(zcashAddress);
  if (cached) {
    return cached;
  }
  
  const accountId = generateAccountId(zcashAddress);
  
  // Check if credentials exist
  if (credentialsExist(accountId)) {
    const creds = readCredentials(accountId);
    const accountInfo: NearAccountInfo = {
      accountId,
      zcashAddress,
      createdAt: new Date(), // Unknown, use now
      network: NETWORK as 'testnet' | 'mainnet',
      credentialsPath: getCredentialsPath(accountId),
      publicKey: creds?.public_key,
    };
    accountCache.set(zcashAddress, accountInfo);
    return accountInfo;
  }
  
  // Create new account
  const result = await createNearAccount(zcashAddress);
  if (!result.success || !result.accountId) {
    console.error('[NearAccount] Failed to get or create account:', result.error);
    return null;
  }
  
  return accountCache.get(zcashAddress) || null;
}

/**
 * Get NEAR account ID for a Zcash address (without creating)
 */
export function getNearAccountId(zcashAddress: string): string {
  return generateAccountId(zcashAddress);
}

/**
 * Check if a user has a NEAR account
 */
export function hasNearAccount(zcashAddress: string): boolean {
  const accountId = generateAccountId(zcashAddress);
  return credentialsExist(accountId);
}

/**
 * Service class for NEAR account management
 */
export class NearAccountService {
  /**
   * Generate account ID from Zcash address
   */
  static generateAccountId = generateAccountId;
  
  /**
   * Check if near-cli is installed
   */
  static isCliInstalled = isNearCliInstalled;
  
  /**
   * Create a new NEAR account
   */
  static createAccount = createNearAccount;
  
  /**
   * Get or create NEAR account
   */
  static getOrCreateAccount = getOrCreateNearAccount;
  
  /**
   * Check if user has a NEAR account
   */
  static hasAccount = hasNearAccount;
  
  /**
   * Get account ID without creating
   */
  static getAccountId = getNearAccountId;
  
  /**
   * Get credentials path
   */
  static getCredentialsPath = getCredentialsPath;
  
  /**
   * Read credentials for an account
   */
  static readCredentials = readCredentials;
  
  /**
   * Get network
   */
  static get network(): 'testnet' | 'mainnet' {
    return NETWORK as 'testnet' | 'mainnet';
  }
  
  /**
   * Get credentials base path
   */
  static get credentialsBasePath(): string {
    return CREDENTIALS_PATH;
  }
}

export default NearAccountService;
