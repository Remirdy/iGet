import AppKit
import Foundation

@main
@MainActor
struct WorkspaceStoreTests {
    static var checks = 0
    struct Failure: Error { let description: String }
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw Failure(description: message) }
        checks += 1
    }
    static func pumpRunLoop(until condition: () -> Bool = { false }, timeout: TimeInterval = 0.5) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        } while !condition() && Date() < deadline
    }
    static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("integration.sqlite")
        let store = WorkspaceStore(databaseURL: url, allowsExternalConnections: false)
        try expect(store.errorMessage == nil, "Store opens")
        store.addTask("  Review changes  ")
        try expect(store.document.tasks.first?.title == "Review changes", "Task input is normalized")
        let task = store.document.tasks[0]
        store.setTask(task.id, completed: true)
        store.setTask(task.id, completed: true)
        try expect(store.document.tasks[0].completed, "Repeated completion keeps its target state")
        store.removeTask(task.id)
        try expect(store.document.tasks.isEmpty && store.canUndo, "Task removal offers undo")
        store.undo()
        try expect(store.document.tasks == [LocalTask(id: task.id, title: task.title, completed: true, createdAt: task.createdAt)], "Task undo restores identity")
        let initialSpace = store.document.activeSpaceID!
        let count = store.document.activeTiles.count
        store.addTile(.notes, size: .medium, palette: "paper")
        let tile = store.document.activeTiles.last!
        try expect(store.document.activeTiles.count == count + 1 && tile.size == .medium, "Library adds a configured widget")
        store.editTile(tile.id) { $0.size = .large; $0.palette = "lilac"; $0.x = 200; $0.y = 250 }
        try expect(store.document.activeTiles.last?.size == .large && store.document.activeTiles.last?.x == 200, "Studio persists appearance and placement")
        store.removeTile(tile.id)
        store.undo()
        try expect(store.document.activeTiles.last?.id == tile.id, "Widget undo restores identity")
        store.newSpace("  A new place  ")
        let newID = store.document.activeSpaceID!
        try expect(store.document.activeSpace?.name == "A new place" && store.document.activeTiles.isEmpty, "New space is independent")
        store.activateSpace(initialSpace)
        try expect(store.document.activeTiles.count == count + 1, "Switching restores the previous layout")
        store.removeSpace(newID)
        store.undo()
        try expect(store.document.spaces.contains(where: { $0.id == newID }), "Space deletion can be undone")
        store.pendingPack = ThemePack(name: "Imported", tiles: [tile, tile])
        store.importPack()
        let imported = store.document.activeTiles
        try expect(imported.count == 2 && Set(imported.map(\.id)).count == 2 && !imported.contains(where: { $0.id == tile.id }), "Import creates fresh widget identities")
        try expect(store.document.tasks.first?.id == task.id, "Theme import preserves productivity data")
        store.preferences { $0.energy = .saver }
        try expect(store.samplingInterval == 15, "Power saver applies immediately")
        store.change { $0.desktopVisible = false }
        store.visiblePageNeedsSystem = false
        store.visiblePageNeedsBattery = false
        store.updateDemand()
        try expect(!store.resources.isSampling, "Hidden providers stop")
        store.visiblePageNeedsSystem = true
        store.updateDemand()
        try expect(store.resources.isSampling, "Opening the system tool starts sampling")
        store.visiblePageNeedsSystem = false
        store.updateDemand()
        try expect(!store.resources.isSampling, "Closing the system tool stops sampling")
        store.toggleFocus()
        try expect(store.document.focus.isRunning, "Focus starts from the controller")
        store.toggleFocus()
        try expect(!store.document.focus.isRunning && store.document.focus.remaining > 0, "Focus pauses from the controller")
        store.resetFocus()
        let backup = directory.appendingPathComponent("backup.json")
        var previous = store.document
        previous.note = "Restored note"
        try JSONEncoder().encode(previous).write(to: backup)
        store.restoreBackup(from: backup)
        try expect(store.document.note == "Restored note", "Backup restore validates and saves")
        store.undo()
        try expect(store.document.note.isEmpty, "Backup restore can be undone")
        let reloaded = WorkspaceStore(databaseURL: url, allowsExternalConnections: false)
        try expect(reloaded.document.tasks == store.document.tasks && reloaded.document.activeSpaceID == store.document.activeSpaceID, "Controller state survives reopening")
        store.activateSpace(initialSpace)
        store.change { $0.desktopVisible = true }
        let overlays = OverlayWindowManager(store: store, showsWindows: false)
        pumpRunLoop { overlays.windowFrames.count == store.document.activeTiles.filter(\.enabled).count }
        try expect(overlays.windowFrames.count == store.document.activeTiles.filter(\.enabled).count, "Desktop creates one window per enabled widget")
        store.editTile(tile.id) { $0.size = .medium }
        pumpRunLoop { overlays.windowFrames[tile.id]?.width == 340 && overlays.windowFrames[tile.id]?.height == 204 }
        try expect(overlays.windowFrames[tile.id]?.width == 340 && overlays.windowFrames[tile.id]?.height == 204, "Studio resizes an existing desktop window")
        store.change { $0.desktopVisible = false }
        pumpRunLoop { overlays.windowFrames.isEmpty }
        try expect(overlays.windowFrames.isEmpty, "Hiding widgets releases desktop windows")
        overlays.stop()
        reloaded.change { $0.desktopVisible = false }
        store.resources.configure(system: false, battery: false, interval: 15)
        store.newSpace("Personalization tests")
        for kind in ToolKind.allCases.filter({ !$0.isOriginal }) { store.addTile(kind, size: .small, palette: kind.defaultPalette) }
        try expect(store.document.activeTiles.count == 12, "Every new widget type can be added")
        let dice = store.document.activeTiles.first { $0.kind == .dice }!
        for _ in 0..<20 { store.rollDice(dice.id) }
        let diceOptions = store.document.activeTiles.first { $0.id == dice.id }!.settings
        try expect(diceOptions.dice.count == 2 && diceOptions.dice.allSatisfy({ (1...6).contains($0) }), "Dice actions persist legal rolls")
        let game = store.document.activeTiles.first { $0.kind == .game }!
        for cell in [0,3,1,4,2] { store.gameMove(game.id, cell: cell) }
        try expect(store.document.activeTiles.first { $0.id == game.id }?.settings.game.winner == 1, "Desktop game actions reach the stored board")
        store.resetGame(game.id)
        try expect(store.document.activeTiles.first { $0.id == game.id }?.settings.game.cells == Array(repeating: 0, count: 9), "New game clears the board")
        let water = store.document.activeTiles.first { $0.kind == .water }!
        store.addWater(water.id, delta: 1); store.addWater(water.id, delta: 1)
        try expect(store.document.activeTiles.first { $0.id == water.id }?.settings.todayCount == 2, "Water controls persist")
        let pet = store.document.activeTiles.first { $0.kind == .pet }!
        store.petAction(pet.id, action: 1); store.petAction(pet.id, action: 0)
        try expect(store.document.activeTiles.first { $0.id == pet.id }?.settings.petEnergy == 80, "Pet actions update energy")
        let canvas = store.document.activeTiles.first { $0.kind == .canvas }!
        store.addCanvasLayer(canvas.id, kind: .text)
        let layers = store.document.activeTiles.first { $0.id == canvas.id }!.settings.layers!
        try expect(layers.count == 4 && Set(layers.map(\.id)).count == 4, "Canvas adds editable stable layers")
        store.customize(canvas.id) { $0.width = 408; $0.height = 264; $0.placement = .floating; $0.clickThrough = true; $0.shadow = true }
        let customWindows = OverlayWindowManager(store: store, showsWindows: false)
        pumpRunLoop { customWindows.windowFrames[canvas.id]?.size == CGSize(width: 408, height: 288) }
        try expect(customWindows.windowFrames[canvas.id]?.size == CGSize(width: 408, height: 288), "Free dimensions reach native windows")
        try expect(customWindows.floatingIDs.contains(canvas.id) && customWindows.clickThroughIDs.contains(canvas.id) && customWindows.shadowIDs.contains(canvas.id), "Window layer, click-through and shadow settings apply")
        let photo = store.document.activeTiles.first { $0.kind == .photo }!
        if let root = ProcessInfo.processInfo.environment["IGET_RESOURCE_ROOT"] {
            store.importPhoto(URL(fileURLWithPath: root + "/Config/BrandLogo.png"), for: photo.id)
            try expect(store.document.activeTiles.first { $0.id == photo.id }?.settings.photo?.isEmpty == false, "Photo import optimizes and persists an actual image")
        }
        let packed = try JSONEncoder().encode(ThemePack(name: "Personalization", tiles: store.document.activeTiles))
        let unpacked = try ThemePack.decode(packed)
        try expect(unpacked.tiles == store.document.activeTiles, "All personalized content survives space export")
        let finalConnection = WorkspaceStore(databaseURL: url, allowsExternalConnections: false)
        try expect(finalConnection.document.activeTiles == store.document.activeTiles, "New widgets survive reopening")
        store.duplicateTile(canvas.id)
        try expect(store.document.activeTiles.count == 13 && Set(store.document.activeTiles.map(\.id)).count == 13, "Widget duplication creates a new identity")
        customWindows.stop()
        store.change { $0.desktopVisible = false }
        finalConnection.change { $0.desktopVisible = false }
        var clockRefreshes = 0
        let clockObservation = store.objectWillChange.sink { clockRefreshes += 1 }
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        pumpRunLoop { clockRefreshes > 0 }
        try expect(clockRefreshes > 0, "Daily widgets refresh at the calendar boundary without polling")
        clockObservation.cancel()
        try expect(store.errorMessage == nil && reloaded.errorMessage == nil, "All mutations succeed")
        let beforeLanguage = store.document
        store.preferences { $0.language = .turkish }
        try expect(LocalizationManager.shared.language == .turkish && ToolKind.clock.title == "Saat", "Settings changes the live language")
        let languageConnection = WorkspaceStore(databaseURL: url, allowsExternalConnections: false)
        try expect(languageConnection.document.preferences.language == .turkish && LocalizationManager.shared.language == .turkish, "Explicit language survives reopening")
        store.preferences { $0.language = .german }
        try expect(LocalizationManager.shared.language == .german && ToolKind.clock.title == "Uhr", "A second language change reaches desktop labels")
        try expect(store.document.tasks == beforeLanguage.tasks && store.document.note == beforeLanguage.note && store.document.spaces == beforeLanguage.spaces, "Language changes preserve all user content and layouts")
        store.preferences { $0.language = .system }
        try expect(LocalizationManager.shared.selection == .system && LocalizationManager.shared.language == AppLanguage.resolve(.system), "System choice restores macOS language resolution")
        print("Passed \(checks) integration checks: tools, layouts, imports, undo, restore, persistence and provider lifecycle.")
    }
}
