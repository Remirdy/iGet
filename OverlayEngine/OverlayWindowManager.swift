// OverlayWindowManager.swift
// iGet — OverlayEngine
//
// Masaüstü overlay pencere sistemi.
// Her widget için şeffaf, çerçevesiz, sürüklenebilir bir NSWindow açar;
// pencere seviyesi `.desktopIconWindow + 1` olarak ayarlanır —
// masaüstü ikonlarının hemen üzerinde, dock ve normal uygulama pencerelerinin altında.
//
// Target Membership: iGet
//
// Organization: TwoBit-Dev

import AppKit
import SwiftUI
import Combine

// MARK: - OverlayWidgetWindow

/// Tek bir overlay widget'ı barındıran özelleştirilmiş NSWindow.
public final class OverlayWidgetWindow: NSWindow {

    // MARK: Properties

    public let widgetConfig: WidgetConfig
    private(set) public var dragHandler: DragHandler?

    // MARK: Init

    public init(config: WidgetConfig) {
        self.widgetConfig = config

        // Kaydedilmiş konum (yoksa config.position kullan)
        let saved    = SharedStorage.shared.position(for: config.id)
        let origin   = saved?.cgPoint ?? config.position.cgPoint
        let size     = config.size.size
        let frame    = CGRect(origin: origin, size: size)

        super.init(
            contentRect: frame,
            styleMask:   [.borderless, .fullSizeContentView],
            backing:     .buffered,
            defer:       false
        )

        configure()

        // Sürükleme yöneticisini bağla
        dragHandler = DragHandler(window: self, widgetID: config.id)
    }

    // MARK: - NSWindow Configuration

    private func configure() {
        // ── Şeffaflık & Görünüm ─────────────────────────────────────────
        isOpaque          = false
        backgroundColor   = .clear
        hasShadow         = widgetConfig.theme.showShadow

        // ── Pencere Seviyesi ─────────────────────────────────────────────
        // desktopIconWindow: masaüstü ikonlarının seviyesi (Finder desktop icons)
        // + 1: ikonların hemen üzerinde, dock'un (kgDockWindowLevel) altında
        level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
        )

        // ── Koleksiyon Davranışı ─────────────────────────────────────────
        collectionBehavior = [
            .canJoinAllSpaces,          // Tüm Spaces'lerde görünür
            .stationary,                // Mission Control'de sabit kalır
            .ignoresCycle               // Cmd+` döngüsüne katılmaz
        ]

        // ── Etkileşim ────────────────────────────────────────────────────
        isMovableByWindowBackground = false   // DragHandler yönetiyor
        ignoresMouseEvents          = false   // QuickNote için tıklama gerekli
        acceptsMouseMovedEvents     = true

        // ── Görev Çubuğu & App Switcher ──────────────────────────────────
        isExcludedFromWindowsMenu = true      // Pencere listesine ekleme
    }

    // MARK: - NSWindow Overrides

    public override var canBecomeKey: Bool   { true  }
    public override var canBecomeMain: Bool  { false }

    // MARK: - Convenience

    /// Widget içeriğini verilen SwiftUI view ile günceller.
    public func setContent<V: View>(_ view: V) {
        contentView = NSHostingView(rootView: view)
    }

    /// Sürükleme event'lerini root NSView'e bağlar.
    public func attachDraggable() {
        guard let dragHandler else { return }
        // ContentView'ü DraggableView olarak sarmala
        if let hosting = contentView {
            let wrapper = DraggableView(frame: hosting.frame)
            wrapper.dragHandler = dragHandler
            wrapper.autoresizingMask = [.width, .height]
            wrapper.addSubview(hosting)
            hosting.autoresizingMask = [.width, .height]
            contentView = wrapper
        }
    }
}

// MARK: - OverlayWindowManager

/// Tüm overlay widget pencerelerini oluşturan, güncelleyen ve yöneten merkezi sınıf.
/// iGetApp'ın yaşam döngüsüne bağlıdır — `AppDelegate` veya `@main` struct tarafından tutulur.
@MainActor
public final class OverlayWindowManager: ObservableObject {

    // MARK: Singleton

    public static let shared = OverlayWindowManager()

    // MARK: Published State

    @Published public private(set) var activeWindows: [UUID: OverlayWidgetWindow] = [:]

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private var screenChangeObserver: NSObjectProtocol?

    // MARK: Init

    private init() {
        observeSettings()
        observeScreenChanges()
    }

    deinit {
        if let obs = screenChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Lifecycle

    /// Ayarlardaki aktif overlay widget'ları için pencereleri başlatır.
    /// AppDelegate'in `applicationDidFinishLaunching` metodundan çağrılmalı.
    public func start() {
        let settings = SharedStorage.shared.appSettings
        let enabled  = settings.overlayWidgets.filter { $0.isEnabled }
        enabled.forEach { open(config: $0) }
        log("OverlayWindowManager başlatıldı — \(enabled.count) widget açıldı.")
    }

    /// Tüm overlay pencerelerini kapatır ve kaynakları serbest bırakır.
    public func stop() {
        activeWindows.values.forEach { $0.close() }
        activeWindows.removeAll()
        log("OverlayWindowManager durduruldu.")
    }

    // MARK: - Window Management

    /// Verilen konfigürasyon için yeni bir overlay penceresi açar.
    @discardableResult
    public func open(config: WidgetConfig) -> OverlayWidgetWindow {
        // Zaten varsa mevcut pencereyi döndür
        if let existing = activeWindows[config.id] {
            existing.orderFront(nil)
            return existing
        }

        let window = OverlayWidgetWindow(config: config)
        mountContent(for: config, in: window)
        window.attachDraggable()
        window.orderFront(nil)

        activeWindows[config.id] = window
        log("Pencere açıldı: \(config.kind.displayName) [\(config.id)]")
        return window
    }

    /// Verilen ID'ye sahip overlay penceresini kapatır.
    public func close(widgetID: UUID) {
        guard let window = activeWindows[widgetID] else { return }
        window.close()
        activeWindows.removeValue(forKey: widgetID)
        log("Pencere kapatıldı: [\(widgetID)]")
    }

    /// Belirtilen widget'ın görünürlüğünü değiştirir.
    public func toggle(config: WidgetConfig) {
        if activeWindows[config.id] != nil {
            close(widgetID: config.id)
        } else {
            open(config: config)
        }
    }

    /// Tüm pencereleri SharedStorage'dan güncel konumlara taşır.
    public func refreshPositions() {
        for (id, window) in activeWindows {
            if let pos = SharedStorage.shared.position(for: id) {
                window.setFrameOrigin(pos.cgPoint)
            }
        }
    }

    // MARK: - Content Mounting

    /// Widget türüne göre doğru SwiftUI view'ı pencereye bağlar.
    private func mountContent(for config: WidgetConfig, in window: OverlayWidgetWindow) {
        let theme = config.theme

        switch config.kind {

        case .systemMonitor:
            let view = SystemMonitorWidgetView(config: config)
                .environment(\.widgetTheme, theme)
            window.setContent(view)

        case .quickNote:
            let view = QuickNoteWidgetView(config: config)
                .environment(\.widgetTheme, theme)
            window.setContent(view)

        default:
            // OverlayEngine yalnızca overlay türü widget'ları render eder
            let placeholder = Text("⚠️ Bu widget WidgetKit motorunda çalışır.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            window.setContent(placeholder)
        }
    }

    // MARK: - Observers

    /// SharedStorage değişikliklerini dinler; pencere listesini günceller.
    private func observeSettings() {
        SharedStorage.shared.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.reconcileWindows(with: settings.overlayWidgets)
            }
            .store(in: &cancellables)
    }

    /// Ekran konfigürasyonu değiştiğinde tüm pencereleri sınır içine taşır.
    private func observeScreenChanges() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPositions()
            }
        }
    }

    /// Ayarlarla aktif pencere listesini karşılaştırıp ekle/kaldır işlemi yapar.
    private func reconcileWindows(with configs: [WidgetConfig]) {
        let enabledIDs = Set(configs.filter { $0.isEnabled }.map { $0.id })
        let activeIDs  = Set(activeWindows.keys)

        // Yeni eklenenler
        for config in configs where config.isEnabled && !activeIDs.contains(config.id) {
            open(config: config)
        }
        // Devre dışı bırakılanlar
        for id in activeIDs where !enabledIDs.contains(id) {
            close(widgetID: id)
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        print("🖥️ [OverlayWindowManager] \(message)")
    }
}

// MARK: - EnvironmentKey: WidgetTheme

private struct WidgetThemeKey: EnvironmentKey {
    static let defaultValue = WidgetTheme.default
}

public extension EnvironmentValues {
    var widgetTheme: WidgetTheme {
        get { self[WidgetThemeKey.self] }
        set { self[WidgetThemeKey.self] = newValue }
    }
}
