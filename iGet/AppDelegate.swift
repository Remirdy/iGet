import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = WorkspaceStore()
    private var overlays: OverlayWindowManager?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        overlays = OverlayWindowManager(store: store)
        store.updateDemand()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { overlays?.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowRegistry.show()
        return true
    }
}
