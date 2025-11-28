import SwiftUI
import UIKit
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @AppStorage("handPreference") private var handPreference: String = "right"

    private var isRightHanded: Bool { handPreference != "left" }

    private enum ActiveSheet: Identifiable {
        case send
        case receive
        case wordSearch

        var id: Int {
            switch self {
            case .send: return 0
            case .receive: return 1
            case .wordSearch: return 2
            }
        }
    }

    @State private var recoveryText: String = ""
    @State private var didCopy: Bool = false
    @State private var showingResetAlert: Bool = false
    @State private var activeSheet: ActiveSheet?
    @State private var isRecoveryPhraseRevealed: Bool = false
    @State private var biometricAuthError: String?
    @State private var isBiometricEnabled: Bool = BiometricSettingsStore.shared.isBiometricEnabled
    
    // Biometric authentication
    private let biometricService = BiometricAuthService.shared
    private let biometricSettings = BiometricSettingsStore.shared

    let onResetWallet: () -> Void

    private let seedStore: WalletSeedStoring

    init(onResetWallet: @escaping () -> Void, seedStore: WalletSeedStoring = WalletSeedStore()) {
        self.onResetWallet = onResetWallet
        self.seedStore = seedStore
        _recoveryText = State(initialValue: Self.loadRecoveryText(from: seedStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                Text("Settings")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)

                VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                    Text("Recovery phrase")
                        .font(.headline)
                    Text("This is the recovery phrase (or legacy seed) for this testnet wallet on this device. Do not share it.")
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)

                    if recoveryText.isEmpty {
                        Text("No recovery data found.")
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                    } else {
                        Text(recoveryText)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(ZapColors.textPrimary)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(ZapRadius.medium)
                            .blur(radius: isRecoveryPhraseRevealed ? 0 : 8)
                            .overlay(
                                Group {
                                    if !isRecoveryPhraseRevealed {
                                        VStack(spacing: ZapSpacing.sm) {
                                            Image(systemName: "eye.slash.fill")
                                                .font(.title2)
                                                .foregroundColor(ZapColors.textSecondary)
                                            Text("Tap to reveal")
                                                .font(.caption)
                                                .foregroundColor(ZapColors.textSecondary)
                                        }
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleRevealTap()
                            }
                            .contextMenu {
                                Button("Copy") {
                                    copyRecovery()
                                }
                            }

                        ZapButton("Copy") {
                            copyRecovery()
                        }

                        if didCopy {
                            Text("Copied to clipboard")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                    }
                }

                Divider()
                
                // Biometric Authentication Section
                if biometricService.isBiometricAvailable() {
                    VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                        Text("Security")
                            .font(.headline)
                        
                        Toggle(isOn: $isBiometricEnabled) {
                            HStack(spacing: ZapSpacing.sm) {
                                Image(systemName: biometricService.biometricType().iconName)
                                    .foregroundColor(ZapColors.primary)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Require \(biometricService.biometricType().displayName)")
                                        .font(.body)
                                        .foregroundColor(ZapColors.textPrimary)
                                    Text("For transactions and viewing recovery phrase")
                                        .font(.caption)
                                        .foregroundColor(ZapColors.textSecondary)
                                }
                            }
                        }
                        .tint(ZapColors.primary)
                        .onChange(of: isBiometricEnabled) { _, newValue in
                            handleBiometricToggle(newValue)
                        }
                        
                        if let error = biometricAuthError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Divider()
                }

                VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                    Text("Hand preference")
                        .font(.headline)
                    Picker("Hand preference", selection: $handPreference) {
                        Text("Left-handed").tag("left")
                        Text("Right-handed").tag("right")
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                    Text("Fun & Games")
                        .font(.headline)
                    Text("Take a break and learn crypto terms!")
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)

                    ZapButton("Play Word Search", style: .primary) {
                        activeSheet = .wordSearch
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                    Text("Danger zone")
                        .font(.headline)
                    Text("Resetting will wipe this wallet from this device and return you to onboarding. Make sure you have backed up your recovery phrase.")
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)

                    ZapButton("Reset wallet", style: .secondary) {
                        showingResetAlert = true
                    }
                    .tint(.red)
                    .foregroundColor(.red)
                    .alert("Reset wallet?", isPresented: $showingResetAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            Task {
                                await walletViewModel.resetWallet()
                                onResetWallet()
                            }
                        }
                    } message: {
                        Text("This will wipe the local wallet data from this device. You can restore it later using your recovery phrase.")
                    }
                }

                Spacer(minLength: ZapSpacing.xl)
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.top, ZapSpacing.xl)
            .background(ZapColors.background.ignoresSafeArea())
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .send:
                SendView()
            case .receive:
                ReceiveView()
            case .wordSearch:
                WordSearchGameView(displayMode: .standalone, onDismiss: {
                    activeSheet = nil
                })
                .environmentObject(walletViewModel)
            }
        }
    }

    private func copyRecovery() {
        guard !recoveryText.isEmpty else { return }
        UIPasteboard.general.string = recoveryText
        didCopy = true
    }
    
    // MARK: - Biometric Handling
    
    private func handleRevealTap() {
        if isRecoveryPhraseRevealed {
            // Already revealed, just hide it
            withAnimation(.easeInOut(duration: 0.2)) {
                isRecoveryPhraseRevealed = false
            }
            return
        }
        
        // Check if biometric authentication is required to reveal
        if biometricSettings.shouldRequireBiometric() {
            Task {
                do {
                    let authenticated = try await biometricService.authenticateForSensitiveData()
                    if authenticated {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRecoveryPhraseRevealed = true
                        }
                    }
                } catch let error as BiometricAuthService.BiometricError {
                    switch error {
                    case .userCancelled:
                        // User cancelled, don't show error
                        break
                    default:
                        biometricAuthError = error.errorDescription
                    }
                } catch {
                    biometricAuthError = "Authentication failed."
                }
            }
        } else {
            // No biometric required, just reveal
            withAnimation(.easeInOut(duration: 0.2)) {
                isRecoveryPhraseRevealed = true
            }
        }
    }
    
    private func handleBiometricToggle(_ enabled: Bool) {
        biometricAuthError = nil
        
        if enabled {
            // Require authentication to enable biometrics
            Task {
                do {
                    let authenticated = try await biometricService.authenticate(
                        reason: "Authenticate to enable \(biometricService.biometricType().displayName)"
                    )
                    if authenticated {
                        biometricSettings.isBiometricEnabled = true
                    } else {
                        // Failed, revert toggle
                        isBiometricEnabled = false
                    }
                } catch let error as BiometricAuthService.BiometricError {
                    // Failed, revert toggle
                    isBiometricEnabled = false
                    switch error {
                    case .userCancelled:
                        break
                    default:
                        biometricAuthError = error.errorDescription
                    }
                } catch {
                    isBiometricEnabled = false
                    biometricAuthError = "Failed to enable biometric authentication."
                }
            }
        } else {
            // Disable without authentication
            biometricSettings.isBiometricEnabled = false
        }
    }

    private static func loadRecoveryText(from store: WalletSeedStoring) -> String {
        if let mnemonic = store.loadMnemonic(), !mnemonic.isEmpty {
            return mnemonic
        }

        guard let seed = store.loadSeed(), !seed.isEmpty else { return "" }
        return seed.map { String(format: "%02x", $0) }.joined()
    }
}
