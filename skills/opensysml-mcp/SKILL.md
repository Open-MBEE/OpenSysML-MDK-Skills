---
name: opensysml-mcp
description: Use and configure `sysml-mcp`, the OpenSysML Model Context Protocol server that gives a coding agent SysML v2 / KerML as tools — workspace diagnostics, navigation and editing (the `lsp` group), one-shot parsing, evaluation, execution, verification, rendering, conversion and v1 migration (the `runtime` group), and persistent REPL sessions with the debugger and solver (the `session` group). Use when an agent host (OpenCode, Claude Code, Cursor, Codex, VS Code, Gemini CLI, Devin) should get OpenSysML tools rather than a shell, when choosing which tool to call for a modeling job, when writing or checking a host's MCP configuration block, or when a tool call is refused.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# `sysml-mcp`: OpenSysML as MCP tools

`sysml-mcp` speaks the [Model Context Protocol](https://modelcontextprotocol.io) over stdin
and stdout. An agent host starts it in the project directory and the agent calls OpenSysML as
tools instead of shelling out to `sysml`: the language server's workspace over the documents
under the root, the runtime's one-shot service (the same operations `sysml-grpc` serves, one
tool per RPC) and named REPL sessions whose declarations, objects and runs persist across
calls. It has no port and nothing is typed at it; the host owns the process.

Verified against `sysml-mcp v0.10.1-1266-gdada45c11` (a `develop` build). `sysml-mcp` is not
in the v0.10.1 release: it comes with the release after 0.10.1, and with the nightly snapshots
once they build a `develop` commit that carries it (the 2026-10-18 nightly, built from an
earlier commit, did not list a `sysml-mcp-*` asset in its `SHA256SUMS.txt`; check the nightly's
manifest before pinning `--version nightly`). Until then, build it from `develop`:
`go install github.com/Open-MBEE/OpenSysML/cmd/sysml-mcp@develop` or `make build-mcp` in a
checkout — `@latest` resolves to the v0.10.1 module, which has no `cmd/sysml-mcp`.

## Install

Every release that carries it publishes `sysml-mcp-<os>-<arch>.tar.gz` (`.zip` on Windows) for
linux/amd64, linux/arm64, darwin/amd64, darwin/arm64 and windows/amd64 — the binary, the
`LICENSE` and, on Unix, `share/man/man1/sysml-mcp.1`. It is its own archive, not part of the
`opensysml-<os>-<arch>` bundle, so the install script's default tool list (`sysml,sysml-lsp`)
does not include it:

```bash
curl -fsSL https://opensysml.org/install.sh | sh -s -- --tools sysml,sysml-lsp,sysml-mcp
curl -fsSL https://opensysml.org/install.sh | sh -s -- --tools all                     # everything the release published
go install github.com/Open-MBEE/OpenSysML/cmd/sysml-mcp@develop                       # from source: the develop head (a v0.10.2-0.<date>-<commit> pseudo-version)
```

A `go install` binary prints `sysml-mcp dev` / `Commit: unknown` for `-version` (no version
ldflags); `make build-mcp` stamps the version. `go install …@latest` works once a tagged
release contains `cmd/sysml-mcp`; today it picks v0.10.1 and fails with `module github.com/Open-MBEE/OpenSysML@latest found (v0.10.1), but does
not contain package github.com/Open-MBEE/OpenSysML/cmd/sysml-mcp`.

`--tools all` resolves against the release's `SHA256SUMS.txt`, so on v0.10.1 it installs the
four tools that release published and says it lacks `sysml-mcp`; naming `sysml-mcp` explicitly
on a release without it fails. Windows: `install.ps1 -Tools sysml,sysml-lsp,sysml-mcp`. The
Homebrew formula (`brew install Open-MBEE/tap/opensysml`) and the Scoop manifest install it
beside `sysml` and `sysml-lsp`; the MSI has it as the *MCP server (sysml-mcp)* feature; the
winget manifest does not carry it (one archive per architecture). A checkout builds it with
`make build-mcp` (into `bin/sysml-mcp`) or as part of `make build`. `sysml-mcp -version`
prints the build. See `opensysml-install` for the other routes.

## Command line

| Flag | Default | Meaning |
|---|---|---|
| `-root DIR` | `.` | Workspace folder whose model documents the server indexes and edits; hosts start the server in the project, which is what `.` means |
| `-tools GROUPS` | `all` | Comma-separated groups to serve: `lsp`, `runtime`, `session` |
| `-strict` | off | Strict conformance from the start: notation no pinned SysML v2 production admits is an error |
| `-no-record-cache` | off | Parse every document and hold it loaded; no interface record read or written (also `OPENSYSML_RECORD_CACHE=0`) |
| `-cache-size N` | `100` | Parsed models the runtime tools hold, at least 1 |
| `-log-level LEVEL` | `warn` | Lowest level logged to stderr: `debug`, `info`, `warn`, `error` |
| `-stdio` | — | The only transport; accepted for hosts that name it |
| `-print-config [HOST]` | — | Write a host's configuration block and exit; alone, list the hosts |
| `-print-config-command CMD` | the binary's absolute path | The command the block names |
| `-version`, `-help`, `-man` | — | Build, option table, manual page (roff) |

Exit status: 0 when the protocol was served to its end (client closed the stream), 1 when the
server could not start or the session ended in a protocol error, 2 when the command line could
not be acted on (`-tools bogus` → `unknown tool group "bogus"; the groups are lsp, runtime and
session`). The standard library is the copy embedded in the binary unless
`OPENSYSML_LIBRARY_PATH` names another; budgets (`OPENSYSML_MAX_STEPS`, …) and the other
environment variables of `opensysml-troubleshooting` apply to the server's environment, which
the host sets (most hosts take an `env`/`environment` key beside `command`).

## Configure a host

```bash
sysml-mcp -print-config                                   # list the hosts
sysml-mcp -print-config opencode                          # the block for one
sysml-mcp -print-config codex >> ~/.codex/config.toml     # append the [mcp_servers.sysml] table
sysml-mcp -print-config cursor -print-config-command sysml-mcp   # name a PATH command, not the absolute path
```

| Host | File the block is for | Shape |
|---|---|---|
| `opencode` | `opencode.json` (project) or `~/.config/opencode/opencode.json` | `{"$schema": "https://opencode.ai/config.json", "mcp": {"sysml": {"type": "local", "command": ["/abs/sysml-mcp"], "enabled": true}}}` |
| `claude-code` | `.mcp.json` in the project (or `claude mcp add --scope user sysml -- /abs/sysml-mcp`) | `{"mcpServers": {"sysml": {"type": "stdio", "command": "/abs/sysml-mcp", "args": []}}}` |
| `cursor` | `.cursor/mcp.json` or `~/.cursor/mcp.json` | `{"mcpServers": {"sysml": {"command": …, "args": []}}}` |
| `codex` | `~/.codex/config.toml` | `[mcp_servers.sysml]` / `command = "/abs/sysml-mcp"` / `args = []` |
| `vscode` | `.vscode/mcp.json` (Copilot agent mode) | `{"servers": {"sysml": {"type": "stdio", "command": …, "args": []}}}` |
| `gemini` | `.gemini/settings.json` or `~/.gemini/settings.json` | `{"mcpServers": {"sysml": {"command": …, "args": []}}}` |
| `devin` | Settings → MCP Marketplace → Add custom (paste) | `{"mcpServers": {"sysml": {"command": …, "args": []}}}` |

The server is named `sysml`, so tools appear as `sysml/diagnostics`, `mcp__sysml__diagnostics`
or however the host spells it. By default the block names the binary by its resolved absolute
path (symlinks followed), so a GUI host that does not read a shell profile still finds it;
`-print-config-command sysml-mcp` names the command instead. Server flags go into `args`
(`command` array for OpenCode): `"-tools", "lsp,runtime"` to leave sessions out, `"-root",
"models"` to serve a subfolder. An unknown host exits 2 and lists the seven. Every block above
parses as what its host reads (the Codex block as TOML, the others as JSON; the OpenCode block
validates against the published `https://opencode.ai/config.json` schema).

## The tools

Three groups, `-tools lsp,runtime,session`, all served by default; `tool_catalog` is served
always and answers the catalogue narrowed to the groups served (`{"group": "session"}` for one
group). With everything on, `tools/list` answers 82 tools: `tool_catalog` + 21 `lsp` + 31
`runtime` + 29 `session`. Names are unique across groups: the `lsp` group's
`workspace_diagnostics`, `render_view`, `render_document` work on a document of the workspace;
the `runtime` group's `diagnostics`, `render_model_view`, `render_model_document` on a model
given as `paths`, inline `sources` or a `modelHash`. The full list, grouped, with each tool's
one-line summary, the RPC or `sysml` flag it stands for and whether it writes, is in
[references/tool-catalog.md](references/tool-catalog.md); it was generated from the server's own
`tool_catalog` and `tools/list` answers (regenerated from `sysml-mcp v0.11.0-1195-g14e53c052`: the same 82
tools; `render_view` now names draw.io among its forms).

**`lsp` — the workspace under `-root`** (21): `workspace_info`, `workspace_diagnostics`,
`workspace_symbols`, `document_symbols`, `hover`, `definition`, `references`, `completion`,
`signature_help`, `inlay_hints`, `code_actions`, `rename`, `format`, `apply_model_edit`,
`open_document`, `update_document`, `close_document`, `views`, `render_view`, `documents`,
`render_document`. Positions are 1-based `line`/`column`. `open_document` holds text the agent
has not written yet, so it can be checked before it goes to disk.

**`runtime` — one call, one answer** (31): `parse`, `diagnostics`, `explain_diagnostic`,
`symbol`, `evaluate`, `evaluate_calc`, `instantiate`, `validate_instance`, `execute_action`,
`execute_state`, `check_behavior`, `verify_constraint`, `verify_requirement`,
`verify_satisfaction`, `run_analysis`, `run_sweep`, `run_runs`, `record_run`, `self_check`,
`query`, `run_document_query`, `render_model_view`, `render_model_document`, `export_graphs`,
`convert`, `migrate`, `import_data`, `compare_results`, `apply_edits`, `list_engines`,
`server_info`. Arguments are the RPC's request under its protojson field names; the structured
result is the response as protojson writes it (`realValue`, `intValue` as a string, …).

**`session` — a REPL that persists** (29): `session_open`, `session_list`, `session_load`,
`session_submit`, `session_eval`, `session_print`, `session_save`, `session_clear`,
`session_close`, `session_run`, `repl_command`; the debugger `debug_start`, `debug_step`,
`debug_continue`, `debug_current`, `debug_breakpoints`, `debug_stop`, `send`, `advance`;
`features`, `instances`; the solver `check`, `explain`, `solve`, `configure`, `optimize`;
`sweep`, `runs`, `render_run`.

### Giving a runtime tool its model

Every `runtime` tool that takes a `modelHash` also takes `paths` and `sources` and parses them
first, so one call suffices; a `modelHash` from an earlier answer reuses the parsed model while
it is in the cache (`-cache-size`). The three combine into one model.

```json
{"paths": ["models/rover.sysml"], "expression": "Rover::rover1.totalMass"}
{"sources": [{"path": "inline.sysml", "text": "package Q { attribute x = 6 * 7; }"}], "expression": "Q::x"}
{"modelHash": "013034ae…", "symbolId": "Rover::rover1"}
```

A `sources` item is `{"path", "text"}` plus optional `"language": "sysml"|"kerml"` (inferred
from the extension); a `.kerml` path is KerML. `strictConformance: true` judges the documents
strictly. Paths are relative to the root or absolute but under it; one that leaves the root is
refused: `INVALID_ARGUMENT: /home/u/etc/passwd is outside the workspace root /home/u/proj`.
Every answer carries `modelHash` and `diagnostics`; a parse that failed still answers, with
its diagnostics. Values are protojson `Value` arms: `{"realValue": 50.0}`, `{"intValue": "7"}`,
`{"boolValue": true}`, `{"stringValue": "…"}`.

### Session semantics

- `session_open {"session": "name"}` opens a named session; every other session tool takes
  `session` and uses the default session when it is omitted. `session_list` names the open
  ones; a wrong name fails with `no such session: "x" (session_list names the open ones;
  session_open opens another)`.
- Calls on one session are served one at a time. A call the client abandons (its context
  ends) interrupts the command the session is running — a long `session_run` or `sweep` stops.
- `session_load` takes files, directories (walked for `.sysml`/`.kerml`/`.ipynb`) or globs under
  the root and answers `declared`, `diagnostics`, `errors`, `files`. `session_submit` takes
  declarations as typed at the prompt; `accepted: false` means the text had an error of its
  own, but what it declared still joins the model (a redeclaration replaces the earlier one).
- `session_save {"path": "models/out.sysml"}` answers `{"applied": false, "content": "…"}` —
  the bytes the file would hold — and touches nothing; only `"apply": true` writes, and only
  under the root (`/home/u/escape.sysml is outside the workspace root …; session tools only
  read and write under the root`). `.ttl`/`.json` write RDF (experimental).
- `session_run` takes `kind` (`action`, `state`, `calc`, `analysis`), `name`, positional
  `arguments` (array of expression strings; `parameter=expression` for an analysis case),
  `object`, `duration` (state) and `schedule`. It answers `status` (`holds`, `unresolved`, …),
  `values` and the REPL's text. An action's `in` parameters are not bound from `arguments`;
  give an action its inputs with the runtime `execute_action` (`inputs`), or declare them
  in the session and run the usage.
- The debugger is `debug_start {"kind": "action"|"state", "name": …, "object": …}`, then
  `debug_step`, `debug_continue`, `debug_current`, `debug_breakpoints`, `send` (a signal to the
  debugged machine), `advance` (clock), `debug_stop`. `render_run {"kind": "timeline"|"sequence",
  "form": "text"|"mermaid"|"plantuml"|"svg"|"svg-animated"}` draws the run the session recorded.
- The solver tools (`check`, `explain`, `solve`, `configure`, `optimize`) need an SMT solver
  (`z3` or `cvc5` on `PATH`, or `OPENSYSML_SMT`) in the server's environment; `sweep` takes
  `ranges` as `parameter=from..to[:step]` or `samples`; `runs` repeats an action or a
  `Simulation::MonteCarlo` case. `repl_command {"line": "%list"}` runs any other `%` command.

### Tools worth knowing by name

- `check_behavior`: search every schedule of an action or state machine
  (`actionSymbolId`/`stateMachineSymbolId`, `checkProperty`, `checkDiverge`, `checkInput`,
  `checkAssume`, `checkWitness`, `checkDepth`, `checkStates`, `checkUnroll`, `checkTimeout`,
  `engine`) — the CLI's `-check-*` flags.
- `import_data`: set feature values from a CSV/TSV/JSON/JSON Lines file, one row per element
  (`-import`, `-import-as`, `-import-map`, `-import-format`, `-import-dry-run`); a value the
  model refuses leaves every row unapplied and answers `error`.
- `compare_results`: run the configurations a SysML v1 tool's results sidecar indexes against
  the migrated model (`runs`, `seed`, `draws`, `clockStep`, `observe`) and table both
  distributions.
- `run_runs`: an action or a `Simulation::MonteCarlo` case `runs` times from `seed`
  (`-runs`/`-observe`); `run_sweep`: rows of `ranges` or `samples` (`-sweep`/`-samples`);
  `record_run`: run an analysis case and record the runs into the model as `AnalysisRecords`
  declarations (`recordInto`, `ranges`, `runs`+`seed`).
- `self_check`: apply the `SysMLValidation` constraints (and named rule packages) reflectively
  to every element (`-self-check`, `-self-check-package`).
- `diagnostics`: every diagnostic of a model as `sysml -validate` reports it, with
  `disableLint`/`enableLint` and `strictConformance`; `explain_diagnostic {"code": …}` explains
  a code with its specification clause.
- `migrate`: a v1 `.xmi`/`.uml`/`.mdzip` by `filePath` (or base64 `content` + `fromFormat`) to
  `toFormat` (`sysml`, `kerml`, `ttl`, `api-json`, …), with `report`, `results`, `layoutPath`,
  `imageBaseUrl`, `strict`. The migrated model comes back *in the answer*: `content` holds the
  notation (`files` when it is several documents), `report` the per-element verdicts when asked,
  `experimentalNotice` the status text; nothing is written and no session is touched. A missing
  file answers `NOT_FOUND: file not found: …`.

## Which tool for the job

| Job | Call |
|---|---|
| Validate a file | `workspace_diagnostics {"path": "models/x.sysml"}` (the workspace, cross-file) or `diagnostics {"paths": [...]}` (the model named, as `sysml -validate`); omit `path` to check the whole workspace |
| Check text before writing it | `open_document` with the text, then `workspace_diagnostics`/`hover`/`render_view` on it, then `close_document` |
| Evaluate an expression | `evaluate {"paths": [...], "expression": "P::x.mass"}` → `result.realValue`; in a session, `session_eval` |
| Instantiate and inspect | `instantiate {"paths": [...], "symbolId": "P::part1"}`; `symbol` for a declaration's facts |
| Run an action | `execute_action {"paths": [...], "actionSymbolId": "P::Drive", "inputs": {"distance": {"realValue": 50.0}}}` → `outputs`; stepping: `session_load` then `debug_start`/`debug_step` |
| Run a state machine | `execute_state` with its events; interactively `debug_start {"kind": "state"}`, `send`, `advance` |
| Does a requirement hold | `verify_requirement {"paths": [...], "symbolId": "P::Req", "subjectSymbolId": "P::part1"}` → `requirement P::Req: holds [run, observed]`; `verify_constraint`, `verify_satisfaction`, `validate_instance` likewise |
| Render a view | `render_view {"path": "models/x.sysml", "view": "P::v", "form": "mermaid"}` (also `#tree:P::Part`, `dot`, `plantuml`, `d2`, `drawio`, `text`, `csv`); `render_model_view` for the data form; `views` lists what a document can draw |
| Export an editable diagram | `render_view` with `"form": "drawio"` answers a diagrams.net file as the text and `structuredContent.artifact`, each cell an `<object fqn=…>` naming what `apply_model_edit`'s `setLayout`/`setRoute` target; a native server routes the edges first (`sysml-mcp v0.11.0-1195-g14e53c052`, in nightly builds and the release after v0.11.0; the exchange is in [references/stdio-session.md](references/stdio-session.md)). No tool reads an edited `.drawio` back yet |
| Render a document | `documents`, then `render_document` (Markdown over the workspace) or `render_model_document` (`-render-document`) |
| Convert | `convert` between notation, Turtle and API JSON (`-convert`) |
| Migrate a v1 model | `migrate {"filePath": "model.xmi", "toFormat": "sysml", "report": true}` → `content` is the SysML v2 text: write it to a file with your editor (or `session_open` + `session_submit {"text": content}` + `session_save {"path": …, "apply": true}`; `session_save` alone writes the session's model, not `migrate`'s answer); read `report`; `compare_results` for the v1 tool's recorded runs |
| Edit by operation | `apply_model_edit` (workspace, `setValue`/`rename`/`addMember`/…, writes with `apply`), `rename`, `format`; `apply_edits` for a parsed model's edited notation |
| Explore interactively | `session_open`, `session_load`, `session_submit`, `session_eval`, `session_run`, `session_print`, `session_save … apply` |

Reading before writing: every tool that writes (`format`, `rename`, `apply_model_edit`,
`session_save`) answers the edit or file it would produce and touches disk only with
`"apply": true`. Session tools that "write" change the session's state, not files.

## Protocol on the wire

Newline-delimited JSON-RPC 2.0 on stdio. `initialize` answers
`protocolVersion: "2025-06-18"`, `serverInfo {"name": "sysml-mcp", "title": "OpenSysML",
"version": "v0.10.1-…"}`, capabilities `tools` and `resources` with `listChanged`, and an
`instructions` text. A tool answer is `result.content[0].text` (readable) beside
`result.structuredContent` (the same data as JSON); a refused call is `result.isError: true`
with the message as text, not a protocol error. Schemas are strict: an unknown argument fails
with `validating "arguments": validating root: unexpected additional properties ["name"]`, and
list arguments are typed `["null", "array"]`. Trimmed real exchanges, including a full session
run, are in [references/stdio-session.md](references/stdio-session.md). To drive it by hand:
`npx @modelcontextprotocol/inspector --cli /usr/local/bin/sysml-mcp --method tools/list`.

## Troubleshooting

- **Never run it at a prompt.** It prints nothing and waits; the first non-JSON line is a
  protocol error and the process exits 1. Use `sysml-mcp -version` to see that it runs.
- **Logs are on stderr**, protocol on stdout; `-log-level debug` in `args` logs every call.
  Hosts show stderr in their MCP log (OpenCode's MCP panel, `claude --mcp-debug`, VS Code
  *MCP: List Servers → Show Output*, Cursor's MCP settings page).
- **Host cannot find the binary**: the block names an absolute path that moved; print it again
  or use `-print-config-command sysml-mcp` with the binary on the host's `PATH`.
- **`unexpected argument`**: the server takes flags only; pass a folder as `-root DIR`.
- **A tool is missing**: `-tools` left its group out, or the host cached the catalogue; restart
  the server from the host. `tool_catalog` says what is served.
- **`is outside the workspace root`**: paths, loads and saves must stay under `-root`; serve
  the parent folder or move the file.
- **A budget error** names an `OPENSYSML_MAX_*` variable: raise it in the host's `env` for the
  server, not in your shell.
- **`no SMT solver found`** from `check`/`solve`/…: install `z3` where the host's environment
  sees it, or set `OPENSYSML_SMT` there (see `opensysml-install`).
