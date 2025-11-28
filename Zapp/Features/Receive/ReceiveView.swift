import SwiftUI
import UIKit

struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletViewModel: WalletViewModel

    @State private var didCopy: Bool = false
    @State private var selectedAddressType: AddressType = .unified

    private enum AddressType: String, CaseIterable, Identifiable {
        case unified
        case transparent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .unified: return "Unified"
            case .transparent: return "Transparent"
            }
        }
    }

    private var address: String {
        guard let info = walletViewModel.walletInfo else { return "No address yet" }

        switch selectedAddressType {
        case .unified:
            return info.unifiedAddress
        case .transparent:
            return info.transparentAddress.isEmpty ? "No address yet" : info.transparentAddress
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                        Picker("Address Type", selection: $selectedAddressType) {
                            ForEach(AddressType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Your address")
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)

                        QRCodeView(value: address)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .padding(.vertical, ZapSpacing.base)

                        Text(address)
                            .font(.footnote)
                            .foregroundColor(ZapColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(ZapRadius.medium)
                            .contextMenu {
                                Button("Copy") {
                                    copyToClipboard()
                                }
                            }

                        if didCopy {
                            Text("Copied to clipboard")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.base)
                    .padding(.bottom, ZapSpacing.lg)
                }

                ZapBottomBar(
                    primaryTitle: "Copy address",
                    isPrimaryLoading: false,
                    isPrimaryDisabled: false,
                    onBack: {
                        dismiss()
                    },
                    onPrimary: {
                        copyToClipboard()
                    }
                )
                .padding(.horizontal, ZapSpacing.xl)
                .padding(.bottom, ZapSpacing.base)
            }
            .background(ZapColors.background.ignoresSafeArea())
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = address
        didCopy = true
    }
}
