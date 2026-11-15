import AppKit
import Combine
import Foundation

struct WeatherSnapshot: Codable, Equatable {
    var temperature: Double
    var humidity: Int
    var wind: Double
    var code: Int
    var updatedAt: Date
    var symbol: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
    var condition: String {
        switch code {
        case 0: return L10n.text("Clear sky")
        case 1...3: return L10n.text("Partly cloudy")
        case 45, 48: return L10n.text("Fog")
        case 51...67, 80...82: return L10n.text("Rain")
        case 71...77, 85, 86: return L10n.text("Snow")
        case 95...99: return L10n.text("Thunderstorms")
        default: return L10n.text("Cloudy")
        }
    }
}

struct WeatherResponse: Decodable {
    struct Current: Decodable {
        var temperature_2m: Double
        var relative_humidity_2m: Int
        var wind_speed_10m: Double
        var weather_code: Int
    }
    var current: Current
    func snapshot(now: Date = Date()) throws -> WeatherSnapshot {
        guard current.temperature_2m.isFinite, (-100...80).contains(current.temperature_2m),
              (0...100).contains(current.relative_humidity_2m), current.wind_speed_10m.isFinite,
              (0...500).contains(current.wind_speed_10m), (0...99).contains(current.weather_code) else { throw WorkspaceError.invalidData }
        return WeatherSnapshot(temperature: current.temperature_2m, humidity: current.relative_humidity_2m, wind: current.wind_speed_10m, code: current.weather_code, updatedAt: now)
    }
}

@MainActor
final class WeatherProvider: ObservableObject {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    @Published private(set) var snapshots: [String: WeatherSnapshot] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var loading: Set<String> = []
    private var tasks: [String: Task<Void, Never>] = [:]
    private var cities: [WeatherCity] = []
    private var timer: Timer?
    private let transport: Transport
    let allowsNetwork: Bool
    private let cacheURL: URL?
    init(allowsNetwork: Bool = true, cacheURL: URL? = nil, transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.allowsNetwork = allowsNetwork
        self.transport = transport
        self.cacheURL = allowsNetwork ? (cacheURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("iGet/weather.json")) : nil
        if let url = self.cacheURL, let data = try? Data(contentsOf: url), data.count <= 100_000, let values = try? JSONDecoder().decode([String: WeatherSnapshot].self, from: data), values.count <= 24 {
            snapshots = values.filter { $0.value.temperature.isFinite && $0.value.wind.isFinite && (0...100).contains($0.value.humidity) }
        }
    }
    deinit { timer?.invalidate(); tasks.values.forEach { $0.cancel() } }
    static func request(for city: WeatherCity) throws -> URLRequest {
        try city.validate()
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [URLQueryItem(name: "latitude", value: String(city.latitude)), URLQueryItem(name: "longitude", value: String(city.longitude)), URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"), URLQueryItem(name: "timezone", value: "auto")]
        return URLRequest(url: components.url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
    }
    func setDemand(_ values: [WeatherCity]) {
        let values = Array(Dictionary(values.map { ($0.cacheKey, $0) }, uniquingKeysWith: { first, _ in first }).values).sorted { $0.cacheKey < $1.cacheKey }
        guard values != cities else { return }
        cities = values
        let keys = Set(values.map(\.cacheKey))
        for key in Array(tasks.keys) where !keys.contains(key) { tasks.removeValue(forKey: key)?.cancel(); loading.remove(key) }
        timer?.invalidate(); timer = nil
        guard allowsNetwork, !values.isEmpty else { return }
        values.forEach { refresh($0) }
        let timer = Timer(timeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.cities.forEach { self?.refresh($0) } }
        }
        timer.tolerance = 60
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func saveCache() {
        guard let url = cacheURL, let data = try? JSONEncoder().encode(snapshots) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
    func refresh(_ city: WeatherCity, force: Bool = false) {
        guard allowsNetwork, tasks[city.cacheKey] == nil else { return }
        if !force, let snapshot = snapshots[city.cacheKey], Date().timeIntervalSince(snapshot.updatedAt) < 900 { return }
        let key = city.cacheKey
        loading.insert(key)
        tasks[key] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.tasks.removeValue(forKey: key); self.loading.remove(key) }
            do {
                let (data, response) = try await self.transport(Self.request(for: city))
                guard !Task.isCancelled else { return }
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count < 100_000 else { throw URLError(.badServerResponse) }
                let value = try JSONDecoder().decode(WeatherResponse.self, from: data).snapshot()
                self.snapshots[key] = value
                self.errors.removeValue(forKey: key)
                if self.snapshots.count > 24, let old = self.snapshots.keys.first(where: { candidate in !self.cities.contains(where: { $0.cacheKey == candidate }) }) { self.snapshots.removeValue(forKey: old) }
                self.saveCache()
            } catch {
                if !Task.isCancelled { self.errors[key] = L10n.text("Weather is unavailable. Try again when connected.") }
            }
        }
    }
}

enum MusicSource: String, CaseIterable { case music = "Apple Music", spotify = "Spotify"
    var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
}
enum MusicCommand { case playPause, next, previous }
struct MusicSnapshot: Equatable { var title: String; var artist: String; var playing: Bool }
@MainActor
protocol MusicControlling {
    func read(_ source: MusicSource) throws -> MusicSnapshot
    func command(_ command: MusicCommand, source: MusicSource) throws
}

@MainActor
final class SystemMusicController: MusicControlling {
    func read(_ source: MusicSource) throws -> MusicSnapshot {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty else { throw ConnectionFailure(L10n.format("Open %@ and start a track first.", source.rawValue)) }
        let result = try execute("tell application id \"\(source.bundleID)\"\nif player state is stopped then return {\"\", \"\", false}\nreturn {name of current track, artist of current track, player state is playing}\nend tell")
        let title = result.atIndex(1)?.stringValue ?? ""
        return MusicSnapshot(title: title.isEmpty ? L10n.text("Nothing playing") : title, artist: title.isEmpty ? L10n.format("Choose a track in %@", source.rawValue) : result.atIndex(2)?.stringValue ?? "", playing: result.atIndex(3)?.booleanValue ?? false)
    }
    func command(_ command: MusicCommand, source: MusicSource) throws {
        let statement: String
        switch command { case .playPause: statement = "playpause"; case .next: statement = "next track"; case .previous: statement = "previous track" }
        _ = try execute("tell application id \"\(source.bundleID)\" to \(statement)")
    }
    private func execute(_ text: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: text) else { throw ConnectionFailure(L10n.text("Playback control is unavailable.")) }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int
            throw ConnectionFailure(code == -1743 ? L10n.text("Allow iGet in System Settings → Privacy & Security → Automation, then reconnect.") : L10n.text("Could not reach the player. Open it and choose a track, then reconnect."))
        }
        return result
    }
}

@MainActor
final class MusicProvider: ObservableObject {
    @Published private(set) var snapshot: MusicSnapshot?
    @Published private(set) var error: String?
    @Published private(set) var connected = false
    @Published var source: MusicSource = .music
    private let controller: MusicControlling
    private let allowsControl: Bool
    private var timer: Timer?
    private var demanded = false
    private var interval: TimeInterval = 5
    init(allowsControl: Bool = true, controller: MusicControlling? = nil) { self.allowsControl = allowsControl; self.controller = controller ?? SystemMusicController() }
    deinit { timer?.invalidate() }
    func connect() {
        guard allowsControl else { error = L10n.text("Player connections are disabled in previews."); return }
        connected = true
        read()
        schedule()
    }
    func disconnect() { connected = false; timer?.invalidate(); timer = nil; snapshot = nil; error = nil }
    func setDemand(_ demand: Bool, interval: TimeInterval) {
        guard demand != demanded || self.interval != interval else { return }
        demanded = demand; self.interval = interval; schedule()
    }
    func perform(_ command: MusicCommand) {
        guard connected && allowsControl else { return }
        do { try controller.command(command, source: source); read() } catch { self.error = error.localizedDescription }
    }
    private func read() {
        do { snapshot = try controller.read(source); error = nil }
        catch { self.error = error.localizedDescription; snapshot = nil; connected = false; timer?.invalidate(); timer = nil }
    }
    var isPolling: Bool { timer != nil }
    private func schedule() {
        timer?.invalidate(); timer = nil
        guard demanded, connected else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in Task { @MainActor in self?.read() } }
        timer.tolerance = interval * 0.2
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

private struct ConnectionFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
