import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class SleepController {
    enum Note: Equatable {
        case lowBattery(Int)
        case overheating
        case setupFailed(String)
        case commandFailed

        var text: String {
            switch self {
            case .lowBattery(let percent): String(format: L("note.lowBattery"), percent)
            case .overheating: L("note.overheating")
            case .setupFailed(let reason): String(format: L("note.setupFailed"), reason)
            case .commandFailed: L("note.commandFailed")
            }
        }
    }

    /// Below this charge on battery power the Mac is allowed to sleep again.
    static let lowBatteryPercent = 10

    private(set) var isEnabled = Power.sleepDisabled {
        didSet { if isEnabled != oldValue { onChange?() } }
    }
    private(set) var isBusy = false
    private(set) var note: Note?
    private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled

    var onChange: (() -> Void)?

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        let center = NotificationCenter.default
        center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func toggle() { Task { await setEnabled(!isEnabled) } }

    func setEnabled(_ enabled: Bool) async {
        guard !isBusy else { return }
        if enabled, let block = safetyBlock() {
            note = block
            return
        }
        isBusy = true
        defer { isBusy = false }
        note = nil

        var applied = await Privileged.setSleepDisabled(enabled)
        if !applied && !Privileged.isInstalled {
            switch await Privileged.install() {
            case .installed: applied = await Privileged.setSleepDisabled(enabled)
            case .cancelled: break
            case .failed(let reason): note = .setupFailed(reason)
            }
        }
        isEnabled = Power.sleepDisabled
        if isEnabled != enabled && note == nil && Privileged.isInstalled {
            note = .commandFailed
        }
    }

    func setOpensAtLogin(_ open: Bool) {
        do {
            if open { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Sleepless: login item change failed: \(error)")
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Keeps the UI in sync with changes made elsewhere and trips the safety cut-offs.
    private func tick() {
        isEnabled = Power.sleepDisabled
        opensAtLogin = SMAppService.mainApp.status == .enabled
        guard isEnabled, !isBusy, let block = safetyBlock() else { return }
        Task {
            await setEnabled(false)
            note = block
        }
    }

    private func safetyBlock() -> Note? {
        if ProcessInfo.processInfo.thermalState == .critical { return .overheating }
        let battery = Power.battery
        if battery.onBattery, let percent = battery.percent, percent <= Self.lowBatteryPercent {
            return .lowBattery(percent)
        }
        return nil
    }
}
