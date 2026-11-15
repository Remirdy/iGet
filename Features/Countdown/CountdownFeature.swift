// CountdownFeature.swift
// Features/Countdown/CountdownFeature.swift
//
// Geri Sayım / Sınav Sayacı İş Mantığı
// Sorumlu: Zeynep (#06 Z · Countdown)

import Foundation

public struct CountdownItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var subtitle: String
    public var targetDate: Date

    public init(id: UUID = UUID(), title: String, subtitle: String, targetDate: Date) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.targetDate = targetDate
    }

    public var daysRemaining: Int {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let startTarget = cal.startOfDay(for: targetDate)
        let diff = cal.dateComponents([.day], from: startToday, to: startTarget).day ?? 0
        return max(0, diff)
    }

    public var isExpired: Bool {
        targetDate < Date()
    }
}
