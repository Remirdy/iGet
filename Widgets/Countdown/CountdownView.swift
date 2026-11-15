// CountdownView.swift
// Widgets/Countdown/CountdownView.swift
//
// iGet Mat Tasarım Sistemine Uygun Countdown Widget Görünümü
// Blueprint Konsepti: NEXT EXAM / 12 days / Algorithms
// Sorumlu: Zeynep (#06 Z · Countdown)

import SwiftUI

public struct CountdownView: View {
    public let theme: ThemePalette
    public let size: WidgetCardSize
    public let item: CountdownItem?

    public init(
        theme: ThemePalette = ThemeTokens.slate,
        size: WidgetCardSize = .small,
        item: CountdownItem? = nil
    ) {
        self.theme = theme
        self.size  = size
        self.item  = item
    }

    public var body: some View {
        WidgetCard(theme: theme, size: size) {
            if let item {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(theme.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(item.daysRemaining)")
                            .font(.system(size: size == .small ? 36 : 44, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.primaryText)

                        Text("gün")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                    }

                    Spacer(minLength: 0)

                    Text(item.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                // Empty State
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.secondaryText)

                    Text("Etkinlik Yok")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
