import Foundation

struct LocalizationChecks {
    static func run() throws {
        let expect = WorkspaceTests.expect
        let manager = LocalizationManager.shared
        let saved = manager.selection
        defer { manager.select(saved) }
        try expect(AppLanguage.resolve(.system, preferredLanguages: ["tr-TR"]) == .turkish, "Turkish system locale")
        try expect(AppLanguage.resolve(.system, preferredLanguages: ["de_AT"]) == .german, "German regional locale")
        try expect(AppLanguage.resolve(.system, preferredLanguages: ["fr-FR", "tr-TR"]) == .turkish, "First supported system preference")
        try expect(AppLanguage.resolve(.system, preferredLanguages: ["ja-JP"]) == .english, "Unsupported language falls back to English")
        try expect(AppLanguage.resolve(.german, preferredLanguages: ["tr-TR"]) == .german, "Explicit choice overrides system")
        manager.select(.turkish)
        try expect(ToolKind.tasks.title == "Görevler" && L10n.text("Settings") == "Ayarlar", "Turkish labels use central manager")
        manager.select(.german)
        try expect(ToolKind.tasks.title == "Aufgaben" && L10n.text("Settings") == "Einstellungen", "German selection replaces current labels")
        try expect(L10n.count(1, one: "%d widget", other: "%d widgets") == "1 Widget" && L10n.count(2, one: "%d widget", other: "%d widgets") == "2 Widgets", "Count forms follow the selected language")
        try expect(L10n.format("%@ wins", "X") == "X gewinnt", "Dynamic values use translated templates")
        try expect(manager.text("A user’s note") == "A user’s note", "Unknown text is preserved")
        manager.select(.english)
        let labels = ToolKind.allCases.flatMap { [$0.title, $0.summary, $0.category] }
        try expect(labels.allSatisfy { LocalizationCatalog.entries[$0] != nil }, "Every widget title, summary and category has translations")
        let optionLabels = WidgetBackdrop.allCases.map { $0.rawValue.capitalized } + WidgetPlacement.allCases.map { $0.rawValue.capitalized } + WidgetTypeface.allCases.map { $0.rawValue.capitalized } + CanvasContent.allCases.map { $0.rawValue.capitalized } + CanvasDataSource.allCases.map { $0.rawValue.capitalized } + TileSize.allCases.map { $0.rawValue.capitalized } + AppearanceMode.allCases.map { $0.rawValue.capitalized }
        try expect(optionLabels.allSatisfy { LocalizationCatalog.entries[$0] != nil }, "Every inspector option has translations")
        let regex = try NSRegularExpression(pattern: "%[-+0-9.]*[@df]")
        func tokens(_ value: String) -> [String] { regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { String(value[Range($0.range, in: value)!]) } }
        try expect(LocalizationCatalog.entries.allSatisfy { key, entry in
            !entry.tr.isEmpty && !entry.de.isEmpty && tokens(key) == tokens(entry.tr) && tokens(key) == tokens(entry.de)
        }, "All catalog entries have both translations and matching format types")
        let old = try JSONEncoder().encode(WorkspaceDocument.initial)
        var object = try JSONSerialization.jsonObject(with: old) as! [String: Any]
        var preferences = object["preferences"] as! [String: Any]
        preferences.removeValue(forKey: "language")
        object["preferences"] = preferences
        let decoded = try JSONDecoder().decode(WorkspaceDocument.self, from: JSONSerialization.data(withJSONObject: object))
        try expect(decoded.preferences.language == nil, "Old documents default to system without migration failure")
        var document = decoded
        document.preferences.language = .turkish
        document.note = "Do not translate my note"
        let roundtrip = try JSONDecoder().decode(WorkspaceDocument.self, from: JSONEncoder().encode(document))
        try expect(roundtrip.preferences.language == .turkish && roundtrip.note == document.note, "Language round-trip preserves user data")
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMMM"
        let date = Date(timeIntervalSince1970: 0)
        manager.select(.turkish); formatter.locale = manager.locale
        let turkish = formatter.string(from: date)
        manager.select(.german); formatter.locale = manager.locale
        try expect(turkish == "Ocak" && formatter.string(from: date) == "Januar", "Month names use the selected language")
    }
}
