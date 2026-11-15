import AppKit
import Combine
import SwiftUI
import WidgetKit
import ServiceManagement

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var document: WorkspaceDocument = .initial
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var pendingPack: ThemePack?
    @Published var selectedTool: ToolKind?
    @Published var page: WorkspacePage = .gallery
    @Published var editingTileID: UUID?
    let weather: WeatherProvider
    let music: MusicProvider
    var visibleWeatherCity: WeatherCity?
    var visibleMusic = false
    private var interfaceDemands: [UUID: (ToolKind, WeatherCity?)] = [:]
    @Published private(set) var systemLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    let resources = ResourceMonitor()
    private(set) var database: WorkspaceDatabase?
    private var observers = Set<AnyCancellable>()
    private var distributedObserver: NSObjectProtocol?
    private var completionWork: DispatchWorkItem?
    private var reloadWork: DispatchWorkItem?
    private var undoAction: (() -> Void)?
    private var isSleeping = false
    var isSharedStorage: Bool { WorkspaceDatabase.sharedContainer != nil }
    var samplingInterval: TimeInterval {
        document.preferences.energy.interval(systemLowPower: systemLowPower, thermalPressure: ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical)
    }
    var appearance: ColorScheme? {
        switch document.preferences.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    init(databaseURL: URL? = nil, allowsExternalConnections: Bool = true) {
        weather = WeatherProvider(allowsNetwork: allowsExternalConnections)
        music = MusicProvider(allowsControl: allowsExternalConnections)
        do {
            let connection = try WorkspaceDatabase(url: databaseURL ?? WorkspaceDatabase.defaultURL())
            database = connection
            document = try connection.update { _ in }
        } catch { errorMessage = error.localizedDescription }
        LocalizationManager.shared.select(document.preferences.language ?? .system)
        let center = NotificationCenter.default
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            center.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                Task { @MainActor in
                    self?.systemLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                    self?.updateDemand()
                }
            }.store(in: &observers)
        }
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            center.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.refresh()
                self?.objectWillChange.send()
            }.store(in: &observers)
        }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            workspaceCenter.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                Task { @MainActor in self?.isSleeping = true; self?.updateDemand() }
            }.store(in: &observers)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            workspaceCenter.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                Task { @MainActor in self?.isSleeping = false; self?.refresh(); self?.updateDemand() }
            }.store(in: &observers)
        }
        center.publisher(for: NSApplication.didBecomeActiveNotification).sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }.store(in: &observers)
        distributedObserver = DistributedNotificationCenter.default().addObserver(forName: Notification.Name(WorkspaceDatabase.changeName), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        scheduleCompletion()
    }
    deinit {
        completionWork?.cancel()
        reloadWork?.cancel()
        if let distributedObserver { DistributedNotificationCenter.default().removeObserver(distributedObserver) }
    }
    func refresh() {
        do {
            guard let database else { return }
            var value = try database.read()
            if let end = value.focus.endDate, end <= Date() { value = try database.update { _ in } }
            LocalizationManager.shared.select(value.preferences.language ?? .system)
            if document != value { document = value }
            scheduleCompletion()
            updateDemand()
        } catch { errorMessage = error.localizedDescription }
    }
    @discardableResult
    func change(_ edit: (inout WorkspaceDocument) throws -> Void) -> Bool {
        do {
            guard let database else { throw WorkspaceError.storage(L10n.text("Reopen iGet to try again.")) }
            let value = try database.update(edit)
            LocalizationManager.shared.select(value.preferences.language ?? .system)
            document = value
            scheduleCompletion()
            updateDemand()
            reloadWork?.cancel()
            let work = DispatchWorkItem { WidgetCenter.shared.reloadAllTimelines() }
            reloadWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func preferences(_ edit: (inout WorkspacePreferences) -> Void) {
        change { edit(&$0.preferences) }
    }
    func addTile(_ kind: ToolKind, size: TileSize, palette: String) {
        guard document.activeSpaceID != nil else { return }
        if change({ value in
            guard let index = value.spaces.firstIndex(where: { $0.id == value.activeSpaceID }) else { return }
            guard value.spaces[index].tiles.count < 24 else { throw WorkspaceError.storage(L10n.text("A space can hold up to 24 widgets.")) }
            let count = value.spaces[index].tiles.count
            value.spaces[index].tiles.append(DesktopTile(kind: kind, size: size, palette: palette, x: 60 + Double(count % 4) * 195, y: 100 + Double(count / 4) * 195))
            value.desktopVisible = true
        }) { notice = L10n.format("%@ added to %@.", kind.title, document.activeSpace?.name ?? L10n.text("Your desktop")) }
    }
    func editTile(_ id: UUID, edit: (inout DesktopTile) -> Void) {
        change { value in
            guard let s = value.spaces.firstIndex(where: { $0.id == value.activeSpaceID }), let t = value.spaces[s].tiles.firstIndex(where: { $0.id == id }) else { return }
            edit(&value.spaces[s].tiles[t])
        }
    }
    func removeTile(_ id: UUID) {
        guard let spaceID = document.activeSpaceID, let tile = document.activeTiles.first(where: { $0.id == id }) else { return }
        guard change({ value in
            guard let index = value.spaces.firstIndex(where: { $0.id == spaceID }) else { return }
            value.spaces[index].tiles.removeAll { $0.id == id }
        }) else { return }
        undoAction = { [weak self] in self?.change { value in
            guard let index = value.spaces.firstIndex(where: { $0.id == spaceID }) else { return }
            value.spaces[index].tiles.append(tile)
        } }
        notice = L10n.format("%@ removed.", tile.kind.title)
    }
    func undo() { let action = undoAction; undoAction = nil; action?(); notice = nil }
    var canUndo: Bool { undoAction != nil }
    func addTask(_ title: String) {
        let title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !title.isEmpty else { return }
        change { $0.tasks.append(LocalTask(title: title)) }
    }
    func setTask(_ id: UUID, completed: Bool) {
        change { value in
            guard let index = value.tasks.firstIndex(where: { $0.id == id }) else { return }
            value.tasks[index].completed = completed
        }
    }
    func removeTask(_ id: UUID) {
        guard let task = document.tasks.first(where: { $0.id == id }), change({ $0.tasks.removeAll { $0.id == id } }) else { return }
        undoAction = { [weak self] in self?.change { $0.tasks.append(task) } }
        notice = L10n.text("Task removed.")
    }
    func toggleFocus() {
        change { $0.focus.toggle(workMinutes: $0.preferences.focusMinutes, breakMinutes: $0.preferences.breakMinutes) }
    }
    func resetFocus() { change { $0.focus.reset(minutes: $0.preferences.focusMinutes) } }
    func toggleHabit(_ id: UUID) {
        change { value in
            guard let i = value.habits.firstIndex(where: { $0.id == id }) else { return }
            let day = LocalHabit.dayKey()
            if value.habits[i].completedDays.contains(day) { value.habits[i].completedDays.remove(day) }
            else { value.habits[i].completedDays.insert(day) }
        }
    }
    func activateSpace(_ id: UUID) { change { $0.activeSpaceID = id } }
    func newSpace(_ name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !clean.isEmpty else { return }
        change { value in
            let space = WorkspaceSpace(name: clean, symbol: "rectangle.3.group", tiles: [])
            value.spaces.append(space)
            value.activeSpaceID = space.id
        }
    }
    func removeSpace(_ id: UUID) {
        guard document.spaces.count > 1, let space = document.spaces.first(where: { $0.id == id }) else { return }
        if change({ value in
            value.spaces.removeAll { $0.id == id }
            if value.activeSpaceID == id { value.activeSpaceID = value.spaces.first?.id }
        }) {
            undoAction = { [weak self] in self?.change { $0.spaces.append(space) } }
            notice = L10n.text("Space removed.")
        }
    }
    func exportSpace() {
        guard let space = document.activeSpace else { return }
        guard !space.tiles.isEmpty else { notice = L10n.text("Add a widget before exporting this space."); return }
        saveFile(name: "\(space.name).iget.json") {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(ThemePack(name: space.name, tiles: space.tiles))
        }
    }
    func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= WidgetOptions.maxFileBytes else { throw WorkspaceError.oversized }
            pendingPack = try ThemePack.decode(Data(contentsOf: url, options: .mappedIfSafe))
        } catch { errorMessage = error.localizedDescription }
    }
    func importPack() {
        guard let pack = pendingPack else { return }
        if change({ value in
            let tiles = pack.tiles.map { tile -> DesktopTile in var copy = tile; copy.id = UUID(); return copy }
            let space = WorkspaceSpace(name: pack.name, symbol: "square.stack", tiles: tiles)
            value.spaces.append(space)
            value.activeSpaceID = space.id
        }) { pendingPack = nil; notice = L10n.text("Space imported.") }
    }
    func exportBackup() {
        saveFile(name: "iGet-backup.json") {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(self.document)
        }
    }
    func restoreBackup(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= WidgetOptions.maxFileBytes else { throw WorkspaceError.oversized }
            let data = try Data(contentsOf: url)
            guard data.count <= WidgetOptions.maxFileBytes else { throw WorkspaceError.oversized }
            let value = try JSONDecoder().decode(WorkspaceDocument.self, from: data)
            try value.validate()
            let old = document
            if change({ $0 = value }) {
                undoAction = { [weak self] in self?.change { $0 = old } }
                notice = L10n.text("Backup restored.")
            }
        } catch { errorMessage = error.localizedDescription }
    }
    private func saveFile(name: String, data: () throws -> Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let content = try data(); guard content.count <= WidgetOptions.maxFileBytes else { throw WorkspaceError.oversized }; try content.write(to: url, options: .atomic); notice = L10n.text("File saved.") }
        catch { errorMessage = error.localizedDescription }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            preferences { $0.launchAtLogin = enabled }
        } catch { errorMessage = L10n.format("Could not change launch at login. %@", error.localizedDescription) }
    }
    private func scheduleCompletion() {
        completionWork?.cancel()
        guard let end = document.focus.endDate else { return }
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.change({ _ in }) { self.notice = self.document.focus.phase == .work ? L10n.text("Session complete. Time for a break.") : L10n.text("Break complete. Ready when you are.") }
            }
        }
        completionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, end.timeIntervalSinceNow), execute: work)
    }
    var visiblePageNeedsSystem = false
    var visiblePageNeedsBattery = false
    func setInterfaceDemand(_ token: UUID, kind: ToolKind?, city: WeatherCity? = nil) {
        if let kind { interfaceDemands[token] = (kind, city) } else { interfaceDemands.removeValue(forKey: token) }
        updateDemand()
    }
    func updateDemand() {
        let kinds = document.desktopVisible ? document.activeTiles.filter(\.enabled).map(\.kind) : []
        var cities = document.desktopVisible ? document.activeTiles.filter { $0.enabled && $0.kind == .weather }.map { $0.settings.city } : []
        if let city = visibleWeatherCity { cities.append(city) }
        cities.append(contentsOf: interfaceDemands.values.compactMap { $0.0 == .weather ? $0.1 : nil })
        let interfaceKinds = interfaceDemands.values.map { $0.0 }
        weather.setDemand(isSleeping ? [] : cities)
        music.setDemand(!isSleeping && (visibleMusic || kinds.contains(.music) || interfaceKinds.contains(.music)), interval: samplingInterval >= 15 ? 15 : 5)
        resources.configure(system: !isSleeping && (visiblePageNeedsSystem || kinds.contains(.system) || interfaceKinds.contains(.system)), battery: !isSleeping && (visiblePageNeedsBattery || kinds.contains(.battery) || interfaceKinds.contains(.battery)), interval: samplingInterval)
    }
}
