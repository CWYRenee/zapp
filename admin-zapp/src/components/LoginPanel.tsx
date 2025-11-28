import { useState } from 'react';
import { useAuth } from '@/hooks/useAuth';

interface Props {
  defaultEmail?: string;
}

export function LoginPanel({ defaultEmail }: Props) {
  const { requestOtp, verifyOtp, loading, token, merchant, logout } = useAuth();
  const [email, setEmail] = useState(defaultEmail ?? '');
  const [otp, setOtp] = useState('');
  const [step, setStep] = useState<'email' | 'otp'>('email');
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (token && merchant) {
    return (
      <div className="flex items-center gap-4">
        <div className="text-sm text-gray-700">
          <div className="font-semibold">{merchant.displayName || merchant.email}</div>
          <div className="text-xs text-gray-500 truncate max-w-xs">{merchant.email}</div>
        </div>
        <button
          type="button"
          onClick={logout}
          className="px-3 py-1.5 text-sm rounded-md border border-gray-300 bg-white hover:bg-gray-50"
        >
          Logout
        </button>
      </div>
    );
  }

  const handleRequestOtp = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setMessage(null);
    if (!email) {
      setError('Email is required');
      return;
    }

    try {
      setSubmitting(true);
      await requestOtp(email);
      setStep('otp');
      setMessage('If the email is valid, an OTP has been sent. Check your inbox or server logs.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to request OTP');
    } finally {
      setSubmitting(false);
    }
  };

  const handleVerifyOtp = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setMessage(null);

    if (!email || !otp) {
      setError('Email and OTP are required');
      return;
    }

    try {
      setSubmitting(true);
      await verifyOtp(email, otp);
      setMessage('Logged in successfully');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to verify OTP');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="flex items-center gap-4">
      <form
        onSubmit={step === 'email' ? handleRequestOtp : handleVerifyOtp}
        className="flex items-center gap-2"
      >
        <input
          type="email"
          className="px-2 py-1.5 text-sm rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-primary"
          placeholder="merchant@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={submitting || loading || step === 'otp'}
        />
        {step === 'otp' && (
          <input
            type="text"
            className="px-2 py-1.5 text-sm rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-primary"
            placeholder="6-digit OTP"
            value={otp}
            onChange={(e) => setOtp(e.target.value)}
            disabled={submitting || loading}
          />
        )}
        <button
          type="submit"
          disabled={submitting || loading}
          className="px-3 py-1.5 text-sm rounded-md bg-[#FF9417] text-white hover:bg-[#E68515] disabled:opacity-50"
        >
          {step === 'email' ? 'Send OTP' : 'Verify OTP'}
        </button>
      </form>
      {(message || error) && (
        <div className="text-xs max-w-xs">
          {message && <div className="text-green-700">{message}</div>}
          {error && <div className="text-red-700">{error}</div>}
        </div>
      )}
    </div>
  );
}
