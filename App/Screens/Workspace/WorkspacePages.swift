import SwiftUI

struct OverviewPage: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeading(eyebrow: Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(localization.locale)), title: L10n.text("Overview"), subtitle: L10n.text("Tasks, focus sessions and active widgets."))
                HStack(spacing: 16) {
                    statistic(L10n.text("Active widgets"), value: "\(store.document.activeTiles.filter(\.enabled).count)", symbol: "macwindow")
                    statistic(L10n.text("Tasks remaining"), value: "\(store.document.tasks.filter { !$0.completed }.count)", symbol: "checklist")
                    statistic(L10n.text("Focus sessions"), value: "\(store.document.focus.completedSessions)", symbol: "timer")
                }
                HStack { Text(L10n.text("TASKS AND FOCUS")).font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary); Spacer(); Button(L10n.text("Daily tools")) { store.page = .tools }.font(.system(size: 11)) }
                HStack(spacing: 18) {
                    WorkspaceWidgetView(kind: .focus, document: store.document, paletteID: "paper", onFocus: { store.toggleFocus() }).frame(height: 210)
                    WorkspaceWidgetView(kind: .tasks, document: store.document, paletteID: "lilac", onTask: { store.setTask($0, completed: $1) }).frame(height: 210)
                }
                Surface {
                    HStack(spacing: 18) {
                        Image(systemName: store.document.activeSpace?.symbol ?? "rectangle.3.group").font(.system(size: 26, weight: .light)).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.format("Current space: %@", store.document.activeSpace?.name ?? "—")).font(.system(size: 16, weight: .medium))
                            Text(L10n.text("Saved widget layout.")).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L10n.text("Manage spaces")) { store.page = .spaces }
                    }
                }
                Label(L10n.text("Local storage · No account required"), systemImage: "internaldrive").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.padding(32)
        }
    }
    private func statistic(_ title: String, value: String, symbol: String) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Image(systemName: symbol).foregroundStyle(.secondary); Spacer(); Text(value).font(.system(size: 29, weight: .medium, design: .rounded)).monospacedDigit() }
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DesktopPage: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: store.document.activeSpace?.name ?? L10n.text("Your space"), title: L10n.text("Your desktop"), subtitle: L10n.text("Manage the widgets in your current space."))
                    Spacer()
                    Button(store.document.desktopVisible ? L10n.text("Hide desktop widgets") : L10n.text("Show desktop widgets")) { store.change { $0.desktopVisible.toggle() } }.controlSize(.large)
                }
                Toggle(L10n.text("Lock widget positions"), isOn: Binding(get: { store.document.preferences.lockLayout }, set: { locked in store.preferences { $0.lockLayout = locked } })).font(.system(size: 12))
                if store.document.activeTiles.isEmpty {
                    EmptyWorkspaceView(symbol: "macwindow.badge.plus", title: L10n.text("No widgets in this space"), detail: L10n.text("Add widgets from the library."))
                    Button(L10n.text("Browse widgets")) { store.page = .gallery }.buttonStyle(.borderedProminent)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 22)], spacing: 24) {
                    ForEach(store.document.activeTiles) { tile in
                        VStack(alignment: .leading, spacing: 12) {
                            LiveTile(tile: tile, interactive: false).frame(height: 190).allowsHitTesting(false).opacity(tile.enabled ? 1 : 0.5)
                            HStack {
                                Text(tile.kind.title).font(.system(size: 12, weight: .medium))
                                Spacer()
                                Button { store.editTile(tile.id) { $0.enabled.toggle() } } label: { Image(systemName: tile.enabled ? "eye" : "eye.slash") }.buttonStyle(.plain).help(tile.enabled ? L10n.text("Hide widget") : L10n.text("Show widget"))
                                Menu {
                                    Button(L10n.text("Open tool")) { store.selectedTool = tile.kind }
                                    Button(L10n.text("Customize")) { store.editInStudio(tile.id) }
                                    Divider()
                                    Button(L10n.text("Remove widget"), role: .destructive) { store.removeTile(tile.id) }
                                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
                            }
                            Text("\(L10n.text(tile.size.rawValue.capitalized)) · \(L10n.text(tile.palette.capitalized))").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding(32)
        }
    }
}

struct SpacesPage: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    @State private var name = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: L10n.text("Desktop layouts"), title: L10n.text("Spaces"), subtitle: L10n.text("Save and switch widget layouts."))
                    Spacer()
                    Menu(L10n.text("Starter layouts")) {
                        Button(L10n.text("Play")) { store.addStarterSpace("Play", kinds: [.pet, .sticker, .dice, .game]) }
                        Button(L10n.text("Personal")) { store.addStarterSpace("Personal", kinds: [.photo, .quote, .canvas, .music]) }
                        Button(L10n.text("Daily dashboard")) { store.addStarterSpace(L10n.text("Daily dashboard"), kinds: [.weather, .water, .clock, .launcher]) }
                    }
                    Button(L10n.text("Import space…")) { store.chooseImport() }
                }
                HStack {
                    TextField(L10n.text("Name a new space"), text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 300).onSubmit(create)
                    Button(L10n.text("Create space"), action: create).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(store.document.spaces) { space in
                    SpaceRow(space: space)
                }
                Text(L10n.text("Spaces arrange iGet’s desktop widgets. Widgets placed through macOS keep their system-managed positions."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(32)
        }
    }
    private func create() { store.newSpace(name); name = "" }
}

private struct SpaceRow: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let space: WorkspaceSpace
    @EnvironmentObject private var store: WorkspaceStore
    @State private var name = ""
    @FocusState private var editing: Bool
    private var active: Bool { space.id == store.document.activeSpaceID }
    var body: some View {
        Surface {
            HStack(spacing: 22) {
                Image(systemName: space.symbol).font(.system(size: 25, weight: .light)).foregroundStyle(.secondary).frame(width: 35)
                VStack(alignment: .leading, spacing: 9) {
                    TextField(L10n.text("Space name"), text: $name).textFieldStyle(.plain).font(.system(size: 17, weight: .medium)).focused($editing).onSubmit(rename).onChange(of: editing) { _, value in if !value { rename() } }
                    HStack(spacing: 12) {
                        ForEach(Array(Set(space.tiles.map(\.kind))).sorted { $0.rawValue < $1.rawValue }) { kind in Image(systemName: kind.symbol).help(kind.title) }
                        Text(L10n.count(space.tiles.count, one: "%d widget", other: "%d widgets"))
                    }.font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(active ? L10n.text("Active") : L10n.text("Use space")) { store.activateSpace(space.id) }.buttonStyle(.bordered).disabled(active)
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
                    Button(L10n.text("Delete space"), role: .destructive) { store.removeSpace(space.id) }.disabled(store.document.spaces.count <= 1)
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
            }
        }.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(active ? Color.accentColor.opacity(0.5) : .clear))
            .onAppear { name = space.name }.onChange(of: space.name) { _, value in if !editing { name = value } }
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

struct ImportReviewView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeading(eyebrow: L10n.text("SPACE IMPORT"), title: store.pendingPack?.name ?? L10n.text("Import space"), subtitle: L10n.text("Review this space before adding it."))
            if let pack = store.pendingPack {
                HStack(spacing: 10) {
                    ForEach(pack.tiles.prefix(6)) { tile in Image(systemName: tile.kind.symbol).font(.title3).padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8)) }
                }
                Text(L10n.format("%d widgets · Schema %d", pack.tiles.count, pack.schemaVersion)).font(.system(size: 12)).foregroundStyle(.secondary)
                if pack.tiles.contains(where: { $0.kind == .weather || $0.kind == .music }) { Text(L10n.text("Connected widgets use their built-in service providers when active. Music still requires you to connect the player.")).font(.system(size: 11)).foregroundStyle(.secondary) }
                if pack.tiles.contains(where: { $0.settings.photo != nil || $0.settings.bodyText != nil }) { Text(L10n.text("This pack includes widget photos or custom text.")).font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("Built-in widgets and editable settings"), systemImage: "checkmark")
                Label(L10n.text("No executable scripts"), systemImage: "checkmark")
                Label(L10n.text("Your shared tasks and notes stay as they are"), systemImage: "checkmark")
            }.font(.system(size: 12))
            HStack { Spacer(); Button(L10n.text("Cancel")) { store.pendingPack = nil }; Button(L10n.text("Import space")) { store.importPack() }.buttonStyle(.borderedProminent) }
        }.padding(32).frame(width: 500)
    }
}
