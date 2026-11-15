// ThemeTokens.swift
// Packages/iGetDesign/Sources/iGetDesign/ThemeTokens.swift
//
// iGet Mat Tasarım Sistemi — Küratörlü Renk ve Tipografi Token'ları
// Tasarım dili: Mat renkler, sakin tipografi, küçük köşe yarıçapı, yeterli kontrast.
// Dekoratif 3D veya parlama/ışıltı yok.
//
// Sorumlu: Zeynep (#02 Z · Design tokens)

import SwiftUI

// MARK: - Theme Palette

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

// MARK: - Curated Presets

public enum ThemeTokens {

    /// Sage (Adaçayı): Sakin, dinlendirici yeşilimsi tonlar
    public static let sage = ThemePalette(
        id: "sage",
        displayName: "Sage",
        backgroundHex: "#E5ECE5",
        surfaceHex: "#EFF4EF",
        primaryTextHex: "#1C271E",
        secondaryTextHex: "#526755",
        accentHex: "#436248",
        cornerRadius: 14
    )

    /// Paper (Kağıt): Sıcak nötr bej ve ahşap tonları
    public static let paper = ThemePalette(
        id: "paper",
        displayName: "Paper",
        backgroundHex: "#F5EFE6",
        surfaceHex: "#FAF6F0",
        primaryTextHex: "#2E251E",
        secondaryTextHex: "#6E5E53",
        accentHex: "#7C5F47",
        cornerRadius: 14
    )

    /// Lilac (Leylak): Yumuşak pastel lila ve mor tonları
    public static let lilac = ThemePalette(
        id: "lilac",
        displayName: "Lilac",
        backgroundHex: "#EAE3F0",
        surfaceHex: "#F3EEF7",
        primaryTextHex: "#251B2D",
        secondaryTextHex: "#5E506B",
        accentHex: "#6D5582",
        cornerRadius: 14
    )

    /// Slate (Arduvaz): Dengeli gri-mavi tonlar
    public static let slate = ThemePalette(
        id: "slate",
        displayName: "Slate",
        backgroundHex: "#DFE5E9",
        surfaceHex: "#EBF0F3",
        primaryTextHex: "#1B2329",
        secondaryTextHex: "#4E5C67",
        accentHex: "#3E5367",
        cornerRadius: 14
    )

    /// Tüm önayarlar listesi
    public static let all: [ThemePalette] = [sage, paper, lilac, slate]

    /// ID'ye göre tema bulucu
    public static func palette(for id: String) -> ThemePalette {
        all.first { $0.id.lowercased() == id.lowercased() } ?? sage
    }
}
