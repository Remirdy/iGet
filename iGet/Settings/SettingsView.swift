import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var store: WorkspaceStore
    @State private var backupToRestore: URL?
    @State private var showRestoreConfirmation = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeading(eyebrow: L10n.text("PREFERENCES"), title: L10n.text("Settings"), subtitle: L10n.text("Appearance, energy use and local data."))
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.text("Language")).font(.system(size: 15, weight: .medium))
                        Picker(L10n.text("Application language"), selection: Binding(get: { store.document.preferences.language ?? .system }, set: { language in store.preferences { $0.language = language } })) {
                            ForEach(AppLanguage.allCases) { language in Text(language.name).tag(language) }
                        }.pickerStyle(.segmented)
                        Text(L10n.text("Follows the macOS language. English is used when the system language is not supported."))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(L10n.text("Language changes apply immediately to iGet and desktop widgets."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.text("Appearance")).font(.system(size: 15, weight: .medium))
                        Picker(L10n.text("Color mode"), selection: Binding(get: { store.document.preferences.appearance }, set: { mode in store.preferences { $0.appearance = mode } })) {
                            ForEach(AppearanceMode.allCases, id: \.self) { Text(L10n.text($0.rawValue.capitalized)).tag($0) }
                        }.pickerStyle(.segmented)
                        HStack { Text(L10n.text("Accent palette")).font(.system(size: 12)); Spacer(); PalettePicker(selection: Binding(get: { store.document.preferences.palette }, set: { palette in store.preferences { $0.palette = palette } })) }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        Label(L10n.text("Energy & performance"), systemImage: "leaf").font(.system(size: 15, weight: .medium))
                        Picker(L10n.text("Power profile"), selection: Binding(get: { store.document.preferences.energy }, set: { mode in store.preferences { $0.energy = mode } })) {
                            Text(L10n.text("Automatic")).tag(EnergyMode.automatic)
                            Text(L10n.text("Balanced")).tag(EnergyMode.balanced)
                            Text(L10n.text("Power saver")).tag(EnergyMode.saver)
                        }.pickerStyle(.segmented)
                        Text(L10n.text("Automatic follows macOS Low Power Mode. Balanced samples live metrics every 3 seconds; Power saver uses 15 seconds. High thermal pressure slows sampling in every mode. Unused providers stop entirely."))
                            .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Divider()
                        HStack { Label(L10n.text("macOS Low Power Mode"), systemImage: "battery.25percent"); Spacer(); Text(store.systemLowPower ? L10n.text("On") : L10n.text("Off")).foregroundStyle(.secondary) }.font(.system(size: 12))
                        HStack { Text(L10n.text("Current live refresh interval")); Spacer(); Text(L10n.format("%d seconds", Int(store.samplingInterval))).foregroundStyle(.secondary) }.font(.system(size: 12))
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L10n.text("General")).font(.system(size: 15, weight: .medium))
                        Toggle(L10n.text("Launch at login"), isOn: Binding(get: { SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval }, set: { store.setLaunchAtLogin($0) })).font(.system(size: 12))
                        if SMAppService.mainApp.status == .requiresApproval {
                            Button(L10n.text("Open Login Items settings")) { SMAppService.openSystemSettingsLoginItems() }.font(.system(size: 11))
                        }
                        Toggle(L10n.text("Lock desktop widget positions"), isOn: Binding(get: { store.document.preferences.lockLayout }, set: { value in store.preferences { $0.lockLayout = value } })).font(.system(size: 12))
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L10n.text("Your data")).font(.system(size: 15, weight: .medium))
                        Text(L10n.text("Tasks, notes, photos and layouts are stored locally. Weather contacts Open-Meteo while needed. Music connects only after you choose a player. There are no analytics or advertising services.")).font(.system(size: 12)).foregroundStyle(.secondary)
                        HStack {
                            Button(L10n.text("Export backup…")) { store.exportBackup() }
                            Button(L10n.text("Restore backup…")) { chooseBackup() }
                            Spacer()
                            Button(L10n.text("Show data folder")) {
                                if let url = store.database?.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            }
                        }
                        if !store.isSharedStorage {
                            Label(L10n.text("Local storage is active. Sharing with macOS widgets requires a signed build with the iGet App Group."), systemImage: "info.circle")
                                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text(L10n.text("iGet · Local, native, open source · macOS 14 and later")).font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(32).frame(maxWidth: 820, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog(L10n.text("Restore this backup?"), isPresented: $showRestoreConfirmation) {
            Button(L10n.text("Restore backup"), role: .destructive) {
                if let url = backupToRestore { store.restoreBackup(from: url) }
                backupToRestore = nil
            }
            Button(L10n.text("Cancel"), role: .cancel) { backupToRestore = nil }
        } message: { Text(L10n.text("This replaces tasks, notes, habits and layouts. You can undo the restore from the message bar.")) }
    }
    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return }
        backupToRestore = panel.url
        showRestoreConfirmation = backupToRestore != nil
    }
}
