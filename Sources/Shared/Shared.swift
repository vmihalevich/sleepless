import Foundation

/// Names the app and its Control Center extension agree on.
enum Shared {
    static let controlKind = "dev.mihalevich.sleepless.control"
    /// Team-prefixed, so it needs no provisioning profile under Developer ID.
    static let appGroup = "22CGV37NDW.dev.mihalevich.sleepless"
    static let enabledKey = "sleepDisabled"
    /// The switch's pending request, `["enabled": Bool, "time": seconds since 1970]`.
    static let requestKey = "request"
    static let requestNotification = "dev.mihalevich.sleepless.request"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
}
