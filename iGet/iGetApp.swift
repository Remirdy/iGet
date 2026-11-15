// iGetApp.swift
// iGet — Ana Uygulama
//
// SwiftUI @main giriş noktası.
// NSApplicationDelegateAdaptor ile AppDelegate'i köprüler.
// Uygulama Dock'ta görünmez (LSUIElement = YES → Info.plist).
//
// Bundle ID : com.twobitdev.iGet
// Platform  : macOS 14.0+
//
// Organization: TwoBit-Dev

import SwiftUI
import WidgetKit
import Combine

@main
struct iGetApp: App {

    // MARK: - AppDelegate Köprüsü

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Shared State

    /// Tüm uygulama genelinde paylaşılan ayarlar gözlemcisi.
    @StateObject private var settings = AppSettingsStore()

    // MARK: - Scene Definition

    var body: some Scene {

        // ── Ana Galeri & Yönetim Penceresi ───────────────────────────────
        WindowGroup("iGet", id: SceneID.main) {
            MainShellView()
                .environmentObject(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 860, height: 580)
        .commands {
            AppCommands()
        }

        // ── Settings Window ──────────────────────────────────────────────
        // Cmd+, veya MenuBar'dan açılır.
        Window("iGet Ayarları", id: SceneID.settings) {
            SettingsView()
                .environmentObject(settings)
                .frame(minWidth: 620, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 720, height: 540)

        // ── Menu Bar Extra ───────────────────────────────────────────────
        MenuBarExtra("iGet", systemImage: "square.grid.2x2.fill") {
            MenuBarView()
                .environmentObject(settings)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Scene Identifiers

enum SceneID {
    static let main     = "iget.main"
    static let settings = "iget.settings"
}

// MARK: - AppSettingsStore (Global ObservableObject)

/// SharedStorage'ı SwiftUI ortamına taşıyan köprü ViewModel.
/// Tüm ekranlar bu nesneyi `@EnvironmentObject` ile okur.
@MainActor
final class AppSettingsStore: ObservableObject {

    @Published var settings: AppSettings = SharedStorage.shared.appSettings

    private var cancellable: AnyCancellable?

    init() {
        // SharedStorage değişikliklerini dinle → UI güncelle
        cancellable = SharedStorage.shared.settingsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.settings, on: self)
    }

    func save() {
        SharedStorage.shared.save(settings: settings)
    }

    func reload() {
        settings = SharedStorage.shared.appSettings
    }
}

// MARK: - App Commands (Menü Çubuğu Komutları)

struct AppCommands: Commands {
    var body: some Commands {
        // Varsayılan "Yeni" komutunu gizle
        CommandGroup(replacing: .newItem) { }

        // Görünüm menüsüne ek komutlar
        CommandMenu("Widget'lar") {
            Button("Tümünü Göster") {
                NotificationCenter.default.post(name: .iGetShowAllWidgets, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Tümünü Gizle") {
                NotificationCenter.default.post(name: .iGetHideAllWidgets, object: nil)
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Divider()

            Button("Ayarları Aç") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let iGetShowAllWidgets = Notification.Name("com.twobitdev.iGet.showAllWidgets")
    static let iGetHideAllWidgets = Notification.Name("com.twobitdev.iGet.hideAllWidgets")
    static let iGetRefreshWidgets = Notification.Name("com.twobitdev.iGet.refreshWidgets")
}
