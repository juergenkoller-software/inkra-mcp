import Foundation
import MCP

@main
struct InkraMCPServer {
    static func main() async throws {
        let server = Server(
            name: "inkra",
            version: "1.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        let client = InkraClient()

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                return try await handleTool(params, client: client)
            } catch let apiError as InkraAPIError {
                return CallTool.Result(content: [.text(apiError.message)], isError: true)
            } catch where isUnreachable(error) {
                return CallTool.Result(content: [.text(client.notReachableMessage)], isError: true)
            } catch {
                return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
