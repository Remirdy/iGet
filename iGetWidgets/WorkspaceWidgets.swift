import WidgetKit
import SwiftUI
import AppIntents

struct WorkspaceEntry: TimelineEntry {
    let date: Date
    let document: WorkspaceDocument?
}

struct WorkspaceTimelineProvider: TimelineProvider {
    let tool: ToolKind
    func placeholder(in context: Context) -> WorkspaceEntry { WorkspaceEntry(date: Date(), document: .initial) }
    func getSnapshot(in context: Context, completion: @escaping (WorkspaceEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkspaceEntry>) -> Void) {
        let first = load()
        let count = tool == .clock ? 60 : 1
        let entries = (0..<count).map { WorkspaceEntry(date: first.date.addingTimeInterval(Double($0) * 60), document: first.document) }
        let refresh: Date
        if tool == .focus, let end = first.document?.focus.endDate, end > Date() { refresh = end }
        else { refresh = first.date.addingTimeInterval(tool == .clock ? 3600 : 900) }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
    private func load() -> WorkspaceEntry {
        guard WorkspaceDatabase.sharedContainer != nil else { return WorkspaceEntry(date: Date(), document: nil) }
        do {
            let database = try WorkspaceDatabase(url: WorkspaceDatabase.defaultURL())
            var document = try database.read()
            document.focus.reconcile()
            return WorkspaceEntry(date: Date(), document: document)
        } catch { return WorkspaceEntry(date: Date(), document: nil) }
    }
}

struct NativeWorkspaceWidget: Widget {
    let tool: ToolKind
    init() { tool = .clock }
    init(tool: ToolKind) { self.tool = tool }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.twobitdev.iGet.widget.\(tool.rawValue)", provider: WorkspaceTimelineProvider(tool: tool)) { entry in
            NativeWorkspaceView(tool: tool, entry: entry)
        }
        .configurationDisplayName(Text(tool.title))
        .description(Text(tool.summary))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct NativeWorkspaceView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let tool: ToolKind
    let entry: WorkspaceEntry
    init(tool: ToolKind, entry: WorkspaceEntry) {
        self.tool = tool
        self.entry = entry
        LocalizationManager.shared.select(entry.document?.preferences.language ?? .system)
    }
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) private var family
    private var scale: CGFloat { family == .systemLarge ? 1 : 0.8 }
    private var effectiveScheme: ColorScheme {
        switch entry.document?.preferences.appearance {
        case .light: return .light
        case .dark: return .dark
        default: return scheme
        }
    }
    var body: some View {
        GeometryReader { geometry in
            nativeContent
                .frame(width: geometry.size.width / scale, height: geometry.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .environment(\.locale, localization.locale)
        .environment(\.colorScheme, effectiveScheme)
        .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        .widgetURL(URL(string: "iget://tool/\(tool.rawValue)"))
    }
    private var nativeContent: some View {
        Group {
            if let document = entry.document {
                let paletteID = document.activeTiles.first(where: { $0.kind == tool })?.palette ?? tool.defaultPalette
                let options = document.activeTiles.first(where: { $0.kind == tool })?.settings ?? WidgetOptions()
                let palette = options.theme(palette: paletteID, dark: effectiveScheme == .dark)
                Group {
                    if tool == .tasks || tool == .focus || tool == .habits {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(tool.title.uppercased(with: localization.locale), systemImage: tool.symbol).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(palette.secondaryText)
                            interactive(document, palette: palette)
                            Spacer(minLength: 0)
                        }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(palette.background).foregroundStyle(palette.primaryText).tint(palette.accent)
                    } else {
                        WorkspaceWidgetView(kind: tool, document: document, paletteID: paletteID, radius: 0, isLarge: family == .systemLarge, referenceDate: entry.date, options: options)
                    }
                }.preferredColorScheme(document.preferences.appearance == .system ? nil : document.preferences.appearance == .dark ? .dark : .light)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("Open iGet")).font(.headline)
                    Text(L10n.text("Shared data is unavailable. Open the signed app to set up your widgets.")).font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
        }
    }
    @ViewBuilder private func interactive(_ document: WorkspaceDocument, palette: ThemePalette) -> some View {
        if tool == .tasks {
            if document.tasks.isEmpty { Text(L10n.text("Add your first task in iGet.")).font(.system(size: 13)) }
            ForEach(document.tasks.prefix(family == .systemSmall ? 3 : 5)) { task in
                Button(intent: SetTaskCompletionIntent(id: task.id.uuidString, completed: !task.completed)) {
                    Label(task.title, systemImage: task.completed ? "checkmark.circle.fill" : "circle").font(.system(size: 12)).lineLimit(1).strikethrough(task.completed)
                }.buttonStyle(.plain)
            }
        } else if tool == .habits {
            if document.habits.isEmpty { Text(L10n.text("Create a habit in iGet.")).font(.system(size: 13)) }
            ForEach(document.habits.prefix(family == .systemSmall ? 3 : 5)) { habit in
                Button(intent: SetHabitCompletionIntent(id: habit.id.uuidString, completed: !habit.done(), day: LocalHabit.dayKey())) {
                    Label(habit.title, systemImage: habit.done() ? "checkmark.circle.fill" : "circle").font(.system(size: 12)).lineLimit(1)
                }.buttonStyle(.plain)
            }
        } else {
            if let end = document.focus.endDate, end > Date() {
                Text(timerInterval: Date()...end, countsDown: true).font(.system(size: 38, weight: .medium, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5)
            } else {
                let seconds = Int(document.focus.seconds())
                Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)).font(.system(size: 38, weight: .medium, design: .rounded)).monospacedDigit()
            }
            Button(intent: ControlFocusIntent(expectedEnd: document.focus.endDate?.timeIntervalSince1970 ?? 0, expectedRemaining: document.focus.remaining, expectedCompleted: document.focus.completed)) {
                Label(document.focus.isRunning ? L10n.text("Pause") : document.focus.completed ? L10n.text("Next session") : L10n.text("Start"), systemImage: document.focus.isRunning ? "pause.fill" : "play.fill").font(.system(size: 12))
            }.buttonStyle(.plain)
        }
    }
}

struct SetTaskCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "Set task completion"
    @Parameter(title: "Task ID") var id: String
    @Parameter(title: "Completed") var completed: Bool
    init() {}
    init(id: String, completed: Bool) { self.id = id; self.completed = completed }
    func perform() async throws -> some IntentResult {
        let database = try intentDatabase()
        try database.update { value in
            guard let index = value.tasks.firstIndex(where: { $0.id.uuidString == id }) else { return }
            value.tasks[index].completed = completed
        }
        notifyWorkspace()
        return .result()
    }
}

struct SetHabitCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "Set habit completion"
    @Parameter(title: "Habit ID") var id: String
    @Parameter(title: "Completed") var completed: Bool
    @Parameter(title: "Day") var day: String
    init() {}
    init(id: String, completed: Bool, day: String) { self.id = id; self.completed = completed; self.day = day }
    func perform() async throws -> some IntentResult {
        let database = try intentDatabase()
        try database.update { value in
            guard day == LocalHabit.dayKey(), let index = value.habits.firstIndex(where: { $0.id.uuidString == id }) else { return }
            if completed { value.habits[index].completedDays.insert(day) }
            else { value.habits[index].completedDays.remove(day) }
        }
        notifyWorkspace()
        return .result()
    }
}

struct ControlFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Control focus session"
    @Parameter(title: "Expected end") var expectedEnd: Double
    @Parameter(title: "Expected remaining") var expectedRemaining: Double
    @Parameter(title: "Expected completed") var expectedCompleted: Bool
    init() {}
    init(expectedEnd: Double, expectedRemaining: Double, expectedCompleted: Bool) {
        self.expectedEnd = expectedEnd; self.expectedRemaining = expectedRemaining; self.expectedCompleted = expectedCompleted
    }
    func perform() async throws -> some IntentResult {
        let database = try intentDatabase()
        try database.update { value in
            guard (value.focus.endDate?.timeIntervalSince1970 ?? 0) == expectedEnd,
                  value.focus.remaining == expectedRemaining, value.focus.completed == expectedCompleted else { return }
            value.focus.toggle(workMinutes: value.preferences.focusMinutes, breakMinutes: value.preferences.breakMinutes)
        }
        notifyWorkspace()
        return .result()
    }
}

private func intentDatabase() throws -> WorkspaceDatabase {
    guard WorkspaceDatabase.sharedContainer != nil else { throw WorkspaceError.storage(L10n.text("Open the signed iGet app first.")) }
    return try WorkspaceDatabase(url: WorkspaceDatabase.defaultURL())
}

private func notifyWorkspace() {
    WidgetCenter.shared.reloadAllTimelines()
    DistributedNotificationCenter.default().postNotificationName(Notification.Name(WorkspaceDatabase.changeName), object: nil, userInfo: nil, deliverImmediately: true)
}

struct ClockWidget: Widget {
    var body: some WidgetConfiguration { NativeWorkspaceWidget(tool: .clock).body }
}

struct TasksWidget: Widget {
    var body: some WidgetConfiguration { NativeWorkspaceWidget(tool: .tasks).body }
}

struct FocusWidget: Widget {
    var body: some WidgetConfiguration { NativeWorkspaceWidget(tool: .focus).body }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration { NativeWorkspaceWidget(tool: .countdown).body }
}

struct NotesWidget: Widget {
    var body: some WidgetConfiguration { NativeWorkspaceWidget(tool: .notes).body }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration { NativeWorkspaceWidget(tool: .calendar).body }
}

struct HabitsWidget: Widget {
    var body: some WidgetConfiguration { NativeWorkspaceWidget(tool: .habits).body }
}
