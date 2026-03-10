import AppKit

enum BundleIDResolver {
    static func bundleID(for applicationURL: URL) -> String? {
        Bundle(url: applicationURL)?.bundleIdentifier
    }
}
