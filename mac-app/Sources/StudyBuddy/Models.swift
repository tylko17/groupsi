import Foundation

struct RegisterResponse: Codable {
    let username: String
    let token: String
}

struct APIError: Codable {
    let error: String
}

struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let username: String
    let totalSeconds: Int
    let sessionCount: Int

    var id: String { username }
}

struct LeaderboardResponse: Codable {
    let period: String
    let leaderboard: [LeaderboardEntry]
}

struct CompareSide: Codable {
    let username: String
    let totalSeconds: Int
    let sessionCount: Int
}

struct CompareResponse: Codable {
    let period: String
    let a: CompareSide
    let b: CompareSide
}

struct SessionTotals: Codable {
    let totalSeconds: Int
    let sessionCount: Int
}

struct LogSessionResponse: Codable {
    let ok: Bool
    let totals: SessionTotals
}

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .all: return "All Time"
        }
    }
}

func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
        return String(format: "%dh %02dm", h, m)
    } else if m > 0 {
        return String(format: "%dm %02ds", m, s)
    } else {
        return String(format: "%ds", s)
    }
}
