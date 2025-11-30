/**
 * Earn Routes
 * API endpoints for Zcash earning via NEAR Intents + RHEA Finance
 */

import { Router, type Request, type Response } from 'express';
import { EarnService } from '../services/earnService.js';
import { NEARIntentsService } from '../services/nearIntentsService.js';
import { OmniBridgeService } from '../services/omniBridgeService.js';
import { refIndexerService } from '../services/refIndexerService.js';
import type { EarnPositionStatus, CreateEarnPositionInput, InitiateWithdrawalInput } from '../types/earn.js';

const router = Router();

// ============================================================================
// Protocol Info Endpoints
// ============================================================================

/**
 * GET /api/zapp/earn/protocol
 * Get RHEA Finance protocol information including current APY
 */
router.get('/protocol', async (_req: Request, res: Response) => {
  try {
    const protocolInfo = await EarnService.getProtocolInfo();
    
    return res.status(200).json({
      success: true,
      protocol: protocolInfo,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get protocol info';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * GET /api/zapp/earn/protocol/apy-history
 * Get APY history for charts
 */
router.get('/protocol/apy-history', async (req: Request, res: Response) => {
  try {
    const days = Math.min(Number(req.query.days) || 30, 90);
    const history = await EarnService.getApyHistory(days);
    
    return res.status(200).json({
      success: true,
      history,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get APY history';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * GET /api/zapp/earn/bridge/health
 * Get NEAR Intents bridge health status
 */
router.get('/bridge/health', async (_req: Request, res: Response) => {
  try {
    const health = await NEARIntentsService.getBridgeHealth();
    
    // Include bridge configuration info
    const isRealBridgeConfigured = OmniBridgeService.isConfigured();
    const network = OmniBridgeService.getNetwork();
    
    return res.status(200).json({
      success: true,
      bridge: {
        ...health,
        // Bridge mode info
        mode: isRealBridgeConfigured ? 'real' : 'simulated',
        network,
        nZecToken: isRealBridgeConfigured ? OmniBridgeService.getNZecTokenAddress() : undefined,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get bridge health';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * POST /api/zapp/earn/bridge/quote
 * Get a swap quote for ZEC/TAZ → NEAR bridging
 * In testnet mode, returns simulated quote
 */
router.post('/bridge/quote', async (req: Request, res: Response) => {
  try {
    const { sellAmount, sourceZecAddress, destinationNearAddress, slippage } = req.body;
    
    if (!sellAmount || !sourceZecAddress || !destinationNearAddress) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'Missing required fields: sellAmount, sourceZecAddress, destinationNearAddress',
      });
    }
    
    // Use SwapKit service to get quote (handles testnet simulation)
    const { getSwapService } = await import('../services/swapkit/index.js');
    const swapService = getSwapService();
    
    const quote = await swapService.getZecToNearQuote({
      sellAmount: String(sellAmount),
      sourceZecAddress: String(sourceZecAddress),
      destinationNearAddress: String(destinationNearAddress),
      slippage: slippage ? Number(slippage) : 3,
    });
    
    return res.status(200).json({
      success: true,
      bestRoute: quote.bestRoute,
      routes: quote.routes,
      sellAsset: quote.sellAsset,
      buyAsset: quote.buyAsset,
      sellAmount: quote.sellAmount,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get bridge quote';
    console.error('[EarnRoutes] Bridge quote error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

// ============================================================================
// Deposit Flow Endpoints
// ============================================================================

/**
 * GET /api/zapp/earn/pools/top
 * Get top pools by APY from RHEA Finance indexer
 */
router.get('/pools/top', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 10, 50);
    const topPools = await refIndexerService.getTopPoolsByApy(limit);
    
    return res.status(200).json({
      success: true,
      pools: topPools.map(p => ({
        id: p.pool.id,
        tokenSymbols: p.pool.token_symbols,
        tvl: p.tvl,
        apy: p.apy,
        fee: p.pool.total_fee,
      })),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get top pools';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * GET /api/zapp/earn/tokens/prices
 * Get token prices from RHEA Finance indexer
 */
router.get('/tokens/prices', async (_req: Request, res: Response) => {
  try {
    const prices = await refIndexerService.getTokenPrices();
    
    return res.status(200).json({
      success: true,
      prices,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get token prices';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * POST /api/zapp/earn/deposit/prepare
 * Get bridge deposit address for ZEC → NEAR/RHEA Finance
 * 
 * Response includes:
 * - bridgeAddress: The Zcash address to send funds to
 * - depositArgs: Opaque payload for bridge finalization (required for real bridging)
 * - isSimulated: Whether this is a testnet simulation (false for real bridging)
 * - source: Where the address came from (omni_bridge_sdk, swapkit_api, testnet_simulation, fallback)
 * - requiresFinalization: Whether explicit finalization is needed (true for real bridging)
 * - nearAccountId: NEAR account associated with the deposit (for real bridging)
 */
router.post('/deposit/prepare', async (req: Request, res: Response) => {
  try {
    const { user_wallet_address, zec_amount } = req.body;
    
    if (!user_wallet_address || zec_amount === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'user_wallet_address and zec_amount are required',
      });
    }
    
    const bridgeInfo = await EarnService.getBridgeDepositInfo(
      String(user_wallet_address),
      Number(zec_amount),
    );
    
    // Determine if finalization is required (real bridging via omni-bridge-sdk)
    const requiresFinalization = bridgeInfo.source === 'omni_bridge_sdk' && !bridgeInfo.isSimulated;
    
    // Prepare instructions based on bridge mode
    const instructions = requiresFinalization
      ? `Send ${zec_amount} ZEC to the bridge address. After the transaction confirms, you'll need to finalize the deposit to receive nZEC on NEAR.`
      : `Send ${zec_amount} ZEC to the bridge address to start earning on RHEA`;
    
    return res.status(200).json({
      success: true,
      deposit: {
        bridgeAddress: bridgeInfo.bridgeAddress,
        expectedAmount: bridgeInfo.expectedAmount,
        estimatedArrivalMinutes: bridgeInfo.estimatedArrivalMinutes,
        bridgeFeePercent: bridgeInfo.bridgeFeePercent,
        nearIntentId: bridgeInfo.nearIntentId,
        // Bridge mode indicators
        isSimulated: bridgeInfo.isSimulated,
        source: bridgeInfo.source,
        // Real bridging data
        depositArgs: bridgeInfo.depositArgs,
        minDepositZec: bridgeInfo.minDepositZec,
        nearAccountId: bridgeInfo.nearAccountId,
        requiresFinalization,
      },
      instructions,
      requiresFinalization,
      // Bridge configuration info
      bridgeMode: OmniBridgeService.isConfigured() ? 'real' : 'simulated',
      network: OmniBridgeService.getNetwork(),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to prepare deposit';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * POST /api/zapp/earn/deposit/finalize
 * Finalize a deposit after ZEC has been sent and confirmed.
 * 
 * Currently unused: reserved for future bridge implementations that may require
 * explicit finalization. In simulation mode this endpoint always returns an error.
 * 
 * Request body:
 * - position_id: The position ID from createPosition
 * - user_wallet_address: User's Zcash wallet address
 * - zcash_tx_hash: The Zcash transaction hash
 * - vout: Output index (usually 0 or 1)
 * - deposit_args: The depositArgs from /deposit/prepare
 */
router.post('/deposit/finalize', async (req: Request, res: Response) => {
  try {
    const { position_id, user_wallet_address, zcash_tx_hash, vout, deposit_args } = req.body;
    
    if (!position_id || !user_wallet_address || !zcash_tx_hash || vout === undefined || !deposit_args) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'position_id, user_wallet_address, zcash_tx_hash, vout, and deposit_args are required',
      });
    }
    
    const result = await NEARIntentsService.finalizeDeposit(
      {
        positionId: String(position_id),
        userWalletAddress: String(user_wallet_address),
        zcashTxHash: String(zcash_tx_hash),
        vout: Number(vout),
      },
      String(deposit_args),
    );
    
    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: 'Finalization Failed',
        message: result.error || 'Failed to finalize deposit',
      });
    }
    
    // Update position status and record bridge transaction
    const nearAmountFromBridge = result.nZecAmount ? Number(result.nZecAmount) : undefined;
    await EarnService.markBridgeDepositReceived(
      String(position_id),
      String(zcash_tx_hash),
      nearAmountFromBridge,
    );
    
    // For real bridging, immediately activate lending (deposit to RHEA pool)
    // The nZEC is already minted, so we can deposit right away
    console.log(`[EarnRoutes] Activating lending for position ${position_id}...`);
    const activatedPosition = await EarnService.activateLending(String(position_id));
    
    if (!activatedPosition || activatedPosition.status !== 'lending_active') {
      console.warn(`[EarnRoutes] Lending activation may have failed for ${position_id}`);
    } else {
      console.log(`[EarnRoutes] ✓ Lending activated! APY: ${activatedPosition.currentApy}%`);
    }
    
    return res.status(200).json({
      success: true,
      nearTxHash: result.nearTxHash,
      nZecAmount: result.nZecAmount,
      explorerUrl: result.explorerUrl,
      lendingActivated: activatedPosition?.status === 'lending_active',
      currentApy: activatedPosition?.currentApy,
      poolId: activatedPosition?.poolId,
      message: activatedPosition?.status === 'lending_active'
        ? `Deposit finalized and deposited to RHEA Finance at ${activatedPosition.currentApy?.toFixed(2)}% APY!`
        : 'Deposit finalized! nZEC has been minted on NEAR.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to finalize deposit';
    console.error('[EarnRoutes] Finalize deposit error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * POST /api/zapp/earn/positions
 * Create a new earn position after sending ZEC to bridge
 */
router.post('/positions', async (req: Request, res: Response) => {
  try {
    const { user_wallet_address, zec_amount, metadata, pool_id } = req.body;
    
    if (!user_wallet_address || !zec_amount) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'user_wallet_address and zec_amount are required',
      });
    }
    
    const input: CreateEarnPositionInput = {
      userWalletAddress: String(user_wallet_address),
      zecAmount: Number(zec_amount),
      metadata,
      ...(pool_id ? { poolId: String(pool_id) } : {}),
    };
    
    const position = await EarnService.createPosition(input);
    
    return res.status(201).json({
      success: true,
      position: EarnService.getPositionSummary(position),
      bridgeAddress: position.bridgeDepositAddress,
      nearIntentId: position.nearIntentId,
      message: 'Position created. Send ZEC to the bridge address to start earning.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to create position';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// ============================================================================
// Position Management Endpoints
// ============================================================================

/**
 * GET /api/zapp/earn/positions/user/:walletAddress
 * Get all positions for a user
 */
router.get('/positions/user/:walletAddress', async (req: Request, res: Response) => {
  try {
    const { walletAddress } = req.params;
    const { status, limit = '50', skip = '0' } = req.query;
    
    const positions = await EarnService.getPositionsForUser(
      walletAddress,
      status ? String(status) as EarnPositionStatus : undefined,
      Number(limit),
      Number(skip),
    );
    
    return res.status(200).json({
      success: true,
      positions: positions.map(p => EarnService.getPositionSummary(p)),
      total: positions.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get positions';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * GET /api/zapp/earn/positions/:positionId
 * Get a single position
 */
router.get('/positions/:positionId', async (req: Request, res: Response) => {
  try {
    const { positionId } = req.params;
    const { user_wallet_address } = req.query;
    
    if (!user_wallet_address || typeof user_wallet_address !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'user_wallet_address query parameter is required',
      });
    }
    
    const position = await EarnService.getPosition(positionId, user_wallet_address);
    
    if (!position) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Position not found',
      });
    }
    
    return res.status(200).json({
      success: true,
      position: EarnService.getPositionSummary(position),
      details: position,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get position';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * GET /api/zapp/earn/positions/:positionId/earnings-history
 * Get earnings history for a position (for charts)
 */
router.get('/positions/:positionId/earnings-history', async (req: Request, res: Response) => {
  try {
    const { positionId } = req.params;
    const { user_wallet_address, days = '30' } = req.query;
    
    if (!user_wallet_address || typeof user_wallet_address !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'user_wallet_address query parameter is required',
      });
    }
    
    const history = await EarnService.getEarningsHistory(
      positionId,
      user_wallet_address,
      Math.min(Number(days), 90),
    );
    
    return res.status(200).json({
      success: true,
      history,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get earnings history';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * GET /api/zapp/earn/user/:walletAddress/stats
 * Get aggregated stats for a user
 */
router.get('/user/:walletAddress/stats', async (req: Request, res: Response) => {
  try {
    const { walletAddress } = req.params;
    const stats = await EarnService.getUserStats(walletAddress);
    
    return res.status(200).json({
      success: true,
      stats,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get user stats';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// ============================================================================
// Withdrawal Flow Endpoints
// ============================================================================

/**
 * POST /api/zapp/earn/positions/:positionId/withdraw
 * Initiate withdrawal back to shielded Zcash
 */
router.post('/positions/:positionId/withdraw', async (req: Request, res: Response) => {
  try {
    const { positionId } = req.params;
    const {
      user_wallet_address,
      withdraw_to_address,
      withdraw_all = true,
      partial_amount,
    } = req.body;
    
    if (!user_wallet_address || !withdraw_to_address) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'user_wallet_address and withdraw_to_address are required',
      });
    }
    
    const input: InitiateWithdrawalInput = {
      positionId,
      userWalletAddress: String(user_wallet_address),
      withdrawToAddress: String(withdraw_to_address),
      withdrawAll: Boolean(withdraw_all),
      partialAmount: partial_amount ? Number(partial_amount) : undefined,
    };
    
    const position = await EarnService.initiateWithdrawal(input);
    
    if (!position) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Position not found',
      });
    }
    
    return res.status(200).json({
      success: true,
      position: EarnService.getPositionSummary(position),
      message: 'Withdrawal initiated. Funds will be bridged back to your shielded Zcash address.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to initiate withdrawal';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// ============================================================================
// Webhook Endpoints (for backend automation)
// ============================================================================

/**
 * POST /api/zapp/earn/positions/:positionId/bridge-received
 * Mark that ZEC was received by the NEAR Intents bridge
 */
router.post('/positions/:positionId/bridge-received', async (req: Request, res: Response) => {
  try {
    const { positionId } = req.params;
    const { zcash_tx_hash } = req.body;
    
    if (!zcash_tx_hash) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'zcash_tx_hash is required',
      });
    }
    
    const position = await EarnService.markBridgeDepositReceived(
      positionId,
      String(zcash_tx_hash),
      undefined,
    );
    
    if (!position) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Position not found',
      });
    }
    
    return res.status(200).json({
      success: true,
      position: EarnService.getPositionSummary(position),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update position';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

/**
 * POST /api/zapp/earn/positions/:positionId/completed
 * Mark position as completed (funds returned to Zcash)
 */
router.post('/positions/:positionId/completed', async (req: Request, res: Response) => {
  try {
    const { positionId } = req.params;
    const { zcash_tx_hash, actual_zec_received } = req.body;
    
    if (!zcash_tx_hash) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'zcash_tx_hash is required',
      });
    }
    
    const position = await EarnService.markCompleted(
      positionId,
      String(zcash_tx_hash),
      actual_zec_received ? Number(actual_zec_received) : undefined,
    );
    
    if (!position) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Position not found',
      });
    }
    
    return res.status(200).json({
      success: true,
      position: EarnService.getPositionSummary(position),
      message: 'Position completed. Funds have been returned to your shielded Zcash address.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to complete position';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

// ============================================================================
// DEPOSIT WATCHER ENDPOINTS
// ============================================================================

/**
 * GET /api/zapp/earn/watcher/status
 * Get the status of the deposit watcher background job
 */
router.get('/watcher/status', async (_req: Request, res: Response) => {
  try {
    const { getJobsStatus } = await import('../jobs/index.js');
    const status = getJobsStatus();
    
    return res.status(200).json({
      success: true,
      watcher: status.depositWatcher,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get watcher status';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * POST /api/zapp/earn/watcher/check/:positionId
 * Manually trigger a deposit check for a specific position
 */
router.post('/watcher/check/:positionId', async (req: Request, res: Response) => {
  try {
    const { positionId } = req.params;
    const { bridgeDepositWatcher } = await import('../services/bridgeDepositWatcher.js');
    
    const result = await bridgeDepositWatcher.checkPosition(positionId);
    
    return res.status(200).json({
      success: true,
      result,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to check position';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

// ============================================================================
// WITHDRAWAL ENDPOINTS
// ============================================================================

/**
 * GET /api/zapp/earn/withdrawal/fee
 * Get withdrawal fee estimate
 */
router.get('/withdrawal/fee', async (req: Request, res: Response) => {
  try {
    const { amount } = req.query;
    
    if (!amount) {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'amount query parameter is required',
      });
    }
    
    const amountZec = Number(amount);
    const amountZatoshis = BigInt(Math.floor(amountZec * 100_000_000));
    
    const OmniBridgeService = (await import('../services/omniBridgeService.js')).default;
    const feeInfo = await OmniBridgeService.getWithdrawalFee(amountZatoshis);
    
    return res.status(200).json({
      success: true,
      fee: {
        amountZec,
        feeZec: Number(feeInfo.feeZatoshis) / 100_000_000,
        netAmountZec: Number(feeInfo.netAmountZatoshis) / 100_000_000,
        feePercent: feeInfo.feePercent,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to get fee estimate';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

/**
 * POST /api/zapp/earn/positions/:positionId/process-withdrawal
 * Process a pending withdrawal (sign and finalize)
 */
router.post('/positions/:positionId/process-withdrawal', async (req: Request, res: Response) => {
  try {
    const { positionId } = req.params;
    
    const position = await EarnService.processWithdrawal(positionId);
    
    if (!position) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Position not found',
      });
    }
    
    return res.status(200).json({
      success: true,
      position: EarnService.getPositionSummary(position),
      message: position.status === 'completed' 
        ? 'Withdrawal completed! Funds sent to your Zcash address.'
        : 'Withdrawal processing in progress.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to process withdrawal';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

export default router;
