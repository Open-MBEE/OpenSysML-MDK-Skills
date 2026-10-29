---
name: opensysml-lsp
description: Wire the `sysml-lsp` language server into editors and coding agents — VS Code (opensysml-sysml.vsix), OpenCode, Neovim or any LSP client — over stdio, configure strict conformance, lint and library-root settings, let it find the installed projects a `.project.json` or `.kpar` project uses, and understand the experimental `opensysml/*` methods (rendering, document rendering, stdlib content, model edits, debugging). Use when setting up SysML v2 editing support, when an agent harness should get live diagnostics for .sysml/.kerml files, or when the server starts but reports nothing. An agent that wants tools to call rather than an editor protocol uses `sysml-mcp` (see opensysml-mcp).
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# `sysml-lsp` and editors

`sysml-lsp` is a Language Server Protocol server for `.sysml` and `.kerml` files: diagnostics
(the same checks `sysml -validate` runs), completion, hover, go-to-definition, references,
rename, document symbols, semantic tokens, formatting and code actions. It serves one
workspace and resolves names across all its files, so cross-file references work in the
editor even though the CLI loads only the files named.

Install it with any route in `opensysml-install` (`--tools sysml-lsp`); the Go route is
`go install github.com/Open-MBEE/OpenSysML/cmd/sysml-lsp@latest`. Verified against
`sysml-lsp v0.10.1-1266-gdada45c11` (a `develop` build); `-library-root`, the `libraryRoots`
setting and project-interchange dependency discovery are in nightly builds and the release
after 0.10.1, not in v0.10.1.

Coding agents: an LSP client gives an agent *diagnostics as it edits*. An agent that should
*call* OpenSysML — validate, evaluate, run, render, migrate, keep a REPL session — gets the
same workspace and more as MCP tools from [`sysml-mcp`](../opensysml-mcp/SKILL.md).

## Command line

```bash
sysml-lsp                         # what an editor runs; -stdio names the only transport for clients that insist
sysml-lsp -strict                 # strict OMG conformance for every document
sysml-lsp -no-record-cache        # parse everything, read and write no interface record (also OPENSYSML_RECORD_CACHE=0)
sysml-lsp -library-root /path/to/store   # where installed projects are, besides the project's own .sysand/lib; repeatable or PATH-separated
sysml-lsp -version                # sysml-lsp v0.10.1-…; -help, -man
```

`-library-root` adds to `OPENSYSML_LIBRARY_ROOTS`; a client can also send the `libraryRoots`
setting (below). Exit status 0 when the client shut down or closed the stream, 1 on an exit
without shutdown or a protocol error, 2 when the command line could not be acted on.

## Settings (sent by the client, `sysml` section)

| Setting | Effect |
|---|---|
| `sysml.strictConformance` (bool) | Same as `-strict`; `nonstandard-notation` becomes an error |
| `sysml.disabledLints` (string[]) | Lint codes to drop, e.g. `["undeclared-signal"]` |
| `sysml.enabledLints` (string[]) | Opt-in lints to report, e.g. `["rounded-real-literal"]` |
| `sysml.libraryRoots` (string[]) | Directories to look for installed projects under, besides the workspace project's `.sysand/lib`; relative to each workspace folder; a root may hold directories or `.kpar` archives at any depth. Replaces the list; `[]` drops the extra roots and re-indexes |

Each setting is read from `initialize`'s `initializationOptions` and from
`workspace/didChangeConfiguration`, in three shapes:
`{"strictConformance": true}`, `{"sysml": {"strictConformance": true}}` or
`{"sysml.strictConformance": true}`. A value of the wrong type is ignored; a lint code naming no
lint is shown to the client as an error.

## Projects and installed dependencies

A workspace folder holding a `.project.json` (the OMG project interchange project file, KerML
1.0 §10.3: `name`, `publisher`, `version`, `usage` entries whose `resource` IRIs name the
projects it uses) is a project. The server reads it — never a lock file, never the network —
and indexes the installed projects its usages select so their names resolve in the editor,
looking under the project's well-known library directory (`.sysand/lib` for a `sysand`
project) and under every directory `-library-root`, `OPENSYSML_LIBRARY_ROOTS` or the
`libraryRoots` setting names. An installed project is matched by its own `.project.json`
(publisher and name against the usage's resource IRI, the exact `versionConstraint` version
when one is named, else the latest installed), and its usages are followed in turn. A project
may be a directory or a project interchange archive (`.kpar`), read from memory and indexed
as `<archive>.kpar/<member>`; a malformed archive is a diagnostic on its path. The standard
library's `*.kpar` usages are answered by the bundled library. The CLI does the same
(`sysml -validate proj`, `sysml -library-root …`); see `opensysml-cli`.

Environment variables apply as for the CLI (`OPENSYSML_LIBRARY_PATH`, budgets; see
`opensysml-troubleshooting`).

## VS Code

The extension lives in `editors/vscode` of the OpenSysML repository and is published as a
VSIX on the nightly release, not on the Marketplace:

```bash
curl -fsSLO https://github.com/Open-MBEE/OpenSysML/releases/download/nightly/opensysml-sysml.vsix
code --install-extension opensysml-sysml.vsix
```

or build it: `cd editors/vscode && npm install && npm run package`. It finds `sysml-lsp`
on `PATH`; pin a specific binary with `.vscode/settings.json`:

```json
{
  "opensysml.server.path": "/absolute/path/to/sysml-lsp",
  "opensysml.server.args": ["-strict"],
  "opensysml.diagram.autoOpen": false
}
```

Extension settings use the `opensysml.*` prefix (`server.path`, `server.args`,
`server.enabled`, `trace.server`, `diagram.autoOpen`, `diagram.style`); the server's own
settings keep the `sysml.*` prefix above and are passed through unchanged.

Beyond LSP it adds a diagram panel (renders views via the server), a standard-library
browser, and "run this element" commands that shell out to `sysml`.
`editors/vscode/README.md` documents every setting.

## OpenCode and other agent harnesses

Any harness that forwards LSP diagnostics to its agent gets `sysml -validate`-grade feedback
on every edit. OpenCode: add to `opencode.json` in the project (or
`~/.config/opencode/opencode.json` for all projects):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
    "sysml": {
      "command": ["sysml-lsp", "--stdio"],
      "extensions": [".sysml", ".kerml"]
    }
  }
}
```

The server must be on `PATH` when the harness starts (`PATH="$PWD/bin:$PATH" opencode`
after `make build` in a checkout).

## Neovim (`nvim-lspconfig` style)

```lua
vim.filetype.add({ extension = { sysml = "sysml", kerml = "kerml" } })
vim.lsp.config("sysml_lsp", {
  cmd = { "sysml-lsp", "--stdio" },
  filetypes = { "sysml", "kerml" },
  root_markers = { ".git" },
  settings = { sysml = { strictConformance = false } },
})
vim.lsp.enable("sysml_lsp")
```

Any client that can run a stdio server works the same way (Helix, Emacs `eglot`, Zed, Sublime
LSP): command `sysml-lsp --stdio`, language ids `sysml` and `kerml`.

## Experimental methods (`opensysml/...`)

The server exposes extensions for tooling: `opensysml/render` (a view of a document as
Mermaid, dot, PlantUML, D2, draw.io, text or a table), `opensysml/views`, `opensysml/documents`,
`opensysml/renderDocument`, `opensysml/stdlibContent` (standard-library source for
navigation), `opensysml/applyModelEdit` (edits by operation on elements), the
`opensysml/renderChanged` notification and the `opensysml/debug/*` requests (stepping actions
and state machines, events). They are documented with request/response shapes in
`docs/reference/lsp.md` of the OpenSysML repository and are used by the VS Code extension;
treat them as unstable and check the server version (`sysml-lsp -version`) before relying
on one. `opensysml/render` with `"form": "drawio"` (listed in the `openSysmlRenderForms`
capability of `sysml-lsp v0.11.0-1195-g14e53c052`; in nightly builds and the release after v0.11.0) answers the diagrams.net file as
`artifact` beside the usual `nodes`/`edges`: every node, port and edge cell is an `<object>`
whose `fqn` is the same qualified name `nodes[].fqn` carries, the target
`opensysml/applyModelEdit`'s `setLayout`/`setRoute` take, so the file and the edit
operations name elements the same way. A native server routes the edges the view leaves
unrouted before answering (exact `exitX`/`entryX` anchors and bend waypoints, as the VS
Code diagram panel draws them); a `js`/`wasip1` server writes them unrouted under a notice
(`opensysml-wasm`). `opensysml/importDiagram` reads the file back after an edit in draw.io:
`{"textDocument": {"uri": …}, "path": "/…/view.drawio", "dryRun": true}` (`content` with the
file's text instead of `path`, compressed as draw.io desktop saves it or not; `view` when the
file has several pages; `inline` to annotate beside the elements). The server renders the view,
exports it again and diffs the file against that export cell by cell; the result lists the
planned `edits` (`kind`, `target`, `label`, `cell`), what it reports rather than imports
(`unmatched` elements the rendering lacks, `unknown` cells naming no element, `deleted` cells,
`notices` for changes no annotation carries), `stale`, the document `version`, and `edit`, a
`WorkspaceEdit` the client applies as it applies `applyModelEdit`'s — the same `setLayout`
/`setRoute`/`setStyle`/`setCanvas` edits, derived from the file instead of a drag. `dryRun` is
echoed; the server never writes files, so a client that applies nothing has done a dry run.
Verified with `sysml-lsp v0.11.0-1240-gedc2cc4c7` (develop plus the import branch, not yet merged):
one node moved in the file answered one `Layout` edit whose `newText` was `100; y = 19` over
the old coordinates. The VS Code extension's *SysML: Export Diagram* command offers the same
form as `.drawio`, and *SysML: Import layout from draw.io…* (`opensysml.importDiagram`) picks
a `.drawio`/`.xml` file, sends this request and applies the `edit`, saying `… matches the
rendering of …; nothing to import` when nothing differs (`opensysml-drawio`). The same operations are plain MCP tools (`render_view`, `views`, `documents`,
`render_document`, `apply_model_edit`, `debug_*`) in `sysml-mcp`.

## Troubleshooting

- No diagnostics at all: the file is not recognised as `sysml`/`kerml` by the client, or the
  server exited at startup — run `sysml-lsp --stdio < /dev/null` to see a clean exit, and
  check the client's LSP log.
- Unresolved references that the CLI resolves: the LSP resolves across the *workspace root*;
  open the folder containing all files, not a single file.
- Different verdicts from the CLI: strict mode or lint settings differ; align
  `sysml.strictConformance` with `-strict`.
- Names from an installed dependency unresolved: the project's `.project.json` usage does not
  match the installed project's own `.project.json` (publisher/name slug, version), or the
  store is not a well-known directory; name it with `-library-root` or `libraryRoots`.
- Stale results after installing a new binary: restart the server (the client caches the
  process); `-no-record-cache` disables the on-disk record cache if it looks corrupt.
