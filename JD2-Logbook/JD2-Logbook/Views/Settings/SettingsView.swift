// SettingsView.swift — JD2-Logbook/Views/Settings/
// Week 11 — 設定頁：語言、Premium IAP、關於

import SwiftUI
import StoreKit
import SwiftData

struct SettingsView: View {
    @State private var purchaseManager        = PurchaseManager.shared
    #if os(iOS)
    @State private var showPremiumSheet       = false
    @State private var showRestoreAlert       = false
    @State private var restoreAlertMessage    = ""
    #endif

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"]            as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        // macOS：NavigationStack 由 MainTabView 容器層提供（避免雙層 nav bar 產生頂部空白）
        #if os(iOS)
        NavigationStack { settingsForm }
        #else
        settingsForm
        #endif
    }

    private var settingsForm: some View {
        Form {

                // ── 語言 ───────────────────────────────────
                Section(header: Text("Language")) {
                    Button {
                        openAppLanguageSettings()
                    } label: {
                        HStack {
                            Label("App Language", systemImage: "globe")
                            Spacer()
                            #if os(iOS)
                            Text("iOS Settings")
                            #else
                            Text("System Settings")
                            #endif
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    }
                    .foregroundStyle(.primary)
                    #if os(iOS)
                    .accessibilityHint(
                        String(localized: "Opens iOS Settings to change the app display language")
                    )
                    #else
                    .accessibilityHint(
                        String(localized: "Opens System Settings to change the app display language")
                    )
                    #endif
                }

                // ── Premium（僅 iOS：macOS 從無廣告，移除項目對 macOS-only 用戶無意義）──
                #if os(iOS)
                Section(
                    header: Text("Premium"),
                    footer: Text(
                        purchaseManager.isPremium
                            ? String(localized: "Premium unlocked — Ads removed.")
                            : String(localized: "One-time purchase. No subscription.\nRemove all ads.")
                    )
                ) {
                    if purchaseManager.isPremium {
                        // ── 已購買：顯示狀態 ──────
                        HStack {
                            Label("Premium Unlocked", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Text("Active")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }

                    } else {
                        // ── 未購買：購買按鈕 + 回復購買 ──
                        Button {
                            showPremiumSheet = true
                        } label: {
                            HStack {
                                Label("Remove Ads",
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
                #endif

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

                #if DEBUG
                Section(header: Text("Developer Tools")) {
                    Button {
                        do {
                            try MockDataSeeder.seed(database: DiveLogDatabase.shared, count: 105)
                        } catch {
                            print("Seeding failed: \(error)")
                        }
                    } label: {
                        Label("Inject 100+ Mock Dives", systemImage: "square.stack.3d.up.fill")
                    }
                    #if os(macOS)
                    .buttonStyle(.borderless)
                    #endif

                    Button(role: .destructive) {
                        do {
                            try DiveLogDatabase.shared.deleteAllDives()
                        } catch {
                            print("Clear failed: \(error)")
                        }
                    } label: {
                        Label("Clear All Dives", systemImage: "trash")
                    }
                    #if os(macOS)
                    .buttonStyle(.borderless)
                    #endif

                    Toggle(isOn: Binding(
                        get: { purchaseManager.isPremium },
                        set: { purchaseManager.setDebugPremium($0) }
                    )) {
                        Label("Simulate Premium (No Ads)", systemImage: "star.fill")
                    }
                }
                #endif

            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #else
            .formStyle(.grouped)        // macOS 下使用 Grouped 樣式更緊密精緻
            .padding(.top, -16)         // 負 margin 抵消系統隱藏導航列所造成的過度空白
            #endif
            // ── Premium Upgrade Sheet（僅 iOS，見上方 Premium Section）─
            #if os(iOS)
            .sheet(isPresented: $showPremiumSheet) {
                PremiumUpgradeSheet()
            }
            .alert("Restore", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreAlertMessage)
            }
            #endif
    }

    // MARK: - Actions

    private func openAppLanguageSettings() {
        #if os(iOS)
        // iOS 16+：直接跳 App 語言設定頁（App-Specific Language Settings）
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        // macOS：開啟系統設定的語言偏好
        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    #if os(iOS)
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
    #endif
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
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.name), \(item.license)")
        }
        .navigationTitle("Open Source Licenses")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Premium Upgrade Sheet

struct PremiumUpgradeSheet: View {
    @State private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRestoreAlert    = false
    @State private var restoreAlertMessage = ""

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
                    Text("JoyDive² Premium")
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
                            do {
                                try await AppStore.sync()
                                await purchaseManager.refreshPurchaseStatus()
                                if purchaseManager.isPremium {
                                    dismiss()
                                } else {
                                    restoreAlertMessage = String(localized: "No previous purchase found.")
                                    showRestoreAlert = true
                                }
                            } catch {
                                restoreAlertMessage = error.localizedDescription
                                showRestoreAlert = true
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(Text(verbatim: "")) // verbatim 避免被抽成空字串 key
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .onChange(of: purchaseManager.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
            .alert("Restore", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreAlertMessage)
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
        .background(Color.platformSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview {
    SettingsView()
}
