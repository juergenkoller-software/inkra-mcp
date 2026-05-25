import Foundation

actor InkraClient {
    private let base: URL
    private let token: String?

    init() {
        let port = ProcessInfo.processInfo.environment["INKRA_API_PORT"] ?? "42932"
        self.base = URL(string: "http://localhost:\(port)")!
        self.token = ProcessInfo.processInfo.environment["INKRA_API_TOKEN"]
    }

    private func authedRequest(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    func get(_ path: String) async throws -> [String: Any] {
        let req = authedRequest(base.appendingPathComponent(path))
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? ["raw": String(data: data, encoding: .utf8) ?? ""]
    }

    func getText(_ path: String) async throws -> String {
        let req = authedRequest(base.appendingPathComponent(path))
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func post(_ path: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        var req = authedRequest(base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? ["raw": String(data: data, encoding: .utf8) ?? ""]
    }

    func delete(_ path: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        var req = authedRequest(base.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? ["raw": String(data: data, encoding: .utf8) ?? ""]
    }

    func isAppRunning() async -> Bool {
        do {
            let _ = try await get("/api/status")
            return true
        } catch {
            return false
        }
    }
}
