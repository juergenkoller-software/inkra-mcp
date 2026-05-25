import Foundation
import MCP

@main
struct InkraMCPServer {
    static func main() async throws {
        let server = Server(
            name: "inkra",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        let client = InkraClient()

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                guard await client.isAppRunning() else {
                    return CallTool.Result(content: [.text("Inkra is not running. Please open the app.")], isError: true)
                }
                return try await handleTool(params, client: client)
            } catch {
                return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
