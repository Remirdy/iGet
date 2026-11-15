// iGetWidgetsBundle.swift
// iGet — iGetWidgets Extension
//
// WidgetKit extension'ının @main giriş noktası.
// Tüm widget'ları tek bir WidgetBundle altında toplar.
//
// Bundle ID : com.twobitdev.iGet.widgets
// App Group : group.com.twobitdev.iGet
//
// Entitlements (iGetWidgets.entitlements):
//   com.apple.security.application-groups = ["group.com.twobitdev.iGet"]
//
// Organization: TwoBit-Dev

import WidgetKit
import SwiftUI

// MARK: - iGetWidgetsBundle

@main
struct iGetWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        CalendarWidget()
        WeatherWidget()
    }
}

// MARK: - Widget Kind Constants
// Sistem genelinde kullanılan sabit tanımlayıcılar.

enum iGetWidgetKind {
    static let clock    = "com.twobitdev.iGet.widget.clock"
    static let calendar = "com.twobitdev.iGet.widget.calendar"
    static let weather  = "com.twobitdev.iGet.widget.weather"
}

// MARK: - Shared Widget Styling

/// Tüm WidgetKit widget'larının ortak arka plan view'ı.
struct WidgetBackground: View {
    let theme: WidgetTheme

    var body: some View {
        Group {
            if theme.blurBackground {
                ContainerRelativeShape()
                    .fill(.ultraThinMaterial)
            } else {
                ContainerRelativeShape()
                    .fill(
                        theme.colorScheme == .dark
                            ? Color.black.opacity(theme.opacity)
                            : Color.white.opacity(theme.opacity)
                    )
            }
        }
    }
}

/// Widget içeriğini tema ayarlarıyla sarar.
struct ThemedWidgetContainer<Content: View>: View {
    let theme:   WidgetTheme
    let content: Content

    init(theme: WidgetTheme, @ViewBuilder content: () -> Content) {
        self.theme   = theme
        self.content = content()
    }

    var body: some View {
        ZStack {
            WidgetBackground(theme: theme)
            content
                .padding(12)
        }
        .preferredColorScheme(theme.colorScheme.colorScheme)
    }
}
