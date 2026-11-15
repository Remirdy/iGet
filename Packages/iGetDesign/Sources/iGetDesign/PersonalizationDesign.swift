import SwiftUI

extension WidgetTypeface {
    var design: Font.Design {
        switch self { case .rounded: return .rounded; case .serif: return .serif; case .monospaced: return .monospaced; case .system: return .default }
    }
}

extension WidgetOptions {
    func theme(palette: String, dark: Bool) -> ThemePalette {
        guard customColors else { return ThemeTokens.palette(palette, dark: dark) }
        return ThemePalette(id: "custom", displayName: L10n.text("Custom"), backgroundHex: backgroundHex, surfaceHex: backgroundHex, primaryTextHex: foregroundHex, secondaryTextHex: foregroundHex, accentHex: accentHex)
    }
}

struct LayerCanvasView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    var layers: [CanvasLayer]
    var options: WidgetOptions
    var document: WorkspaceDocument
    var selectedID: UUID?
    var onSelect: ((UUID) -> Void)?
    var onMove: ((UUID, Double, Double) -> Void)?
    @Environment(\.colorScheme) private var scheme
    @State private var draggingID: UUID?
    @State private var translation: CGSize = .zero
    var body: some View {
        if layers.contains(where: { $0.kind == .time || $0.kind == .date || $0.source == .focus }) {
            TimelineView(.periodic(from: .now, by: layers.contains(where: { $0.source == .focus }) && document.focus.isRunning ? document.preferences.energy.interval(systemLowPower: ProcessInfo.processInfo.isLowPowerModeEnabled) : 60)) { context in canvas(date: context.date) }
        } else { canvas(date: Date()) }
    }
    private func canvas(date: Date) -> some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(layers) { layer in
                    layerContent(layer, date: date)
                        .font(.system(size: layer.fontSize * options.fontScale, weight: .medium, design: options.typeface.design))
                        .foregroundStyle(layerColor(layer)).multilineTextAlignment(.center)
                        .frame(width: max(12, geometry.size.width * layer.width))
                        .opacity(layer.opacity).rotationEffect(.degrees(layer.rotation))
                        .padding(4)
                        .overlay { if selectedID == layer.id { RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4])) } }
                        .position(x: geometry.size.width * layer.x + (draggingID == layer.id ? translation.width : 0), y: geometry.size.height * layer.y + (draggingID == layer.id ? translation.height : 0))
                        .onTapGesture { onSelect?(layer.id) }
                        .gesture(DragGesture().onChanged { value in draggingID = layer.id; translation = value.translation }.onEnded { value in
                            onMove?(layer.id, min(1, max(0, layer.x + value.translation.width / max(geometry.size.width, 1))), min(1, max(0, layer.y + value.translation.height / max(geometry.size.height, 1))))
                            draggingID = nil; translation = .zero
                        }, including: onMove == nil ? .none : .all)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.timeZone = TimeZone(identifier: options.timeZone ?? document.preferences.clockTimeZone)
        formatter.dateFormat = document.preferences.use24Hour ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
    private func layerColor(_ layer: CanvasLayer) -> Color {
        Color(hex: scheme == .dark && layer.colorHex.lowercased() == "#7356cf" ? "#C8AEFF" : layer.colorHex)
    }
    @ViewBuilder private func layerContent(_ layer: CanvasLayer, date: Date) -> some View {
        switch layer.kind {
        case .text: Text(layer.text)
        case .symbol:
            if NSImage(systemSymbolName: layer.text, accessibilityDescription: nil) != nil { Image(systemName: layer.text) } else { Text(layer.text) }
        case .time:
            Text(timeString(date)).monospacedDigit()
        case .date: Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(localization.locale)).environment(\.timeZone, TimeZone(identifier: options.timeZone ?? document.preferences.clockTimeZone) ?? .current)
        case .progress: ProgressView(value: layer.resolvedProgress(document: document, options: options, at: date)).tint(layerColor(layer)).padding(.vertical, 8)
        }
    }
}
