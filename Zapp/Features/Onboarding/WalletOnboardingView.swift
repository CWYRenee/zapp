import SwiftUI

struct WalletOnboardingView: View {
    @StateObject private var viewModel: WalletOnboardingViewModel
    private let onCompleted: () -> Void

    init(
        viewModel: WalletOnboardingViewModel = WalletOnboardingViewModel(),
        onCompleted: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompleted = onCompleted
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: 40, maxHeight: 80)
            
            // Header section
            VStack(alignment: .center, spacing: ZapSpacing.sm) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 56))
                    .foregroundColor(ZapColors.primary)
                    .padding(.bottom, ZapSpacing.sm)
                
                Text("Set up your wallet")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, ZapSpacing.xl)
            
            Spacer()
                .frame(minHeight: 32, maxHeight: 60)
            
            // Options section
            VStack(spacing: ZapSpacing.lg) {
                // Create new wallet card
                VStack(alignment: .leading, spacing: ZapSpacing.md) {
                    HStack(spacing: ZapSpacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(ZapColors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create new wallet")
                                .font(.headline)
                                .foregroundColor(ZapColors.textPrimary)
                            Text("Generate a new testnet wallet")
                                .font(.subheadline)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                        
                        Spacer()
                    }

                    ZapButton("Create new wallet") {
                        viewModel.createNewWallet()
                    }
                }
                .padding(ZapSpacing.lg)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(ZapRadius.large)
                
                // Divider with "or"
                HStack {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)
                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)
                        .padding(.horizontal, ZapSpacing.sm)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)
                }
                .padding(.vertical, ZapSpacing.xs)

                // Import wallet card
                VStack(alignment: .leading, spacing: ZapSpacing.md) {
                    HStack(spacing: ZapSpacing.md) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(ZapColors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import existing wallet")
                                .font(.headline)
                                .foregroundColor(ZapColors.textPrimary)
                            Text("Use your recovery phrase")
                                .font(.subheadline)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                        
                        Spacer()
                    }

                    TextField("Recovery phrase or hex seed", text: $viewModel.importText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(ZapRadius.medium)

                    ZapButton("Import wallet", style: .secondary) {
                        viewModel.importWallet()
                    }
                }
                .padding(ZapSpacing.lg)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(ZapRadius.large)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, ZapSpacing.xs)
                }
            }
            .padding(.horizontal, ZapSpacing.xl)
            
            Spacer()
                .frame(minHeight: 40)
        }
        .background(ZapColors.background.ignoresSafeArea())
        .onChange(of: viewModel.didComplete) { _, didComplete in
            if didComplete {
                onCompleted()
            }
        }
    }
}
