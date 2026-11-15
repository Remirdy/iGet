// CalendarWidget.swift
// iGet — iGetWidgets Extension
//
// EventKit tabanlı takvim widget'ı.
// Bugünün ve yarının etkinliklerini listeler.
// Kullanıcı takvim erişimi vermediyse izin iste ekranı gösterir.
//
// Güncelleme politikası:
//   • Her saat başı yeni timeline (atEnd)
//   • Yeni etkinlik eklenince iGet.app → WidgetCenter.reloadTimelines(ofKind:)
//
// Target Membership: iGetWidgets
//
// Organization: TwoBit-Dev

import WidgetKit
import SwiftUI
import EventKit

// MARK: - Calendar Models

struct CalendarEvent: Identifiable, Equatable {
    let id:         String
    let title:      String
    let startDate:  Date
    let endDate:    Date
    let isAllDay:   Bool
    let calendarColor: Color

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    var timeString: String {
        if isAllDay { return "Tüm gün" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }

    var isHappeningNow: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }
}

// MARK: - Calendar Entry

struct CalendarEntry: TimelineEntry {
    let date:            Date
    let todayEvents:     [CalendarEvent]
    let tomorrowEvents:  [CalendarEvent]
    let isAuthorized:    Bool
    let theme:           WidgetTheme
    let config:          WidgetConfig
}

// MARK: - EventKit Manager

/// EventKit ile takvim etkinliklerini çeken yardımcı sınıf.
final class EventKitManager {

    static let shared = EventKitManager()
    private let store = EKEventStore()
    private init() {}

    // MARK: Authorization

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        guard !isAuthorized else { return true }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    // MARK: Fetch

    /// Belirtilen tarih aralığındaki etkinlikleri döner.
    func events(from start: Date, to end: Date) -> [CalendarEvent] {
        guard isAuthorized else { return [] }

        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let raw       = store.events(matching: predicate)
                             .sorted { $0.startDate < $1.startDate }

        return raw.map { ek in
            CalendarEvent(
                id:            ek.eventIdentifier ?? UUID().uuidString,
                title:         ek.title ?? "(Başlıksız)",
                startDate:     ek.startDate,
                endDate:       ek.endDate,
                isAllDay:      ek.isAllDay,
                calendarColor: Color(nsColor: ek.calendar.color ?? .systemBlue)
            )
        }
    }

    /// Bugünün ve yarının etkinliklerini tuple olarak döner.
    func fetchTodayAndTomorrow() -> (today: [CalendarEvent], tomorrow: [CalendarEvent]) {
        let cal   = Calendar.current
        let now   = Date()

        let startOfToday    = cal.startOfDay(for: now)
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        let endOfTomorrow   = cal.date(byAdding: .day, value: 2, to: startOfToday)!

        let today    = events(from: startOfToday,    to: startOfTomorrow)
        let tomorrow = events(from: startOfTomorrow, to: endOfTomorrow)

        return (today, tomorrow)
    }
}

// MARK: - Calendar Provider

struct CalendarProvider: TimelineProvider {
    typealias Entry = CalendarEntry

    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(
            date:           Date(),
            todayEvents:    CalendarEntry.sampleEvents,
            tomorrowEvents: [],
            isAuthorized:   true,
            theme:          .default,
            config:         .calendar()
        )
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (CalendarEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        Task {
            let entry = await makeEntry()

            // Her saat başı güncelle
            let nextUpdate = Calendar.current.date(
                byAdding: .hour, value: 1, to: Date()
            ) ?? Date().addingTimeInterval(3600)

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    // MARK: Helper

    private func makeEntry() async -> CalendarEntry {
        let manager   = EventKitManager.shared
        let authorized = await manager.requestAccess()
        let (today, tomorrow) = manager.fetchTodayAndTomorrow()
        let theme  = SharedStorage.shared.appSettings.globalTheme
        let config = SharedStorage.shared.widgetKitConfig(for: .calendar) ?? .calendar()

        return CalendarEntry(
            date:           Date(),
            todayEvents:    today,
            tomorrowEvents: tomorrow,
            isAuthorized:   authorized,
            theme:          theme,
            config:         config
        )
    }
}

// MARK: - Sample Data

extension CalendarEntry {
    static let sampleEvents: [CalendarEvent] = [
        CalendarEvent(
            id: "1", title: "Tasarım Toplantısı",
            startDate: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
            endDate:   Calendar.current.date(bySettingHour: 11, minute: 30, second: 0, of: Date())!,
            isAllDay: false, calendarColor: .blue
        ),
        CalendarEvent(
            id: "2", title: "Öğle Yemeği",
            startDate: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!,
            endDate:   Calendar.current.date(bySettingHour: 13, minute: 30, second: 0, of: Date())!,
            isAllDay: false, calendarColor: .green
        ),
        CalendarEvent(
            id: "3", title: "Sprint Review",
            startDate: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!,
            endDate:   Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
            isAllDay: false, calendarColor: .orange
        )
    ]
}

// MARK: - Calendar Widget

struct CalendarWidget: Widget {
    let kind = iGetWidgetKind.calendar

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Takvim")
        .description("Bugün ve yarınki etkinliklerinizi gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - CalendarWidgetView

struct CalendarWidgetView: View {
    let entry: CalendarEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        ThemedWidgetContainer(theme: entry.theme) {
            if !entry.isAuthorized {
                CalendarPermissionView(accentColor: entry.theme.accentColor)
            } else {
                switch family {
                case .systemSmall:
                    CalendarSmallView(entry: entry)
                case .systemMedium:
                    CalendarMediumView(entry: entry)
                case .systemLarge:
                    CalendarLargeView(entry: entry)
                default:
                    CalendarMediumView(entry: entry)
                }
            }
        }
    }
}

// MARK: - Small: Bugünün tarihi + etkinlik sayısı

private struct CalendarSmallView: View {
    let entry: CalendarEntry

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "MMMM"
        return f
    }()

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Gün adı
            Text(Self.dayNameFormatter.string(from: entry.date).capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            // Gün numarası (büyük)
            Text(Self.dayFormatter.string(from: entry.date))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(entry.theme.accentColor)
                .lineLimit(1)

            // Ay adı
            Text(Self.monthFormatter.string(from: entry.date).capitalized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Etkinlik sayısı
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(entry.theme.accentColor)
                Text("\(entry.todayEvents.count) etkinlik")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium: Bugünün etkinlik listesi

private struct CalendarMediumView: View {
    let entry: CalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Başlık
            HStack {
                Label("Bugün", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(entry.theme.accentColor)
                Spacer()
                Text(entry.date, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Divider().opacity(0.3)

            if entry.todayEvents.isEmpty {
                EmptyEventsView(message: "Bugün etkinlik yok ✓")
            } else {
                ForEach(entry.todayEvents.prefix(3)) { event in
                    EventRow(event: event, accentColor: entry.theme.accentColor)
                }
                if entry.todayEvents.count > 3 {
                    Text("+ \(entry.todayEvents.count - 3) etkinlik daha")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Large: Bugün + Yarın

private struct CalendarLargeView: View {
    let entry: CalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // BUGÜN
            SectionHeader(title: "Bugün", systemImage: "sun.max.fill", color: entry.theme.accentColor)

            if entry.todayEvents.isEmpty {
                EmptyEventsView(message: "Bugün etkinlik yok ✓")
            } else {
                ForEach(entry.todayEvents.prefix(4)) { event in
                    EventRow(event: event, accentColor: entry.theme.accentColor)
                }
                if entry.todayEvents.count > 4 {
                    Text("+ \(entry.todayEvents.count - 4) etkinlik daha")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Divider().opacity(0.3).padding(.vertical, 2)

            // YARIN
            SectionHeader(title: "Yarın", systemImage: "moon.stars.fill", color: .secondary)

            if entry.tomorrowEvents.isEmpty {
                EmptyEventsView(message: "Yarın etkinlik yok")
            } else {
                ForEach(entry.tomorrowEvents.prefix(3)) { event in
                    EventRow(event: event, accentColor: entry.theme.accentColor)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Shared Sub-Views

private struct SectionHeader: View {
    let title:       String
    let systemImage: String
    let color:       Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
    }
}

private struct EventRow: View {
    let event:       CalendarEvent
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            // Takvim renk çubuğu
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(event.timeString)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Şu an devam eden etkinlik
            if event.isHappeningNow {
                Text("Devam ediyor")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct EmptyEventsView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }
}

private struct CalendarPermissionView: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(accentColor)
            Text("Takvim Erişimi Gerekli")
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Ayarlar'dan iGet'e takvim izni verin.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG && canImport(XcodePreview)
#Preview("Takvim Orta", as: .systemMedium) {
    CalendarWidget()
} timeline: {
    CalendarEntry(
        date:           Date(),
        todayEvents:    CalendarEntry.sampleEvents,
        tomorrowEvents: [CalendarEntry.sampleEvents[0]],
        isAuthorized:   true,
        theme:          .default,
        config:         .calendar()
    )
}

#Preview("Takvim Büyük", as: .systemLarge) {
    CalendarWidget()
} timeline: {
    CalendarEntry(
        date:           Date(),
        todayEvents:    CalendarEntry.sampleEvents,
        tomorrowEvents: CalendarEntry.sampleEvents,
        isAuthorized:   true,
        theme:          .dark,
        config:         .calendar()
    )
}
#endif
