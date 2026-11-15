// MainShellView.swift
// App/Shell/MainShellView.swift
//
// iGet Ana Pencere Kabuğu ve Navigasyon Menüsü
// Sorumlu: Zeynep (#07 Z · Shell/Gallery)

import SwiftUI

public enum NavigationTab: String, CaseIterable, Identifiable {
    case overview  = "Overview"
    case gallery   = "Gallery"
    case myWidgets = "My widgets"
    case studio    = "Studio"
    case spaces    = "Spaces"
    case settings  = "Settings"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .overview:  return "square.grid.2x2"
        case .gallery:   return "square.stack.3d.down.forward"
        case .myWidgets: return "macwindow"
        case .studio:    return "paintbrush"
        case .spaces:    return "rectangle.3.group"
        case .settings:  return "gearshape"
        }
    }
}

public struct MainShellView: View {
    @State private var selectedTab: NavigationTab = .gallery

    public init() {}

    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                // Logo & Başlık
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "#436248"))

                    Text("iGet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                List(NavigationTab.allCases, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.iconName)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .tag(tab)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch selectedTab {
            case .gallery:
                GalleryView()
            case .studio:
                StudioPlaceholderView()
            case .spaces:
                SpacesPlaceholderView()
            case .settings:
                SettingsPlaceholderView()
            case .overview, .myWidgets:
                GalleryView()
            }
        }
        .frame(minWidth: 840, minHeight: 560)
    }
}

// MARK: - Placeholder Screens

struct StudioPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintbrush")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Widget Studio")
                .font(.system(size: 18, weight: .bold))
            Text("Parametrik şablon editörü v0.2 aşamasında açılacaktır.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SpacesPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Spaces")
                .font(.system(size: 18, weight: .bold))
            Text("Study, Developer ve Daily profilleri v0.3 aşamasında açılacaktır.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Ayarlar")
                .font(.system(size: 18, weight: .bold))
            Text("Görünüm, güç modu ve gizlilik tercihleri.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


