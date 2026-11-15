import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { BrandMark(size: 25); Text("iGet").font(.system(size: 19, weight: .semibold)); Spacer(); Label(store.document.preferences.energy == .saver ? L10n.text("Power saver") : L10n.text(store.document.preferences.energy.rawValue.capitalized), systemImage: "leaf").font(.system(size: 10)).foregroundStyle(.secondary) }
            WorkspaceWidgetView(kind: .focus, document: store.document, paletteID: "paper", onFocus: { store.toggleFocus() }).frame(height: 155)
            Picker(L10n.text("Space"), selection: Binding(get: { store.document.activeSpaceID }, set: { id in if let id { store.activateSpace(id) } })) {
                ForEach(store.document.spaces) { Text($0.name).tag(Optional($0.id)) }
            }
            Button(store.document.desktopVisible ? L10n.text("Hide desktop widgets") : L10n.text("Show desktop widgets")) { store.change { $0.desktopVisible.toggle() } }.frame(maxWidth: .infinity)
            Divider()
            HStack {
                Button(L10n.text("Open iGet")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button(L10n.text("Quit")) { NSApp.terminate(nil) }
            }
        }.padding(20).frame(width: 300).preferredColorScheme(store.appearance).environment(\.locale, localization.locale)
    }
}
