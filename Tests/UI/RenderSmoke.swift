import AppKit
import SwiftUI

@main
@MainActor
struct RenderSmoke {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/previews")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("iget-render-\(UUID().uuidString).sqlite")
        defer {
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: databaseURL.path + suffix) }
        }
        let store = WorkspaceStore(databaseURL: databaseURL, allowsExternalConnections: false)
        store.change { value in
            value.tasks = [LocalTask(title: "Review the desktop layout", completed: true), LocalTask(title: "Read a chapter"), LocalTask(title: "Plan the week ahead")]
            value.note = "Shopping list\n\nCoffee\nNotebook\nUSB-C cable"
            value.habits = [LocalHabit(title: "Read"), LocalHabit(title: "Go for a walk")]
            value.countdown = LocalCountdown(title: "A weekend away", date: Date().addingTimeInterval(12 * 86400))
        }
        store.change { value in
            value.spaces[0].tiles.append(DesktopTile(kind: .canvas, size: .large, palette: "aurora"))
            value.spaces[0].tiles.append(DesktopTile(kind: .pet, palette: "peach"))
            value.spaces[0].tiles.append(DesktopTile(kind: .sticker, palette: "aurora"))
            value.spaces[0].tiles.append(DesktopTile(kind: .photo, palette: "rose"))
        }
        store.editingTileID = store.document.activeTiles.first { $0.kind == .canvas }?.id
        let baseOutput = output
        for language in [AppLanguage.english, .turkish, .german] {
            store.preferences { $0.language = language }
            let output = language == .english ? baseOutput : baseOutput.appendingPathComponent(language.rawValue)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for appearance in [AppearanceMode.light, .dark] {
                store.preferences { $0.appearance = appearance }
                for page in WorkspacePage.allCases {
                    store.page = page
                    let view = MainShellView().environmentObject(store).frame(width: 1180, height: 800)
                    try render(view, size: CGSize(width: 1180, height: 800), url: output.appendingPathComponent("\(page.id.replacingOccurrences(of: " ", with: "-").lowercased())-\(appearance.rawValue).png"))
                }
                for tool in ToolKind.allCases {
                    let view = ToolEditorView(kind: tool).environmentObject(store).preferredColorScheme(appearance == .dark ? .dark : .light)
                    try render(view, size: CGSize(width: 650, height: 590), url: output.appendingPathComponent("tool-\(tool.rawValue)-\(appearance.rawValue).png"))
                }
                try render(StudioPage(tab: "Layers").environmentObject(store).preferredColorScheme(appearance == .dark ? .dark : .light).frame(width: 984, height: 752), size: CGSize(width: 984, height: 752), url: output.appendingPathComponent("canvas-editor-\(appearance.rawValue).png"))
                for tool in ToolKind.allCases {
                    for size in TileSize.allCases {
                        let scale: CGFloat = size == .large ? 1 : 0.8
                        let dimensions = CGSize(width: size == .small ? 141 : 300, height: size == .large ? 300 : 141)
                        let view = LiveTile(tile: DesktopTile(kind: tool, size: size, palette: tool.defaultPalette), interactive: false).environmentObject(store)
                            .frame(width: dimensions.width / scale, height: dimensions.height / scale)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: dimensions.width, height: dimensions.height, alignment: .topLeading)
                            .preferredColorScheme(appearance == .dark ? .dark : .light)
                        try render(view, size: dimensions, url: output.appendingPathComponent("widget-\(tool.rawValue)-\(size.rawValue)-\(appearance.rawValue).png"))
                    }
                }
            }
            store.page = .gallery
            try render(MainShellView().environmentObject(store).frame(width: 1040, height: 700), size: CGSize(width: 1040, height: 700), url: output.appendingPathComponent("minimum-window.png"))
        }
        print("Rendered 555 page, tool and widget views in English, Turkish and German to \(baseOutput.path)")
    }
    static func render<V: View>(_ view: V, size: CGSize, url: URL) throws {
        let hosting = NSHostingView(rootView: view.environment(\.locale, LocalizationManager.shared.locale))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw CocoaError(.coderInvalidValue) }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.coderInvalidValue) }
        try data.write(to: url)
        window.contentView = nil
        window.close()
    }
}
