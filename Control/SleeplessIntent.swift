import AppIntents

/// The Control Center switch. The system performs it in the sandboxed extension, which can't run
/// `sudo`, so `SleeplessRemote` hands the request to the app.
struct SetSleeplessIntent: SetValueIntent {
    static let title: LocalizedStringResource = "control.title"
    static let isDiscoverable = false

    @Parameter(title: "control.title")
    var value: Bool

    func perform() async throws -> some IntentResult {
        await SleeplessRemote.set(value)
        return .result()
    }
}
