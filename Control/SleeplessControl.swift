import AppIntents
import AppKit
import notify
import SwiftUI
import WidgetKit

@main
struct SleeplessControls: WidgetBundle {
    var body: some Widget {
        SleeplessControl()
    }
}

struct SleeplessControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Shared.controlKind, provider: StateProvider()) { isOn in
            ControlWidgetToggle("control.title", isOn: isOn, action: SetSleeplessIntent()) { isOn in
                Label(isOn ? "status.on" : "status.off",
                      systemImage: isOn ? "cup.and.saucer.fill" : "cup.and.saucer")
            }
            .tint(.orange)
        }
        .displayName("control.name")
        .description("control.description")
    }
}

struct StateProvider: ControlValueProvider {
    var previewValue: Bool { false }

    /// The app publishes the flag after every change it applies; reading it directly from the
    /// sandbox is only a fallback for before the app's first run.
    func currentValue() async throws -> Bool {
        if let published = Shared.defaults?.object(forKey: Shared.enabledKey) as? Bool { return published }
        return Power.readSleepDisabled() ?? false
    }
}

/// Leaves the request in the app group and pings the app, which applies it with `sudo`.
enum SleeplessRemote {
    static func set(_ enabled: Bool) async {
        Shared.defaults?.set(["enabled": enabled, "time": Date().timeIntervalSince1970], forKey: Shared.requestKey)
        notify_post(Shared.requestNotification)
        // Starts the app only if it isn't running; it takes the request on launch. Opening a running
        // app would reopen it and show its panel.
        let bundleID = "dev.mihalevich.sleepless"
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else { return }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
        }
    }
}
