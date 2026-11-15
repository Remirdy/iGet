// ClockWidget.swift
// iGet — iGetWidgets Extension
//
// Analog + dijital saat widget'ı.
// Her dakika başı güncellenir (TimelinePolicy: .atEnd).
// Küçük boyutta analog, orta/büyük boyutta analog + dijital gösterim.
//
// Target Membership: iGetWidgets
//
// Organization: TwoBit-Dev

import WidgetKit
import SwiftUI

// MARK: - Clock Entry

struct ClockEntry: TimelineEntry {
    let date:   Date
    let theme:  WidgetTheme
    let config: WidgetConfig
}

// MARK: - Clock Provider

struct ClockProvider: TimelineProvider {

    typealias Entry = ClockEntry

    // MARK: Placeholder

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), theme: .default, config: .clock())
    }

    // MARK: Snapshot

    func getSnapshot(in context: Context,
                     completion: @escaping (ClockEntry) -> Void) {
        let entry = makeEntry(for: Date())
        completion(entry)
    }

    // MARK: Timeline

    /// Her dakika başı güncellenecek 60 entry üretir (1 saatlik buffer).
    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let now      = Date()
        let calendar = Calendar.current
        var entries: [ClockEntry] = []

        // Şu anki dakikanın başına yuvarla
        let startOfMinute = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        ) ?? now

        for minute in 0..<60 {
            let date  = calendar.date(byAdding: .minute, value: minute, to: startOfMinute) ?? now
            let entry = makeEntry(for: date)
            entries.append(entry)
        }

        // Son entry'nin hemen ardından yeni timeline iste
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    // MARK: Helper

    private func makeEntry(for date: Date) -> ClockEntry {
        let config = SharedStorage.shared.widgetKitConfig(for: .clock) ?? .clock()
        let theme  = SharedStorage.shared.appSettings.globalTheme
        return ClockEntry(date: date, theme: theme, config: config)
    }
}

// MARK: - Clock Widget

struct ClockWidget: Widget {
    let kind = iGetWidgetKind.clock

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("Saat")
        .description("Analog ve dijital saati masaüstünüzde gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - ClockWidgetView

struct ClockWidgetView: View {
    let entry: ClockEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        ThemedWidgetContainer(theme: entry.theme) {
            switch family {
            case .systemSmall:
                AnalogClockFace(date: entry.date, accentColor: entry.theme.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .systemMedium:
                HStack(spacing: 16) {
                    AnalogClockFace(date: entry.date, accentColor: entry.theme.accentColor)
                        .frame(width: 90, height: 90)
                    DigitalClockPanel(date: entry.date, accentColor: entry.theme.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            case .systemLarge:
                VStack(spacing: 12) {
                    AnalogClockFace(date: entry.date, accentColor: entry.theme.accentColor)
                        .frame(width: 160, height: 160)
                    DigitalClockPanel(date: entry.date, accentColor: entry.theme.accentColor)
                }

            default:
                AnalogClockFace(date: entry.date, accentColor: entry.theme.accentColor)
            }
        }
    }
}

// MARK: - AnalogClockFace

struct AnalogClockFace: View {
    let date:        Date
    let accentColor: Color

    private var calendar: Calendar { .current }

    private var seconds: Double {
        Double(calendar.component(.second, from: date))
    }
    private var minutes: Double {
        let m = Double(calendar.component(.minute, from: date))
        let s = Double(calendar.component(.second, from: date))
        return m + s / 60.0
    }
    private var hours: Double {
        let h = Double(calendar.component(.hour,   from: date)) .truncatingRemainder(dividingBy: 12)
        let m = Double(calendar.component(.minute, from: date))
        return h + m / 60.0
    }

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 4

            ZStack {
                // Kadran
                Circle()
                    .stroke(accentColor.opacity(0.15), lineWidth: 2)
                    .frame(width: size - 8, height: size - 8)
                    .position(center)

                // Saat tikleri
                ForEach(0..<12, id: \.self) { tick in
                    let angle = Angle(degrees: Double(tick) * 30 - 90)
                    let isMajor = tick % 3 == 0
                    Rectangle()
                        .fill(isMajor ? accentColor : accentColor.opacity(0.4))
                        .frame(width: isMajor ? 2 : 1, height: isMajor ? 8 : 5)
                        .offset(y: -radius + (isMajor ? 4 : 2.5))
                        .rotationEffect(angle)
                        .position(center)
                }

                // Saatlik akrep
                ClockHand(
                    angle:     Angle(degrees: hours * 30 - 90),
                    length:    radius * 0.55,
                    width:     3,
                    color:     .primary,
                    center:    center
                )

                // Dakikalık yelkovan
                ClockHand(
                    angle:     Angle(degrees: minutes * 6 - 90),
                    length:    radius * 0.80,
                    width:     2,
                    color:     .primary,
                    center:    center
                )

                // Saniyelik ibre (ince, aksan renkli)
                ClockHand(
                    angle:     Angle(degrees: seconds * 6 - 90),
                    length:    radius * 0.88,
                    width:     1,
                    color:     accentColor,
                    center:    center,
                    hasCounterTail: true,
                    tailLength: radius * 0.20
                )

                // Merkez noktası
                Circle()
                    .fill(accentColor)
                    .frame(width: 7, height: 7)
                    .position(center)
            }
        }
    }
}

// MARK: - ClockHand

private struct ClockHand: View {
    let angle:          Angle
    let length:         Double
    let width:          Double
    let color:          Color
    let center:         CGPoint
    var hasCounterTail: Bool   = false
    var tailLength:     Double = 0

    var body: some View {
        ZStack {
            // Baş
            Rectangle()
                .fill(color)
                .frame(width: width, height: length)
                .offset(y: -length / 2)
                .rotationEffect(angle)
                .position(center)

            // Kuyruk (saniye ibresi için)
            if hasCounterTail {
                Rectangle()
                    .fill(color.opacity(0.7))
                    .frame(width: width * 0.8, height: tailLength)
                    .offset(y: tailLength / 2)
                    .rotationEffect(angle)
                    .position(center)
            }
        }
    }
}

// MARK: - DigitalClockPanel

struct DigitalClockPanel: View {
    let date:        Date
    let accentColor: Color

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    private static let secondFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Saat
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(Self.timeFormatter.string(from: date))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(Self.secondFormatter.string(from: date))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(accentColor)
            }

            // Tarih
            Text(Self.dateFormatter.string(from: date).capitalized)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            // Hafta numarası
            let weekNumber = Calendar.current.component(.weekOfYear, from: date)
            Text("Hafta \(weekNumber)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Preview
// #Preview macro'ları yalnızca Xcode Canvas'ta çalışır.
// Sandbox ortamında (xcodebuild CLI) swift-plugin-server kısıtlandığından
// bu blok derleme dışı bırakılmıştır.
// Xcode'da önizleme için ENABLE_PREVIEWS=YES ile açılabilir.

#if DEBUG && canImport(XcodePreview)
#Preview("Küçük", as: .systemSmall) {
    ClockWidget()
} timeline: {
    ClockEntry(date: Date(), theme: .default, config: .clock())
}

#Preview("Orta", as: .systemMedium) {
    ClockWidget()
} timeline: {
    ClockEntry(date: Date(), theme: .dark, config: .clock())
}
#endif
