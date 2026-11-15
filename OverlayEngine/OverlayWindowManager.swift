import AppKit
import SwiftUI
import Combine

@MainActor
final class OverlayWindowManager {
    private var windows: [UUID: NSPanel] = [:]
    private var configurations: [UUID: DesktopTile] = [:]
    private weak var store: WorkspaceStore?
    private var subscription: AnyCancellable?
    private var screenObserver: AnyCancellable?
    private let showsWindows: Bool
    var clickThroughIDs: Set<UUID> { Set(windows.filter { $0.value.ignoresMouseEvents }.map(\.key)) }
    var floatingIDs: Set<UUID> { Set(windows.filter { $0.value.level == .floating }.map(\.key)) }
    var shadowIDs: Set<UUID> { Set(windows.filter { $0.value.hasShadow }.map(\.key)) }
    var windowFrames: [UUID: CGRect] { windows.mapValues(\.frame) }
    init(store: WorkspaceStore, showsWindows: Bool = true) {
        self.store = store
        self.showsWindows = showsWindows
        subscription = store.$document.receive(on: DispatchQueue.main).sink { [weak self] document in
            self?.reconcile(document)
        }
        screenObserver = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.clampAll()
        }
    }
    func stop() {
        subscription = nil
        screenObserver = nil
        for window in windows.values { window.close() }
        windows.removeAll()
        configurations.removeAll()
    }
    private func reconcile(_ document: WorkspaceDocument) {
        guard let store else { return }
        let visible = document.desktopVisible ? document.activeTiles.filter(\.enabled) : []
        let ids = Set(visible.map(\.id))
        for id in Array(windows.keys) where !ids.contains(id) {
            windows.removeValue(forKey: id)?.close()
            configurations.removeValue(forKey: id)
        }
        for tile in visible {
            if let window = windows[tile.id] {
                if configurations[tile.id] != tile {
                    let frame = clamp(CGRect(x: tile.x, y: tile.y, width: tile.displayWidth, height: tile.displayHeight + 24))
                    window.setFrame(frame, display: true)
                    if let old = configurations[tile.id], old.displayWidth != tile.displayWidth || old.displayHeight != tile.displayHeight { window.contentView = makeContent(tile, store: store) }
                    configure(window, tile: tile)
                    configurations[tile.id] = tile
                }
            } else {
                let window = DesktopPanel(contentRect: clamp(CGRect(x: tile.x, y: tile.y, width: tile.displayWidth, height: tile.displayHeight + 24)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = tile.settings.shadow
                window.isReleasedWhenClosed = false
                window.hidesOnDeactivate = false
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                window.isExcludedFromWindowsMenu = true
                window.contentView = makeContent(tile, store: store)
                configure(window, tile: tile)
                windows[tile.id] = window
                configurations[tile.id] = tile
                if showsWindows { window.orderFrontRegardless() }
            }
        }
    }
    private func configure(_ window: NSPanel, tile: DesktopTile) {
        switch tile.settings.placement {
        case .desktop: window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .normal: window.level = .normal
        case .floating: window.level = .floating
        }
        window.ignoresMouseEvents = tile.settings.clickThrough
        window.hasShadow = tile.settings.shadow
    }
    private func makeContent(_ tile: DesktopTile, store: WorkspaceStore) -> NSView {
        let hosting = NSHostingView(rootView: DesktopWidgetView(initialTile: tile).environmentObject(store).frame(width: tile.displayWidth, height: tile.displayHeight + 24))
        hosting.sizingOptions = []
        return hosting
    }
    private func clamp(_ frame: CGRect) -> CGRect {
        let screens = NSScreen.screens.map(\.visibleFrame)
        guard let screen = screens.max(by: { area($0.intersection(frame)) < area($1.intersection(frame)) }) else { return frame }
        return CGRect(x: min(max(frame.minX, screen.minX), max(screen.minX, screen.maxX - frame.width)),
                      y: min(max(frame.minY, screen.minY), max(screen.minY, screen.maxY - frame.height)), width: frame.width, height: frame.height)
    }
    private func area(_ frame: CGRect) -> CGFloat { frame.isNull ? 0 : frame.width * frame.height }
    private func clampAll() {
        for window in windows.values { window.setFrame(clamp(window.frame), display: true) }
    }
}

private final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct DesktopWidgetView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let initialTile: DesktopTile
    @EnvironmentObject private var store: WorkspaceStore
    private var tile: DesktopTile { store.document.activeTiles.first { $0.id == initialTile.id } ?? initialTile }
    @State private var hovering = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if !store.document.preferences.lockLayout && !tile.settings.locked {
                    WidgetDragHandle(snapEdges: tile.settings.snapToGrid) { point in store.editTile(tile.id) {
                        $0.x = tile.settings.snapToGrid ? (Double(point.x) / 8.0).rounded() * 8.0 : Double(point.x)
                        $0.y = tile.settings.snapToGrid ? (Double(point.y) / 8.0).rounded() * 8.0 : Double(point.y)
                    } }
                        .overlay(Image(systemName: "line.3.horizontal").font(.system(size: 9)).allowsHitTesting(false))
                        .frame(maxWidth: .infinity)
                        .help(L10n.text("Drag to move widget"))
                } else { Spacer() }
                Button {
                    store.editInStudio(tile.id)
                } label: { Image(systemName: "arrow.up.right").font(.system(size: 9)) }.buttonStyle(.plain).help(L10n.format("Open %@", tile.kind.title))
                Button { store.removeTile(tile.id) } label: { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain).help(L10n.text("Remove widget"))
            }.padding(.horizontal, 10).frame(height: 24).foregroundStyle(.primary)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7)).opacity(hovering ? 1 : 0)
            LiveTile(tile: tile)
                .contextMenu {
                    Button(L10n.text("Customize")) { store.editInStudio(tile.id) }
                    Button(L10n.text("Duplicate")) { store.duplicateTile(tile.id) }
                    Button(L10n.text("Lock position")) { store.customize(tile.id) { $0.locked.toggle() } }
                    Divider()
                    Button(L10n.text("Remove"), role: .destructive) { store.removeTile(tile.id) }
                }
        }.onHover { hovering = $0 }.preferredColorScheme(store.appearance).environment(\.locale, localization.locale)
    }
}

private struct WidgetDragHandle: NSViewRepresentable {
    var snapEdges = true
    let moved: (CGPoint) -> Void
    func makeNSView(context: Context) -> HandleView { let view = HandleView(); view.moved = moved; view.snapEdges = snapEdges; return view }
    func updateNSView(_ nsView: HandleView, context: Context) { nsView.moved = moved; nsView.snapEdges = snapEdges }
    final class HandleView: NSView {
        var moved: ((CGPoint) -> Void)?
        var snapEdges = true
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            window.performDrag(with: event)
            let frame = window.frame
            let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? NSScreen.main
            if let screen {
                let rect = screen.visibleFrame
                var origin = CGPoint(x: max(rect.minX, min(frame.minX, rect.maxX - frame.width)), y: max(rect.minY, min(frame.minY, rect.maxY - frame.height)))
                if snapEdges {
                    if abs(origin.x - rect.minX) < 14 { origin.x = rect.minX }
                    if abs(origin.x + frame.width - rect.maxX) < 14 { origin.x = rect.maxX - frame.width }
                    if abs(origin.y - rect.minY) < 14 { origin.y = rect.minY }
                    if abs(origin.y + frame.height - rect.maxY) < 14 { origin.y = rect.maxY - frame.height }
                }
                window.setFrameOrigin(origin)
            }
            moved?(window.frame.origin)
        }
    }
}

@MainActor
enum MainWindowRegistry {
    static weak var window: NSWindow?
    static var reopen: (() -> Void)?
    static func show() {
        if let window { window.makeKeyAndOrderFront(nil) } else { reopen?() }
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MainWindowReader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { MainWindowRegistry.window = view.window }; return view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
