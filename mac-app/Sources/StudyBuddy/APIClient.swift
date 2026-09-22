import Foundation

enum APIClientError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return "Unexpected response from server"
        }
    }
}

final class APIClient {
    // Overridable at launch with: STUDYBUDDY_API_URL=http://localhost:8080 open StudyBuddy.app
    static let baseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["STUDYBUDDY_API_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://studybuddy-api-lb.fly.dev")!
    }()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private func send<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        var request = URLRequest(url: APIClient.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        if http.statusCode >= 400 {
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw APIClientError.server(apiError.error)
            }
            throw APIClientError.server("Server error (\(http.statusCode))")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func sendWithQuery<T: Decodable>(_ path: String, query: [String: String]) async throws -> T {
        var components = URLComponents(url: APIClient.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        if http.statusCode >= 400 {
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw APIClientError.server(apiError.error)
            }
            throw APIClientError.server("Server error (\(http.statusCode))")
        }
        return try decoder.decode(T.self, from: data)
    }

    func register(username: String) async throws -> RegisterResponse {
        try await send("/api/register", method: "POST", body: ["username": username])
    }

    func logSession(username: String, token: String, durationSeconds: Int, startedAt: Date, endedAt: Date) async throws -> LogSessionResponse {
        try await send("/api/sessions", method: "POST", body: [
            "username": username,
            "token": token,
            "durationSeconds": durationSeconds,
            "startedAt": Int(startedAt.timeIntervalSince1970 * 1000),
            "endedAt": Int(endedAt.timeIntervalSince1970 * 1000),
        ])
    }

    func leaderboard(period: LeaderboardPeriod) async throws -> LeaderboardResponse {
        try await sendWithQuery("/api/leaderboard", query: ["period": period.rawValue])
    }

    func compare(a: String, b: String, period: LeaderboardPeriod) async throws -> CompareResponse {
        try await sendWithQuery("/api/compare", query: ["a": a, "b": b, "period": period.rawValue])
    }
}
