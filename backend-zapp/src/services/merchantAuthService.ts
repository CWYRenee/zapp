import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { Facilitator, type MerchantDocument } from '../models/Facilitator.js';

interface AuthTokenPayload {
  sub: string;
  email: string;
}

export class MerchantAuthService {
  private static normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }

  private static generateOtp(): string {
    const code = Math.floor(100000 + Math.random() * 900000);
    return String(code);
  }

  static async requestOtp(email: string): Promise<void> {
    const normalizedEmail = this.normalizeEmail(email);

    let facilitator = await Facilitator.findOne({ email: normalizedEmail });
    if (!facilitator) {
      facilitator = new Facilitator({
        email: normalizedEmail,
        paymentRails: [],
      });
    }

    const otp = this.generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    facilitator.otpCode = otp;
    facilitator.otpExpiresAt = expiresAt;

    await facilitator.save();

    // In production, send OTP via email provider here.
    // For development, log it so it can be used in tests.
    console.log(`[zapp-backend] OTP for ${normalizedEmail}: ${otp}`);
  }

  static async verifyOtp(email: string, otp: string): Promise<{ facilitator: MerchantDocument; token: string }> {
    const normalizedEmail = this.normalizeEmail(email);

    const facilitator = await Facilitator.findOne({ email: normalizedEmail });
    if (!facilitator || !facilitator.otpCode || !facilitator.otpExpiresAt) {
      throw new Error('Invalid or expired OTP');
    }

    // Demo mode: accept '000000' as valid OTP for testing purposes
    const isDemoOtp = otp.trim() === '000000';
    const isValidOtp = facilitator.otpCode === otp.trim();
    
    if (!isDemoOtp && !isValidOtp) {
      throw new Error('Invalid OTP');
    }

    if (!isDemoOtp && facilitator.otpExpiresAt.getTime() < Date.now()) {
      throw new Error('OTP has expired');
    }

    // Clear OTP fields
    facilitator.otpCode = null;
    facilitator.otpExpiresAt = null;

    await facilitator.save();

    const payload: AuthTokenPayload = {
      sub: facilitator.id,
      email: facilitator.email,
    };

    const token = jwt.sign(payload, env.MERCHANT_JWT_SECRET, {
      algorithm: 'HS256',
      expiresIn: '7d',
    });

    return { facilitator, token };
  }
}
