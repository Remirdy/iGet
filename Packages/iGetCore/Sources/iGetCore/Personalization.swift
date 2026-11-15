import Foundation

enum WidgetBackdrop: String, Codable, CaseIterable { case solid, glass, transparent }
enum WidgetPlacement: String, Codable, CaseIterable { case desktop, normal, floating }
enum WidgetTypeface: String, Codable, CaseIterable { case rounded, system, serif, monospaced }
enum CanvasDataSource: String, Codable, CaseIterable { case manual, tasks, focus, habits, water }

enum CanvasContent: String, Codable, CaseIterable { case text, symbol, time, date, progress }

struct CanvasLayer: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: CanvasContent = .text
    var text = "Text"
    var x = 0.5
    var y = 0.5
    var width = 0.85
    var fontSize = 28.0
    var rotation = 0.0
    var opacity = 1.0
    var colorHex = "#7356CF"
    var progress = 0.65
    var source: CanvasDataSource?
    static let starter: [CanvasLayer] = [CanvasLayer(kind: .text, text: "LOCAL TIME", y: 0.24, fontSize: 11), CanvasLayer(kind: .time, text: "", y: 0.52, fontSize: 42), CanvasLayer(kind: .date, text: "", y: 0.8, fontSize: 12)]
    static var localizedStarter: [CanvasLayer] {
        var layers = starter
        layers[0].text = L10n.text("LOCAL TIME")
        return layers
    }
    func validate() throws {
        guard text.count <= 2000, [x, y, width, opacity, progress].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              width >= 0.05, fontSize.isFinite, (8...120).contains(fontSize), rotation.isFinite,
              (-180...180).contains(rotation), WidgetOptions.validHex(colorHex) else { throw WorkspaceError.invalidData }
    }
}

struct NoughtsGame: Codable, Equatable {
    var cells = Array(repeating: 0, count: 9)
    var turn = 1
    var winner: Int? {
        guard cells.count == 9 else { return nil }
        for line in [[0,1,2], [3,4,5], [6,7,8], [0,3,6], [1,4,7], [2,5,8], [0,4,8], [2,4,6]] {
            if cells[line[0]] != 0 && cells[line[0]] == cells[line[1]] && cells[line[1]] == cells[line[2]] { return cells[line[0]] }
        }
        return nil
    }
    var finished: Bool { winner != nil || !cells.contains(0) }
    mutating func move(_ index: Int) {
        guard (0..<9).contains(index), cells.count == 9, cells[index] == 0, !finished else { return }
        cells[index] = turn
        turn = turn == 1 ? 2 : 1
    }
    func validate() throws {
        let x = cells.filter { $0 == 1 }.count
        let o = cells.filter { $0 == 2 }.count
        let lines = [[0,1,2], [3,4,5], [6,7,8], [0,3,6], [1,4,7], [2,5,8], [0,4,8], [2,4,6]]
        let winners = cells.count == 9 ? Set(lines.compactMap { line -> Int? in cells[line[0]] != 0 && cells[line[0]] == cells[line[1]] && cells[line[1]] == cells[line[2]] ? cells[line[0]] : nil }) : []
        guard winners.count <= 1, (winner != 1 || x == o + 1), (winner != 2 || x == o),
              cells.count == 9, cells.allSatisfy({ (0...2).contains($0) }), x == o || x == o + 1,
              turn == (x == o ? 1 : 2) else { throw WorkspaceError.invalidData }
    }
}

struct LaunchShortcut: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var website: String?
    var bundleIdentifier: String?
    var symbol = "arrow.up.right"
    var validatedWebsite: URL? {
        guard let website, let url = URL(string: website), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
    func validate() throws {
        guard !title.isEmpty, title.count <= 80, symbol.count <= 100,
              (website == nil) != (bundleIdentifier == nil) else { throw WorkspaceError.invalidData }
        if website != nil { guard validatedWebsite != nil, website!.count <= 2000 else { throw WorkspaceError.invalidData } }
        if let bundleIdentifier {
            guard (3...150).contains(bundleIdentifier.count), bundleIdentifier.contains("."),
                  bundleIdentifier.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_")).contains($0) }) else { throw WorkspaceError.invalidData }
        }
    }
}

struct WeatherCity: Codable, Equatable, Identifiable {
    var name: String
    var latitude: Double
    var longitude: Double
    var id: String { name }
    static let presets = [WeatherCity(name: "Istanbul", latitude: 41.01, longitude: 28.98), WeatherCity(name: "London", latitude: 51.51, longitude: -0.13), WeatherCity(name: "New York", latitude: 40.71, longitude: -74.01), WeatherCity(name: "Berlin", latitude: 52.52, longitude: 13.4), WeatherCity(name: "Tokyo", latitude: 35.68, longitude: 139.69), WeatherCity(name: "Sydney", latitude: -33.87, longitude: 151.21)]
    var cacheKey: String { "\(latitude),\(longitude)" }
    func validate() throws {
        guard !name.isEmpty, name.count <= 80, latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { throw WorkspaceError.invalidData }
    }
}

struct WidgetOptions: Codable, Equatable {
    var width: Double?
    var height: Double?
    var title = ""
    var backdrop: WidgetBackdrop = .solid
    var placement: WidgetPlacement = .desktop
    var typeface: WidgetTypeface = .rounded
    var fontScale = 1.0
    var opacity = 1.0
    var borderWidth = 1.0
    var shadow = false
    var showHeader = true
    var locked = false
    var clickThrough = false
    var snapToGrid = true
    var customColors = false
    var backgroundHex = "#ECE6FF"
    var foregroundHex = "#302347"
    var accentHex = "#7856D8"
    var bodyText: String?
    var timeZone: String?
    var countdownDate: Date?
    var countdownTitle: String?
    var symbol = "🌸"
    var rotation = 0.0
    var photo: Data?
    var photoFill = true
    var counter = 0
    var dailyKey = ""
    var goal = 8
    var dice = [1, 4]
    var game = NoughtsGame()
    var quoteIndex = 0
    var petEnergy = 75
    var petAction = "Idle"
    var shortcuts: [LaunchShortcut] = []
    var city = WeatherCity.presets[0]
    var layers: [CanvasLayer]?
    static let maxFileBytes = 20 * 1_048_576
    static let quotes: [String] = []
    var quoteLines: [String] {
        bodyText?.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
    }
    var displayedQuote: String {
        let values = quoteLines
        guard !values.isEmpty else { return L10n.text("No quotes added") }
        return values[((quoteIndex % values.count) + values.count) % values.count]
    }
    var todayCount: Int { dailyKey == LocalHabit.dayKey() ? counter : 0 }
    mutating func addWater(_ delta: Int) {
        if dailyKey != LocalHabit.dayKey() { counter = 0; dailyKey = LocalHabit.dayKey() }
        counter = min(1000, max(0, counter + delta))
    }
    static func validHex(_ text: String) -> Bool {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy { $0.isHexDigit }
    }
    func validate() throws {
        guard width.map({ $0.isFinite && (144...720).contains($0) }) != false,
              height.map({ $0.isFinite && (144...720).contains($0) }) != false,
              title.count <= 80, fontScale.isFinite, (0.65...1.6).contains(fontScale), opacity.isFinite, (0.2...1).contains(opacity),
              borderWidth.isFinite, (0...6).contains(borderWidth), rotation.isFinite, (-180...180).contains(rotation),
              [backgroundHex, foregroundHex, accentHex].allSatisfy(Self.validHex),
              (bodyText?.utf8.count ?? 0) <= 100_000, symbol.count <= 30,
              timeZone.map({ TimeZone(identifier: $0) != nil }) != false,
              countdownDate?.timeIntervalSince1970.isFinite != false, (countdownTitle?.count ?? 0) <= 200,
              (photo?.count ?? 0) <= 524_288, (-1_000_000...1_000_000).contains(counter), (1...1000).contains(goal),
              dice.count == 2, dice.allSatisfy({ (1...6).contains($0) }), (0...100).contains(petEnergy), petAction.count <= 100,
              shortcuts.count <= 12, Set(shortcuts.map(\.id)).count == shortcuts.count,
              (layers?.count ?? 0) <= 30, layers.map({ Set($0.map(\.id)).count == $0.count }) != false else { throw WorkspaceError.invalidData }
        try game.validate()
        try city.validate()
        try shortcuts.forEach { try $0.validate() }
        try layers?.forEach { try $0.validate() }
    }
}

extension DesktopTile {
    var settings: WidgetOptions {
        get {
            if let options { return options }
            var defaults = WidgetOptions()
            if kind == .sticker { defaults.showHeader = false; defaults.backdrop = .transparent; defaults.borderWidth = 0 }
            if kind == .pet { defaults.symbol = "🐈" }
            if kind == .quote { defaults.typeface = .serif }
            return defaults
        }
        set { options = newValue }
    }
    var displayWidth: Double { settings.width ?? size.width }
    var displayHeight: Double { settings.height ?? size.height }
    var displayTitle: String { settings.title.isEmpty ? kind.title : settings.title }
}

struct BreathingCycle {
    static func phase(at elapsed: TimeInterval) -> Int { max(0, Int(min(60, max(0, elapsed)) / 4)) % 3 }
    static func finished(at elapsed: TimeInterval) -> Bool { elapsed >= 60 }
}

extension CanvasLayer {
    func resolvedProgress(document: WorkspaceDocument, options: WidgetOptions, at date: Date = Date()) -> Double {
        switch source ?? .manual {
        case .manual: return progress
        case .tasks: return document.tasks.isEmpty ? 0 : Double(document.tasks.filter(\.completed).count) / Double(document.tasks.count)
        case .habits: return document.habits.isEmpty ? 0 : Double(document.habits.filter { $0.done() }.count) / Double(document.habits.count)
        case .water: return min(1, Double(options.todayCount) / Double(options.goal))
        case .focus: return min(1, max(0, 1 - document.focus.seconds(at: date) / max(1, document.focus.duration)))
        }
    }
}
