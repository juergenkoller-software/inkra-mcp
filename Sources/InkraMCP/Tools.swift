import Foundation
import MCP

// MARK: - Tool definitions

func schema(_ props: [String: Value], required: [String] = []) -> Value {
    var obj: [String: Value] = [
        "type": .string("object"),
        "properties": .object(props)
    ]
    if !required.isEmpty {
        obj["required"] = .array(required.map { .string($0) })
    }
    return .object(obj)
}

func prop(_ type: String, _ desc: String) -> Value {
    .object(["type": .string(type), "description": .string(desc)])
}

let allTools: [Tool] = [
    Tool(name: "document_get_content",
         description: "Returns the full text content of the document",
         inputSchema: schema([:])),

    Tool(name: "document_set_content",
         description: "Replaces the full text content of the document",
         inputSchema: schema(["content": prop("string", "New document content")], required: ["content"])),

    Tool(name: "document_insert",
         description: "Inserts text at a position (line/column, 0-based)",
         inputSchema: schema([
            "text": prop("string", "Text to insert"),
            "line": prop("integer", "Line number (0-based)"),
            "column": prop("integer", "Column number (0-based)")
         ], required: ["text", "line", "column"])),

    Tool(name: "document_replace",
         description: "Finds and replaces text in the document",
         inputSchema: schema([
            "pattern": prop("string", "Search text or regex"),
            "replacement": prop("string", "Replacement text"),
            "regex": prop("boolean", "Interpret pattern as regex")
         ], required: ["pattern", "replacement"])),

    Tool(name: "document_open",
         description: "Opens a file in the editor (absolute path)",
         inputSchema: schema(["path": prop("string", "Absolute file path")], required: ["path"])),

    Tool(name: "document_create",
         description: "Creates a new document with optional content",
         inputSchema: schema([
            "content": prop("string", "Initial content"),
            "path": prop("string", "File path to save to")
         ])),

    Tool(name: "document_save",
         description: "Saves the current document",
         inputSchema: schema([:])),

    Tool(name: "document_search",
         description: "Searches the document for text or regex",
         inputSchema: schema([
            "query": prop("string", "Search term or regex"),
            "regex": prop("boolean", "Search as regex")
         ], required: ["query"])),

    Tool(name: "outline_get",
         description: "Returns the heading structure of the document",
         inputSchema: schema([:])),

    Tool(name: "window_info",
         description: "Returns the current app state",
         inputSchema: schema([:])),

    Tool(name: "folder_open",
         description: "Opens a folder in the sidebar",
         inputSchema: schema(["path": prop("string", "Absolute folder path")], required: ["path"])),

    Tool(name: "folder_list_files",
         description: "Lists files in the opened folder",
         inputSchema: schema(["glob": prop("string", "Filter, e.g. *.md")])),

    Tool(name: "theme_set",
         description: "Switches the theme (standard, sepia, night)",
         inputSchema: schema(["id": prop("string", "Theme ID")], required: ["id"])),

    Tool(name: "view_mode_set",
         description: "Controls Focus Mode and Wide Mode",
         inputSchema: schema([
            "focus": prop("boolean", "Focus Mode"),
            "wide": prop("boolean", "Wide Mode")
         ])),

    Tool(name: "frontmatter_get",
         description: "Returns the YAML frontmatter of the document",
         inputSchema: schema([:])),

    Tool(name: "bookmarks_list",
         description: "Returns all bookmarks of the current document",
         inputSchema: schema([:])),

    Tool(name: "bookmark_add",
         description: "Adds a bookmark at a specific position in the text",
         inputSchema: schema([
            "name": prop("string", "Name of the bookmark"),
            "offset": prop("integer", "Character position in the text")
         ], required: ["name", "offset"])),

    Tool(name: "bookmark_remove",
         description: "Removes a bookmark by its ID",
         inputSchema: schema(["id": prop("string", "UUID of the bookmark")], required: ["id"])),
]

// MARK: - Tool dispatch

func handleTool(_ params: CallTool.Parameters, client: InkraClient) async throws -> CallTool.Result {
    let args = params.arguments ?? [:]

    switch params.name {
    case "document_get_content":
        let text = try await client.getText("/api/document/content")
        return .init(content: [.text(text)])

    case "document_set_content":
        let r = try await client.post("/api/document/content", body: ["content": str(args["content"])])
        return .init(content: [.text("OK, \(r["length"] ?? 0) characters")])

    case "document_insert":
        let r = try await client.post("/api/document/insert", body: [
            "text": str(args["text"]), "line": num(args["line"]), "column": num(args["column"])
        ] as [String: Any])
        return .init(content: [.text("Inserted, \(r["length"] ?? 0) characters total")])

    case "document_replace":
        let r = try await client.post("/api/document/replace", body: [
            "pattern": str(args["pattern"]),
            "replacement": str(args["replacement"]),
            "regex": args["regex"]?.boolValue ?? false
        ] as [String: Any])
        return .init(content: [.text("Replaced, \(r["length"] ?? 0) characters")])

    case "document_open":
        let r = try await client.post("/api/document/open", body: ["path": str(args["path"])])
        return .init(content: [.text("Opened: \(r["path"] ?? ""), \(r["length"] ?? 0) characters")])

    case "document_create":
        var body: [String: Any] = ["content": str(args["content"])]
        if let p = args["path"]?.stringValue { body["path"] = p }
        let r = try await client.post("/api/document/create", body: body)
        return .init(content: [.text("Created, \(r["length"] ?? 0) characters")])

    case "document_save":
        let r = try await client.post("/api/document/save")
        return .init(content: [.text("Saved: \(r["path"] ?? "no path")")])

    case "document_search":
        let q = str(args["query"]).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let regex = args["regex"]?.boolValue ?? false
        let r = try await client.get("/api/document/search?query=\(q)&regex=\(regex)")
        return .init(content: [.text(jsonStr(r))])

    case "outline_get":
        let r = try await client.get("/api/document/outline")
        return .init(content: [.text(jsonStr(r))])

    case "window_info":
        let r = try await client.get("/api/status")
        return .init(content: [.text(jsonStr(r))])

    case "folder_open":
        let r = try await client.post("/api/folder/open", body: ["path": str(args["path"])])
        return .init(content: [.text("Folder opened, \(r["fileCount"] ?? 0) files")])

    case "folder_list_files":
        let g = (args["glob"]?.stringValue ?? "*").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "*"
        let r = try await client.get("/api/folder/files?glob=\(g)")
        return .init(content: [.text(jsonStr(r))])

    case "theme_set":
        let r = try await client.post("/api/theme", body: ["id": str(args["id"])])
        return .init(content: [.text("Theme: \(r["theme"] ?? "")")])

    case "view_mode_set":
        var body: [String: Any] = [:]
        if let f = args["focus"]?.boolValue { body["focus"] = f }
        if let w = args["wide"]?.boolValue { body["wide"] = w }
        let r = try await client.post("/api/viewmode", body: body)
        return .init(content: [.text("Focus: \(r["focusMode"] ?? false), Wide: \(r["wideMode"] ?? false)")])

    case "frontmatter_get":
        let r = try await client.get("/api/frontmatter")
        return .init(content: [.text(jsonStr(r))])

    case "bookmarks_list":
        let r = try await client.get("/api/document/bookmarks")
        return .init(content: [.text(jsonStr(r))])

    case "bookmark_add":
        let r = try await client.post("/api/document/bookmarks", body: [
            "name": str(args["name"]),
            "offset": num(args["offset"])
        ] as [String: Any])
        return .init(content: [.text(jsonStr(r))])

    case "bookmark_remove":
        let r = try await client.delete("/api/document/bookmarks", body: ["id": str(args["id"])])
        return .init(content: [.text(jsonStr(r))])

    default:
        return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
    }
}

// MARK: - Helpers

private func str(_ val: Value?) -> String { val?.stringValue ?? "" }
private func num(_ val: Value?) -> Int { val?.intValue ?? 0 }

private func jsonStr(_ dict: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
          let s = String(data: data, encoding: .utf8)
    else { return "\(dict)" }
    return s
}

extension Value {
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var intValue: Int? { if case .int(let i) = self { return i }; return nil }
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
}
