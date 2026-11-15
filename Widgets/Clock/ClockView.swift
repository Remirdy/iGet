// ClockView.swift
// Widgets/Clock/ClockView.swift
//
// iGet Mat Tasarım Sistemine Uygun Clock Widget Görünümü
// Blueprint Konsepti: ISTANBUL / 09:41 / Sunday, 15 November
// Sorumlu: Zeynep (#04 Z · Clock)

import SwiftUI

public struct ClockView: View {
    public let theme: ThemePalette
    public let size: WidgetCardSize
    public let cityName: String
    public let date: Date
    public let is24Hour: Bool

    public init(
        theme: ThemePalette = ThemeTokens.sage,
        size: WidgetCardSize = .small,
        cityName: String = "İSTANBUL",
        date: Date = Date(),
        is24Hour: Bool = true
    ) {
        self.theme    = theme
        self.size     = size
        self.cityName = cityName
        self.date     = date
        self.is24Hour = is24Hour
    }

    public var body: some View {
        WidgetCard(theme: theme, size: size) {
            VStack(alignment: .leading, spacing: 6) {
                // Şehir / Konum başlığı
                Text(cityName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(theme.secondaryText)

                // Büyük saat metni
                Text(ClockFeature.shared.formatTime(date, is24Hour: is24Hour))
                    .font(.system(size: size == .small ? 40 : 48, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                // Tarih
                Text(ClockFeature.shared.formatDate(date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
