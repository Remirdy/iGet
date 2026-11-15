import SwiftUI


public struct ThemePalette: Identifiable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let background: Color
    public let surface: Color
    public let primaryText: Color
    public let secondaryText: Color
    public let accent: Color
    public let subtleBorder: Color
    public let cornerRadius: CGFloat

    public init(
        id: String,
        displayName: String,
        backgroundHex: String,
        surfaceHex: String,
        primaryTextHex: String,
        secondaryTextHex: String,
        accentHex: String,
        cornerRadius: CGFloat = 14
    ) {
        self.id            = id
        self.displayName   = displayName
        self.background    = Color(hex: backgroundHex)
        self.surface       = Color(hex: surfaceHex)
        self.primaryText   = Color(hex: primaryTextHex)
        self.secondaryText = Color(hex: secondaryTextHex)
        self.accent        = Color(hex: accentHex)
        self.subtleBorder  = Color(hex: primaryTextHex).opacity(0.08)
        self.cornerRadius  = cornerRadius
    }
}


public enum ThemeTokens {

    public static let sage = ThemePalette(
        id: "sage",
        displayName: "Sage",
        backgroundHex: "#E4F6ED",
        surfaceHex: "#EFF4EF",
        primaryTextHex: "#1C271E",
        secondaryTextHex: "#526755",
        accentHex: "#2F7B60",
        cornerRadius: 14
    )

    public static let paper = ThemePalette(
        id: "paper",
        displayName: "Paper",
        backgroundHex: "#FFF3DF",
        surfaceHex: "#FAF6F0",
        primaryTextHex: "#2E251E",
        secondaryTextHex: "#6E5E53",
        accentHex: "#7C5F47",
        cornerRadius: 14
    )

    public static let lilac = ThemePalette(
        id: "lilac",
        displayName: "Lilac",
        backgroundHex: "#EDE6FF",
        surfaceHex: "#F3EEF7",
        primaryTextHex: "#251B2D",
        secondaryTextHex: "#5E506B",
        accentHex: "#6D5582",
        cornerRadius: 14
    )

    public static let slate = ThemePalette(
        id: "slate",
        displayName: "Slate",
        backgroundHex: "#E8EEF8",
        surfaceHex: "#EBF0F3",
        primaryTextHex: "#1B2329",
        secondaryTextHex: "#4E5C67",
        accentHex: "#3E5367",
        cornerRadius: 14
    )

    public static let aurora = ThemePalette(id: "aurora", displayName: "Aurora", backgroundHex: "#ECE6FF", surfaceHex: "#F8F5FF", primaryTextHex: "#302347", secondaryTextHex: "#74618F", accentHex: "#7856D8")
    public static let peach = ThemePalette(id: "peach", displayName: "Peach", backgroundHex: "#FFEBDD", surfaceHex: "#FFF7F0", primaryTextHex: "#57382C", secondaryTextHex: "#926957", accentHex: "#C86C47")
    public static let sky = ThemePalette(id: "sky", displayName: "Sky", backgroundHex: "#E2F2FF", surfaceHex: "#F1FAFF", primaryTextHex: "#223E57", secondaryTextHex: "#527A99", accentHex: "#388AC3")
    public static let rose = ThemePalette(id: "rose", displayName: "Rose", backgroundHex: "#FFE6EF", surfaceHex: "#FFF4F8", primaryTextHex: "#542B40", secondaryTextHex: "#95637C", accentHex: "#C65891")
    public static let all: [ThemePalette] = [aurora, sky, rose, peach, sage, paper, lilac, slate]

    public static func palette(for id: String) -> ThemePalette {
        all.first { $0.id.lowercased() == id.lowercased() } ?? sage
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}
