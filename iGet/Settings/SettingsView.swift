// SettingsView.swift
// iGet — Settings/
//
// Ana ayarlar penceresi — NavigationSplitView tabanlı çok sayfalı yapı:
//
//   Sidebar                 Detail
//   ──────────────────────  ──────────────────────────────────
//   ◉ Genel                 Launch at login, menü çubuğu
//   ◉ Overlay Widget'lar    Widget listesi, aktif/pasif, konum sıfırla
//   ◉ WidgetKit             Timeline konfigürasyonu
//   ◉ Tema                  Renk, blur, opacity, köşe yarıçapı
//   ◉ Hakkında              Sürüm, lisans, kaynaklar
//
// Target Membership: iGet
//
// Organization: TwoBit-Dev

import SwiftUI
import WidgetKit
import ServiceManagement

// MARK: - Settings Page Enum

enum SettingsPage: String, CaseIterable, Identifiable {
    case general        = "Genel"
    case overlayWidgets = "Overlay Widget'lar"
    case widgetKit      = "WidgetKit"
    case theme          = "Tema"
    case about          = "Hakkında"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .general:        return "gearshape.fill"
        case .overlayWidgets: return "macwindow.on.rectangle"
        case .widgetKit:      return "widget.small"
        case .theme:          return "paintbrush.pointed.fill"
        case .about:          return "info.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .general:        return Color(hex: "#636366")
        case .overlayWidgets: return Color(hex: "#0A84FF")
        case .widgetKit:      return Color(hex: "#30D158")
        case .theme:          return Color(hex: "#FF9F0A")
        case .about:          return Color(hex: "#BF5AF2")
        }
    }
}

// MARK: - SettingsView (Root)

struct SettingsView: View {

    @EnvironmentObject private var store: AppSettingsStore
    @State private var selectedPage: SettingsPage? = .general

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.prominentDetail)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(SettingsPage.allCases, selection: $selectedPage) { page in
            Label {
                Text(page.rawValue)
                    .font(.system(size: 13, weight: .medium))
            } icon: {
                Image(systemName: page.symbolName)
                    .foregroundStyle(page.accentColor)
                    .frame(width: 22, height: 22)
                    .background(page.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .tag(page as SettingsPage?)
            .padding(.vertical, 2)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 190, idealWidth: 200)
        .navigationTitle("iGet")
        .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
    }

    // MARK: Detail Router

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .general:        GeneralSettingsView()
        case .overlayWidgets: OverlayWidgetsSettingsView()
        case .widgetKit:      WidgetKitSettingsView()
        case .theme:          ThemeSettingsView()
        case .about:          AboutView()
        case .none:           GeneralSettingsView()
        }
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: Page 1 — General Settings
// MARK: ─────────────────────────────────────────────

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: AppSettingsStore

    var body: some View {
        SettingsPageContainer(title: "Genel", symbol: "gearshape.fill") {

            // Başlangıç
            SettingsSection("Başlangıç") {
                SettingsRow(label: "Girişte Başlat", description: "iGet oturumda otomatik çalışır") {
                    Toggle("", isOn: $store.settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: store.settings.launchAtLogin) { _, enabled in
                            try? enabled
                                ? SMAppService.mainApp.register()
                                : SMAppService.mainApp.unregister()
                            store.save()
                        }
                }

                SettingsRow(label: "Menü Çubuğu İkonunu Göster", description: "Üst çubuktaki iGet simgesi") {
                    Toggle("", isOn: $store.settings.showMenuBarIcon)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: store.settings.showMenuBarIcon) { _, _ in store.save() }
                }
            }

            // Sistem Monitörü
            SettingsSection("Sistem Monitörü") {
                SettingsRow(label: "Güncelleme Aralığı", description: "Saniye — düşük = yüksek güç") {
                    HStack(spacing: 10) {
                        Slider(
                            value:  $store.settings.systemMonitorInterval,
                            in:     0.5...5.0,
                            step:   0.5
                        )
                        .frame(width: 140)
                        .onChange(of: store.settings.systemMonitorInterval) { _, _ in store.save() }

                        Text(String(format: "%.1f s", store.settings.systemMonitorInterval))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                }
            }

            // Veri
            SettingsSection("Veri") {
                SettingsRow(label: "Fabrika Ayarlarına Sıfırla", description: "Tüm widget konumları ve ayarlar silinir") {
                    Button("Sıfırla", role: .destructive) {
                        SharedStorage.shared.resetToDefaults()
                        store.reload()
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: Page 2 — Overlay Widgets Settings
// MARK: ─────────────────────────────────────────────

struct OverlayWidgetsSettingsView: View {
    @EnvironmentObject private var store: AppSettingsStore
    @State private var selectedWidget: WidgetConfig?

    var body: some View {
        SettingsPageContainer(title: "Overlay Widget'lar", symbol: "macwindow.on.rectangle") {

            SettingsSection("Widget Listesi") {
                ForEach($store.settings.overlayWidgets) { $config in
                    OverlayWidgetRow(config: $config) {
                        SharedStorage.shared.updateOverlayWidget(config)
                        // Pencere yöneticisini bildir
                        if config.isEnabled {
                            OverlayWindowManager.shared.open(config: config)
                        } else {
                            OverlayWindowManager.shared.close(widgetID: config.id)
                        }
                    }
                }
            }

            SettingsSection("Konumlar") {
                SettingsRow(label: "Tüm Konumları Sıfırla", description: "Widget'lar sol üst köşeye döner") {
                    Button("Sıfırla") {
                        store.settings.overlayWidgets = store.settings.overlayWidgets.map { w in
                            var updated = w
                            SharedStorage.shared.updatePosition(.defaultTopRight, for: w.id)
                            return updated
                        }
                        OverlayWindowManager.shared.refreshPositions()
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}

// MARK: OverlayWidgetRow

private struct OverlayWidgetRow: View {
    @Binding var config: WidgetConfig
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // İkon
                Image(systemName: config.kind.symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#0A84FF"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#0A84FF").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // İsim + tür
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.title ?? config.kind.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(config.size.displayName + " · Overlay Engine")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Aktif toggle
                Toggle("", isOn: $config.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: config.isEnabled) { _, _ in onSave() }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: Page 3 — WidgetKit Settings
// MARK: ─────────────────────────────────────────────

struct WidgetKitSettingsView: View {
    @EnvironmentObject private var store: AppSettingsStore

    var body: some View {
        SettingsPageContainer(title: "WidgetKit", symbol: "widget.small") {

            SettingsSection("Widget'lar") {
                ForEach(store.settings.widgetKitConfigs) { config in
                    HStack(spacing: 12) {
                        Image(systemName: config.kind.symbolName)
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "#30D158"))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: "#30D158").opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(config.kind.displayName)
                                .font(.system(size: 13, weight: .semibold))
                            Text("WidgetKit · Bildirim Merkezi")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: "#30D158"))
                    }
                    .padding(.vertical, 6)
                }
            }

            SettingsSection("Yönetim") {
                SettingsRow(label: "Tüm Timeline'ları Yenile", description: "WidgetKit'e anında güncelleme sinyali gönderir") {
                    Button("Yenile") {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    .controlSize(.small)
                }

                InfoBanner(
                    symbol: "info.circle",
                    text:   "WidgetKit widget'larını Bildirim Merkezi veya Masaüstü bağlamından sürükleyerek ekleyebilirsiniz."
                )
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: Page 4 — Theme Settings
// MARK: ─────────────────────────────────────────────

struct ThemeSettingsView: View {
    @EnvironmentObject private var store: AppSettingsStore

    // Yerel çalışma kopyası
    @State private var theme: WidgetTheme = SharedStorage.shared.appSettings.globalTheme

    var body: some View {
        SettingsPageContainer(title: "Tema", symbol: "paintbrush.pointed.fill") {

            // Önayar hızlı seçim
            SettingsSection("Hazır Temalar") {
                HStack(spacing: 12) {
                    ThemePresetCard(label: "Varsayılan", theme: .default,  current: theme) { theme = .default  }
                    ThemePresetCard(label: "Koyu",       theme: .dark,     current: theme) { theme = .dark     }
                    ThemePresetCard(label: "Minimal",    theme: .minimal,  current: theme) { theme = .minimal  }
                }
                .padding(.vertical, 4)
            }

            // Renk şeması
            SettingsSection("Renk Şeması") {
                Picker("", selection: $theme.colorScheme) {
                    ForEach(WidgetColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Görünüm ayarları
            SettingsSection("Görünüm") {
                SettingsRow(label: "Köşe Yarıçapı", description: "0 – 32 pt") {
                    HStack(spacing: 10) {
                        Slider(value: $theme.cornerRadius, in: 0...32, step: 1)
                            .frame(width: 140)
                        Text("\(Int(theme.cornerRadius)) pt")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                }

                SettingsRow(label: "Opaklık", description: "0.5 – 1.0") {
                    HStack(spacing: 10) {
                        Slider(value: $theme.opacity, in: 0.5...1.0, step: 0.05)
                            .frame(width: 140)
                        Text(String(format: "%.0f%%", theme.opacity * 100))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                }

                SettingsRow(label: "Arka Plan Bulanıklığı") {
                    Toggle("", isOn: $theme.blurBackground)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsRow(label: "Gölge") {
                    Toggle("", isOn: $theme.showShadow)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsRow(label: "Gölge Yarıçapı") {
                    HStack(spacing: 10) {
                        Slider(value: $theme.shadowRadius, in: 0...32, step: 2)
                            .frame(width: 140)
                            .disabled(!theme.showShadow)
                        Text("\(Int(theme.shadowRadius)) pt")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                }
            }

            // Kaydet butonu
            HStack {
                Spacer()
                Button("Temayı Uygula") {
                    store.settings.globalTheme = theme
                    store.save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.top, 4)
        }
        .onAppear { theme = store.settings.globalTheme }
    }
}

// MARK: ThemePresetCard

private struct ThemePresetCard: View {
    let label:   String
    let theme:   WidgetTheme
    let current: WidgetTheme
    let onSelect: () -> Void

    var isSelected: Bool { theme == current }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: theme.cornerRadius * 0.5, style: .continuous)
                    .fill(
                        theme.colorScheme == .dark
                            ? Color.black
                            : Color.white.opacity(0.9)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadius * 0.5, style: .continuous)
                            .strokeBorder(Color(hex: theme.accentColorHex), lineWidth: 2)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .frame(width: 60, height: 40)
                    .shadow(color: .black.opacity(0.1), radius: 4)

                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color(hex: "#0A84FF") : .secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: Page 5 — About
// MARK: ─────────────────────────────────────────────

struct AboutView: View {
    var body: some View {
        SettingsPageContainer(title: "Hakkında", symbol: "info.circle.fill") {
            VStack(spacing: 20) {
                // Logo & isim
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#30D158")],
                                startPoint: .topLeading,
                                endPoint:   .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)

                    Text("iGet")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Versiyon 1.0.0 (Build 1)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

                Divider()

                // Bilgi satırları
                VStack(spacing: 8) {
                    AboutRow(label: "Geliştirici",    value: "TwoBit-Dev")
                    AboutRow(label: "Bundle ID",      value: "com.twobitdev.iGet")
                    AboutRow(label: "Platform",       value: "macOS 14.0+")
                    AboutRow(label: "Swift",          value: "5.9")
                    AboutRow(label: "WidgetKit",      value: "macOS 14.0+")
                    AboutRow(label: "WeatherKit",     value: "macOS 13.0+")
                }

                Divider()

                // Motor bilgisi
                VStack(alignment: .leading, spacing: 6) {
                    Text("Widget Motorları")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        EngineBadge(name: "OverlayEngine",
                                    description: "Canlı · NSWindow",
                                    color: Color(hex: "#0A84FF"))
                        EngineBadge(name: "WidgetKit",
                                    description: "Düşük Güç · Apple",
                                    color: Color(hex: "#30D158"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)

                Spacer()

                Text("© 2024 TwoBit-Dev. Tüm hakları saklıdır.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

private struct EngineBadge: View {
    let name:        String
    let description: String
    let color:       Color

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: Shared Layout Components
// MARK: ─────────────────────────────────────────────

struct SettingsPageContainer<Content: View>: View {
    let title:   String
    let symbol:  String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title   = title
        self.symbol  = symbol
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Sayfa başlığı
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                }
                .padding(.bottom, 4)

                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(title)
    }
}

struct SettingsSection<Content: View>: View {
    let title:   String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title   = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
        }
    }
}

struct SettingsRow<Control: View>: View {
    let label:       String
    var description: String = ""
    let control:     Control

    init(label: String, description: String = "", @ViewBuilder control: () -> Control) {
        self.label       = label
        self.description = description
        self.control     = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct InfoBanner: View {
    let symbol: String
    let text:   String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}
