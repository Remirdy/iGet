import SwiftUI

struct DailyToolsPage: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var selected: ToolKind = .tasks
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeading(eyebrow: L10n.text("Notes, tasks & routines"), title: L10n.text("Daily tools"), subtitle: L10n.text("Tasks, notes and habit tracking."))
                Picker(L10n.text("Tool"), selection: $selected) { ForEach(ToolKind.allCases) { Text($0.title).tag($0) } }.frame(width: 260)
                ToolEditorContent(kind: selected).id(selected)
            }.padding(32).frame(maxWidth: 840, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ToolEditorView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let kind: ToolKind
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Label(kind.title, systemImage: kind.symbol).font(.title2.weight(.semibold)); Spacer(); Button(L10n.text("Done")) { dismiss() }.keyboardShortcut(.cancelAction) }
            ScrollView { ToolEditorContent(kind: kind).padding(2) }
        }.padding(28).frame(width: 650, height: 590).background(Color(nsColor: .windowBackgroundColor)).environment(\.locale, localization.locale)
    }
}

struct ToolEditorContent: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let kind: ToolKind
    @EnvironmentObject private var store: WorkspaceStore
    @State private var newTask = ""
    @State private var newHabit = ""
    @State private var countdownTitle = ""
    @State private var countdownDate = Date()
    @State private var monthOffset = 0
    @State private var demandToken = UUID()
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch kind {
            case .tasks: tasks
            case .focus: focus
            case .notes: NoteEditor()
            case .countdown: countdown
            case .habits: habits
            case .clock: clock
            case .calendar: calendar
            case .system, .battery:
                ResourceTileView(kind: kind, paletteID: kind.defaultPalette, monitor: store.resources).frame(height: 240)
                Text(kind == .system ? L10n.text("CPU is measured between samples. Memory includes active, wired and compressed pages. Sampling stops when no visible tool needs it.") : L10n.text("Battery data comes from macOS. Desktop Macs without a battery show AC power."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Label(L10n.format("Refresh interval: %d seconds", Int(store.samplingInterval)), systemImage: "leaf").font(.system(size: 12)).foregroundStyle(.secondary)
            default:
                LiveTile(tile: DesktopTile(kind: kind, palette: kind.defaultPalette), interactive: false).frame(height: kind == .game || kind == .canvas ? 280 : 210)
                Text(kind.summary).foregroundStyle(.secondary)
                Button(L10n.text("Add & customize")) { store.createAndCustomize(kind) }.buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            countdownTitle = store.document.countdown.title
            countdownDate = store.document.countdown.date
            store.setInterfaceDemand(demandToken, kind: kind, city: WeatherCity.presets[0])
        }
        .onDisappear {
            store.setInterfaceDemand(demandToken, kind: nil)
        }
    }
    private var tasks: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.format("%d of %d complete", store.document.tasks.filter(\.completed).count, store.document.tasks.count)).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if store.document.tasks.contains(where: \.completed) {
                    Button(L10n.text("Clear completed")) {
                        let ids = store.document.tasks.filter(\.completed).map(\.id)
                        store.change { $0.tasks.removeAll { ids.contains($0.id) } }
                    }.font(.system(size: 11))
                }
            }
            HStack {
                TextField(L10n.text("What needs doing?"), text: $newTask).textFieldStyle(.roundedBorder).onSubmit(addTask)
                Button(action: addTask) { Image(systemName: "plus") }.disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel(L10n.text("Add task"))
            }
            if store.document.tasks.isEmpty { EmptyWorkspaceView(symbol: "checklist", title: L10n.text("No tasks"), detail: L10n.text("Enter a task above.")) }
            else {
                VStack(spacing: 0) {
                    ForEach(store.document.tasks) { task in
                        TaskEditRow(task: task)
                        if task.id != store.document.tasks.last?.id { Divider() }
                    }
                }
            }
        }
    }
    private func addTask() { store.addTask(newTask); newTask = "" }
    private var focus: some View {
        VStack(alignment: .leading, spacing: 22) {
            WorkspaceWidgetView(kind: .focus, document: store.document, paletteID: "paper", onFocus: { store.toggleFocus() }).frame(height: 220)
            HStack {
                Button(store.document.focus.isRunning ? L10n.text("Pause session") : store.document.focus.completed ? (store.document.focus.phase == .work ? L10n.text("Start break") : L10n.text("Start focus")) : L10n.text("Start session")) { store.toggleFocus() }.buttonStyle(.borderedProminent).controlSize(.large)
                Button(L10n.text("Reset")) { store.resetFocus() }.controlSize(.large)
                Spacer()
                Text(L10n.count(store.document.focus.completedSessions, one: "%d session completed", other: "%d sessions completed")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    Stepper(L10n.format("Focus · %d min", store.document.preferences.focusMinutes), value: Binding(get: { store.document.preferences.focusMinutes }, set: { minutes in
                        store.change { $0.preferences.focusMinutes = minutes; if !$0.focus.isRunning { $0.focus.reset(minutes: minutes) } }
                    }), in: 1...180)
                    Stepper(L10n.format("Break · %d min", store.document.preferences.breakMinutes), value: Binding(get: { store.document.preferences.breakMinutes }, set: { minutes in store.preferences { $0.breakMinutes = minutes } }), in: 1...60)
                }.font(.system(size: 12))
            }
            Text(L10n.text("Closing the window or putting your Mac to sleep won’t reset a running session. Breaks begin when you’re ready.")).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
    private var countdown: some View {
        VStack(alignment: .leading, spacing: 20) {
            WorkspaceWidgetView(kind: .countdown, document: store.document, paletteID: "slate").frame(height: 200)
            TextField(L10n.text("What are you counting down to?"), text: $countdownTitle).textFieldStyle(.roundedBorder)
            DatePicker(L10n.text("Date"), selection: $countdownDate, displayedComponents: .date)
            Button(L10n.text("Save countdown")) {
                if store.change({ $0.countdown = LocalCountdown(title: String(countdownTitle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)), date: countdownDate) }) { store.notice = L10n.text("Countdown saved.") }
            }.buttonStyle(.borderedProminent).disabled(countdownTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    private var habits: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                TextField(L10n.text("Habit name"), text: $newHabit).textFieldStyle(.roundedBorder).onSubmit(addHabit)
                Button(action: addHabit) { Image(systemName: "plus") }.disabled(newHabit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel(L10n.text("Add habit"))
            }
            if store.document.habits.isEmpty { EmptyWorkspaceView(symbol: "repeat", title: L10n.text("No habits"), detail: L10n.text("Enter a habit above.")) }
            ForEach(store.document.habits) { habit in
                Surface {
                    HStack(spacing: 12) {
                        Button { store.toggleHabit(habit.id) } label: { Image(systemName: habit.done() ? "checkmark.circle.fill" : "circle").font(.title3) }.buttonStyle(.plain).accessibilityLabel(L10n.format(habit.done() ? "Mark %@ incomplete" : "Mark %@ complete", habit.title))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(habit.title).font(.system(size: 13, weight: .medium))
                            Text(L10n.count(habit.streak(), one: "%d day streak", other: "%d-day streak")).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach((0..<7).reversed(), id: \.self) { offset in
                                let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
                                Circle().fill(habit.done(on: day) ? Color.accentColor : Color.primary.opacity(0.08)).frame(width: 9, height: 9)
                                    .help(day.formatted(.dateTime.day().month().year().locale(localization.locale)))
                            }
                        }
                        Button(role: .destructive) { store.change { $0.habits.removeAll { $0.id == habit.id } } } label: { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(L10n.format("Delete %@", habit.title))
                    }
                }
            }
        }
    }
    private func addHabit() {
        let title = String(newHabit.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !title.isEmpty else { return }
        if store.change({ $0.habits.append(LocalHabit(title: title)) }) { newHabit = "" }
    }
    private var clock: some View {
        VStack(alignment: .leading, spacing: 20) {
            WorkspaceWidgetView(kind: .clock, document: store.document, paletteID: "sage").frame(height: 230)
            Picker(L10n.text("Time zone"), selection: Binding(get: { store.document.preferences.clockTimeZone }, set: { zone in store.preferences { $0.clockTimeZone = zone } })) {
                ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
            }
            Toggle(L10n.text("24-hour clock"), isOn: Binding(get: { store.document.preferences.use24Hour }, set: { value in store.preferences { $0.use24Hour = value } }))
            Toggle(L10n.text("Show date"), isOn: Binding(get: { store.document.preferences.showDate }, set: { value in store.preferences { $0.showDate = value } }))
        }.font(.system(size: 12))
    }
    private var calendar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }.accessibilityLabel(L10n.text("Previous month"))
                Button(L10n.text("Today")) { monthOffset = 0 }
                Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }.accessibilityLabel(L10n.text("Next month"))
                Spacer()
            }
            Surface { MonthGrid(date: Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date(), accent: .accentColor, expanded: true).frame(maxWidth: .infinity).padding(12) }
            Text(L10n.text("A simple month view. Calendar account access is not required.")).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

private struct TaskEditRow: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let task: LocalTask
    @EnvironmentObject private var store: WorkspaceStore
    @State private var title = ""
    @FocusState private var editing: Bool
    var body: some View {
        HStack(spacing: 10) {
            Button { store.setTask(task.id, completed: !task.completed) } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").font(.system(size: 17))
            }.buttonStyle(.plain).accessibilityLabel(L10n.format(task.completed ? "Mark %@ incomplete" : "Mark %@ complete", task.title))
            TextField(L10n.text("Task"), text: $title).textFieldStyle(.plain).font(.system(size: 13)).strikethrough(task.completed).foregroundStyle(task.completed ? .secondary : .primary)
                .focused($editing).onSubmit(save).onChange(of: editing) { _, value in if !value { save() } }
            Button { store.removeTask(task.id) } label: { Image(systemName: "trash").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel(L10n.format("Delete %@", task.title))
        }.padding(.vertical, 13)
            .onAppear { title = task.title }
            .onChange(of: task.title) { _, value in if !editing { title = value } }
    }
    private func save() {
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !clean.isEmpty, clean != task.title else { title = task.title; return }
        store.change { value in
            guard let i = value.tasks.firstIndex(where: { $0.id == task.id }) else { return }
            value.tasks[i].title = clean
        }
    }
}

private struct NoteEditor: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    @State private var draft = ""
    @State private var loaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var saved = true
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(L10n.text("QUICK NOTE")).font(.system(size: 10, weight: .semibold)).tracking(1.5); Spacer(); Text(saved ? L10n.text("Saved locally") : L10n.text("Saving…")).font(.system(size: 11)).foregroundStyle(.secondary) }
            TextEditor(text: $draft).font(.system(size: 16)).lineSpacing(6).scrollContentBackground(.hidden).padding(16)
                .frame(minHeight: 300).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty { Text(L10n.text("Write a note…")).font(.system(size: 16)).foregroundStyle(.tertiary).padding(21).allowsHitTesting(false) }
                }
            Text(L10n.format("%d characters · Plain text · Autosaved", draft.count)).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .onAppear { draft = store.document.note; loaded = true }
        .onChange(of: draft) { _, value in
            guard loaded else { return }
            saveTask?.cancel()
            guard value != store.document.note else { saved = true; return }
            if value.utf8.count > 100_000 { draft = String(value.prefix(25_000)); return }
            saved = false
            saveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                save()
            }
        }
        .onDisappear { saveTask?.cancel(); if !saved { save() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in if !saved { save() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in if !saved { save() } }
    }
    private func save() {
        guard draft != store.document.note else { saved = true; return }
        saved = store.change { $0.note = draft }
    }
}
