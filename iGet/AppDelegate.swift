// AppDelegate.swift
// iGet — Ana Uygulama
//
// NSApplicationDelegate: uygulama yaşam döngüsünü yönetir.
//   • Başlatma: OverlayWindowManager.start()
//   • Sonlandırma: overlay pencereleri temizleme
//   • Uyku/Uyanış: güç yönetimi kancaları
//   • Bildirim izinleri
//
// Target Membership: iGet
//
// Organization: TwoBit-Dev

import AppKit
import SwiftUI
import WidgetKit
import UserNotifications
import ServiceManagement   // Login item (launchAtLogin)

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var overlayManager: OverlayWindowManager { .shared }
    private var sleepObserver:  NSObjectProtocol?
    private var wakeObserver:   NSObjectProtocol?
    private var showObserver:   NSObjectProtocol?
    private var hideObserver:   NSObjectProtocol?

    // MARK: - applicationDidFinishLaunching

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("Uygulama başlatıldı.")

        // Dock ikonunu gizle (LSUIElement = YES ile birlikte çalışır)
        NSApp.setActivationPolicy(.accessory)

        // Overlay widget pencerelerini aç
        overlayManager.start()

        // Login item senkronizasyonu
        syncLaunchAtLogin()

        // Bildirim izni iste (Calendar / System Monitor uyarıları için)
        requestNotificationPermission()

        // Sistem uyku/uyanış olaylarını dinle
        observeSleepWake()

        // Show/Hide bildirimlerini dinle
        observeWidgetNotifications()

        log("Başlatma tamamlandı.")
    }

    // MARK: - applicationWillTerminate

    func applicationWillTerminate(_ notification: Notification) {
        log("Uygulama sonlandırılıyor.")
        overlayManager.stop()
    }

    // MARK: - applicationShouldTerminateAfterLastWindowClosed

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Tüm pencereler kapansa bile uygulama çalışmaya devam eder (MenuBar uygulaması)
        return false
    }

    // MARK: - applicationShouldHandleReopen

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Dock'tan veya Finder'dan tekrar açılınca ayarlar penceresini göster
        if !flag {
            openSettings()
        }
        return false
    }

    // MARK: - Launch at Login

    private func syncLaunchAtLogin() {
        let enabled = SharedStorage.shared.appSettings.launchAtLogin
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log("LaunchAtLogin senkronizasyon hatası: \(error.localizedDescription)", level: .warning)
        }
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error {
                self.log("Bildirim izni hatası: \(error.localizedDescription)", level: .warning)
            } else {
                self.log("Bildirim izni: \(granted ? "verildi" : "reddedildi")")
            }
        }
    }

    // MARK: - Sleep / Wake Observers

    private func observeSleepWake() {
        let workspace = NSWorkspace.shared.notificationCenter

        sleepObserver = workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.log("Sistem uyku moduna geçiyor — overlay'ler duraklatıldı.")
            // OverlayEngine'deki SystemMonitor kendi sleep notif'ini zaten dinliyor.
            // Burada ek kaynak serbest bırakma yapılabilir.
        }

        wakeObserver = workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.log("Sistem uyandı — overlay'ler yenileniyor.")
            // Ekran boyut değişikliği sonrası pencereleri yenile
            Task { @MainActor in
                self?.overlayManager.refreshPositions()
            }
        }
    }

    // MARK: - Widget Notification Observers

    private func observeWidgetNotifications() {
        showObserver = NotificationCenter.default.addObserver(
            forName: .iGetShowAllWidgets, object: nil, queue: .main
        ) { [weak self] _ in
            let settings = SharedStorage.shared.appSettings
            settings.overlayWidgets.filter { $0.isEnabled }.forEach {
                self?.overlayManager.open(config: $0)
            }
        }

        hideObserver = NotificationCenter.default.addObserver(
            forName: .iGetHideAllWidgets, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Array(self.overlayManager.activeWindows.keys).forEach {
                self.overlayManager.close(widgetID: $0)
            }
        }
    }

    // MARK: - Open Settings

    func openSettings() {
        // SwiftUI Window(id:) sahnesini tetikler
        if let url = URL(string: "iget://settings") {
            NSWorkspace.shared.open(url)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Logging

    private enum LogLevel { case info, warning, error }

    private func log(_ msg: String, level: LogLevel = .info) {
        let prefix: String
        switch level {
        case .info:    prefix = "ℹ️  [AppDelegate]"
        case .warning: prefix = "⚠️  [AppDelegate]"
        case .error:   prefix = "❌  [AppDelegate]"
        }
        print("\(prefix) \(msg)")
    }
}
