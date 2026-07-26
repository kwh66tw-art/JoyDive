// SettingsView.swift — JD2-Logbook/Views/Settings/
// Week 11 — 設定頁：語言、Premium IAP、關於

import SwiftUI
import StoreKit
import SwiftData
import CoreLocation
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @State private var purchaseManager        = PurchaseManager.shared
    @State private var locationProvider       = UserLocationProvider()
    @AppStorage(UserLocationProvider.isEnabledKey) private var gpsLocationEnabled = false
    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric
    #if os(iOS)
    @State private var showPremiumSheet       = false
    @State private var showRestoreAlert       = false
    @State private var restoreAlertMessage    = ""
    #endif

    // v1.2：Export/Import Backup 功能尚未經過完整測試，這版先隱藏 UI、保留程式碼，
    // 下一版驗證過再開放。要重新開放：把這個常數改回 true 即可，不需要改動其他任何地方。
    private let showBackupSection = false

    // v1.1 #14：備份匯出/匯入
    @State private var showBackupExporter    = false
    @State private var backupExportDocument: BackupJSONDocument?
    @State private var showBackupImporter    = false
    @State private var showBackupResultAlert = false
    @State private var backupResultMessage   = ""

    private var backupExportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "JoyDive2-Backup-\(formatter.string(from: Date()))"
    }

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

                // ── 語言（App 內設定，即時生效，比照 JD2-ultra 四段式解法）──
                Section(
                    header: Text("Language"),
                    footer: Text("Language changes take effect right away. Some system-provided panels may still use the device language until you reopen the app.")
                ) {
                    Picker(selection: Binding(
                        get: { languageManager.appLanguage ?? "" },
                        set: { languageManager.appLanguage = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Follow System").tag("")
                        ForEach(AppLanguageManager.supportedLanguages, id: \.code) { lang in
                            Text(verbatim: lang.nativeName).tag(lang.code)
                        }
                    } label: {
                        Label("App Language", systemImage: "globe")
                    }
                }

                // ── 單位系統（v1.2 #4：用單位符號本身表示選項，不用文字）───
                Section(header: Text("Units")) {
                    Picker(selection: $unitSystem) {
                        Text(verbatim: "m / °C").tag(UnitSystem.metric)
                        Text(verbatim: "ft / °F").tag(UnitSystem.imperial)
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                    .pickerStyle(.segmented)
                }

                // ── GPS 定位（雙平台：地圖 recenter 按鈕的前置開關）──────
                Section(
                    header: Text("GPS Location"),
                    footer: Text("Location data stays on your device and is only requested while enabled.")
                ) {
                    Toggle(isOn: $gpsLocationEnabled) {
                        Label("Enable GPS Location", systemImage: "location.fill")
                    }
                    .onChange(of: gpsLocationEnabled) { _, isEnabled in
                        if isEnabled {
                            locationProvider.requestAuthorizationIfNeeded()
                        }
                    }

                    if gpsLocationEnabled,
                       locationProvider.authorizationStatus == .denied
                        || locationProvider.authorizationStatus == .restricted {
                        Button {
                            openSystemLocationSettings()
                        } label: {
                            HStack {
                                Label("Location Access Denied", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
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
                    }
                }

                // ── Premium（僅 iOS：macOS 從無廣告，移除項目對 macOS-only 用戶無意義）──
                #if os(iOS)
                Section(
                    header: Text("Premium"),
                    footer: Text(
                        purchaseManager.isPremium
                            ? languageManager.localized("Premium unlocked — Ads removed.")
                            : languageManager.localized("One-time purchase. No subscription.\nRemove all ads.")
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
                            String(format: languageManager.localized("Buy Premium for %@"),
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

                // ── 備份（v1.1 #14：Export/Import round-trip）───────
                // v1.2：尚未完整測試過，先隱藏，見 showBackupSection 說明。
                if showBackupSection {
                    Section(
                        header: Text("Backup"),
                        footer: Text("Export all dives to a JSON file, or restore from a previously exported file.")
                    ) {
                        Button {
                            exportBackup()
                        } label: {
                            Label("Export Backup", systemImage: "square.and.arrow.up")
                        }
                        #if os(macOS)
                        .buttonStyle(.borderless)
                        #endif

                        Button {
                            showBackupImporter = true
                        } label: {
                            Label("Import Backup", systemImage: "square.and.arrow.down")
                        }
                        #if os(macOS)
                        .buttonStyle(.borderless)
                        #endif
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
                        String(format: languageManager.localized("Version %@"), appVersion)
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
                }
                #endif

            }
            .navigationTitle(Text(verbatim: languageManager.localized("Settings")))
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
            // ── 備份 Export/Import（v1.1 #14）───────────────────
            .fileExporter(
                isPresented: $showBackupExporter,
                document: backupExportDocument,
                contentType: .json,
                defaultFilename: backupExportFilename
            ) { result in
                if case .failure(let error) = result {
                    backupResultMessage = error.localizedDescription
                    showBackupResultAlert = true
                }
            }
            .fileImporter(
                isPresented: $showBackupImporter,
                allowedContentTypes: [.json]
            ) { result in
                importBackup(from: result)
            }
            .alert("Backup", isPresented: $showBackupResultAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(backupResultMessage)
            }
    }

    // MARK: - Actions

    private func exportBackup() {
        do {
            let data = try DiveLogDatabase.shared.exportAsJSON()
            backupExportDocument = BackupJSONDocument(data: data)
            showBackupExporter = true
        } catch {
            backupResultMessage = error.localizedDescription
            showBackupResultAlert = true
        }
    }

    private func importBackup(from result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            backupResultMessage = error.localizedDescription
            showBackupResultAlert = true

        case .success(let url):
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw DiveLogImportError.fileNotFound(url.path)
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                let (imported, skipped) = try DiveLogDatabase.shared.importFromJSON(data)
                backupResultMessage = String(
                    format: languageManager.localized("Imported %d dives, skipped %d duplicates."),
                    imported, skipped
                )
            } catch {
                backupResultMessage = error.localizedDescription
            }
            showBackupResultAlert = true
        }
    }

    private func openSystemLocationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        // macOS：開啟系統設定的「定位服務」面板
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
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
                restoreAlertMessage = languageManager.localized("Premium restored successfully.")
            } else {
                restoreAlertMessage = languageManager.localized("No previous purchase found.")
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
    @Environment(AppLanguageManager.self) private var languageManager
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
        .navigationTitle(Text(verbatim: languageManager.localized("Open Source Licenses")))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Premium Upgrade Sheet

struct PremiumUpgradeSheet: View {
    @State private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageManager.self) private var languageManager
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
                        title: languageManager.localized("Remove All Ads"),
                        subtitle: languageManager.localized("Enjoy an uninterrupted dive log experience.")
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
                                Text(String(format: languageManager.localized("Unlock for %@"),
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

                    Button(languageManager.localized("Restore Purchase")) {
                        Task {
                            do {
                                try await AppStore.sync()
                                await purchaseManager.refreshPurchaseStatus()
                                if purchaseManager.isPremium {
                                    dismiss()
                                } else {
                                    restoreAlertMessage = languageManager.localized("No previous purchase found.")
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
                    Button(languageManager.localized("Close")) { dismiss() }
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

// MARK: - Backup JSON Document (v1.1 #14)

/// fileExporter 用的最小 FileDocument 包裝，資料已由 DiveLogDatabase.exportAsJSON() 產生
struct BackupJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
}
