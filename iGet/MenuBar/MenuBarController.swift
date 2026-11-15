// MenuBarController.swift
// iGet — MenuBar/
//
// MenuBarExtra pencere içeriği.
// Kompakt bir popover arayüzü sunar:
//   • Widget açma/kapama toggle'ları
//   • Sistem monitörü mini özeti
//   • Hızlı eylemler (Ayarlar, Yenile, Çıkış)
//
// Target Membership: iGet
//
// Organization: TwoBit-Dev

import SwiftUI
import WidgetKit

// MARK: - MenuBarView

/// MenuBarExtra'nın .window stilindeki içerik view'ı.
struct MenuBarView: View {

    // MARK: Environment

    @EnvironmentObject private var store: AppSettingsStore

    // MARK: State

    @State private var cpuUsage:   Double = 0
    @State private var ramUsedGB:  Double = 0
    @State private var ramTotalGB: Double = 0

    // CPU/RAM'i MenuBar içinde hafif şekilde okumak için mini monitor
    @StateObject private var miniMonitor = SystemMonitor(interval: 3.0)

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            systemSnapshot
            Divider()
            widgetToggles
            Divider()
            quickActions
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .onAppear  { miniMonitor.start() }
        .onDisappear { miniMonitor.stop() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#0A84FF"), Color(hex: "#30D158")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 1) {
                Text("iGet")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Widget Yöneticisi")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Versiyon etiketi
            Text("v1.0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - System Snapshot (CPU + RAM mini özet)

    private var systemSnapshot: some View {
        HStack(spacing: 0) {
            // CPU
            MiniStatView(
                symbol:  "cpu",
                label:   "CPU",
                value:   String(format: "%.0f%%", miniMonitor.stats.cpuUsage * 100),
                color:   cpuColor
            )
            .frame(maxWidth: .infinity)

            Divider().frame(height: 32)

            // RAM
            MiniStatView(
                symbol:  "memorychip",
                label:   "RAM",
                value:   String(format: "%.1f GB", miniMonitor.stats.ramUsedGB),
                color:   ramColor
            )
            .frame(maxWidth: .infinity)

            Divider().frame(height: 32)

            // Aktif widget sayısı
            MiniStatView(
                symbol: "square.stack",
                label:  "Widget",
                value:  "\(OverlayWindowManager.shared.activeWindows.count) aktif",
                color:  Color(hex: "#0A84FF")
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    private var cpuColor: Color {
        let v = miniMonitor.stats.cpuUsage
        if v > 0.85 { return .red }
        if v > 0.60 { return .orange }
        return Color(hex: "#0A84FF")
    }

    private var ramColor: Color {
        let v = miniMonitor.stats.ramUsagePercent
        if v > 0.90 { return .red }
        if v > 0.70 { return .orange }
        return Color(hex: "#30D158")
    }

    // MARK: - Widget Toggles

    private var widgetToggles: some View {
        VStack(spacing: 0) {
            // Bölüm başlığı
            SectionLabel(title: "OVERLAY WIDGET'LAR")

            ForEach(store.settings.overlayWidgets) { config in
                WidgetToggleRow(config: config) { isEnabled in
                    toggleOverlay(config: config, enabled: isEnabled)
                }
            }

            SectionLabel(title: "WIDGETKIT")

            ForEach(store.settings.widgetKitConfigs) { config in
                WidgetKitRow(config: config)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 2) {
            // Ayarlar
            MenuActionButton(
                symbol: "gear",
                label:  "Ayarlar",
                shortcut: "⌘,"
            ) {
                openSettings()
            }

            // Tüm widget'ları yenile
            MenuActionButton(
                symbol: "arrow.triangle.2.circlepath",
                label:  "Widget'ları Yenile"
            ) {
                WidgetCenter.shared.reloadAllTimelines()
                Task { @MainActor in
                    OverlayWindowManager.shared.refreshPositions()
                }
            }

            Divider().padding(.vertical, 2)

            // Çıkış
            MenuActionButton(
                symbol:    "power",
                label:     "Çıkış",
                shortcut:  "⌘Q",
                role:      .destructive
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func toggleOverlay(config: WidgetConfig, enabled: Bool) {
        var updated = config
        // `isEnabled` değişkeni let olduğundan yeni config oluştur
        let newConfig = WidgetConfig(
            id:        config.id,
            kind:      config.kind,
            size:      config.size,
            theme:     config.theme,
            position:  config.position,
            isEnabled: enabled,
            title:     config.title,
            metadata:  config.metadata
        )
        SharedStorage.shared.updateOverlayWidget(newConfig)

        if enabled {
            OverlayWindowManager.shared.open(config: newConfig)
        } else {
            OverlayWindowManager.shared.close(widgetID: config.id)
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI Window sahnesini aç
        for window in NSApp.windows where window.identifier?.rawValue == SceneID.settings {
            window.makeKeyAndOrderFront(nil)
            return
        }
        // Yoksa AppDelegate üzerinden aç
        (NSApp.delegate as? AppDelegate)?.openSettings()
    }
}

// MARK: - MiniStatView

private struct MiniStatView: View {
    let symbol: String
    let label:  String
    let value:  String
    let color:  Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SectionLabel

private struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}

// MARK: - WidgetToggleRow (Overlay)

private struct WidgetToggleRow: View {
    let config:    WidgetConfig
    let onToggle:  (Bool) -> Void

    @State private var isOn: Bool

    init(config: WidgetConfig, onToggle: @escaping (Bool) -> Void) {
        self.config   = config
        self.onToggle = onToggle
        _isOn = State(initialValue: config.isEnabled)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: config.kind.symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#0A84FF"))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(config.title ?? config.kind.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text(config.kind.engine == .overlay ? "Canlı Katman" : "WidgetKit")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .onChange(of: isOn) { _, newVal in onToggle(newVal) }
    }
}

// MARK: - WidgetKitRow (sadece bilgi — toggle WidgetKit üzerinden çalışmaz)

private struct WidgetKitRow: View {
    let config: WidgetConfig

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: config.kind.symbolName)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(config.title ?? config.kind.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text("WidgetKit · Sistem yönetiminde")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#30D158"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}

// MARK: - MenuActionButton

private struct MenuActionButton: View {
    let symbol:   String
    let label:    String
    var shortcut: String     = ""
    var role:     ButtonRole? = nil
    let action:   () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
    }
}
