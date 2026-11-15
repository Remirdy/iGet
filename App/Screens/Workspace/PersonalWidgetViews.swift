import AppKit
import SwiftUI

struct TileSurface<Content: View>: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let tile: DesktopTile
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    private var theme: ThemePalette { tile.settings.theme(palette: tile.palette, dark: scheme == .dark) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if tile.settings.showHeader {
                Label(tile.displayTitle.uppercased(with: localization.locale), systemImage: tile.kind.symbol)
                    .font(.system(size: 10 * tile.settings.fontScale, weight: .semibold)).tracking(1.1)
                    .foregroundStyle(theme.secondaryText).lineLimit(1)
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(18).font(.system(size: 13 * tile.settings.fontScale, design: tile.settings.typeface.design))
        .foregroundStyle(theme.primaryText).tint(theme.accent)
        .background {
            switch tile.settings.backdrop {
            case .solid: theme.background
            case .glass: Rectangle().fill(.regularMaterial)
            case .transparent: Color.clear
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: tile.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: tile.cornerRadius).strokeBorder(theme.accent.opacity(0.18), lineWidth: tile.settings.borderWidth))
        .opacity(tile.settings.opacity)
    }
}

struct AdvancedWidgetView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let tile: DesktopTile
    var interactive = true
    @EnvironmentObject private var store: WorkspaceStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false
    private var options: WidgetOptions { tile.settings }
    private var theme: ThemePalette { options.theme(palette: tile.palette, dark: scheme == .dark) }
    var body: some View {
        TileSurface(tile: tile) { content }
    }
    @ViewBuilder private var content: some View {
        switch tile.kind {
        case .photo:
            if let photo = options.photo, let image = PhotoCache.image(photo) {
                GeometryReader { geometry in
                    Image(nsImage: image).resizable().aspectRatio(contentMode: options.photoFill ? .fill : .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }.clipShape(RoundedRectangle(cornerRadius: max(0, tile.cornerRadius - 8)))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 34, weight: .light))
                    Text(L10n.text("No photo selected")).font(.system(size: 13, weight: .medium))
                    if interactive { Button(L10n.text("Choose photo")) { store.choosePhoto(for: tile.id) }.controlSize(.small) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .sticker:
            GeometryReader { geometry in
                Text(options.symbol).font(.system(size: min(geometry.size.width, geometry.size.height) * 0.78))
                    .rotationEffect(.degrees(options.rotation)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .dice:
            VStack(spacing: 10) {
                HStack(spacing: 12) { ForEach(0..<2) { index in Image(systemName: "die.face.\(options.dice[index]).fill").font(.system(size: 37 * min(options.fontScale, 1.3))).foregroundStyle(theme.accent) } }
                Spacer(minLength: 0)
                HStack { Text(L10n.format("Total %d", options.dice.reduce(0, +))).font(.system(size: 11)); Spacer(); if interactive { Button(L10n.text("Roll")) { store.rollDice(tile.id) }.controlSize(.small) } }
            }.frame(maxWidth: .infinity)
        case .game:
            GeometryReader { geometry in
                VStack(spacing: 6) {
                    Text(options.game.winner.map { L10n.format("%@ wins", $0 == 1 ? "X" : "O") } ?? (options.game.finished ? L10n.text("A draw") : L10n.format("%@’s turn", options.game.turn == 1 ? "X" : "O")))
                        .font(.system(size: 11, weight: .medium))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                        ForEach(0..<9) { index in
                            Button { store.gameMove(tile.id, cell: index) } label: {
                                Text(options.game.cells[index] == 0 ? " " : options.game.cells[index] == 1 ? "×" : "○")
                                    .font(.system(size: max(14, min(geometry.size.width, geometry.size.height - 40) / 5), weight: .medium))
                                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                    .background(theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain).allowsHitTesting(interactive).accessibilityLabel(L10n.format("Cell %d", index + 1))
                        }
                    }.frame(width: max(60, min(geometry.size.width, geometry.size.height - 40)))
                    if interactive { Button(L10n.text("New game")) { store.resetGame(tile.id) }.font(.system(size: 10)).buttonStyle(.plain) }
                }.frame(maxWidth: .infinity)
            }
        case .water:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 5) { Text("\(options.todayCount)").font(.system(size: 37 * options.fontScale, weight: .medium, design: .rounded)); Text("/ \(options.goal)").foregroundStyle(theme.secondaryText) }
                ProgressView(value: min(Double(options.todayCount) / Double(options.goal), 1)).tint(theme.accent)
                Spacer(minLength: 0)
                HStack { Text(L10n.text("glasses today")).font(.system(size: 10)); Spacer(); if interactive {
                    Button { store.addWater(tile.id, delta: -1) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel(L10n.text("Remove a glass"))
                    Button { store.addWater(tile.id, delta: 1) } label: { Image(systemName: "plus.circle.fill") }.buttonStyle(.plain).accessibilityLabel(L10n.text("Add a glass"))
                } }
            }
        case .quote:
            VStack(alignment: .leading, spacing: 10) {
                Text(options.displayedQuote).font(.system(size: (tile.size == .large ? 24 : 16) * options.fontScale, weight: .medium, design: options.typeface.design)).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                HStack { Text(L10n.text("Saved quotes")).font(.system(size: 10)).foregroundStyle(theme.secondaryText); Spacer(); if interactive && options.quoteLines.count > 1 { Button { store.nextQuote(tile.id) } label: { Image(systemName: "arrow.triangle.2.circlepath") }.buttonStyle(.plain).accessibilityLabel(L10n.text("Next quote")) }
                    else if interactive && options.quoteLines.isEmpty { Button(L10n.text("Edit")) { store.editInStudio(tile.id) }.buttonStyle(.plain) } }
            }
        case .pet:
            VStack(spacing: 5) {
                Text(options.symbol == "🌸" ? "🐈" : options.symbol).font(.system(size: tile.size == .large ? 90 : 45)).scaleEffect(bounce && !reduceMotion ? 1.12 : 1)
                Text(L10n.text(options.petAction)).font(.system(size: 10)).lineLimit(1)
                ProgressView(value: Double(options.petEnergy), total: 100).tint(theme.accent)
                Spacer(minLength: 0)
                if interactive { HStack(spacing: 5) { petButton(L10n.text("Feed"), action: 0); petButton(L10n.text("Play"), action: 1); petButton(L10n.text("Nap"), action: 2) }.controlSize(.mini) }
            }.frame(maxWidth: .infinity)
        case .breathing:
            BreathingBody(reduceMotion: reduceMotion || store.samplingInterval >= 15, interactive: interactive, accent: theme.accent)
        case .launcher:
            if options.shortcuts.isEmpty {
                VStack(alignment: .leading, spacing: 8) { Image(systemName: "arrow.up.forward.app").font(.system(size: 30)); Text(L10n.text("No shortcuts")).font(.system(size: 14, weight: .medium)); Spacer(minLength: 0); if interactive { Button(L10n.text("Add in Studio")) { store.editInStudio(tile.id) }.controlSize(.small) } }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 65), spacing: 8)], spacing: 8) {
                    ForEach(options.shortcuts) { shortcut in
                        Button { store.openShortcut(shortcut) } label: {
                            VStack(spacing: 5) { Image(systemName: shortcut.symbol).font(.system(size: 20)); Text(shortcut.title).font(.system(size: 10)).lineLimit(1) }.frame(maxWidth: .infinity).padding(8).background(theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).allowsHitTesting(interactive)
                    }
                }
            }
        case .weather: WeatherBody(city: options.city, provider: store.weather, interactive: interactive)
        case .music: MusicBody(provider: store.music, interactive: interactive)
        case .canvas: LayerCanvasView(layers: options.layers ?? CanvasLayer.localizedStarter, options: options, document: store.document)
        default: EmptyView()
        }
    }
    private func petButton(_ name: String, action: Int) -> some View {
        Button(name) {
            store.petAction(tile.id, action: action)
            if !reduceMotion && store.samplingInterval < 15 { withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { bounce.toggle() } }
        }
    }
}

private struct BreathingBody: View {
    @ObservedObject private var localization = LocalizationManager.shared
    var reduceMotion: Bool
    var interactive: Bool
    let accent: Color
    @State private var start: Date?
    var body: some View {
        VStack(spacing: 8) {
            if let start {
                TimelineView(.periodic(from: start, by: 1)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(start))
                    let phase = BreathingCycle.phase(at: elapsed)
                    VStack(spacing: 8) {
                        Circle().fill(accent.opacity(0.18)).overlay(Circle().stroke(accent.opacity(0.5), lineWidth: 2))
                            .scaleEffect(reduceMotion ? 1 : phase == 0 ? 0.75 : phase == 1 ? 1 : 0.8)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 3), value: phase).frame(width: 45, height: 45)
                        Text([L10n.text("Breathe in"), L10n.text("Hold"), L10n.text("Breathe out")][phase]).font(.system(size: 13, weight: .medium))
                    }.onChange(of: BreathingCycle.finished(at: elapsed)) { _, finished in if finished { self.start = nil } }
                }
                if interactive { Button(L10n.text("Stop")) { self.start = nil }.controlSize(.mini) }
            } else {
                Image(systemName: "wind").font(.system(size: 32, weight: .light)).foregroundStyle(accent)
                Text(L10n.text("60-second session")).font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
                if interactive { Button(L10n.text("Begin")) { start = Date() }.controlSize(.small) }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WeatherBody: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let city: WeatherCity
    @ObservedObject var provider: WeatherProvider
    var interactive = true
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(city.name).font(.system(size: 12, weight: .medium)); Spacer(); if interactive { Button { provider.refresh(city, force: true) } label: { Image(systemName: "arrow.clockwise").font(.system(size: 10)) }.buttonStyle(.plain).accessibilityLabel(L10n.text("Refresh weather")) } }
            if let value = provider.snapshots[city.cacheKey] {
                HStack { Text("\(Int(value.temperature.rounded()))°").font(.system(size: 37, weight: .medium, design: .rounded)); Spacer(); Image(systemName: value.symbol).font(.system(size: 27)) }
                Text(value.condition).font(.system(size: 11))
                Spacer(minLength: 0)
                Text(L10n.format("%d%% humidity · %d km/h", value.humidity, Int(value.wind))).font(.system(size: 9)).foregroundStyle(.secondary)
                if provider.errors[city.cacheKey] != nil || Date().timeIntervalSince(value.updatedAt) > 1800 { Text(L10n.format("Last reading · %@", value.updatedAt.formatted(.dateTime.hour().minute().locale(localization.locale)))).font(.system(size: 9)).foregroundStyle(.secondary) }
            } else {
                Image(systemName: "cloud.sun").font(.system(size: 28, weight: .light)).padding(.vertical, 3)
                Text(provider.loading.contains(city.cacheKey) ? L10n.text("Getting the forecast…") : provider.errors[city.cacheKey] ?? L10n.text("Weather appears when this widget is on your desktop.")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!).buttonStyle(.plain)
                Text("·").foregroundStyle(.secondary)
                Link("CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!).buttonStyle(.plain)
            }.font(.system(size: 8))
        }
    }
}

struct MusicBody: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject var provider: MusicProvider
    var interactive = true
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let track = provider.snapshot {
                HStack(alignment: .top) { Image(systemName: "opticaldisc.fill").font(.system(size: 30)); VStack(alignment: .leading, spacing: 5) { Text(track.title).font(.system(size: 14, weight: .medium)).lineLimit(2); Text(track.artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) } }
                if let error = provider.error { Text(error).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(2) }
                Spacer(minLength: 0)
                if interactive { HStack(spacing: 22) {
                    Button { provider.perform(.previous) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel(L10n.text("Previous track"))
                    Button { provider.perform(.playPause) } label: { Image(systemName: track.playing ? "pause.fill" : "play.fill") }.accessibilityLabel(L10n.text("Play or pause"))
                    Button { provider.perform(.next) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel(L10n.text("Next track"))
                }.buttonStyle(.plain).frame(maxWidth: .infinity) }
            } else {
                Image(systemName: "music.note").font(.system(size: 29, weight: .light))
                Text(provider.source.rawValue).font(.system(size: 15, weight: .medium))
                Text(provider.error ?? L10n.text("Connect your player to show the current track.")).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(3)
                Spacer(minLength: 0)
                if interactive { Button(L10n.text("Connect player")) { provider.connect() }.controlSize(.small) }
            }
        }
    }
}

private enum PhotoCache {
    static let cache: NSCache<NSNumber, NSImage> = { let cache = NSCache<NSNumber, NSImage>(); cache.totalCostLimit = 16 * 1_048_576; cache.countLimit = 24; return cache }()
    static func image(_ data: Data) -> NSImage? {
        let key = NSNumber(value: data.hashValue)
        if let value = cache.object(forKey: key) { return value }
        guard let value = NSImage(data: data) else { return nil }
        cache.setObject(value, forKey: key, cost: Int(value.size.width * value.size.height * 4))
        return value
    }
}
