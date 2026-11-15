import AppKit
import ImageIO
import UniformTypeIdentifiers

extension WorkspaceStore {
    func customize(_ id: UUID, _ edit: (inout WidgetOptions) -> Void) {
        editTile(id) { tile in var options = tile.settings; edit(&options); tile.settings = options }
    }
    func editInStudio(_ id: UUID) { editingTileID = id; page = .studio; MainWindowRegistry.show() }
    func createAndCustomize(_ kind: ToolKind, size: TileSize? = nil, palette: String? = nil) {
        let previous = Set(document.activeTiles.map(\.id))
        let targetSize = size ?? (kind == .canvas || kind == .game ? .large : .small)
        let targetPalette = palette ?? kind.defaultPalette
        addTile(kind, size: targetSize, palette: targetPalette)
        guard let tile = document.activeTiles.last, !previous.contains(tile.id) else { return }
        selectedTool = nil
        editInStudio(tile.id)
    }
    func duplicateTile(_ id: UUID) {
        change { value in
            guard let index = value.spaces.firstIndex(where: { $0.id == value.activeSpaceID }),
                  let tile = value.spaces[index].tiles.first(where: { $0.id == id }) else { return }
            var copy = tile; copy.id = UUID(); copy.x += 24; copy.y += 24
            value.spaces[index].tiles.append(copy)
        }
    }
    func rollDice(_ id: UUID) { customize(id) { $0.dice = [Int.random(in: 1...6), Int.random(in: 1...6)] } }
    func gameMove(_ id: UUID, cell: Int) { customize(id) { $0.game.move(cell) } }
    func resetGame(_ id: UUID) { customize(id) { $0.game = NoughtsGame() } }
    func addWater(_ id: UUID, delta: Int) { customize(id) { $0.addWater(delta) } }
    func nextQuote(_ id: UUID) { customize(id) { $0.quoteIndex = ($0.quoteIndex % 1_000_000) + 1 } }
    func petAction(_ id: UUID, action: Int) {
        customize(id) { options in
            switch action {
            case 0: options.petEnergy = min(100, options.petEnergy + 15); options.petAction = "Fed"
            case 1: options.petEnergy = max(0, options.petEnergy - 10); options.petAction = options.petEnergy == 0 ? "Tired" : "Playing"
            default: options.petEnergy = min(100, options.petEnergy + 25); options.petAction = "Rested"
            }
        }
    }
    func choosePhoto(for id: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importPhoto(url, for: id)
    }
    func importPhoto(_ url: URL, for id: UUID) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20 * 1_048_576 else { throw WorkspaceError.oversized }
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 900, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { throw WorkspaceError.invalidData }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw WorkspaceError.invalidData }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
            guard CGImageDestinationFinalize(destination), data.length <= 524_288 else { throw WorkspaceError.storage(L10n.text("Choose a smaller photo. The optimized image must fit within 512 KB.")) }
            customize(id) { $0.photo = data as Data }
        } catch { errorMessage = error.localizedDescription }
    }
    func chooseApplication(for id: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? url.deletingPathExtension().lastPathComponent
        customize(id) { $0.shortcuts.append(LaunchShortcut(title: String(name.prefix(80)), bundleIdentifier: identifier, symbol: "app")) }
    }
    func openShortcut(_ shortcut: LaunchShortcut) {
        do {
            try shortcut.validate()
            if let url = shortcut.validatedWebsite { NSWorkspace.shared.open(url) }
            else if let bundle = shortcut.bundleIdentifier, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) { NSWorkspace.shared.open(url) }
            else { errorMessage = L10n.text("This application is not installed on this Mac.") }
        } catch { errorMessage = error.localizedDescription }
    }
    func addCanvasLayer(_ id: UUID, kind: CanvasContent) {
        customize(id) { options in
            if options.layers == nil { options.layers = CanvasLayer.localizedStarter }
            options.layers?.append(CanvasLayer(kind: kind, text: kind == .symbol ? "✨" : kind == .text ? L10n.text("Your text") : "", y: 0.55, fontSize: kind == .symbol ? 44 : 24))
        }
    }
}

extension WorkspaceStore {
    func addStarterSpace(_ name: String, kinds: [ToolKind]) {
        change { value in
            var space = WorkspaceSpace.preset(name, kinds: kinds)
            space.tiles = space.tiles.enumerated().map { index, tile in
                var tile = tile
                if tile.kind == .game || tile.kind == .canvas { tile.size = .large }
                tile.x = 60 + Double(index % 3) * 365
                tile.y = 80 + Double(index / 3) * 365
                if tile.kind == .sticker { var options = tile.settings; options.showHeader = false; options.backdrop = .transparent; options.borderWidth = 0; tile.settings = options }
                return tile
            }
            value.spaces.append(space)
            value.activeSpaceID = space.id
        }
    }
}
