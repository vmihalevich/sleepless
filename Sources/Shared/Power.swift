import Foundation
import IOKit.ps
import IOKit.pwr_mgt

enum Power {
    private typealias CopySettings = @convention(c) () -> Unmanaged<CFDictionary>?

    /// `IOPMCopySystemPowerSettings` is exported by IOKit but declared only in a private header.
    private static let copySystemPowerSettings: CopySettings? = {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let symbol = dlsym(handle, "IOPMCopySystemPowerSettings")
        else { return nil }
        return unsafeBitCast(symbol, to: CopySettings.self)
    }()

    /// The system-wide `SleepDisabled` flag that `pmset -a disablesleep` writes.
    static var sleepDisabled: Bool { readSleepDisabled() ?? false }

    /// Nil when the settings can't be read, e.g. from inside a sandbox.
    static func readSleepDisabled() -> Bool? {
        guard let settings = copySystemPowerSettings?()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        switch settings["SleepDisabled"] {
        case let flag as Bool: return flag
        case let number as NSNumber: return number.boolValue
        default: return false
        }
    }

    struct Battery {
        var onBattery: Bool
        /// Nil on Macs without an internal battery.
        var percent: Int?
    }

    static var battery: Battery {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return Battery(onBattery: false, percent: nil) }

        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        var percent: Int?
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            percent = current * 100 / max
        }
        return Battery(onBattery: providing == kIOPSBatteryPowerValue, percent: percent)
    }
}
