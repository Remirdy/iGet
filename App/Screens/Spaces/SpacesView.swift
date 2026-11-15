import SwiftUI

struct SpacesView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    @State private var name = ""

    private let curatedPresets: [CuratedPreset] = [
        CuratedPreset(
            id: "study",
            titleKey: "Study Space",
            matchName: "Study",
            symbol: "book",
            badge: "STUDY SPACE",
            descriptionKey: "Study, focus, tasks and exam countdown.",
            kinds: [.clock, .focus, .tasks, .countdown],
            desktopHex: "#3E4C42"
        ),
        CuratedPreset(
            id: "developer",
            titleKey: "Developer Space",
            matchName: "Developer",
            symbol: "terminal",
            badge: "DEVELOPER SPACE",
            descriptionKey: "System, contributions, quick launch and notes.",
            kinds: [.system, .notes, .launcher],
            desktopHex: "#34414A"
        ),
        CuratedPreset(
            id: "daily",
            titleKey: "Daily Space",
            matchName: "Daily",
            symbol: "sun.max",
            badge: "DAILY SPACE",
            descriptionKey: "Calendar, weather, battery and habits.",
            kinds: [.calendar, .weather, .battery, .habits],
            desktopHex: "#434840"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Top Header & Actions
                HStack(alignment: .top) {
                    PageHeading(
                        eyebrow: L10n.text("Desktop layouts"),
                        title: L10n.text("Spaces"),
                        subtitle: L10n.text("Save and switch widget layouts.")
                    )
                    Spacer()
                    Menu(L10n.text("Starter layouts")) {
                        Button(L10n.text("Play")) { store.addStarterSpace("Play", kinds: [.pet, .sticker, .dice, .game]) }
                        Button(L10n.text("Personal")) { store.addStarterSpace("Personal", kinds: [.photo, .quote, .canvas, .music]) }
                        Button(L10n.text("Daily dashboard")) { store.addStarterSpace(L10n.text("Daily dashboard"), kinds: [.weather, .water, .clock, .launcher]) }
                    }
                    Button(L10n.text("Import space…")) { store.chooseImport() }
                }

                // Curated Presets (FIG 05–07)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(L10n.text("CURATED PRESETS").uppercased(with: localization.locale))
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 20)], spacing: 20) {
                        ForEach(curatedPresets) { preset in
                            CuratedSpaceCard(
                                preset: preset,
                                isActive: isPresetActive(preset),
                                onActivate: { activatePreset(preset) }
                            )
                        }
                    }
                }

                Divider().opacity(0.4)

                // All Spaces & Custom Management
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(L10n.text("ALL SPACES").uppercased(with: localization.locale))
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(L10n.count(store.document.spaces.count, one: "%d space", other: "%d spaces"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        TextField(L10n.text("Name a new space"), text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                            .onSubmit(create)
                        Button(L10n.text("Create space"), action: create)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    VStack(spacing: 12) {
                        ForEach(store.document.spaces) { space in
                            SpaceRow(space: space)
                        }
                    }
                }

                // Notes & Architecture Disclaimer (Page 9)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Spaces arrange iGet’s desktop widgets. Widgets placed through macOS keep their system-managed positions."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(L10n.text("P1: In-app presets and shared theme. P2: Restore visibility and coordinates for iGet custom panels."))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)

            }
            .padding(32)
        }
    }

    private func create() {
        store.newSpace(name)
        name = ""
    }

    private func isPresetActive(_ preset: CuratedPreset) -> Bool {
        guard let active = store.document.activeSpace else { return false }
        return active.name.localizedCaseInsensitiveCompare(preset.matchName) == .orderedSame ||
               active.name.localizedCaseInsensitiveCompare(preset.titleKey) == .orderedSame
    }

    private func activatePreset(_ preset: CuratedPreset) {
        if let existing = store.document.spaces.first(where: {
            $0.name.localizedCaseInsensitiveCompare(preset.matchName) == .orderedSame ||
            $0.name.localizedCaseInsensitiveCompare(preset.titleKey) == .orderedSame
        }) {
            store.activateSpace(existing.id)
        } else {
            store.addStarterSpace(preset.matchName, kinds: preset.kinds)
        }
    }
}

// MARK: - Curated Preset Model

struct CuratedPreset: Identifiable {
    let id: String
    let titleKey: String
    let matchName: String
    let symbol: String
    let badge: String
    let descriptionKey: String
    let kinds: [ToolKind]
    let desktopHex: String
}

// MARK: - Curated Space Card (FIG 05–07)

private struct CuratedSpaceCard: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let preset: CuratedPreset
    let isActive: Bool
    let onActivate: () -> Void

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                // Desktop Preview Window (FIG 05–07)
                CuratedDesktopPreview(preset: preset)
                    .frame(height: 175)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                // Info & Action Header
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: preset.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.accentColor)

                    Text(L10n.text(preset.titleKey))
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    if isActive {
                        Label(L10n.text("Active"), systemImage: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    } else {
                        Button(L10n.text("Use space"), action: onActivate)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }

                // Description Subtitle
                Text(L10n.text(preset.descriptionKey))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Widget Tags
                HStack(spacing: 6) {
                    ForEach(preset.kinds) { kind in
                        HStack(spacing: 4) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 8))
                            Text(kind.title)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Curated Desktop Preview (Mini Simulated Mac Screen)

private struct CuratedDesktopPreview: View {
    let preset: CuratedPreset

    var body: some View {
        ZStack(alignment: .top) {
            // Desktop Wallpaper Tone
            Color(hex: preset.desktopHex)

            VStack(spacing: 0) {
                // Simulated macOS Menu Bar
                HStack(spacing: 6) {
                    Text("Finder  File  Edit  View")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("Wi-Fi  82%  Sun 09:41")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .frame(height: 15)
                .background(Color.black.opacity(0.35))

                // Simulated Desktop Content
                VStack(spacing: 8) {
                    // Space Title Badge
                    HStack {
                        Spacer()
                        Text(preset.badge)
                            .font(.system(size: 7, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.black.opacity(0.22), in: Capsule())
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 10)

                    // 2x2 Mini Widget Layout
                    HStack(spacing: 8) {
                        miniTileLeft(preset.id)
                        miniTileRight(preset.id)
                    }
                    .padding(.horizontal, 10)

                    Spacer(minLength: 0)

                    // Bottom Palette Swatch Pills (FIG 05–07)
                    HStack(spacing: 4) {
                        ForEach([ThemeTokens.sage.accent, ThemeTokens.paper.accent, ThemeTokens.lilac.accent, ThemeTokens.slate.accent, ThemeTokens.sky.accent], id: \.self) { c in
                            Circle().fill(c).frame(width: 5, height: 5)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.black.opacity(0.25), in: Capsule())
                    .padding(.bottom, 6)
                }
            }
        }
    }

    @ViewBuilder
    private func miniTileLeft(_ presetID: String) -> some View {
        VStack(spacing: 6) {
            switch presetID {
            case "study":
                // Mini Clock (Sage)
                miniCard(bgHex: "#E4F6ED", textHex: "#1C271E", secHex: "#526755") {
                    Text("ISTANBUL").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    Text("09:41").font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("Sunday, 15 Nov").font(.system(size: 4.5))
                }
                // Mini Tasks (Lilac)
                miniCard(bgHex: "#EDE6FF", textHex: "#251B2D", secHex: "#5E506B") {
                    Text("TODAY").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    HStack(spacing: 3) {
                        Circle().fill(Color(hex: "#251B2D")).frame(width: 3, height: 3)
                        Text("Read chapter").font(.system(size: 5))
                    }
                    HStack(spacing: 3) {
                        Circle().stroke(Color(hex: "#251B2D"), lineWidth: 0.6).frame(width: 3, height: 3)
                        Text("Review PR").font(.system(size: 5))
                    }
                }

            case "developer":
                // Mini System (Slate)
                miniCard(bgHex: "#E8EEF8", textHex: "#1B2329", secHex: "#4E5C67") {
                    Text("SYSTEM").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    HStack {
                        Text("CPU 18%").font(.system(size: 8, weight: .bold, design: .rounded))
                        Spacer()
                        Text("5.2 GB").font(.system(size: 6))
                    }
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach([3, 6, 4, 8, 5, 7, 3, 9, 4], id: \.self) { h in
                            RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#3E5367")).frame(width: 2, height: CGFloat(h))
                        }
                    }
                }
                // Mini Quick Launch (Lilac/Slate)
                miniCard(bgHex: "#EDE6FF", textHex: "#251B2D", secHex: "#5E506B") {
                    Text("QUICK LAUNCH").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    HStack(spacing: 3) {
                        ForEach(["X", "T", "G", "F"], id: \.self) { l in
                            Text(l).font(.system(size: 6, weight: .bold))
                                .frame(width: 12, height: 12)
                                .background(Color(hex: "#6D5582").opacity(0.3), in: RoundedRectangle(cornerRadius: 2.5))
                        }
                    }
                }

            default: // "daily"
                // Mini Calendar (Paper)
                miniCard(bgHex: "#FFF3DF", textHex: "#2E251E", secHex: "#6E5E53") {
                    Text("NOVEMBER").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    Text("M  T  W  T  F  S  S").font(.system(size: 4))
                    HStack(spacing: 2) {
                        ForEach(["15", "16", "17", "18", "19", "20", "21"], id: \.self) { d in
                            Text(d).font(.system(size: 4, weight: d == "15" ? .bold : .regular))
                                .frame(width: 6, height: 6)
                                .background(d == "15" ? Color(hex: "#2F7B60") : Color.clear, in: Circle())
                                .foregroundStyle(d == "15" ? .white : Color(hex: "#2E251E"))
                        }
                    }
                }
                // Mini Battery (Slate)
                miniCard(bgHex: "#E8EEF8", textHex: "#1B2329", secHex: "#4E5C67") {
                    Text("BATTERY").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    Text("82%").font(.system(size: 11, weight: .bold, design: .rounded))
                    RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: "#2F7B60")).frame(height: 2.5)
                }
            }
        }
    }

    @ViewBuilder
    private func miniTileRight(_ presetID: String) -> some View {
        VStack(spacing: 6) {
            switch presetID {
            case "study":
                // Mini Focus (Paper)
                miniCard(bgHex: "#FFF3DF", textHex: "#2E251E", secHex: "#6E5E53") {
                    Text("FOCUS").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    Text("24:08").font(.system(size: 13, weight: .bold, design: .rounded))
                    RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: "#2F7B60")).frame(height: 2.5)
                }
                // Mini Countdown (Slate)
                miniCard(bgHex: "#E8EEF8", textHex: "#1B2329", secHex: "#4E5C67") {
                    Text("NEXT EXAM").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    Text("12 days").font(.system(size: 10, weight: .bold, design: .rounded))
                    Text("Algorithms").font(.system(size: 4.5))
                }

            case "developer":
                // Mini Contributions (Sage)
                miniCard(bgHex: "#E4F6ED", textHex: "#1C271E", secHex: "#526755") {
                    Text("CONTRIBUTIONS").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    HStack(spacing: 2) {
                        ForEach(0..<6, id: \.self) { c in
                            VStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { r in
                                    RoundedRectangle(cornerRadius: 0.8)
                                        .fill(Color(hex: "#2F7B60").opacity((c + r) % 2 == 0 ? 0.9 : 0.3))
                                        .frame(width: 3.5, height: 3.5)
                                }
                            }
                        }
                    }
                }
                // Mini Quick Note (Paper)
                miniCard(bgHex: "#FFF3DF", textHex: "#2E251E", secHex: "#6E5E53") {
                    Text("QUICK NOTE").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    Text("Ideas for sprint").font(.system(size: 5.5, weight: .medium))
                    Text("Edited just now").font(.system(size: 4))
                }

            default: // "daily"
                // Mini Weather (Sky)
                miniCard(bgHex: "#E2F2FF", textHex: "#223E57", secHex: "#527A99") {
                    Text("ISTANBUL").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    HStack(spacing: 3) {
                        Text("14°").font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "sun.max.fill").font(.system(size: 7)).foregroundStyle(.orange)
                    }
                    Text("Partly cloudy").font(.system(size: 4.5))
                }
                // Mini Habits (Peach)
                miniCard(bgHex: "#FFEBDD", textHex: "#57382C", secHex: "#926957") {
                    Text("HABITS").font(.system(size: 5, weight: .semibold)).tracking(0.4)
                    Text("3 / 5").font(.system(size: 10, weight: .bold, design: .rounded))
                    HStack(spacing: 2.5) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle().fill(Color(hex: "#2F7B60").opacity(i < 3 ? 1.0 : 0.25)).frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
    }

    private func miniCard<Content: View>(bgHex: String, textHex: String, secHex: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            content()
        }
        .foregroundStyle(Color(hex: textHex))
        .padding(5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: bgHex), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - SpaceRow for Custom & User Spaces

struct SpaceRow: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let space: WorkspaceSpace
    @EnvironmentObject private var store: WorkspaceStore
    @State private var name = ""
    @FocusState private var editing: Bool
    private var active: Bool { space.id == store.document.activeSpaceID }

    var body: some View {
        Surface {
            HStack(spacing: 20) {
                Image(systemName: space.symbol)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(width: 35)

                VStack(alignment: .leading, spacing: 7) {
                    TextField(L10n.text("Space name"), text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .focused($editing)
                        .onSubmit(rename)
                        .onChange(of: editing) { _, value in if !value { rename() } }

                    HStack(spacing: 10) {
                        ForEach(Array(Set(space.tiles.map(\.kind))).sorted { $0.rawValue < $1.rawValue }) { kind in
                            Image(systemName: kind.symbol)
                                .font(.system(size: 11))
                                .help(kind.title)
                        }
                        Text(L10n.count(space.tiles.count, one: "%d widget", other: "%d widgets"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(active ? L10n.text("Active") : L10n.text("Use space")) {
                    store.activateSpace(space.id)
                }
                .buttonStyle(.bordered)
                .disabled(active)

                Menu {
                    Button(L10n.text("Duplicate space")) {
                        store.change { value in
                            var copy = space
                            copy.id = UUID()
                            copy.name = String(L10n.format("%@ copy", space.name).prefix(60))
                            copy.tiles = copy.tiles.map { var tile = $0; tile.id = UUID(); return tile }
                            value.spaces.append(copy)
                        }
                    }
                    Button(L10n.text("Delete space"), role: .destructive) {
                        store.removeSpace(space.id)
                    }
                    .disabled(store.document.spaces.count <= 1)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(active ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .onAppear { name = space.name }
        .onChange(of: space.name) { _, value in if !editing { name = value } }
    }

    private func rename() {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !clean.isEmpty, clean != space.name else { name = space.name; return }
        store.change { value in
            guard let i = value.spaces.firstIndex(where: { $0.id == space.id }) else { return }
            value.spaces[i].name = clean
        }
    }
}

// MARK: - Compatibility Typealias

typealias SpacesPage = SpacesView
