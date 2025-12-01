import { Facilitator } from '../models/Facilitator.js';

const DEMO_FACILITATOR = {
  email: 'demo@zapp.finance',
  displayName: 'Demo Facilitator',
  zecAddress: 'ztestsapling1demo...', // Testnet address placeholder
  paymentRails: [
    { type: 'upi' as const, enabled: true, label: 'Demo UPI', upiId: 'demo@upi' },
    { type: 'alipay' as const, enabled: true, label: 'Demo Alipay', alipayId: 'demo_alipay' },
    { type: 'pix' as const, enabled: true, label: 'Demo PIX', paxId: 'demo_pix_key' },
  ],
};

/**
 * Ensures a demo facilitator exists in the database for demo mode.
 * This runs on server startup.
 */
export async function seedDemoFacilitator(): Promise<void> {
  try {
    const existing = await Facilitator.findOne({ email: DEMO_FACILITATOR.email });
    
    if (!existing) {
      const demo = new Facilitator(DEMO_FACILITATOR);
      await demo.save();
      console.log('[zapp-backend] Created demo facilitator:', DEMO_FACILITATOR.email);
    } else {
      console.log('[zapp-backend] Demo facilitator already exists:', existing.email);
    }
  } catch (error) {
    console.error('[zapp-backend] Failed to seed demo facilitator:', error);
    // Don't throw - seeding failure shouldn't prevent server from starting
  }
}
