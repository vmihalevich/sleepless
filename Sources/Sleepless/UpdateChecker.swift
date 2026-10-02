import Foundation
import Observation

/// Asks the site which version is current, at launch and then once a day, and compares the
/// answer with its own version here. The request tells the site nothing: not this version,
/// not the Mac, not the user. Turn the check off with
/// `defaults write dev.mihalevich.sleepless checksForUpdates -bool NO`.
@MainActor
@Observable
final class UpdateChecker {
    static let site = URL(string: "https://sleepless.nextwell.top/")!

    /// The newer version on the site, nil while this one is current.
    private(set) var available: String?

    private static let endpoint = URL(string: "https://sleepless.nextwell.top/api/version")!
    private static let interval: TimeInterval = 24 * 60 * 60
    private static let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private var lastAnswer = Date.distantPast
    private var timer: Timer?

    func start() {
        guard UserDefaults.standard.object(forKey: "checksForUpdates") as? Bool ?? true else { return }
        check()
        // Hourly, so a check that failed offline is retried and a Mac that slept through the day catches up.
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Date().timeIntervalSince(self.lastAnswer) >= Self.interval else { return }
                self.check()
            }
        }
    }

    private func check() {
        Task {
            guard let latest = await Self.latestVersion() else { return }
            lastAnswer = Date()
            available = latest.compare(Self.current, options: .numeric) == .orderedDescending ? latest : nil
        }
    }

    private static func latestVersion() async -> String? {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        // Left alone, URLSession fills these in with the app's build, the system's version
        // and the user's language list.
        request.setValue("Sleepless", forHTTPHeaderField: "User-Agent")
        request.setValue("*", forHTTPHeaderField: "Accept-Language")
        // Ephemeral: no cookies, no cache, nothing kept between checks.
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }

        struct Reply: Decodable { let version: String }
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let reply = try? JSONDecoder().decode(Reply.self, from: data),
              reply.version.wholeMatch(of: #/\d{1,4}(\.\d{1,4}){0,3}/#) != nil
        else { return nil }
        return reply.version
    }
}
