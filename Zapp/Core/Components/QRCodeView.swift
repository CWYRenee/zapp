import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let value: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        Group {
            if let image = generateQRImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(ZapRadius.medium)
            } else {
                Color(.secondarySystemBackground)
                    .overlay(
                        Text("QR unavailable")
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                    )
                    .cornerRadius(ZapRadius.medium)
            }
        }
    }

    private func generateQRImage() -> UIImage? {
        guard let data = value.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))

        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
