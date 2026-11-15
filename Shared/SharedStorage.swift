// SharedStorage.swift
// iGet — Shared Layer
//
// App Group tabanlı UserDefaults yöneticisi.
// iGet ana uygulaması ve iGetWidgets extension'ı arasında
// veri senkronizasyonunu sağlar.
//
// Target Membership: iGet + iGetWidgets
//
// Kullanım (her iki target'ta aynı):
//   let config = SharedStorage.shared.appSettings
//   SharedStorage.shared.save(settings: updatedSettings)
//
// Organization: TwoBit-Dev

import Foundation
import Combine
import WidgetKit

// MARK: - Storage Keys

private enum StorageKey {
    static let appSettings      = "iget.appSettings"
    static let overlayPositions = "iget.overlayPositions"
    static let quickNoteContent = "iget.quickNoteContent"
    static let lastUpdated      = "iget.lastUpdated"
}

// MARK: - SharedStorage

/// App Group UserDefaults üzerinden iGet ve iGetWidgets arasında
/// veri paylaşımını yöneten tekil (singleton) sınıf.
///
/// - Note: Her iki target'ın Entitlements dosyasında
///   `com.apple.security.application-groups = ["group.com.twobitdev.iGet"]`
///   tanımlı olmalıdır.
public final class SharedStorage: ObservableObject {

    // MARK: Singleton

    public static let shared = SharedStorage()

    // MARK: Constants

    public static let appGroupIdentifier = "group.com.twobitdev.iGet"

    // MARK: Private

    private let defaults: UserDefaults
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

    /// Dışarıdan init engellendi — `SharedStorage.shared` kullanın.
    private init() {
        guard let suite = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            // App Group Entitlement eksikse geliştirme sırasında standart defaults'a düşer.
            // Production'da bu duruma izin verilmez.
            assertionFailure("""
            [SharedStorage] App Group UserDefaults oluşturulamadı.
            Entitlements'ta 'group.com.twobitdev.iGet' tanımlı olduğundan emin olun.
            """)
            defaults = .standard
            return
        }
        defaults = suite
        registerDefaults()
    }

    // MARK: - Default Values Registration

    private func registerDefaults() {
        guard let encoded = try? encoder.encode(AppSettings.default) else { return }
        defaults.register(defaults: [StorageKey.appSettings: encoded])
    }

    // MARK: - App Settings

    /// Tüm uygulama ayarlarını okur.
    public var appSettings: AppSettings {
        guard
            let data = defaults.data(forKey: StorageKey.appSettings),
            let settings = try? decoder.decode(AppSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    /// Tüm uygulama ayarlarını App Group'a yazar.
    /// Kayıt sonrası WidgetKit timeline'larını otomatik yeniler.
    @discardableResult
    public func save(settings: AppSettings) -> Bool {
        guard let data = try? encoder.encode(settings) else {
            log("AppSettings encode hatası", level: .error)
            return false
        }
        defaults.set(data, forKey: StorageKey.appSettings)
        defaults.set(Date(), forKey: StorageKey.lastUpdated)
        defaults.synchronize()

        // WidgetKit timeline'larını yenile (sadece ana app target'ında etkili)
        reloadWidgetTimelines()

        log("AppSettings kaydedildi.")
        return true
    }

    // MARK: - Overlay Widget Positions

    /// Overlay widget konumlarını `[widgetID: WidgetPosition]` şeklinde okur.
    public var overlayPositions: [String: WidgetPosition] {
        guard
            let data = defaults.data(forKey: StorageKey.overlayPositions),
            let positions = try? decoder.decode([String: WidgetPosition].self, from: data)
        else {
            return [:]
        }
        return positions
    }

    /// Belirli bir overlay widget'ın konumunu günceller.
    public func updatePosition(_ position: WidgetPosition, for widgetID: UUID) {
        var positions = overlayPositions
        positions[widgetID.uuidString] = position
        guard let data = try? encoder.encode(positions) else { return }
        defaults.set(data, forKey: StorageKey.overlayPositions)
        defaults.synchronize()
        log("Pozisyon güncellendi: \(widgetID.uuidString) → (\(position.x), \(position.y))")
    }

    /// Belirli bir overlay widget'ın kaydedilmiş konumunu döner.
    public func position(for widgetID: UUID) -> WidgetPosition? {
        overlayPositions[widgetID.uuidString]
    }

    // MARK: - Quick Note Content

    /// Hızlı Not widget'ının metin içeriğini döner.
    public var quickNoteContent: String {
        defaults.string(forKey: StorageKey.quickNoteContent) ?? ""
    }

    /// Hızlı Not içeriğini günceller.
    public func saveQuickNote(_ content: String) {
        defaults.set(content, forKey: StorageKey.quickNoteContent)
        defaults.synchronize()
        log("QuickNote kaydedildi (\(content.count) karakter).")
    }

    // MARK: - Individual Widget Config Helpers

    /// Belirtilen türdeki overlay widget konfigürasyonunu döner.
    public func overlayConfig(for kind: WidgetKind) -> WidgetConfig? {
        appSettings.overlayWidgets.first { $0.kind == kind }
    }

    /// Belirtilen türdeki WidgetKit widget konfigürasyonunu döner.
    public func widgetKitConfig(for kind: WidgetKind) -> WidgetConfig? {
        appSettings.widgetKitConfigs.first { $0.kind == kind }
    }

    /// Overlay widget konfigürasyonunu günceller.
    public func updateOverlayWidget(_ config: WidgetConfig) {
        var settings = appSettings
        if let idx = settings.overlayWidgets.firstIndex(where: { $0.id == config.id }) {
            settings.overlayWidgets[idx] = config
        } else {
            settings.overlayWidgets.append(config)
        }
        save(settings: settings)
    }

    /// WidgetKit widget konfigürasyonunu günceller.
    public func updateWidgetKitConfig(_ config: WidgetConfig) {
        var settings = appSettings
        if let idx = settings.widgetKitConfigs.firstIndex(where: { $0.id == config.id }) {
            settings.widgetKitConfigs[idx] = config
        } else {
            settings.widgetKitConfigs.append(config)
        }
        save(settings: settings)
    }

    // MARK: - Theme

    /// Global temayı günceller.
    public func updateGlobalTheme(_ theme: WidgetTheme) {
        var settings = appSettings
        settings.globalTheme = theme
        save(settings: settings)
    }

    // MARK: - Metadata

    /// Verinin en son güncellenme zamanı.
    public var lastUpdated: Date? {
        defaults.object(forKey: StorageKey.lastUpdated) as? Date
    }

    // MARK: - Reset

    /// Tüm ayarları fabrika değerlerine sıfırlar.
    public func resetToDefaults() {
        save(settings: .default)
        defaults.removeObject(forKey: StorageKey.overlayPositions)
        defaults.removeObject(forKey: StorageKey.quickNoteContent)
        defaults.synchronize()
        log("Tüm ayarlar sıfırlandı.")
    }

    // MARK: - WidgetKit Timeline Reload

    /// WidgetKit widget timeline'larını yeniler.
    /// Bu çağrı yalnızca ana uygulama target'ında (iGet.app) etkilidir;
    /// extension içinden çağrılsa da hata vermez.
    private func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Combine Publisher

    /// App Group değişikliklerini dinleyen bir Combine publisher.
    /// SwiftUI @ObservedObject ile birlikte kullanılabilir.
    ///
    /// Örnek:
    /// ```swift
    /// SharedStorage.shared.settingsPublisher
    ///     .receive(on: DispatchQueue.main)
    ///     .sink { settings in … }
    ///     .store(in: &cancellables)
    /// ```
    public var settingsPublisher: AnyPublisher<AppSettings, Never> {
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .compactMap { [weak self] _ in self?.appSettings }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    // MARK: - Logging

    private enum LogLevel { case info, error }

    private func log(_ message: String, level: LogLevel = .info) {
        let prefix = level == .error ? "❌ [SharedStorage]" : "ℹ️ [SharedStorage]"
        print("\(prefix) \(message)")
    }
}

// MARK: - UserDefaults Convenience Extension

public extension UserDefaults {
    /// App Group shared defaults'a kısa erişim.
    static var iGetShared: UserDefaults {
        UserDefaults(suiteName: SharedStorage.appGroupIdentifier) ?? .standard
    }
}

// MARK: - Preview / Testing Support

#if DEBUG
public extension SharedStorage {
    /// Unit test ve SwiftUI Preview'lar için in-memory mock storage oluşturur.
    static func makeMock(settings: AppSettings = .default) -> SharedStorage {
        let storage = SharedStorage.shared
        storage.save(settings: settings)
        return storage
    }
}
#endif
