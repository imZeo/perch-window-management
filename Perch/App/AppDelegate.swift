import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appState = AppState()
        let statusBarController = StatusBarController(appState: appState)

        self.appState = appState
        self.statusBarController = statusBarController

        appState.start()
        statusBarController.installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stop()
    }
}
