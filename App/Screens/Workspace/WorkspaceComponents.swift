import SwiftUI

struct PageHeading: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased(with: localization.locale)).font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary)
            Text(title).font(.system(size: 30, weight: .semibold)).tracking(-0.9)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

struct Surface<Content: View>: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        content.padding(20)
            .background(BrandTheme.surface(scheme == .dark), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
    }
}

struct EmptyWorkspaceView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 18, weight: .medium))
            Text(detail).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 55)
    }
}

struct ResourceTileView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let kind: ToolKind
    let paletteID: String
    var radius: Double = 18
    @ObservedObject var monitor: ResourceMonitor
    var options = WidgetOptions()
    @Environment(\.colorScheme) private var scheme
    private var palette: ThemePalette { options.theme(palette: paletteID, dark: scheme == .dark) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if options.showHeader { Label(options.title.isEmpty ? kind.title.uppercased(with: localization.locale) : options.title.uppercased(with: localization.locale), systemImage: kind.symbol)
                .font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(palette.secondaryText) }
            if kind == .battery {
                Text(monitor.sample.batteryPercent.map { "\($0)%" } ?? "AC")
                    .font(.system(size: 42, weight: .medium, design: .rounded)).monospacedDigit()
                Spacer(minLength: 0)
                ProgressView(value: Double(monitor.sample.batteryPercent ?? 100), total: 100).tint(palette.accent)
                Text(monitor.sample.batteryPercent == nil ? L10n.text("Connected to power") : monitor.sample.charging ? L10n.text("Charging") : monitor.sample.onAC ? L10n.text("Power adapter connected") : L10n.text("On battery"))
                    .font(.system(size: 11)).foregroundStyle(palette.secondaryText)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(monitor.sample.cpu.map { "\(Int($0 * 100))%" } ?? "—")
                        .font(.system(size: 36, weight: .medium, design: .rounded)).monospacedDigit()
                    Text("CPU").font(.system(size: 10)).foregroundStyle(palette.secondaryText)
                }
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(monitor.history.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 2).fill(palette.accent.opacity(0.7)).frame(height: max(2, value * 28))
                    }
                }.frame(maxWidth: .infinity, minHeight: 28, alignment: .bottomLeading)
                Spacer(minLength: 0)
                Text(monitor.sample.memoryGB.map { L10n.format("%.1f / %.0f GB memory", $0, monitor.sample.totalMemoryGB) } ?? L10n.text("Taking first sample…"))
                    .font(.system(size: 11)).foregroundStyle(palette.secondaryText).lineLimit(1).minimumScaleFactor(0.6)
            }
        }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(palette.primaryText)
            .background {
                switch options.backdrop { case .solid: palette.background; case .glass: Rectangle().fill(.regularMaterial); case .transparent: Color.clear }
            }.clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(palette.subtleBorder, lineWidth: options.borderWidth)).opacity(options.opacity)
            .help(monitor.sample.updatedAt.map { L10n.format("Updated %@", $0.formatted(.dateTime.hour().minute().second().locale(localization.locale))) } ?? L10n.text("Waiting for a sample"))
    }
}

struct LiveTile: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    let tile: DesktopTile
    var interactive = true
    private var data: WorkspaceDocument {
        var data = store.document
        if let text = tile.settings.bodyText, tile.kind == .notes { data.note = text }
        if let zone = tile.settings.timeZone { data.preferences.clockTimeZone = zone }
        if let date = tile.settings.countdownDate { data.countdown.date = date }
        if let title = tile.settings.countdownTitle { data.countdown.title = title }
        return data
    }
    var body: some View {
        Group {
            if !tile.kind.isOriginal { AdvancedWidgetView(tile: tile, interactive: interactive) }
            else if tile.kind == .system || tile.kind == .battery {
                ResourceTileView(kind: tile.kind, paletteID: tile.palette, radius: tile.cornerRadius, monitor: store.resources, options: tile.settings)
            } else {
                WorkspaceWidgetView(kind: tile.kind, document: data, paletteID: tile.palette, radius: tile.cornerRadius, isLarge: tile.displayHeight >= 280,
                                    onTask: interactive ? { store.setTask($0, completed: $1) } : nil,
                                    onFocus: interactive ? { store.toggleFocus() } : nil,
                                    onHabit: interactive ? { store.toggleHabit($0) } : nil, options: tile.settings)
            }
        }
    }
}

struct PalettePicker: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @Binding var selection: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 6) {
            ForEach(ThemeTokens.all) { palette in
                Button { selection = palette.id } label: {
                    Circle().fill(ThemeTokens.palette(palette.id, dark: scheme == .dark).background)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(selection == palette.id ? Color.primary.opacity(0.7) : Color.primary.opacity(0.15), lineWidth: selection == palette.id ? 2 : 1))
                        .overlay { if selection == palette.id { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) } }
                }.buttonStyle(.plain).help(L10n.text(palette.displayName)).accessibilityLabel(L10n.text(palette.displayName)).accessibilityAddTraits(selection == palette.id ? .isSelected : [])
            }
        }
    }
}
