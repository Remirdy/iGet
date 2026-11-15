// PreviewFixtures.swift
// Packages/iGetCore/Sources/iGetCore/PreviewFixtures.swift
//
// Zeynep'in UI geliştirmesinde loading, empty, stale ve error durumlarını
// test edebilmesi için mock ve örnek veri sağlayıcıları.

import Foundation

public enum PreviewFixtures {

    // MARK: - Clock Fixture

    public static let clockSnapshot = WidgetSnapshot(
        updatedAt: Date(),
        state: .ready,
        payload: .clock(ClockPayload(cityName: "İSTANBUL", timezoneIdentifier: "Europe/Istanbul", is24Hour: true))
    )

    // MARK: - Countdown Fixture

    public static var countdownSnapshot: WidgetSnapshot {
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .day, value: 12, to: Date()) ?? Date()
        return WidgetSnapshot(
            updatedAt: Date(),
            state: .ready,
            payload: .countdown(CountdownPayload(eventName: "SONRAKİ SINAV", targetDate: target, subtitle: "Algoritmalar"))
        )
    }

    // MARK: - Tasks Fixture

    public static let tasksSnapshot = WidgetSnapshot(
        updatedAt: Date(),
        state: .ready,
        payload: .tasks(TasksPayload(
            title: "BUGÜN",
            tasks: [
                TaskItem(title: "Kitap bölümünü oku", isCompleted: true),
                TaskItem(title: "PR'ı incele", isCompleted: false),
                TaskItem(title: "Notları teslim et", isCompleted: false)
            ]
        ))
    )

    // MARK: - Focus Fixture

    public static let focusSnapshot = WidgetSnapshot(
        updatedAt: Date(),
        state: .ready,
        payload: .focus(FocusPayload(
            currentSeconds: 24 * 60 + 8,
            totalSeconds: 25 * 60,
            isActive: true,
            label: "Derin Çalışma"
        ))
    )

    // MARK: - Empty & Error Fixtures

    public static let emptyTasksSnapshot = WidgetSnapshot(
        updatedAt: Date(),
        state: .empty,
        payload: .tasks(TasksPayload(title: "BUGÜN", tasks: []))
    )

    public static let errorSnapshot = WidgetSnapshot(
        updatedAt: Date(),
        state: .error,
        payload: .clock(ClockPayload())
    )
}

// MARK: - Mock Widget Data Provider

public final class MockWidgetDataProvider: WidgetDataProvider {
    public init() {}

    public func snapshot(for config: WidgetConfig) async throws -> WidgetSnapshot {
        switch config.kind {
        case .clock:
            return PreviewFixtures.clockSnapshot
        case .countdown:
            return PreviewFixtures.countdownSnapshot
        case .tasks:
            return PreviewFixtures.tasksSnapshot
        case .focus:
            return PreviewFixtures.focusSnapshot
        default:
            return PreviewFixtures.clockSnapshot
        }
    }
}
