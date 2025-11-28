import { useState } from 'react';
import { Copy, Check, QrCode, X } from 'lucide-react';

interface QRCodeDisplayProps {
  data: string;
  size?: number;
  label?: string;
}

/**
 * Displays a QR code for the given data using Google Charts API.
 * Shows a modal with a larger QR code when clicked.
 */
export function QRCodeDisplay({ data, size = 120, label = 'Payment QR Code' }: QRCodeDisplayProps) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [copied, setCopied] = useState(false);

  // Use Google Charts API for QR code generation (no additional dependencies needed)
  const qrCodeUrl = `https://chart.googleapis.com/chart?cht=qr&chs=${size}x${size}&chl=${encodeURIComponent(data)}&choe=UTF-8`;
  const largeQrCodeUrl = `https://chart.googleapis.com/chart?cht=qr&chs=300x300&chl=${encodeURIComponent(data)}&choe=UTF-8`;

  const handleCopy = async () => {
    if (typeof navigator === 'undefined' || !navigator.clipboard) return;
    try {
      await navigator.clipboard.writeText(data);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (error) {
      console.error('Failed to copy to clipboard', error);
    }
  };

  return (
    <>
      <div className="flex flex-col items-center gap-2">
        <button
          type="button"
          onClick={() => setIsModalOpen(true)}
          className="group relative rounded-lg border-2 border-dashed border-gray-300 bg-white p-2 hover:border-[#FF9417] hover:bg-orange-50 transition-colors"
          title="Click to enlarge"
        >
          <img
            src={qrCodeUrl}
            alt={label}
            width={size}
            height={size}
            className="rounded"
          />
          <div className="absolute inset-0 flex items-center justify-center bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity rounded-lg">
            <QrCode className="h-6 w-6 text-white" />
          </div>
        </button>
        <span className="text-[10px] text-gray-500 text-center">{label}</span>
      </div>

      {/* Modal for larger QR code */}
      {isModalOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
          onClick={() => setIsModalOpen(false)}
        >
          <div
            className="relative bg-white rounded-xl shadow-2xl p-6 max-w-sm w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              type="button"
              onClick={() => setIsModalOpen(false)}
              className="absolute top-3 right-3 p-1 rounded-full hover:bg-gray-100 text-gray-500 hover:text-gray-700"
            >
              <X className="h-5 w-5" />
            </button>

            <div className="flex flex-col items-center gap-4">
              <h3 className="text-lg font-semibold text-gray-900">{label}</h3>
              
              <div className="rounded-lg border-2 border-gray-200 bg-white p-3">
                <img
                  src={largeQrCodeUrl}
                  alt={label}
                  width={300}
                  height={300}
                  className="rounded"
                />
              </div>

              <div className="w-full">
                <div className="text-xs text-gray-500 mb-1">QR Code Data:</div>
                <div className="flex items-start gap-2">
                  <div className="flex-1 bg-gray-50 rounded-md p-2 text-xs font-mono text-gray-700 break-all max-h-24 overflow-y-auto">
                    {data}
                  </div>
                  <button
                    type="button"
                    onClick={handleCopy}
                    className="flex-shrink-0 inline-flex items-center gap-1 rounded-md border border-gray-200 bg-white px-2 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50"
                  >
                    {copied ? (
                      <>
                        <Check className="h-3.5 w-3.5 text-green-600" />
                        <span className="text-green-600">Copied</span>
                      </>
                    ) : (
                      <>
                        <Copy className="h-3.5 w-3.5" />
                        <span>Copy</span>
                      </>
                    )}
                  </button>
                </div>
              </div>

              <p className="text-xs text-gray-500 text-center">
                Scan this QR code with your payment app to complete the fiat transfer.
              </p>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
