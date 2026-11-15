import Foundation
import SQLite3

@main
struct WorkspaceTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw Failure(message: message) }
        checks += 1
    }
    struct Failure: Error { let message: String }
    static func main() throws {
        try focus()
        try datesAndHabits()
        try imports()
        try storage()
        try energy()
        try PersonalizationChecks.run()
        try LocalizationChecks.run()
        print("Passed \(checks) checks: focus, storage, game rules, customization, migration, canvas bindings, import validation and energy policy.")
    }
    static func focus() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var value = FocusSession()
        value.toggle(at: start, workMinutes: 25, breakMinutes: 5)
        try expect(value.endDate == start.addingTimeInterval(1500), "Focus deadline")
        value.toggle(at: start.addingTimeInterval(120), workMinutes: 25, breakMinutes: 5)
        try expect(value.endDate == nil && value.remaining == 1380, "Pause preserves remaining time")
        value.toggle(at: start.addingTimeInterval(300), workMinutes: 25, breakMinutes: 5)
        try expect(value.endDate == start.addingTimeInterval(1680), "Resume creates a new deadline")
        let restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(value))
        try expect(restored.seconds(at: start.addingTimeInterval(600)) == 1080, "Restart uses absolute time")
        value.reconcile(at: start.addingTimeInterval(5000))
        try expect(value.completed && value.completedSessions == 1 && value.remaining == 0, "Sleep past deadline")
        value.reconcile(at: start.addingTimeInterval(5100))
        try expect(value.completedSessions == 1, "Completion is idempotent")
        value.toggle(at: start.addingTimeInterval(5200), workMinutes: 25, breakMinutes: 5)
        try expect(value.phase == .rest && value.duration == 300, "Start a break")
        value.reconcile(at: start.addingTimeInterval(5600))
        try expect(value.completedSessions == 1, "Break does not count as work")
        value.reset(minutes: 50)
        try expect(value.phase == .work && value.remaining == 3000 && !value.isRunning, "Reset duration")
    }
    static func datesAndHabits() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 50))!
        let target = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 1))!
        let countdown = LocalCountdown(title: "Deadline", date: target)
        try expect(countdown.days(from: start, calendar: calendar) == 2, "DST uses calendar days")
        try expect(LocalCountdown(title: "Past", date: start).days(from: target, calendar: calendar) == -2, "Past dates show elapsed days")
        try expect(countdown.days(from: target, calendar: calendar) == 0, "Same-day countdown")
        var habit = LocalHabit(title: "Read")
        for offset in 0..<4 {
            let day = calendar.date(byAdding: .day, value: -offset, to: target)!
            habit.completedDays.insert(LocalHabit.dayKey(day, calendar: calendar))
        }
        try expect(habit.streak(at: target, calendar: calendar) == 4, "Habit streak")
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: target)!
        try expect(habit.streak(at: tomorrow, calendar: calendar) == 4, "Yesterday's streak remains before today's check-in")
        let later = calendar.date(byAdding: .day, value: 2, to: target)!
        try expect(habit.streak(at: later, calendar: calendar) == 0, "Missed day resets streak")
    }
    static func imports() throws {
        let encoder = JSONEncoder()
        let pack = ThemePack(name: "Study", tiles: [DesktopTile(kind: .focus)])
        let encoded = try encoder.encode(pack)
        try expect(try ThemePack.decode(encoded).tiles.count == 1, "Valid theme import")
        func rejected(_ data: Data) throws {
            do { _ = try ThemePack.decode(data) } catch { checks += 1; return }
            throw Failure(message: "Unsafe import accepted")
        }
        var invalid = pack
        invalid.schemaVersion = 2
        try rejected(encoder.encode(invalid))
        invalid = pack; invalid.tiles[0].palette = "remote"
        try rejected(encoder.encode(invalid))
        invalid = pack; invalid.tiles[0].cornerRadius = 10000
        try rejected(encoder.encode(invalid))
        invalid = pack; invalid.tiles = Array(repeating: DesktopTile(kind: .clock), count: 25)
        try rejected(encoder.encode(invalid))
        try rejected(Data(repeating: 32, count: 1_048_577))
        try rejected(Data("{\"schemaVersion\":1,\"name\":\"bad\",\"tiles\":[],\"script\":\"run\"}".utf8))
        try rejected(Data("not json".utf8))
    }
    static func storage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let first = try WorkspaceDatabase(url: url)
        let task = LocalTask(title: "Persist me")
        try first.update { $0.tasks.append(task); $0.note = "A durable note" }
        let second = try WorkspaceDatabase(url: url)
        try expect(try second.read().tasks == [task], "Tasks survive reopening")
        try expect(try second.read().note == "A durable note", "Notes survive reopening")
        do { try first.update { $0.note = "lost"; throw Failure(message: "rollback") } } catch {}
        try expect(try second.read().note == "A durable note", "Failed edits roll back")
        do { try first.update { $0.preferences.focusMinutes = 0 } } catch {}
        try expect(try second.read().preferences.focusMinutes == 25, "Invalid settings roll back")
        for _ in 0..<2 {
            try first.update { value in if let i = value.tasks.firstIndex(where: { $0.id == task.id }) { value.tasks[i].completed = true } }
        }
        try expect(try second.read().tasks.first?.completed == true, "Repeated task completion is idempotent")
        let queue = DispatchQueue(label: "iget.tests", attributes: .concurrent)
        let group = DispatchGroup()
        let failures = ErrorCollector()
        for index in 0..<60 {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    let connection = try WorkspaceDatabase(url: url)
                    try connection.update { $0.tasks.append(LocalTask(title: "Concurrent \(index)")) }
                } catch { failures.add(error) }
            }
        }
        group.wait()
        try expect(failures.isEmpty, "Concurrent writers succeed")
        let value = try first.read()
        try expect(value.tasks.count == 61, "Transactions prevent lost updates")
        try expect(Set(value.tasks.map(\.id)).count == 61, "Concurrent IDs remain unique")
        try value.validate()
    }
    static func energy() throws {
        try expect(EnergyMode.automatic.interval(systemLowPower: false) == 3, "Normal automatic sampling")
        try expect(EnergyMode.automatic.interval(systemLowPower: true) == 15, "Follow low power mode")
        try expect(EnergyMode.saver.interval(systemLowPower: false) == 15, "Explicit power saver")
        try expect(EnergyMode.balanced.interval(systemLowPower: true) == 3, "Balanced policy")
        try expect(EnergyMode.balanced.interval(systemLowPower: false, thermalPressure: true) == 15, "Thermal override")
    }
}

final class ErrorCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [Error] = []
    func add(_ error: Error) { lock.lock(); defer { lock.unlock() }; errors.append(error) }
    var isEmpty: Bool { lock.lock(); defer { lock.unlock() }; return errors.isEmpty }
}
