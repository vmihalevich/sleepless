import Foundation

/// Root access is limited to the two exact `pmset` commands whitelisted by the sudoers rule that
/// `helper-install.sh` writes; nothing else runs as root.
enum Privileged {
    static let sudoersRule = "/etc/sudoers.d/sleepless"

    enum SetupResult { case installed, cancelled, failed(String) }

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: sudoersRule) }

    static func setSleepDisabled(_ disabled: Bool) async -> Bool {
        await run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"]).status == 0
    }

    /// Blocking variant for app termination, when there is no run loop left to await on.
    static func restoreSleepNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// Runs the bundled installer as root behind the standard macOS administrator prompt.
    static func install() async -> SetupResult {
        guard let script = Bundle.main.path(forResource: "helper-install", ofType: "sh") else {
            return .failed("helper-install.sh is missing from the app bundle")
        }
        let result = await run("/usr/bin/osascript", [
            "-e", "on run argv",
            "-e", "do shell script \"/bin/sh \" & quoted form of (item 1 of argv) with administrator privileges with prompt (item 2 of argv)",
            "-e", "end run",
            script,
            L("setup.prompt"),
        ])
        if result.status == 0 { return .installed }
        // AppleScript error -128 is "User canceled".
        if result.stderr.contains("-128") { return .cancelled }
        return .failed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func run(_ path: String, _ arguments: [String]) async -> (status: Int32, stderr: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderr
            process.terminationHandler = { finished in
                let output = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                continuation.resume(returning: (finished.terminationStatus, output))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: (-1, error.localizedDescription))
            }
        }
    }
}

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
