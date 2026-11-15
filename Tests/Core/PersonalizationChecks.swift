import Foundation

enum PersonalizationChecks {
    static func run() throws {
        typealias T = WorkspaceTests
        var document = WorkspaceDocument.initial
        let original = DesktopTile(kind: .clock)
        let data = try JSONEncoder().encode(original)
        var legacyJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        legacyJSON.removeValue(forKey: "options")
        let migrated = try JSONDecoder().decode(DesktopTile.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        try T.expect(migrated.options == nil && migrated.displayWidth == 180 && migrated.settings.fontScale == 1, "Legacy tiles keep default dimensions and style")
        var tile = original
        var options = WidgetOptions()
        options.width = 512; options.height = 280; options.title = "My clock"; options.timeZone = "Asia/Tokyo"
        options.customColors = true; options.backgroundHex = "#FCE6FF"; options.foregroundHex = "#321144"
        options.typeface = .serif; options.placement = .floating; options.clickThrough = true
        options.layers = CanvasLayer.starter
        tile.settings = options
        try ThemePack.validate(tile)
        let restored = try JSONDecoder().decode(DesktopTile.self, from: JSONEncoder().encode(tile))
        try T.expect(restored == tile && restored.displayWidth == 512 && restored.displayHeight == 280, "Per-widget appearance round-trips")
        try T.expect(CanvasLayer.starter.map(\.id) == CanvasLayer.starter.map(\.id), "Starter layer identities are stable")
        func rejected(_ mutation: (inout WidgetOptions) -> Void) throws {
            var bad = options; mutation(&bad)
            do { try bad.validate() } catch { T.checks += 1; return }
            throw T.Failure(message: "Invalid widget options were accepted")
        }
        try rejected { $0.width = 1 }
        try rejected { $0.height = 5000 }
        try rejected { $0.opacity = -0.2 }
        try rejected { $0.fontScale = 5 }
        try rejected { $0.backgroundHex = "javascript:run" }
        try rejected { $0.timeZone = "Imaginary/Place" }
        try rejected { $0.photo = Data(repeating: 0, count: 524_289) }
        try rejected { $0.counter = Int.min }
        try rejected { $0.dice = [0, 7] }
        try rejected { $0.layers = Array(repeating: CanvasLayer(), count: 31) }
        try rejected { $0.layers = [CanvasLayer(fontSize: 0)] }
        try rejected { $0.game.cells = [1] }
        var game = NoughtsGame()
        for cell in [0, 3, 1, 4, 2] { game.move(cell) }
        try T.expect(game.winner == 1 && game.finished, "A row wins")
        let won = game
        game.move(8)
        try T.expect(game == won, "Moves after a win are ignored")
        var draw = NoughtsGame()
        for cell in [0, 1, 2, 4, 3, 5, 7, 6, 8] { draw.move(cell) }
        try T.expect(draw.finished && draw.winner == nil, "A full board can draw")
        for line in [[0,4,8], [0,3,6], [2,4,6]] {
            var value = NoughtsGame()
            let others = (0..<9).filter { !line.contains($0) }
            for cell in [line[0], others[0], line[1], others[1], line[2]] { value.move(cell) }
            try T.expect(value.winner == 1, "Columns and diagonals win")
        }
        for _ in 0..<40 {
            var value = NoughtsGame()
            while !value.finished {
                let empty = value.cells.indices.filter { value.cells[$0] == 0 }
                value.move(empty.randomElement()!)
                try value.validate()
            }
        }
        try T.expect(true, "Random complete games preserve valid states")
        var water = WidgetOptions()
        water.dailyKey = "2000-01-01"; water.counter = 99
        try T.expect(water.todayCount == 0, "Water resets across dates")
        water.addWater(1)
        try T.expect(water.todayCount == 1 && water.dailyKey == LocalHabit.dayKey(), "First glass starts today's count")
        water.addWater(-100)
        try T.expect(water.todayCount == 0, "Water cannot become negative")
        var quote = WidgetOptions()
        quote.bodyText = "First\nSecond\nThird"; quote.quoteIndex = 4
        try T.expect(quote.displayedQuote == "Second", "Custom quote rotation")
        quote.quoteIndex = Int.min
        try T.expect(!quote.displayedQuote.isEmpty, "Quote indices remain safe")
        try T.expect(BreathingCycle.phase(at: 0) == 0 && BreathingCycle.phase(at: 4) == 1 && BreathingCycle.phase(at: 8) == 2, "Breathing phases")
        try T.expect(!BreathingCycle.finished(at: 59) && BreathingCycle.finished(at: 60), "Breathing ends after one minute")
        let website = LaunchShortcut(title: "Project", website: "https://github.com/TwoBit-Dev/iGet")
        try website.validate()
        try T.expect(website.validatedWebsite?.host == "github.com", "Website shortcuts resolve safely")
        for address in ["javascript:alert(1)", "file:///etc/passwd", "https://name:secret@example.com"] {
            let item = LaunchShortcut(title: "Invalid", website: address)
            do { try item.validate() } catch { T.checks += 1; continue }
            throw T.Failure(message: "Unsafe shortcut accepted")
        }
        let application = LaunchShortcut(title: "Safari", bundleIdentifier: "com.apple.Safari")
        try application.validate()
        document.tasks = [LocalTask(title: "One", completed: true), LocalTask(title: "Two")]
        var layer = CanvasLayer(kind: .progress, source: .tasks)
        try T.expect(layer.resolvedProgress(document: document, options: options) == 0.5, "Canvas binds to real task progress")
        layer.source = .water; water.goal = 4; water.addWater(2)
        try T.expect(layer.resolvedProgress(document: document, options: water) == 0.5, "Canvas binds to water count")
        layer.source = .focus
        let now = Date(); document.focus.endDate = now.addingTimeInterval(750)
        try T.expect(layer.resolvedProgress(document: document, options: options, at: now) == 0.5, "Canvas binds to a running focus deadline")
        let pack = ThemePack(name: "Custom", tiles: [tile])
        let encoded = try JSONEncoder().encode(pack)
        try T.expect(try ThemePack.decode(encoded).tiles.first == tile, "Customized theme packs round-trip")
        var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        var tiles = json["tiles"] as! [[String: Any]]
        var config = tiles[0]["options"] as! [String: Any]
        config["script"] = "do something"; tiles[0]["options"] = config; json["tiles"] = tiles
        do { _ = try ThemePack.decode(JSONSerialization.data(withJSONObject: json)) } catch { T.checks += 1; return }
        throw T.Failure(message: "Unknown executable fields were accepted")
    }
}
