// SettingsView.swift — JD2-Logbook/Views/Settings/
// Week 11 — 設定頁：語言、Premium IAP、關於

import SwiftUI
import StoreKit

struct SettingsView: View {
    @State private var purchaseManager = PurchaseManager.shared
    @State private var showPremiumSheet     = false
    @State private var showRestoreAlert     = false
    @State private var restoreAlertMessage  = ""

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"]            as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {

                // ── 語言 ───────────────────────────────────
                Section(header: Text("Language")) {
                    Button {
                        openAppLanguageSettings()
                    } label: {
                        HStack {
                            Label("App Language", systemImage: "globe")
                            Spacer()
                            Text("iOS Settings")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityHint(
                        String(localized: "Opens iOS Settings to change the app display language")
                    )
                }

                // ── Premium ────────────────────────────────
                Section(
                    header: Text("Premium"),
                    footer: Text(
                        purchaseManager.isPremium
                            ? String(localized: "Premium unlocked — Ads removed, Export enabled.")
                            : String(localized: "One-time purchase. No subscription.")
                    )
                ) {
                    if purchaseManager.isPremium {
                        // 已購買狀態
                        HStack {
                            Label("Premium Unlocked", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Text("Active")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    } else {
                        // 購買按鈕
                        Button {
                            showPremiumSheet = true
                        } label: {
                            HStack {
                                Label("Remove Ads + Enable Export",
                                      systemImage: "star.fill")
                                Spacer()
                                Text(purchaseManager.premiumPriceString)
                                    .foregroundStyle(.tint)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .foregroundStyle(.primary)
                        .accessibilityLabel(
                            String(format: String(localized: "Buy Premium for %@"),
                                   purchaseManager.premiumPriceString)
                        )

                        // 回復購買
                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            HStack {
                                Label("Restore Purchase", systemImage: "arrow.clockwise")
                                if purchaseManager.isLoading {
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .disabled(purchaseManager.isLoading)
                    }
                }

                // ── 關於 ───────────────────────────────────
                Section(header: Text("About")) {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                            .font(.subheadline.monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Version %@"), appVersion)
                    )

                    NavigationLink {
                        LicensesView()
                    } label: {
                        Label("Open Source Licenses", systemImage: "doc.text")
                    }
                }

            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPremiumSheet) {
                PremiumUpgradeSheet()
            }
            .alert("Restore", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreAlertMessage)
            }
        }
    }

    // MARK: - Actions

    private func openAppLanguageSettings() {
        // iOS 18+：直接跳 App 語言設定頁（App-Specific Language Settings）
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func restorePurchases() async {
        do {
            try await AppStore.sync()
            await purchaseManager.refreshPurchaseStatus()
            if purchaseManager.isPremium {
                restoreAlertMessage = String(localized: "Premium restored successfully.")
            } else {
                restoreAlertMessage = String(localized: "No previous purchase found.")
            }
        } catch {
            restoreAlertMessage = error.localizedDescription
        }
        showRestoreAlert = true
    }
}

// MARK: - Licenses View

private struct LicensesView: View {
    private let licenses: [(name: String, license: String, url: String)] = [
        (
            "FitFileParser",
            "MIT License",
            "https://github.com/roznet/FitFileParser"
        )
    ]

    var body: some View {
        List(licenses, id: \.name) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text(item.license)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.url)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.name), \(item.license)")
        }
        .navigationTitle("Open Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Premium Upgrade Sheet

struct PremiumUpgradeSheet: View {
    @State private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 16)

                // Icon
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.yellow, .orange)

                // 標題
                VStack(spacing: 8) {
                    Text("JD2 Logbook Premium")
                        .font(.title2.bold())
                    Text("One-time purchase — no subscription.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 功能列表
                VStack(spacing: 12) {
                    PremiumFeatureRow(
                        icon: "nosign",
                        color: .red,
                        title: String(localized: "Remove All Ads"),
                        subtitle: String(localized: "Enjoy an uninterrupted dive log experience.")
                    )
                    PremiumFeatureRow(
                        icon: "square.and.arrow.up",
                        color: .blue,
                        title: String(localized: "Export Dive Logs"),
                        subtitle: String(localized: "Export your dives as UDDF or CSV anytime.")
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // 購買按鈕
                VStack(spacing: 12) {
                    Button {
                        Task { await purchaseManager.purchase() }
                    } label: {
                        Group {
                            if purchaseManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(String(format: String(localized: "Unlock for %@"),
                                           purchaseManager.premiumPriceString))
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(purchaseManager.isLoading)
                    .padding(.horizontal, 24)

                    Button(String(localized: "Restore Purchase")) {
                        Task {
                            try? await AppStore.sync()
                            await purchaseManager.refreshPurchaseStatus()
                            if purchaseManager.isPremium { dismiss() }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .onChange(of: purchaseManager.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
        }
    }
}

private struct PremiumFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview {
    SettingsView()
}
