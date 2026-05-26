# Inkra MCP Server

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![MCP](https://img.shields.io/badge/protocol-MCP-purple.svg)](https://modelcontextprotocol.io)
[![juergenkoller-software/inkra-mcp MCP server](https://glama.ai/mcp/servers/juergenkoller-software/inkra-mcp/badges/score.svg)](https://glama.ai/mcp/servers/juergenkoller-software/inkra-mcp)

**Drive a native macOS Markdown editor from Claude, Cursor, or any MCP client.**

This is the official [Model Context Protocol](https://modelcontextprotocol.io) bridge for [**Inkra**](https://store.juergenkoller.software/en/apps/inkra) — a native macOS Markdown editor (SwiftUI + AppKit, not Electron) with live KaTeX/Mermaid preview and a built-in AI assistant.

> **You need the Inkra app installed and running.** This MCP server is a stdio→HTTP bridge — Inkra owns the document state, undo stack, syntax highlighting, and rendering. Get Inkra at [store.juergenkoller.software/apps/inkra](https://store.juergenkoller.software/en/apps/inkra).

---

## What you can do

> "Claude, open ~/Notes/2026-thesis.md, find every heading that contains 'TODO', add a checkbox after it, and save."
>
> "Cursor, list all files in the current folder, bookmark the H2 'Methodology', and switch to Focus Mode."

The MCP server exposes **18 tools** across these categories:

| Category | Tools |
|---|---|
| **Document content** | `document_get_content`, `document_set_content`, `document_insert`, `document_replace`, `document_search` |
| **Document lifecycle** | `document_open`, `document_create`, `document_save` |
| **Navigation** | `outline_get`, `bookmarks_list`, `bookmark_add`, `bookmark_remove` |
| **Folder / files** | `folder_open`, `folder_list_files` |
| **Metadata** | `frontmatter_get` (YAML front-matter parser) |
| **View** | `theme_set` (standard / sepia / night), `view_mode_set` (focus / wide) |
| **State** | `window_info` |

Every tool operates on the **currently open document** in the Inkra app — so AI agents see exactly what you see, edits show up live with syntax highlighting and preview, and undo/redo work in the app's normal undo stack.

---

## Installation

### Prerequisites

1. **macOS 14 (Sonoma) or later**
2. **Inkra app installed and running** — [get it here](https://store.juergenkoller.software/en/apps/inkra) (free during beta, available on Mac App Store and direct download)
3. **Swift 5.9+** (Xcode 15+) if building from source

### Build from source

```bash
git clone https://github.com/juergenkoller-software/inkra-mcp.git
cd inkra-mcp
swift build -c release
# Binary: .build/release/InkraMCP
```

### Pre-built binary

See [Releases](https://github.com/juergenkoller-software/inkra-mcp/releases).

---

## Configuration

### Claude Desktop

```json
{
  "mcpServers": {
    "inkra": {
      "command": "/path/to/InkraMCP",
      "env": {
        "INKRA_PORT": "22300",
        "INKRA_TOKEN": "your-token-here"
      }
    }
  }
}
```

Get `INKRA_TOKEN` from **Inkra → Settings → API & Integrations**.

### Claude Code

```bash
claude mcp add inkra /path/to/InkraMCP \
  --env INKRA_PORT=22300 \
  --env INKRA_TOKEN=your-token-here
```

### Cursor / other MCP clients

Same pattern — stdio MCP server, two env vars.

---

## How it works

```
┌────────────────┐  JSON-RPC stdio   ┌────────────────┐  HTTP+Bearer   ┌────────────────┐
│  Claude/Cursor │ ───────────────►  │  InkraMCP      │ ─────────────► │  Inkra.app     │
│  (MCP client)  │ ◄───────────────  │   (this repo)  │ ◄───────────── │  (port 22300)  │
└────────────────┘                   └────────────────┘                └────────────────┘
```

The bridge forwards JSON-RPC over stdio to Inkra's local HTTP MCP endpoint. The app handles document state (NSTextView with TextKit 2), AST-based syntax highlighting, KaTeX/Mermaid live preview, undo/redo, session restore, and exports.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `INKRA_PORT` | `22300` | Port of Inkra's local HTTP server |
| `INKRA_TOKEN` | _(none)_ | Bearer token from Inkra Settings (required) |

---

## About Inkra

Inkra is a native macOS Markdown editor — **not** an Electron app. Highlights:

- **Native** — SwiftUI + AppKit, real macOS performance
- **Live preview** — KaTeX formulas, Mermaid diagrams, code highlighting rendered in real time via WKWebView
- **Focus mode + wide mode** — distraction-free writing
- **Built-in AI assistant** — Claude, OpenAI, Ollama, or Inkra KI (dedicated endpoint, no API key needed)
- **Export** — HTML and PDF with full layout, formulas, diagrams, code blocks
- **Session restore** — folder, file, cursor, scroll position
- **MCP server** (this repo) + REST API with Swagger UI
- **23 EU language localizations**
- **Available on Mac App Store + direct download**

→ **[Get Inkra at store.juergenkoller.software](https://store.juergenkoller.software/en/apps/inkra)**

---

## License

MIT — see [LICENSE](LICENSE). Bridge open source; Inkra app is commercial.

## Issues & support

- **Bridge bugs:** [open an issue](https://github.com/juergenkoller-software/inkra-mcp/issues)
- **App support:** [support@juergenkoller.software](mailto:support@juergenkoller.software)

Built by [Juergen Koller Software GmbH](https://juergenkoller.software).
