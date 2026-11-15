// FocusView.swift
// Widgets/Focus/FocusView.swift
//
// iGet Mat Tasarım Sistemine Uygun Focus Widget Görünümü
// Blueprint Konsepti: FOCUS / 24:08 / İlerleme çubuğu
// Ortak UI Bileşeni

import SwiftUI

public struct FocusView: View {
    public let theme: ThemePalette
    public let size: WidgetCardSize
    public let payload: FocusPayload

    public init(
        theme: ThemePalette = ThemeTokens.paper,
        size: WidgetCardSize = .small,
        payload: FocusPayload = FocusPayload()
    ) {
        self.theme   = theme
        self.size    = size
        self.payload = payload
    }

    public var body: some View {
        WidgetCard(theme: theme, size: size) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ODAK")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(theme.secondaryText)

                Text(payload.timeString)
                    .font(.system(size: size == .small ? 36 : 44, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 0)

                // İlerleme Çubuğu
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.secondaryText.opacity(0.2))
                        Capsule()
                            .fill(theme.accent)
                            .frame(width: geo.size.width * CGFloat(payload.progress))
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
