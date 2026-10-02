import AppKit
import SwiftUI

@main
enum SleeplessMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = SleepController()
    private let updates = UpdateChecker()
    private lazy var lid = LidWatcher { [controller] in controller.isEnabled }
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var signalSources: [DispatchSourceSignal] = []
    private var launchedAsLoginItem = false

    /// The launch Apple event is only readable before launching finishes.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAsLoginItem = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()
        controller.onChange = { [weak self] in
            guard let self else { return }
            updateIcon()
            ControlLink.publish(controller.isEnabled)
        }
        ControlLink.start(with: controller)
        lid.start()

        popover.behavior = .transient
        popover.animates = true
        let hosting = NSHostingController(rootView: PanelView(controller: controller, updates: updates))
        // Lets the popover grow and shrink when a note appears or a translation wraps.
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        restoreSleepOnSignals()
        updates.start()

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "launchedBefore") || !launchedAsLoginItem {
            defaults.set(true, forKey: "launchedBefore")
            // A launch for the Control Center switch delivers its request a moment later.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !ControlLink.servedRecently { self.showPopover() }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Serving the Control Center switch also reopens the app; that one shouldn't open the panel.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !ControlLink.servedRecently { self.showPopover() }
        }
        return false
    }

    /// Normal sleep must come back whenever the app goes away: quit, logout, shutdown, update.
    func applicationWillTerminate(_ notification: Notification) {
        if Power.sleepDisabled { Privileged.restoreSleepNow() }
        ControlLink.publish(false)
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: L("toggle.title"), action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        toggle.state = controller.isEnabled ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("footer.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleFromMenu() { controller.toggle() }

    private func updateIcon() {
        let image = CupGlyph.image(steaming: controller.isEnabled)
        image.accessibilityDescription = L(controller.isEnabled ? "status.on" : "status.off")
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Sleepless — " + L(controller.isEnabled ? "status.on" : "status.off")
    }

    private func restoreSleepOnSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }
}
