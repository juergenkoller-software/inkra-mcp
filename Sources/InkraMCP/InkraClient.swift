import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A non-2xx answer from Inkra's local API.
///
/// Before 0.2.0 the bridge ignored the HTTP status: a missing token or the
/// Inkra Pro lock came back as a normal tool result ("OK, 0 characters").
/// Now every refusal becomes an MCP error with a sentence the agent can act on.
struct InkraAPIError: Error {
    let status: Int
    /// The `error` field of Inkra's JSON answer, e.g. `inkra_pro_required`.
    let code: String?
    /// The `message` field, or the raw body if it was not JSON.
    let detail: String?

    static let storeURL = "https://store.juergenkoller.software/en/apps/inkra?mtm_source=mcp&mtm_medium=agent&mtm_campaign=inkra-mcp"

    var message: String {
        switch (status, code) {
        case (401, _):
            return "Inkra rejected the request because the API token is missing or wrong (HTTP 401). "
                + "Set INKRA_API_TOKEN to the token shown in Inkra → Settings → API; "
                + "the “Copy MCP Config” button there produces a complete configuration."
        case (403, "inkra_pro_required"):
            return "This needs Inkra Pro (HTTP 403, inkra_pro_required). The MCP server and the REST API "
                + "are part of Inkra Pro, and the trial includes them. Only the user can upgrade, "
                + "in the Inkra app or in the store: \(Self.storeURL)"
        default:
            let reason = [code, detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ")
            return "Inkra answered HTTP \(status)" + (reason.isEmpty ? "." : ": \(reason)")
        }
    }

    init(status: Int, body: Data) {
        self.status = status
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        self.code = json?["error"] as? String
        if let json {
            self.detail = json["message"] as? String
        } else {
            let text = String(data: body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.detail = text.isEmpty ? nil : String(text.prefix(300))
        }
    }
}

actor InkraClient {
    private let base: URL
    private let token: String?
    let port: String

    init() {
        let port = ProcessInfo.processInfo.environment["INKRA_API_PORT"] ?? "42932"
        self.port = port
        self.base = URL(string: "http://localhost:\(port)")!
        self.token = ProcessInfo.processInfo.environment["INKRA_API_TOKEN"]
    }

    /// Shown when nothing listens on the port.
    nonisolated var notReachableMessage: String {
        "Inkra is not reachable at http://localhost:\(port). Open Inkra and turn on “API Enabled” "
            + "in Inkra → Settings → API. The MCP server is part of the Inkra version from the website."
    }

    private func authedRequest(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    /// Sends the request and throws `InkraAPIError` for every answer outside 2xx.
    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw InkraAPIError(status: http.statusCode, body: data)
        }
        return data
    }

    private func object(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? ["raw": String(data: data, encoding: .utf8) ?? ""]
    }

    func get(_ path: String) async throws -> [String: Any] {
        object(try await send(authedRequest(base.appendingPathComponent(path))))
    }

    func getText(_ path: String) async throws -> String {
        String(data: try await send(authedRequest(base.appendingPathComponent(path))), encoding: .utf8) ?? ""
    }

    func post(_ path: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        var req = authedRequest(base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return object(try await send(req))
    }

    func delete(_ path: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        var req = authedRequest(base.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return object(try await send(req))
    }
}

/// True when the app is not there at all (nothing listens on the port).
func isUnreachable(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    switch urlError.code {
    case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .timedOut, .notConnectedToInternet:
        return true
    default:
        return false
    }
}
