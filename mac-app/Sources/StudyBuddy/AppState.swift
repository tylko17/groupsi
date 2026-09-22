import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var username: String?
    @Published var token: String?
    @Published var usernameInput: String = ""
    @Published var registerError: String?
    @Published var isRegistering = false

    @Published var isSessionActive = false
    @Published var sessionStart: Date?
    @Published var elapsedSeconds: Int = 0

    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var leaderboardPeriod: LeaderboardPeriod = .week
    @Published var leaderboardError: String?
    @Published var isLoadingLeaderboard = false

    @Published var compareTarget: String = ""
    @Published var compareResult: CompareResponse?
    @Published var compareError: String?

    @Published var myTotals: SessionTotals?

    private let api = APIClient()
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let username = "sb_username"
        static let token = "sb_token"
        static let sessionStart = "sb_session_start"
    }

    init() {
        username = defaults.string(forKey: Keys.username)
        token = defaults.string(forKey: Keys.token)
        if let savedStart = defaults.object(forKey: Keys.sessionStart) as? Date {
            sessionStart = savedStart
            isSessionActive = true
            elapsedSeconds = max(0, Int(Date().timeIntervalSince(savedStart)))
            startTicking()
        }
    }

    var isLoggedIn: Bool { username != nil && token != nil }

    var menuBarIcon: String {
        isSessionActive ? "book.fill" : "book.closed"
    }

    var menuBarTitle: String {
        isSessionActive ? formatDuration(elapsedSeconds) : ""
    }

    func register() async {
        let name = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isRegistering = true
        registerError = nil
        do {
            let response = try await api.register(username: name)
            username = response.username
            token = response.token
            defaults.set(response.username, forKey: Keys.username)
            defaults.set(response.token, forKey: Keys.token)
            usernameInput = ""
            await refreshLeaderboard()
        } catch {
            registerError = error.localizedDescription
        }
        isRegistering = false
    }

    func signOut() {
        username = nil
        token = nil
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.token)
    }

    func toggleSession() {
        if isSessionActive {
            stopSession()
        } else {
            startSession()
        }
    }

    private func startSession() {
        sessionStart = Date()
        isSessionActive = true
        elapsedSeconds = 0
        defaults.set(sessionStart, forKey: Keys.sessionStart)
        startTicking()
    }

    private func stopSession() {
        guard let start = sessionStart else { return }
        let end = Date()
        let duration = max(1, Int(end.timeIntervalSince(start)))
        isSessionActive = false
        timer?.invalidate()
        timer = nil
        sessionStart = nil
        elapsedSeconds = 0
        defaults.removeObject(forKey: Keys.sessionStart)

        guard let username, let token else { return }
        Task {
            do {
                let response = try await api.logSession(
                    username: username, token: token,
                    durationSeconds: duration, startedAt: start, endedAt: end
                )
                myTotals = response.totals
                await refreshLeaderboard()
            } catch {
                leaderboardError = "Couldn't save session: \(error.localizedDescription)"
            }
        }
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.sessionStart else { return }
                self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
            }
        }
    }

    func refreshLeaderboard() async {
        isLoadingLeaderboard = true
        leaderboardError = nil
        do {
            let response = try await api.leaderboard(period: leaderboardPeriod)
            leaderboard = response.leaderboard
            if let username, let mine = response.leaderboard.first(where: { $0.username == username }) {
                myTotals = SessionTotals(totalSeconds: mine.totalSeconds, sessionCount: mine.sessionCount)
            }
        } catch {
            leaderboardError = error.localizedDescription
        }
        isLoadingLeaderboard = false
    }

    func runCompare() async {
        guard let username else { return }
        let target = compareTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        compareError = nil
        do {
            compareResult = try await api.compare(a: username, b: target, period: leaderboardPeriod)
        } catch {
            compareError = error.localizedDescription
            compareResult = nil
        }
    }
}
