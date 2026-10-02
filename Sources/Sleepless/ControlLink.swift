import Foundation
import notify
import os
import WidgetKit

let log = Logger(subsystem: "dev.mihalevich.sleepless", category: "control")

/// Keeps the Control Center button in step with the app.
@MainActor
enum ControlLink {
    static weak var controller: SleepController?
    private static var requestToken: Int32 = 0
    private static var lastServed: Date?

    /// True shortly after the switch asked for a change, so its side effects can be told apart.
    static var servedRecently: Bool {
        guard let lastServed else { return false }
        return Date().timeIntervalSince(lastServed) < 2
    }


    static func start(with controller: SleepController) {
        self.controller = controller
        notify_register_dispatch(Shared.requestNotification, &requestToken, .main) { _ in
            MainActor.assumeIsolated { takeRequest() }
        }
        takeRequest()
        publish(controller.isEnabled)
    }

    static func publish(_ enabled: Bool) {
        Shared.defaults?.set(enabled, forKey: Shared.enabledKey)
        if #available(macOS 26, *) {
            ControlCenter.shared.reloadControls(ofKind: Shared.controlKind)
        }
    }

    /// Applies the switch's request; stale ones (e.g. left before a crash) are dropped.
    private static func takeRequest() {
        guard let defaults = Shared.defaults,
              let request = defaults.dictionary(forKey: Shared.requestKey),
              let enabled = request["enabled"] as? Bool,
              let time = request["time"] as? Double
        else { return }
        defaults.removeObject(forKey: Shared.requestKey)
        guard Date().timeIntervalSince1970 - time < 10 else { return }
        log.notice("Control Center switch: \(enabled ? "on" : "off", privacy: .public)")
        lastServed = Date()
        Task { await controller?.setEnabled(enabled) }
    }
}
