// Contracts.swift
// Packages/iGetCore/Sources/iGetCore/Contracts.swift
//
// iGet Resmi Veri Sözleşmeleri ve Yapılandırma Modelleri
// Emirhan × Zeynep Ortak Sözleşmesi
//
// Target Membership: iGet + iGetWidgets

import SwiftUI
import Foundation

// MARK: - Widget Engine Type

public enum WidgetEngine: String, Codable, CaseIterable, Sendable {
    /// Apple WidgetKit — düşük güç, timeline bazlı
    case widgetKit = "widgetKit"
    /// Canlı Masaüstü Katmanı — NSWindow / NSPanel
    case overlay = "overlay"
}

// MARK: - Widget Kind

public enum WidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    // MVP / P0 Widget'ları
    case clock          = "clock"
    case countdown      = "countdown"
    case tasks          = "tasks"
    case focus          = "focus"

    // P1 / Sonraki
    case notes          = "notes"
    case calendar       = "calendar"
    case habits         = "habits"
    case battery        = "battery"

    // P2 / Canlı Katman
    case systemMonitor  = "systemMonitor"
    case quickNote      = "quickNote"
    case weather        = "weather"
    case github         = "github"
    case launcher       = "launcher"

    public var id: String { rawValue }

    public var engine: WidgetEngine {
        switch self {
        case .systemMonitor, .quickNote:
            return .overlay
        default:
            return .widgetKit
        }
    }

    public var displayName: String {
        switch self {
        case .clock:         return "Saat"
        case .countdown:     return "Geri Sayım"
        case .tasks:         return "Görevler"
        case .focus:         return "Odak"
        case .notes:         return "Notlar"
        case .calendar:      return "Takvim"
        case .habits:        return "Alışkanlıklar"
        case .battery:       return "Pil"
        case .systemMonitor: return "Sistem Monitörü"
        case .quickNote:     return "Hızlı Not"
        case .weather:       return "Hava Durumu"
        case .github:        return "GitHub"
        case .launcher:      return "Başlatıcı"
        }
    }

    public var symbolName: String {
        switch self {
        case .clock:         return "clock"
        case .countdown:     return "timer"
        case .tasks:         return "checklist"
        case .focus:         return "brain.head.profile"
        case .notes:         return "note.text"
        case .calendar:      return "calendar"
        case .habits:        return "checkmark.seal"
        case .battery:       return "battery.100"
        case .systemMonitor: return "cpu"
        case .quickNote:     return "note.text"
        case .weather:       return "cloud.sun.fill"
        case .github:        return "chevron.left.forwardslash.chevron.right"
        case .launcher:      return "command"
        }
    }
}

// MARK: - Widget Size

public enum WidgetSize: String, Codable, CaseIterable, Sendable {
    case small      = "small"       // 141 × 141 pt
    case medium     = "medium"      // 300 × 141 pt
    case large      = "large"       // 300 × 300 pt
    case extraLarge = "extraLarge"  // 600 × 300 pt

    public var size: CGSize {
        switch self {
        case .small:      return CGSize(width: 141, height: 141)
        case .medium:     return CGSize(width: 300, height: 141)
        case .large:      return CGSize(width: 300, height: 300)
        case .extraLarge: return CGSize(width: 600, height: 300)
        }
    }

    public var displayName: String {
        switch self {
        case .small:      return "Küçük"
        case .medium:     return "Orta"
        case .large:      return "Büyük"
        case .extraLarge: return "Ekstra Büyük"
        }
    }
}

// MARK: - Widget Theme

public struct WidgetTheme: Codable, Equatable, Sendable {
    public var colorScheme:    WidgetColorScheme
    public var accentColorHex: String
    public var cornerRadius:   Double
    public var opacity:        Double
    public var fontFamily:     String
    public var showShadow:     Bool
    public var shadowRadius:   Double
    public var blurBackground: Bool

    public static let `default` = WidgetTheme(
        colorScheme:    .adaptive,
        accentColorHex: "#436248",
        cornerRadius:   14,
        opacity:        0.92,
        fontFamily:     "SF Pro",
        showShadow:     true,
        shadowRadius:   10,
        blurBackground: true
    )

    public static let dark = WidgetTheme(
        colorScheme:    .dark,
        accentColorHex: "#30D158",
        cornerRadius:   14,
        opacity:        0.88,
        fontFamily:     "SF Pro",
        showShadow:     true,
        shadowRadius:   14,
        blurBackground: true
    )

    public static let minimal = WidgetTheme(
        colorScheme:    .light,
        accentColorHex: "#636366",
        cornerRadius:   8,
        opacity:        1.0,
        fontFamily:     "SF Pro",
        showShadow:     false,
        shadowRadius:   0,
        blurBackground: false
    )
}

public enum WidgetColorScheme: String, Codable, CaseIterable, Sendable {
    case light    = "light"
    case dark     = "dark"
    case adaptive = "adaptive"

    public var colorScheme: ColorScheme? {
        switch self {
        case .light:    return .light
        case .dark:     return .dark
        case .adaptive: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .light:    return "Açık"
        case .dark:     return "Koyu"
        case .adaptive: return "Otomatik"
        }
    }
}

// MARK: - Widget Position (Overlay Engine)

public struct WidgetPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public static let defaultTopRight = WidgetPosition(x: 50, y: 50)
    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
}

// MARK: - Widget Configuration

public struct WidgetConfig: Codable, Sendable, Identifiable, Equatable {
    public let id:            UUID
    public var kind:          WidgetKind
    public var size:          WidgetSize
    public var theme:         WidgetTheme
    public var themeID:       String
    public var schemaVersion: Int
    public var position:      WidgetPosition
    public var isEnabled:     Bool
    public var title:         String?
    public var metadata:      [String: String]

    public init(
        id:            UUID = UUID(),
        kind:          WidgetKind,
        size:          WidgetSize = .medium,
        theme:         WidgetTheme = .default,
        themeID:       String = "sage",
        schemaVersion: Int = 1,
        position:      WidgetPosition = .defaultTopRight,
        isEnabled:     Bool = true,
        title:         String? = nil,
        metadata:      [String: String] = [:]
    ) {
        self.id            = id
        self.kind          = kind
        self.size          = size
        self.theme         = theme
        self.themeID       = themeID
        self.schemaVersion = schemaVersion
        self.position      = position
        self.isEnabled     = isEnabled
        self.title         = title
        self.metadata      = metadata
    }

    // MARK: Convenience Factories

    public static func clock() -> WidgetConfig {
        WidgetConfig(kind: .clock, size: .small, themeID: "sage")
    }

    public static func countdown() -> WidgetConfig {
        WidgetConfig(kind: .countdown, size: .small, themeID: "slate")
    }

    public static func tasks() -> WidgetConfig {
        WidgetConfig(kind: .tasks, size: .medium, themeID: "lilac")
    }

    public static func focus() -> WidgetConfig {
        WidgetConfig(kind: .focus, size: .small, themeID: "paper")
    }

    public static func systemMonitor(position: WidgetPosition = WidgetPosition(x: 20, y: 20)) -> WidgetConfig {
        WidgetConfig(
            kind:     .systemMonitor,
            size:     .medium,
            theme:    .dark,
            position: position,
            metadata: ["updateInterval": "1.0"]
        )
    }

    public static func quickNote(position: WidgetPosition = WidgetPosition(x: 20, y: 200)) -> WidgetConfig {
        WidgetConfig(kind: .quickNote, size: .medium, theme: .default)
    }

    public static func calendar() -> WidgetConfig {
        WidgetConfig(kind: .calendar, size: .medium)
    }

    public static func weather() -> WidgetConfig {
        WidgetConfig(kind: .weather, size: .medium, metadata: ["locationName": "İstanbul"])
    }
}

// MARK: - App-wide Settings

public struct AppSettings: Codable, Equatable, Sendable {
    public var globalTheme:          WidgetTheme
    public var launchAtLogin:        Bool
    public var showMenuBarIcon:      Bool
    public var overlayWidgets:       [WidgetConfig]
    public var widgetKitConfigs:     [WidgetConfig]
    public var systemMonitorInterval: Double

    public static let `default` = AppSettings(
        globalTheme:           .default,
        launchAtLogin:         false,
        showMenuBarIcon:       true,
        overlayWidgets:        [.systemMonitor(), .quickNote()],
        widgetKitConfigs:      [.clock(), .countdown(), .tasks(), .focus()],
        systemMonitorInterval: 1.0
    )

    public init(
        globalTheme:           WidgetTheme,
        launchAtLogin:         Bool,
        showMenuBarIcon:       Bool,
        overlayWidgets:        [WidgetConfig],
        widgetKitConfigs:      [WidgetConfig],
        systemMonitorInterval: Double
    ) {
        self.globalTheme           = globalTheme
        self.launchAtLogin         = launchAtLogin
        self.showMenuBarIcon       = showMenuBarIcon
        self.overlayWidgets        = overlayWidgets
        self.widgetKitConfigs      = widgetKitConfigs
        self.systemMonitorInterval = systemMonitorInterval
    }
}

// MARK: - Snapshot State

public enum SnapshotState: String, Codable, Sendable {
    case ready
    case stale
    case empty
    case error
}

// MARK: - Domain Payloads

public struct ClockPayload: Codable, Sendable, Equatable {
    public let cityName: String
    public let timezoneIdentifier: String
    public let is24Hour: Bool

    public init(cityName: String = "İstanbul", timezoneIdentifier: String = "Europe/Istanbul", is24Hour: Bool = true) {
        self.cityName = cityName
        self.timezoneIdentifier = timezoneIdentifier
        self.is24Hour = is24Hour
    }
}

public struct CountdownPayload: Codable, Sendable, Equatable {
    public let eventName: String
    public let targetDate: Date
    public let subtitle: String

    public init(eventName: String, targetDate: Date, subtitle: String) {
        self.eventName = eventName
        self.targetDate = targetDate
        self.subtitle = subtitle
    }

    public var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return max(0, components.day ?? 0)
    }
}

public struct TaskItem: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool

    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

public struct TasksPayload: Codable, Sendable, Equatable {
    public let title: String
    public let tasks: [TaskItem]

    public init(title: String = "Bugün", tasks: [TaskItem]) {
        self.title = title
        self.tasks = tasks
    }
}

public struct FocusPayload: Codable, Sendable, Equatable {
    public let currentSeconds: Int
    public let totalSeconds: Int
    public let isActive: Bool
    public let label: String

    public init(currentSeconds: Int = 24 * 60 + 8, totalSeconds: Int = 25 * 60, isActive: Bool = true, label: String = "Derin Çalışma") {
        self.currentSeconds = currentSeconds
        self.totalSeconds = totalSeconds
        self.isActive = isActive
        self.label = label
    }

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(currentSeconds) / Double(totalSeconds)
    }

    public var timeString: String {
        let minutes = currentSeconds / 60
        let seconds = currentSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

public enum WidgetPayload: Codable, Sendable, Equatable {
    case clock(ClockPayload)
    case countdown(CountdownPayload)
    case tasks(TasksPayload)
    case focus(FocusPayload)
}

public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let updatedAt: Date
    public let state:     SnapshotState
    public let payload:   WidgetPayload

    public init(updatedAt: Date = Date(), state: SnapshotState = .ready, payload: WidgetPayload) {
        self.updatedAt = updatedAt
        self.state     = state
        self.payload   = payload
    }
}

public protocol WidgetDataProvider: Sendable {
    func snapshot(for config: WidgetConfig) async throws -> WidgetSnapshot
}

// MARK: - Color Hex Extensions

public extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8)  / 255
        let b = Double(value & 0x0000FF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}

public extension WidgetTheme {
    var accentColor: Color { Color(hex: accentColorHex) }
}
