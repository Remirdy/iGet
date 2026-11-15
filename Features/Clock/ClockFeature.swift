// ClockFeature.swift
// Features/Clock/ClockFeature.swift
//
// Saat Özelliği Mantığı ve Biçimlendiricisi
// Sorumlu: Zeynep (#04 Z · Clock)

import Foundation

public final class ClockFeature {
    public static let shared = ClockFeature()
    private init() {}

    private let timeFormatter24: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private let timeFormatter12: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "h:mm a"
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    public func formatTime(_ date: Date = Date(), is24Hour: Bool = true) -> String {
        is24Hour ? timeFormatter24.string(from: date) : timeFormatter12.string(from: date)
    }

    public func formatDate(_ date: Date = Date()) -> String {
        dateFormatter.string(from: date).capitalized
    }
}
