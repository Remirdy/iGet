import Foundation

enum ToolKind: String, Codable, CaseIterable, Identifiable {
    case clock, focus, tasks, countdown, notes, calendar, habits, battery, system
    case photo, sticker, dice, game, water, quote, pet, breathing, launcher, weather, music, canvas
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return L10n.text("System monitor")
        case .game: return L10n.text("Noughts & crosses")
        case .water: return L10n.text("Water tracker")
        case .pet: return L10n.text("Pocket pet")
        case .canvas: return L10n.text("Custom canvas")
        default: return L10n.text(rawValue.capitalized)
        }
    }
    var isOriginal: Bool { [.clock, .focus, .tasks, .countdown, .notes, .calendar, .habits, .battery, .system].contains(self) }
    var symbol: String {
        switch self {
        case .clock: return "clock"
        case .focus: return "timer"
        case .tasks: return "checklist"
        case .countdown: return "hourglass"
        case .notes: return "note.text"
        case .calendar: return "calendar"
        case .habits: return "repeat"
        case .battery: return "battery.75percent"
        case .system: return "waveform.path.ecg"
        case .photo: return "photo"
        case .sticker: return "face.smiling"
        case .dice: return "dice"
        case .game: return "square.grid.3x3"
        case .water: return "drop"
        case .quote: return "quote.opening"
        case .pet: return "pawprint"
        case .breathing: return "wind"
        case .launcher: return "arrow.up.forward.app"
        case .weather: return "cloud.sun"
        case .music: return "music.note"
        case .canvas: return "square.on.square.dashed"
        }
    }
    var summary: String {
        switch self {
        case .clock: return L10n.text("Time, date and time zone settings.")
        case .focus: return L10n.text("Timed work and break sessions.")
        case .tasks: return L10n.text("Local task list with completion tracking.")
        case .countdown: return L10n.text("Days until a selected date.")
        case .notes: return L10n.text("Local plain text notes.")
        case .calendar: return L10n.text("Monthly calendar.")
        case .habits: return L10n.text("Daily check-ins and streaks.")
        case .battery: return L10n.text("Battery charge and power source.")
        case .system: return L10n.text("CPU and memory usage.")
        case .photo: return L10n.text("Display a photo from this Mac.")
        case .sticker: return L10n.text("Emoji and text stickers.")
        case .dice: return L10n.text("Two six-sided dice.")
        case .game: return L10n.text("Two-player tic-tac-toe.")
        case .water: return L10n.text("Daily glass counter.")
        case .quote: return L10n.text("Quotes saved in Studio.")
        case .pet: return L10n.text("A pet with feed, play and rest controls.")
        case .breathing: return L10n.text("One-minute breathing timer.")
        case .launcher: return L10n.text("Shortcuts to apps and websites.")
        case .weather: return L10n.text("Current weather for a selected city.")
        case .music: return L10n.text("Playback controls for Apple Music and Spotify.")
        case .canvas: return L10n.text("Edit text, time, date, symbol and progress layers.")
        }
    }
    var category: String {
        switch self {
        case .clock, .countdown, .calendar: return "Time"
        case .focus, .tasks, .notes, .habits: return "Productivity"
        case .battery, .system: return "System"
        case .dice, .game, .pet, .sticker: return "Play"
        case .photo, .quote, .canvas: return "Personal"
        case .water, .breathing: return "Productivity"
        case .launcher, .weather, .music: return "Connected"
        }
    }
    var defaultPalette: String {
        switch self {
        case .clock, .habits: return "sage"
        case .focus, .calendar: return "paper"
        case .tasks, .notes: return "lilac"
        case .canvas, .sticker: return "aurora"
        case .photo: return "rose"
        case .pet: return "peach"
        case .music: return "lilac"
        case .dice, .game, .quote: return "peach"
        case .weather, .water, .breathing: return "sky"
        default: return "slate"
        }
    }
}

enum TileSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var width: Double { self == .small ? 180 : 340 }
    var height: Double { self == .large ? 340 : 180 }
}

enum AppearanceMode: String, Codable, CaseIterable { case system, light, dark }
enum EnergyMode: String, Codable, CaseIterable {
    case automatic, balanced, saver
    func interval(systemLowPower: Bool, thermalPressure: Bool = false) -> TimeInterval {
        self == .saver || thermalPressure || (self == .automatic && systemLowPower) ? 15 : 3
    }
}

struct WorkspacePreferences: Codable, Equatable {
    var language: AppLanguage?
    var appearance: AppearanceMode = .system
    var energy: EnergyMode = .automatic
    var palette = "aurora"
    var use24Hour = true
    var showDate = true
    var clockTimeZone = TimeZone.current.identifier
    var focusMinutes = 25
    var breakMinutes = 5
    var launchAtLogin = false
    var lockLayout = false
}

struct DesktopTile: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ToolKind
    var size: TileSize = .small
    var palette = "sage"
    var cornerRadius = 18.0
    var x = 80.0
    var y = 100.0
    var enabled = true
    var options: WidgetOptions?
}

struct WorkspaceSpace: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var symbol: String
    var tiles: [DesktopTile]
    static func preset(_ name: String, kinds: [ToolKind]) -> WorkspaceSpace {
        WorkspaceSpace(name: name, symbol: name == "Study" ? "book" : name == "Developer" ? "terminal" : "sun.max", tiles: kinds.enumerated().map { index, kind in
            DesktopTile(kind: kind, palette: kind.defaultPalette, x: 70 + Double(index % 3) * 205, y: 130 + Double(index / 3) * 205)
        })
    }
}

struct LocalTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var completed = false
    var createdAt = Date()
}

struct LocalHabit: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var completedDays: Set<String> = []
    static func dayKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    func done(on date: Date = Date()) -> Bool { completedDays.contains(Self.dayKey(date)) }
    func streak(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: date)
        if !completedDays.contains(Self.dayKey(day, calendar: calendar)) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while completedDays.contains(Self.dayKey(day, calendar: calendar)) && count < 36600 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }
}

struct LocalCountdown: Codable, Equatable {
    var title = ""
    var date = Date()
    func days(from now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}

struct FocusSession: Codable, Equatable {
    enum Phase: String, Codable { case work, rest }
    var phase: Phase = .work
    var endDate: Date?
    var remaining: TimeInterval = 25 * 60
    var duration: TimeInterval = 25 * 60
    var completedSessions = 0
    var completed = false
    var isRunning: Bool { endDate != nil }
    func seconds(at now: Date = Date()) -> TimeInterval { max(0, endDate?.timeIntervalSince(now) ?? remaining) }
    mutating func reconcile(at now: Date = Date()) {
        guard let endDate, endDate <= now else { return }
        if phase == .work { completedSessions += 1 }
        self.endDate = nil
        remaining = 0
        completed = true
    }
    mutating func toggle(at now: Date = Date(), workMinutes: Int, breakMinutes: Int) {
        reconcile(at: now)
        if let endDate {
            remaining = max(0, endDate.timeIntervalSince(now))
            self.endDate = nil
        } else {
            if completed {
                phase = phase == .work ? .rest : .work
                completed = false
                remaining = TimeInterval((phase == .work ? workMinutes : breakMinutes) * 60)
                duration = remaining
            }
            endDate = now.addingTimeInterval(remaining)
        }
    }
    mutating func reset(minutes: Int) {
        phase = .work
        endDate = nil
        completed = false
        remaining = TimeInterval(minutes * 60)
        duration = remaining
    }
}

struct WorkspaceDocument: Codable, Equatable {
    var schemaVersion = 1
    var preferences = WorkspacePreferences()
    var spaces = [WorkspaceSpace.preset("Study", kinds: [.clock, .focus, .tasks]), WorkspaceSpace.preset("Developer", kinds: [.system, .notes, .clock]), WorkspaceSpace.preset("Daily", kinds: [.calendar, .habits, .battery])]
    var activeSpaceID: UUID?
    var tasks: [LocalTask] = []
    var habits: [LocalHabit] = []
    var note = ""
    var countdown = LocalCountdown()
    var focus = FocusSession()
    var desktopVisible = true
    var activeSpace: WorkspaceSpace? { spaces.first { $0.id == activeSpaceID } }
    var activeTiles: [DesktopTile] { activeSpace?.tiles ?? [] }
    static var initial: WorkspaceDocument {
        var document = WorkspaceDocument()
        document.activeSpaceID = document.spaces.first?.id
        return document
    }
    func validate() throws {
        var contentBytes = 0
        for tile in spaces.flatMap(\.tiles) {
            let options = tile.settings
            contentBytes += options.photo?.count ?? 0
            contentBytes += options.bodyText?.utf8.count ?? 0
            for layer in options.layers ?? [] { contentBytes += layer.text.utf8.count }
        }
        guard schemaVersion == 1, spaces.count <= 32, Set(spaces.map(\.id)).count == spaces.count,
              activeSpaceID == nil || spaces.contains(where: { $0.id == activeSpaceID }),
              tasks.count <= 5000, habits.count <= 100, note.utf8.count <= 100_000,
              (1...180).contains(preferences.focusMinutes), (1...60).contains(preferences.breakMinutes),
              TimeZone(identifier: preferences.clockTimeZone) != nil,
              countdown.title.count <= 200, countdown.date.timeIntervalSince1970.isFinite,
              focus.remaining.isFinite, focus.duration.isFinite, focus.duration > 0,
              focus.remaining >= 0, focus.remaining <= 10800,
              focus.endDate?.timeIntervalSince1970.isFinite != false,
              focus.completedSessions >= 0, ThemePack.paletteIDs.contains(preferences.palette),
              contentBytes <= 12 * 1_048_576 else { throw WorkspaceError.invalidData }
        for space in spaces {
            guard !space.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, space.name.count <= 60,
                  space.tiles.count <= 24, Set(space.tiles.map(\.id)).count == space.tiles.count else { throw WorkspaceError.invalidData }
            for tile in space.tiles { try ThemePack.validate(tile) }
        }
        guard Set(tasks.map(\.id)).count == tasks.count, tasks.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 300 }),
              Set(habits.map(\.id)).count == habits.count, habits.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 100 && $0.completedDays.count <= 36600 }) else { throw WorkspaceError.invalidData }
    }
}

enum WorkspaceError: LocalizedError {
    case invalidData, oversized, storage(String)
    var errorDescription: String? {
        switch self {
        case .invalidData: return L10n.text("This file contains unsupported or invalid settings.")
        case .oversized: return L10n.text("Choose a file smaller than 20 MB.")
        case .storage(let message): return L10n.format("Your changes could not be saved. %@", message)
        }
    }
}

struct ThemePack: Codable {
    static let paletteIDs = ["sage", "paper", "lilac", "slate", "aurora", "peach", "sky", "rose"]
    var schemaVersion = 1
    var name: String
    var tiles: [DesktopTile]
    static func validate(_ tile: DesktopTile) throws {
        guard paletteIDs.contains(tile.palette), tile.x.isFinite, tile.y.isFinite,
              abs(tile.x) <= 100_000, abs(tile.y) <= 100_000,
              tile.cornerRadius.isFinite, (0...48).contains(tile.cornerRadius) else { throw WorkspaceError.invalidData }
        try tile.options?.validate()
    }
    static func decode(_ data: Data) throws -> ThemePack {
        guard data.count <= WidgetOptions.maxFileBytes else { throw WorkspaceError.oversized }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any], Set(root.keys).isSubset(of: ["schemaVersion", "name", "tiles"]),
              let tiles = root["tiles"] as? [[String: Any]], tiles.allSatisfy({ Set($0.keys).isSubset(of: ["id", "kind", "size", "palette", "cornerRadius", "x", "y", "enabled", "options"]) }) else { throw WorkspaceError.invalidData }
        let optionKeys = Set(["width", "height", "title", "backdrop", "placement", "typeface", "fontScale", "opacity", "borderWidth", "shadow", "showHeader", "locked", "clickThrough", "snapToGrid", "customColors", "backgroundHex", "foregroundHex", "accentHex", "bodyText", "timeZone", "countdownDate", "countdownTitle", "symbol", "rotation", "photo", "photoFill", "counter", "dailyKey", "goal", "dice", "game", "quoteIndex", "petEnergy", "petAction", "shortcuts", "city", "layers"])
        for tile in tiles {
            guard let options = tile["options"] as? [String: Any] else { continue }
            guard Set(options.keys).isSubset(of: optionKeys) else { throw WorkspaceError.invalidData }
            if let layers = options["layers"] as? [[String: Any]] {
                guard layers.allSatisfy({ Set($0.keys).isSubset(of: ["id", "kind", "text", "x", "y", "width", "fontSize", "rotation", "opacity", "colorHex", "progress", "source"]) }) else { throw WorkspaceError.invalidData }
            }
            if let shortcuts = options["shortcuts"] as? [[String: Any]] {
                guard shortcuts.allSatisfy({ Set($0.keys).isSubset(of: ["id", "title", "website", "bundleIdentifier", "symbol"]) }) else { throw WorkspaceError.invalidData }
            }
            if let city = options["city"] as? [String: Any], !Set(city.keys).isSubset(of: ["name", "latitude", "longitude"]) { throw WorkspaceError.invalidData }
            if let game = options["game"] as? [String: Any], !Set(game.keys).isSubset(of: ["cells", "turn"]) { throw WorkspaceError.invalidData }
        }
        let pack = try JSONDecoder().decode(ThemePack.self, from: data)
        guard pack.schemaVersion == 1, !pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              pack.name.count <= 60, (1...24).contains(pack.tiles.count) else { throw WorkspaceError.invalidData }
        try pack.tiles.forEach { try validate($0) }
        return pack
    }
}
