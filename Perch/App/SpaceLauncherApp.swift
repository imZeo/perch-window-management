import AppKit

@main
enum SpaceLauncherApp {
    private static let delegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared

        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}
