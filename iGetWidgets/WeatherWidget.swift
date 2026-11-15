// WeatherWidget.swift
// iGet — iGetWidgets Extension
//
// WeatherKit tabanlı hava durumu widget'ı.
// Şu anki hava + 5 günlük tahmin + saatlik tahmin gösterir.
//
// Gereksinimler:
//   • WeatherKit capability (Xcode → Signing & Capabilities)
//   • com.apple.developer.weatherkit = true (Entitlements)
//   • Privacy – Location When In Use Usage Description (Info.plist)
//   • Apple Developer hesabında WeatherKit etkin olmalı
//
// Güncelleme politikası: Her 30 dakika (atEnd timeline)
//
// Target Membership: iGetWidgets
//
// Organization: TwoBit-Dev

import WidgetKit
import SwiftUI
import WeatherKit
import CoreLocation

// MARK: - Weather Models

struct WeatherSnapshot: Equatable {
    let temperature:    Double          // °C
    let feelsLike:      Double          // °C
    let condition:      WeatherConditionKind
    let humidity:       Double          // 0.0 – 1.0
    let windSpeedKmh:   Double
    let uvIndex:        Int
    let visibility:     Double          // km
    let symbolName:     String          // SF Symbol
    let locationName:   String
    let hourly:         [HourlySnapshot]
    let daily:          [DailySnapshot]

    static let placeholder = WeatherSnapshot(
        temperature: 18, feelsLike: 16, condition: .partlyCloudy,
        humidity: 0.65, windSpeedKmh: 12, uvIndex: 3, visibility: 10,
        symbolName: "cloud.sun.fill", locationName: "İstanbul",
        hourly: HourlySnapshot.samples, daily: DailySnapshot.samples
    )
}

struct HourlySnapshot: Identifiable, Equatable {
    let id         = UUID()
    let hour:      Int          // 0–23
    let temp:      Double       // °C
    let symbolName: String
}

struct DailySnapshot: Identifiable, Equatable {
    let id         = UUID()
    let dayName:   String       // "Pzt", "Sal" …
    let high:      Double
    let low:       Double
    let symbolName: String
}

extension HourlySnapshot {
    static let samples: [HourlySnapshot] = [
        HourlySnapshot(hour: 9,  temp: 14, symbolName: "cloud.sun.fill"),
        HourlySnapshot(hour: 12, temp: 18, symbolName: "sun.max.fill"),
        HourlySnapshot(hour: 15, temp: 20, symbolName: "sun.max.fill"),
        HourlySnapshot(hour: 18, temp: 17, symbolName: "cloud.fill"),
        HourlySnapshot(hour: 21, temp: 13, symbolName: "moon.fill")
    ]
}

extension DailySnapshot {
    static let samples: [DailySnapshot] = [
        DailySnapshot(dayName: "Bugün", high: 20, low: 12, symbolName: "sun.max.fill"),
        DailySnapshot(dayName: "Sal",   high: 18, low: 11, symbolName: "cloud.sun.fill"),
        DailySnapshot(dayName: "Çar",   high: 15, low: 9,  symbolName: "cloud.rain.fill"),
        DailySnapshot(dayName: "Per",   high: 17, low: 10, symbolName: "cloud.fill"),
        DailySnapshot(dayName: "Cum",   high: 22, low: 13, symbolName: "sun.max.fill")
    ]
}

// MARK: - Condition Kind

enum WeatherConditionKind: String, Equatable {
    case sunny, partlyCloudy, cloudy, rainy, snowy, stormy, foggy, windy, unknown

    var displayName: String {
        switch self {
        case .sunny:        return "Güneşli"
        case .partlyCloudy: return "Parçalı Bulutlu"
        case .cloudy:       return "Bulutlu"
        case .rainy:        return "Yağmurlu"
        case .snowy:        return "Karlı"
        case .stormy:       return "Fırtınalı"
        case .foggy:        return "Sisli"
        case .windy:        return "Rüzgarlı"
        case .unknown:      return "Bilinmiyor"
        }
    }
}

// MARK: - Weather Entry

struct WeatherEntry: TimelineEntry {
    let date:     Date
    let snapshot: WeatherSnapshot?
    let error:    WeatherError?
    let theme:    WidgetTheme
    let config:   WidgetConfig
}

enum WeatherError: Error, Equatable {
    case locationDenied
    case networkUnavailable
    case weatherKitUnavailable
    case unknown(String)
}

// MARK: - WeatherKit Fetcher

/// WeatherKit API'sini saran yardımcı aktör.
actor WeatherFetcher {

    static let shared = WeatherFetcher()
    private let service = WeatherService.shared

    private init() {}

    // MARK: Fetch

    func fetch(for location: CLLocation) async throws -> WeatherSnapshot {
        let weather = try await service.weather(for: location)

        let current  = weather.currentWeather
        let hourly   = weather.hourlyForecast.forecast
        let daily    = weather.dailyForecast.forecast

        // Türkçe gün adları
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "tr_TR")
        dayFormatter.dateFormat = "EEE"

        let hourlySnapshots: [HourlySnapshot] = hourly.prefix(6).map { h in
            HourlySnapshot(
                hour:       Calendar.current.component(.hour, from: h.date),
                temp:       h.temperature.converted(to: .celsius).value,
                symbolName: h.symbolName
            )
        }

        let dailySnapshots: [DailySnapshot] = daily.prefix(5).enumerated().map { (idx, d) in
            DailySnapshot(
                dayName:   idx == 0 ? "Bugün" : dayFormatter.string(from: d.date).capitalized,
                high:      d.highTemperature.converted(to: .celsius).value,
                low:       d.lowTemperature.converted(to: .celsius).value,
                symbolName: d.symbolName
            )
        }

        return WeatherSnapshot(
            temperature:  current.temperature.converted(to: .celsius).value,
            feelsLike:    current.apparentTemperature.converted(to: .celsius).value,
            condition:    mapCondition(current.condition),
            humidity:     current.humidity,
            windSpeedKmh: current.wind.speed.converted(to: .kilometersPerHour).value,
            uvIndex:      current.uvIndex.value,
            visibility:   current.visibility.converted(to: .kilometers).value,
            symbolName:   current.symbolName,
            locationName: "",                // Reverse geocoding ile doldurulur
            hourly:       hourlySnapshots,
            daily:        dailySnapshots
        )
    }

    // MARK: Condition Mapping

    private func mapCondition(_ condition: WeatherCondition) -> WeatherConditionKind {
        switch condition {
        case .clear:          return .sunny
        case .partlyCloudy:   return .partlyCloudy
        case .mostlyCloudy,
             .cloudy:         return .cloudy
        case .drizzle,
             .rain,
             .heavyRain:      return .rainy
        case .snow,
             .heavySnow,
             .flurries:       return .snowy
        case .thunderstorms,
             .tropicalStorm,
             .hurricane:      return .stormy
        case .foggy,
             .haze:           return .foggy
        case .windy,
             .breezy:         return .windy
        default:              return .unknown
        }
    }
}

// MARK: - Location Helper

final class WidgetLocationHelper: NSObject, CLLocationManagerDelegate {

    static let shared = WidgetLocationHelper()
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    private override init() {
        super.init()
        manager.delegate           = self
        manager.desiredAccuracy    = kCLLocationAccuracyKilometer
        manager.distanceFilter     = 5000  // 5 km altı değişiklikler güncelleme tetiklemez
    }

    /// Tek seferlik konum ister.
    func currentLocation() async -> CLLocation? {
        await withCheckedContinuation { cont in
            continuation = cont
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

// MARK: - Weather Provider

struct WeatherProvider: TimelineProvider {
    typealias Entry = WeatherEntry

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), snapshot: .placeholder, error: nil, theme: .default, config: .weather())
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (WeatherEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            // 30 dakikada bir güncelle
            let next = Date().addingTimeInterval(30 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(next))
            completion(timeline)
        }
    }

    // MARK: Helper

    private func makeEntry() async -> WeatherEntry {
        let theme  = SharedStorage.shared.appSettings.globalTheme
        let config = SharedStorage.shared.widgetKitConfig(for: .weather) ?? .weather()

        // Konum al
        guard let location = await WidgetLocationHelper.shared.currentLocation() else {
            return WeatherEntry(
                date: Date(), snapshot: nil, error: .locationDenied,
                theme: theme, config: config
            )
        }

        do {
            var snapshot = try await WeatherFetcher.shared.fetch(for: location)

            // Reverse geocoding ile şehir adını ekle
            let cityName = await reverseGeocode(location) ?? config.metadata["locationName"] ?? "Konum"
            snapshot = WeatherSnapshot(
                temperature:  snapshot.temperature,
                feelsLike:    snapshot.feelsLike,
                condition:    snapshot.condition,
                humidity:     snapshot.humidity,
                windSpeedKmh: snapshot.windSpeedKmh,
                uvIndex:      snapshot.uvIndex,
                visibility:   snapshot.visibility,
                symbolName:   snapshot.symbolName,
                locationName: cityName,
                hourly:       snapshot.hourly,
                daily:        snapshot.daily
            )

            return WeatherEntry(date: Date(), snapshot: snapshot, error: nil, theme: theme, config: config)

        } catch {
            return WeatherEntry(
                date: Date(), snapshot: nil,
                error: .unknown(error.localizedDescription),
                theme: theme, config: config
            )
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { cont in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                cont.resume(returning: placemarks?.first?.locality)
            }
        }
    }
}

// MARK: - Weather Widget

struct WeatherWidget: Widget {
    let kind = iGetWidgetKind.weather

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Hava Durumu")
        .description("Şu anki hava ve 5 günlük tahmin.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - WeatherWidgetView

struct WeatherWidgetView: View {
    let entry: WeatherEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        ThemedWidgetContainer(theme: entry.theme) {
            if let error = entry.error {
                WeatherErrorView(error: error, accentColor: entry.theme.accentColor)
            } else if let snapshot = entry.snapshot {
                switch family {
                case .systemSmall:
                    WeatherSmallView(snapshot: snapshot, theme: entry.theme)
                case .systemMedium:
                    WeatherMediumView(snapshot: snapshot, theme: entry.theme)
                case .systemLarge:
                    WeatherLargeView(snapshot: snapshot, theme: entry.theme)
                default:
                    WeatherSmallView(snapshot: snapshot, theme: entry.theme)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Small: Sıcaklık + Sembol + Şehir

private struct WeatherSmallView: View {
    let snapshot: WeatherSnapshot
    let theme:    WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.locationName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: snapshot.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 22))
            }

            Spacer()

            Text("\(Int(snapshot.temperature.rounded()))°")
                .font(.system(size: 48, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)

            Text(snapshot.condition.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium: Şu an + Saatlik tahmin

private struct WeatherMediumView: View {
    let snapshot: WeatherSnapshot
    let theme:    WidgetTheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Sol: mevcut durum
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int(snapshot.temperature.rounded()))°C")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text(snapshot.condition.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(snapshot.locationName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                // Detaylar
                HStack(spacing: 10) {
                    WeatherDetailBadge(symbol: "humidity.fill",   value: "\(Int(snapshot.humidity * 100))%")
                    WeatherDetailBadge(symbol: "wind",            value: "\(Int(snapshot.windSpeedKmh))km/h")
                    WeatherDetailBadge(symbol: "eye",             value: "\(Int(snapshot.visibility))km")
                }
            }
            .frame(maxWidth: .infinity)

            Divider().opacity(0.3)

            // Sağ: saatlik tahmin
            VStack(alignment: .center, spacing: 6) {
                ForEach(snapshot.hourly.prefix(4)) { h in
                    HStack(spacing: 6) {
                        Text(String(format: "%02d:00", h.hour))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)
                        Image(systemName: h.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 12))
                        Text("\(Int(h.temp.rounded()))°")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Large: Şu an + Saatlik + 5 Günlük

private struct WeatherLargeView: View {
    let snapshot: WeatherSnapshot
    let theme:    WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Mevcut durum başlık
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.locationName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(Int(snapshot.temperature.rounded()))°C")
                        .font(.system(size: 52, weight: .thin, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Hissedilen \(Int(snapshot.feelsLike.rounded()))° · \(snapshot.condition.displayName)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: snapshot.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 56))
            }

            Divider().opacity(0.3)

            // Detay rozetler
            HStack(spacing: 14) {
                WeatherDetailBadge(symbol: "humidity.fill",   value: "\(Int(snapshot.humidity * 100))%",   label: "Nem")
                WeatherDetailBadge(symbol: "wind",            value: "\(Int(snapshot.windSpeedKmh))km/h", label: "Rüzgar")
                WeatherDetailBadge(symbol: "sun.max.fill",    value: "UV \(snapshot.uvIndex)",             label: "UV İndeksi")
                WeatherDetailBadge(symbol: "eye",             value: "\(Int(snapshot.visibility))km",      label: "Görüş")
            }

            Divider().opacity(0.3)

            // Saatlik tahmin
            HStack(spacing: 0) {
                ForEach(snapshot.hourly) { h in
                    VStack(spacing: 4) {
                        Text(String(format: "%02d", h.hour))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Image(systemName: h.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 14))
                        Text("\(Int(h.temp.rounded()))°")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider().opacity(0.3)

            // 5 günlük tahmin
            VStack(spacing: 6) {
                ForEach(snapshot.daily) { d in
                    HStack(spacing: 8) {
                        Text(d.dayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .leading)
                        Image(systemName: d.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 14))
                        Spacer()
                        // Sıcaklık aralığı bar
                        DailyTempBar(low: d.low, high: d.high,
                                     globalLow: snapshot.daily.map(\.low).min() ?? 0,
                                     globalHigh: snapshot.daily.map(\.high).max() ?? 40,
                                     accentColor: theme.accentColor)
                            .frame(width: 60, height: 5)
                        Text("\(Int(d.low.rounded()))° – \(Int(d.high.rounded()))°")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(width: 72, alignment: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - WeatherDetailBadge

private struct WeatherDetailBadge: View {
    let symbol: String
    let value:  String
    var label:  String = ""

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.multicolor)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - DailyTempBar

private struct DailyTempBar: View {
    let low:         Double
    let high:        Double
    let globalLow:   Double
    let globalHigh:  Double
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let range = globalHigh - globalLow
            guard range > 0 else {
                return AnyView(Capsule().fill(.secondary.opacity(0.2)))
            }

            let startFraction = (low  - globalLow) / range
            let endFraction   = (high - globalLow) / range
            let barWidth      = geo.size.width

            return AnyView(
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.15))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.6), accentColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(
                            width:  barWidth * (endFraction - startFraction),
                            height: 5
                        )
                        .offset(x: barWidth * startFraction)
                }
            )
        }
    }
}

// MARK: - Error View

private struct WeatherErrorView: View {
    let error:       WeatherError
    let accentColor: Color

    var errorMessage: String {
        switch error {
        case .locationDenied:        return "Konum erişimi reddedildi.\nAyarlar'dan izin verin."
        case .networkUnavailable:    return "İnternet bağlantısı yok."
        case .weatherKitUnavailable: return "WeatherKit servisi kullanılamıyor."
        case .unknown(let msg):      return msg
        }
    }

    var symbolName: String {
        switch error {
        case .locationDenied:     return "location.slash.fill"
        case .networkUnavailable: return "wifi.slash"
        default:                  return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 32))
                .foregroundStyle(accentColor)
            Text(errorMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG && canImport(XcodePreview)
#Preview("Hava Küçük", as: .systemSmall) {
    WeatherWidget()
} timeline: {
    WeatherEntry(date: Date(), snapshot: .placeholder, error: nil, theme: .default, config: .weather())
}

#Preview("Hava Orta", as: .systemMedium) {
    WeatherWidget()
} timeline: {
    WeatherEntry(date: Date(), snapshot: .placeholder, error: nil, theme: .dark, config: .weather())
}

#Preview("Hava Büyük", as: .systemLarge) {
    WeatherWidget()
} timeline: {
    WeatherEntry(date: Date(), snapshot: .placeholder, error: nil, theme: .default, config: .weather())
}
#endif
