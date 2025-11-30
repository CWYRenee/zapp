import { Router, type Request, type Response } from 'express';
import { MerchantAuthService } from '../services/merchantAuthService.js';

const router = Router();

// Request OTP for merchant login/signup
router.post('/auth/request-otp', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;

    if (!email || typeof email !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'email is required',
      });
    }

    await MerchantAuthService.requestOtp(email);

    return res.status(200).json({
      success: true,
      message: 'If the email is valid, an OTP has been sent',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to request OTP';
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message,
    });
  }
});

// Verify OTP and issue JWT for merchant
router.post('/auth/verify-otp', async (req: Request, res: Response) => {
  try {
    const { email, otp } = req.body;

    if (!email || typeof email !== 'string' || !otp || typeof otp !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Bad Request',
        message: 'email and otp are required',
      });
    }

    const { merchant, token } = await MerchantAuthService.verifyOtp(email, otp);

    return res.status(200).json({
      success: true,
      token,
      merchant,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to verify OTP';
    return res.status(400).json({
      success: false,
      error: 'Bad Request',
      message,
    });
  }
});

export default router;
