// WidgetCard.swift
// Packages/iGetDesign/Sources/iGetDesign/WidgetCard.swift
//
// iGet Tüm Widget'lar İçin Ortak Mat Kart Sarmalayıcısı
// Küçük köşe yarıçapı, mat yüzey, hafif sınır çizgisi ve tema desteği.
//
// Sorumlu: Zeynep (#02 Z · Design tokens)

import SwiftUI

public enum WidgetCardSize: String, CaseIterable, Sendable {
    case small
    case medium
    case large

    public var dimensions: CGSize {
        switch self {
        case .small:  return CGSize(width: 155, height: 155)
        case .medium: return CGSize(width: 320, height: 155)
        case .large:  return CGSize(width: 320, height: 320)
        }
    }
}

public struct WidgetCard<Content: View>: View {
    public let theme: ThemePalette
    public let size: WidgetCardSize
    public let content: Content

    public init(
        theme: ThemePalette = ThemeTokens.sage,
        size: WidgetCardSize = .small,
        @ViewBuilder content: () -> Content
    ) {
        self.theme   = theme
        self.size    = size
        self.content = content()
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.background)

            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(theme.subtleBorder, lineWidth: 1)

            content
                .padding(14)
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
    }
}

// MARK: - Standard Widget Header

public struct WidgetHeader: View {
    public let title: String
    public let subtitle: String?
    public let theme: ThemePalette

    public init(title: String, subtitle: String? = nil, theme: ThemePalette = ThemeTokens.sage) {
        self.title    = title
        self.subtitle = subtitle
        self.theme    = theme
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(theme.secondaryText)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.primaryText.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
