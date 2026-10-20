# Inkra MCP Server

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![MCP](https://img.shields.io/badge/protocol-MCP-purple.svg)](https://modelcontextprotocol.io)
[![juergenkoller-software/inkra-mcp MCP server](https://glama.ai/mcp/servers/juergenkoller-software/inkra-mcp/badges/score.svg)](https://glama.ai/mcp/servers/juergenkoller-software/inkra-mcp)

**Drive a native macOS Markdown editor from Claude, Cursor, or any MCP client.**

This is the official [Model Context Protocol](https://modelcontextprotocol.io) bridge for [**Inkra**](https://store.juergenkoller.software/en/apps/inkra?mtm_source=mcp&mtm_medium=agent&mtm_campaign=inkra-mcp&mtm_content=github-readme) — a native macOS Markdown editor (SwiftUI + AppKit, not Electron) with live KaTeX/Mermaid preview and a built-in AI assistant.

> **You need the Inkra app installed and running, with Inkra Pro.** This MCP server is a stdio→HTTP bridge — Inkra owns the document state, undo stack, syntax highlighting, and rendering. The MCP server and the REST API are part of **Inkra Pro**; the free trial includes them. Get Inkra at [store.juergenkoller.software/apps/inkra](https://store.juergenkoller.software/en/apps/inkra?mtm_source=mcp&mtm_medium=agent&mtm_campaign=inkra-mcp&mtm_content=github-readme).
>
> The Inkra version from the website already contains this bridge as `inkra-mcp-server`. Inkra → Settings → API → **Copy MCP Config** gives you a ready-made configuration. Build from this repository only if you want to audit or modify the bridge.

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
2. **Inkra app installed and running** — [get it here](https://store.juergenkoller.software/en/apps/inkra?mtm_source=mcp&mtm_medium=agent&mtm_campaign=inkra-mcp&mtm_content=github-readme) (website version; the Mac App Store version does not include the MCP server)
3. **Inkra Pro**, or the free trial — without it the app answers every MCP call with “Inkra Pro required”
4. **API enabled** in Inkra → Settings → API (“API Enabled”)
5. **Swift 5.9+** (Xcode 15+) only if building from source

### Use the bridge inside the app (recommended)

```
/Applications/Inkra.app/Contents/MacOS/inkra-mcp-server
```

It always matches the installed app version.

### Build from source

```bash
git clone https://github.com/juergenkoller-software/inkra-mcp.git
cd inkra-mcp
swift build -c release
# Binary: .build/release/InkraMCP
```

### Pre-built binary

Not needed on a Mac: the website version of Inkra ships the bridge (see above). The binary attached to [Releases](https://github.com/juergenkoller-software/inkra-mcp/releases) is a static Linux x86_64 build for container-based MCP registries such as Glama; it does not run on macOS.

---

## Configuration

### Claude Desktop

```json
{
  "mcpServers": {
    "inkra": {
      "command": "/Applications/Inkra.app/Contents/MacOS/inkra-mcp-server",
      "env": {
        "INKRA_API_PORT": "42932",
        "INKRA_API_TOKEN": "your-token-here"
      }
    }
  }
}
```

Get `INKRA_API_TOKEN` from **Inkra → Settings → API**, or use **Copy MCP Config** there, which fills in path, port, and token.

### Claude Code

```bash
claude mcp add inkra /Applications/Inkra.app/Contents/MacOS/inkra-mcp-server \
  --env INKRA_API_PORT=42932 \
  --env INKRA_API_TOKEN=your-token-here
```

### Cursor / other MCP clients

Same pattern — stdio MCP server, two env vars.

---

## How it works

```
┌────────────────┐  JSON-RPC stdio   ┌────────────────┐  HTTP+Bearer   ┌────────────────┐
│  Claude/Cursor │ ───────────────►  │  InkraMCP      │ ─────────────► │  Inkra.app     │
│  (MCP client)  │ ◄───────────────  │   (this repo)  │ ◄───────────── │  (port 42932)  │
└────────────────┘                   └────────────────┘                └────────────────┘
```

The bridge translates MCP tool calls into requests to Inkra's local REST API. The app handles document state (NSTextView with TextKit 2), AST-based syntax highlighting, KaTeX/Mermaid live preview, undo/redo, session restore, and exports.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `INKRA_API_PORT` | `42932` | Port of Inkra's local HTTP server (Inkra → Settings → API) |
| `INKRA_API_TOKEN` | _(none)_ | Bearer token from Inkra → Settings → API (required) |

---

## Errors

Every refusal comes back as an MCP error (`isError: true`) with a sentence the agent can act on:

| Situation | What the bridge reports |
|---|---|
| Inkra not running, or API switched off | Inkra is not reachable at `http://localhost:<port>`; open Inkra and turn on “API Enabled” |
| Token missing or wrong (HTTP 401) | Set `INKRA_API_TOKEN` to the token in Inkra → Settings → API |
| No Inkra Pro (HTTP 403 `inkra_pro_required`) | The MCP server is part of Inkra Pro; only the user can upgrade, in the app or in the store |
| Any other HTTP error | Status code and Inkra's error text |

Before version 0.2.0 the bridge ignored the HTTP status, so a wrong token or the Pro lock looked like a successful call (“OK, 0 characters”).

---

## About Inkra

Inkra is a native macOS Markdown editor — **not** an Electron app. Highlights:

- **Native** — SwiftUI + AppKit, real macOS performance
- **Live preview** — KaTeX formulas, Mermaid diagrams, code highlighting rendered in real time via WKWebView
- **Focus mode + wide mode** — distraction-free writing
- **Built-in AI assistant** — Claude, OpenAI, Ollama, or Inkra KI (dedicated endpoint, no API key needed)
- **Export** — HTML and PDF with full layout, formulas, diagrams, code blocks
- **Session restore** — folder, file, cursor, scroll position
- **MCP server** (this repo) + REST API with Swagger UI — part of Inkra Pro
- **24 EU languages**
- **Available on the Mac App Store and as a direct download** — the MCP server ships with the direct download

→ **[Get Inkra at store.juergenkoller.software](https://store.juergenkoller.software/en/apps/inkra?mtm_source=mcp&mtm_medium=agent&mtm_campaign=inkra-mcp&mtm_content=github-readme)**

---

## License

MIT — see [LICENSE](LICENSE). Bridge open source; Inkra app is commercial.

## Issues & support

- **Bridge bugs:** [open an issue](https://github.com/juergenkoller-software/inkra-mcp/issues)
- **App support:** [support@juergenkoller.software](mailto:support@juergenkoller.software)

Built by [Juergen Koller Software GmbH](https://juergenkoller.software).
