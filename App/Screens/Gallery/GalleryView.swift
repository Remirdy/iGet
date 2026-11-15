// GalleryView.swift
// App/Screens/Gallery/GalleryView.swift
//
// Widget Galerisi ve Detay Ekranı (FIG 01 & FIG 02)
// Sorumlu: Zeynep (#07 Z · Shell/Gallery)

import SwiftUI

public struct GalleryWidgetDescriptor: Identifiable {
    public let id: String
    public let kind: WidgetKind
    public let title: String
    public let description: String
    public let defaultTheme: ThemePalette

    public static let catalog: [GalleryWidgetDescriptor] = [
        GalleryWidgetDescriptor(id: "clock", kind: .clock, title: "Clock", description: "Zamanı ve tarihi sakin bir tipografiyle takip edin.", defaultTheme: ThemeTokens.sage),
        GalleryWidgetDescriptor(id: "focus", kind: .focus, title: "Focus", description: "Tek bir şeye odaklanın. Pomodoro ve derin çalışma sayacı.", defaultTheme: ThemeTokens.paper),
        GalleryWidgetDescriptor(id: "tasks", kind: .tasks, title: "Tasks", description: "Gününüzü planlayın, görevlerinizi yerel olarak tutun.", defaultTheme: ThemeTokens.lilac),
        GalleryWidgetDescriptor(id: "countdown", kind: .countdown, title: "Countdown", description: "Sınav, teslim ve önemli tarihler için gün sayacı.", defaultTheme: ThemeTokens.slate)
    ]
}

public struct GalleryView: View {
    @State private var searchText = ""
    @State private var selectedWidget: GalleryWidgetDescriptor? = GalleryWidgetDescriptor.catalog.first
    @State private var selectedSize: WidgetCardSize = .small
    @State private var selectedTheme: ThemePalette = ThemeTokens.sage

    public init() {}

    public var filteredWidgets: [GalleryWidgetDescriptor] {
        if searchText.isEmpty {
            return GalleryWidgetDescriptor.catalog
        }
        return GalleryWidgetDescriptor.catalog.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        HSplitView {
            // Sol: Galeri Izgarası (FIG 01)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Explore widgets")
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search widgets…", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding([.top, .horizontal], 20)

                ScrollView {
                    if filteredWidgets.isEmpty {
                        // Empty State (FIG 14)
                        VStack(spacing: 12) {
                            Text("?")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("No widgets found")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Try a different search.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Button("Clear search") {
                                searchText = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                            ForEach(filteredWidgets) { item in
                                Button {
                                    selectedWidget = item
                                    selectedTheme = item.defaultTheme
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        previewWidget(for: item.kind, theme: item.defaultTheme, size: .small)
                                            .allowsHitTesting(false)

                                        HStack {
                                            Text(item.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.primary)
                                            Text("›")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .frame(minWidth: 420)

            // Sağ: Widget Detay & Boyut Seçimi (FIG 02)
            if let selected = selectedWidget {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selected.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(selected.description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    // Önizleme
                    ZStack {
                        Color.primary.opacity(0.02)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        previewWidget(for: selected.kind, theme: selectedTheme, size: selectedSize)
                    }
                    .frame(height: 190)

                    // Boyut Seçici (Small, Medium, Large)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Size")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)

                        Picker("Size", selection: $selectedSize) {
                            Text("Small").tag(WidgetCardSize.small)
                            Text("Medium").tag(WidgetCardSize.medium)
                            Text("Large").tag(WidgetCardSize.large)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Tema Seçici (Sage, Paper, Lilac, Slate)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            ForEach(ThemeTokens.all) { palette in
                                Button {
                                    selectedTheme = palette
                                } label: {
                                    Circle()
                                        .fill(palette.background)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedTheme.id == palette.id ? palette.accent : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        // Konfigüre et
                    } label: {
                        Text("Configure widget")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Add via macOS → Edit Widgets.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(24)
                .frame(width: 320)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }

    @ViewBuilder
    private func previewWidget(for kind: WidgetKind, theme: ThemePalette, size: WidgetCardSize) -> some View {
        switch kind {
        case .clock:
            ClockView(theme: theme, size: size)
        case .countdown:
            CountdownView(theme: theme, size: size, item: CountdownItem(title: "SONRAKİ SINAV", subtitle: "Algoritmalar", targetDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()))
        case .tasks:
            TasksView(theme: theme, size: size)
        case .focus:
            FocusView(theme: theme, size: size)
        default:
            ClockView(theme: theme, size: size)
        }
    }
}
