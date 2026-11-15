// TasksView.swift
// Widgets/Tasks/TasksView.swift
//
// iGet Mat Tasarım Sistemine Uygun Tasks Widget Görünümü
// Blueprint Konsepti: TODAY / Read chapter / Review PR / Submit notes
// Ortak UI Bileşeni

import SwiftUI

public struct TasksView: View {
    public let theme: ThemePalette
    public let size: WidgetCardSize
    public let payload: TasksPayload

    public init(
        theme: ThemePalette = ThemeTokens.lilac,
        size: WidgetCardSize = .small,
        payload: TasksPayload = TasksPayload(
            title: "BUGÜN",
            tasks: [
                TaskItem(title: "Kitap bölümünü oku", isCompleted: true),
                TaskItem(title: "PR'ı incele", isCompleted: false),
                TaskItem(title: "Notları teslim et", isCompleted: false)
            ]
        )
    ) {
        self.theme   = theme
        self.size    = size
        self.payload = payload
    }

    public var body: some View {
        WidgetCard(theme: theme, size: size) {
            VStack(alignment: .leading, spacing: 6) {
                Text(payload.title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(theme.secondaryText)

                if payload.tasks.isEmpty {
                    Spacer()
                    Text("Tüm görevler tamamlandı ✓")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(payload.tasks.prefix(size == .small ? 3 : 5)) { task in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(task.isCompleted ? theme.accent : Color.clear)
                                    .overlay(
                                        Circle().stroke(theme.accent, lineWidth: 1.5)
                                    )
                                    .frame(width: 8, height: 8)

                                Text(task.title)
                                    .font(.system(size: 11, weight: task.isCompleted ? .regular : .medium))
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? theme.secondaryText : theme.primaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
