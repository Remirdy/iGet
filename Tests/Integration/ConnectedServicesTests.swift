import AppKit
import Foundation

@main
@MainActor
struct ConnectedServicesTests {
    static var checks = 0
    struct Failure: Error { let message: String }
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw Failure(message: message) }; checks += 1
    }
    static func wait(_ provider: WeatherProvider) async throws {
        for _ in 0..<1000 {
            if provider.loading.isEmpty { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw Failure(message: "Weather request timed out")
    }
    static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        LocalizationManager.shared.select(.english)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let city = WeatherCity.presets[1]
        let fixture = Data("{\"current\":{\"temperature_2m\":15.2,\"relative_humidity_2m\":72,\"wind_speed_10m\":8.4,\"weather_code\":3}}".utf8)
        var requests = 0
        var fail = false
        let cacheURL = root.appendingPathComponent("weather.json")
        let provider = WeatherProvider(cacheURL: cacheURL) { request in
            requests += 1
            if fail { throw URLError(.notConnectedToInternet) }
            return (fixture, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        provider.setDemand([city, city])
        try await wait(provider)
        try expect(requests == 1, "Weather requests are deduplicated")
        try expect(provider.snapshots[city.cacheKey]?.temperature == 15.2, "Weather response reaches the observable snapshot")
        try expect(provider.snapshots[city.cacheKey]?.condition == "Partly cloudy", "Weather code maps to a condition")
        LocalizationManager.shared.select(.turkish)
        try expect(provider.snapshots[city.cacheKey]?.condition == "Parçalı bulutlu", "Cached weather conditions follow Turkish selection")
        LocalizationManager.shared.select(.german)
        try expect(provider.snapshots[city.cacheKey]?.condition == "Teilweise bewölkt", "Cached weather conditions follow German selection")
        LocalizationManager.shared.select(.english)
        provider.refresh(city)
        try expect(requests == 1 && provider.loading.isEmpty, "Fresh data is cached for fifteen minutes")
        fail = true
        provider.refresh(city, force: true)
        try await wait(provider)
        try expect(provider.errors[city.cacheKey] != nil && provider.snapshots[city.cacheKey]?.temperature == 15.2, "Offline failures keep the last reading")
        provider.setDemand([])
        let cached = WeatherProvider(cacheURL: cacheURL, transport: { _ in throw URLError(.notConnectedToInternet) })
        try expect(cached.snapshots[city.cacheKey]?.temperature == 15.2, "Weather cache survives reopening")
        let disabled = WeatherProvider(allowsNetwork: false, cacheURL: root.appendingPathComponent("unused.json")) { _ in requests += 1; throw URLError(.cancelled) }
        let count = requests
        disabled.setDemand([city]); disabled.refresh(city, force: true)
        try expect(disabled.loading.isEmpty && requests == count, "Preview mode makes no requests")
        let bad = WeatherProvider(cacheURL: root.appendingPathComponent("bad.json")) { request in
            (Data("{\"current\":{\"temperature_2m\":900,\"relative_humidity_2m\":72,\"wind_speed_10m\":8.4,\"weather_code\":3}}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        bad.setDemand([city]); try await wait(bad)
        try expect(bad.snapshots.isEmpty && bad.errors[city.cacheKey] != nil, "Invalid weather values do not become live data")
        bad.setDemand([])
        let player = TestPlayer()
        let music = MusicProvider(controller: player)
        music.setDemand(true, interval: 5)
        try expect(!music.connected && !music.isPolling && player.reads == 0, "Music does not request access before connecting")
        music.connect()
        try expect(music.snapshot?.title == "A test track" && music.isPolling, "Music connects through its controller")
        music.perform(.playPause); music.perform(.next); music.perform(.previous)
        try expect(player.commands.count == 3 && player.reads == 4, "Playback controls reach the controller and refresh state")
        music.setDemand(false, interval: 5)
        try expect(!music.isPolling, "Hidden music widgets stop polling")
        music.disconnect()
        try expect(!music.connected && music.snapshot == nil, "Disconnect clears the player")
        player.denied = true
        music.setDemand(true, interval: 5); music.connect()
        try expect(!music.connected && !music.isPolling && music.error != nil, "Denied Automation access leaves a recoverable connection state")
        if ProcessInfo.processInfo.environment["IGET_TEST_LIVE_WEATHER"] == "1" {
            let live = WeatherProvider(cacheURL: root.appendingPathComponent("live.json"))
            live.setDemand([city]); try await wait(live)
            try expect(live.snapshots[city.cacheKey] != nil && live.errors[city.cacheKey] == nil, "Live Open-Meteo request succeeds")
            if let value = live.snapshots[city.cacheKey] { print("Live weather verified for London: \(value.temperature) °C") }
            live.setDemand([])
        }
        print("Passed \(checks) service checks: weather transport, caching, offline errors, player consent and playback dispatch.")
    }
}

@MainActor
final class TestPlayer: MusicControlling {
    var reads = 0
    var commands: [MusicCommand] = []
    var denied = false
    func read(_ source: MusicSource) throws -> MusicSnapshot {
        reads += 1
        if denied { throw URLError(.userAuthenticationRequired) }
        return MusicSnapshot(title: "A test track", artist: "Test artist", playing: true)
    }
    func command(_ command: MusicCommand, source: MusicSource) throws { commands.append(command) }
}
