import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { Merchant, type MerchantDocument } from '../models/Merchant';

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

    let merchant = await Merchant.findOne({ email: normalizedEmail });
    if (!merchant) {
      merchant = new Merchant({
        email: normalizedEmail,
        paymentRails: [],
      });
    }

    const otp = this.generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    merchant.otpCode = otp;
    merchant.otpExpiresAt = expiresAt;

    await merchant.save();

    // In production, send OTP via email provider here.
    // For development, log it so it can be used in tests.
    console.log(`[zapp-backend] OTP for ${normalizedEmail}: ${otp}`);
  }

  static async verifyOtp(email: string, otp: string): Promise<{ merchant: MerchantDocument; token: string }> {
    const normalizedEmail = this.normalizeEmail(email);

    const merchant = await Merchant.findOne({ email: normalizedEmail });
    if (!merchant || !merchant.otpCode || !merchant.otpExpiresAt) {
      throw new Error('Invalid or expired OTP');
    }

    if (merchant.otpCode !== otp.trim()) {
      throw new Error('Invalid OTP');
    }

    if (merchant.otpExpiresAt.getTime() < Date.now()) {
      throw new Error('OTP has expired');
    }

    // Clear OTP fields
    merchant.otpCode = null;
    merchant.otpExpiresAt = null;

    await merchant.save();

    const payload: AuthTokenPayload = {
      sub: merchant.id,
      email: merchant.email,
    };

    const token = jwt.sign(payload, env.MERCHANT_JWT_SECRET, {
      algorithm: 'HS256',
      expiresIn: '7d',
    });

    return { merchant, token };
  }
}
