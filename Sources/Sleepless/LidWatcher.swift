import AppKit
import IOKit
import IOKit.pwr_mgt

/// `iokit_family_msg(sub_iokit_powermanagement, 0x100)`; the macro doesn't import into Swift.
private let clamshellStateChange: UInt32 = 0xE003_4100
/// Bit 0 of the message argument is set while the lid is closed.
private let clamshellClosedBit = 1

/// With SleepDisabled set, macOS keeps the built-in screen and keyboard lit under a closed lid,
/// so this puts the display to sleep itself and wakes it when the lid opens.
@MainActor
final class LidWatcher {
    private let isActive: () -> Bool
    private var port: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var sleptDisplay = false

    init(isActive: @escaping () -> Bool) {
        self.isActive = isActive
    }

    func start() {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else { return }
        defer { IOObjectRelease(rootDomain) }
        port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, .main)
        // Unretained: the app delegate keeps the watcher for the app's lifetime.
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddInterestNotification(port, rootDomain, kIOGeneralInterest, { context, _, type, argument in
            guard type == clamshellStateChange, let context else { return }
            let closed = Int(bitPattern: argument) & clamshellClosedBit != 0
            let watcher = Unmanaged<LidWatcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.lidChanged(closed: closed) }
        }, context, &notifier)
    }

    private func lidChanged(closed: Bool) {
        if closed {
            // With an external display attached, macOS turns the built-in one off itself, and
            // sleeping displays would blank the external one too.
            guard isActive(), !externalDisplayOnline else { return }
            sleptDisplay = true
            try? Process.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["displaysleepnow"])
        } else if sleptDisplay {
            sleptDisplay = false
            var assertion: IOPMAssertionID = 0
            if IOPMAssertionDeclareUserActivity("Sleepless: lid opened" as CFString, kIOPMUserActiveLocal, &assertion) == kIOReturnSuccess {
                IOPMAssertionRelease(assertion)
            }
        }
    }

    private var externalDisplayOnline: Bool {
        NSScreen.screens.contains { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) == 0
        }
    }
}
