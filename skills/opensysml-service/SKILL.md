---
name: opensysml-service
description: Run and talk to the `sysml-grpc` service that backs every OpenSysML language client — start it on a port, check `/health`, negotiate capabilities with GetServerInfo, call any of the 31 RPCs over Connect JSON with curl, gRPC, or gRPC-Web, configure CORS/TLS for browsers, and share one service between several clients via OPENSYSML_SERVICE. Use when a client cannot connect, when exposing OpenSysML to a browser or another machine, when debugging requests with curl, when a client reports a missing capability, or when choosing between a private per-process service and a shared one.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# The `sysml-grpc` service

`sysml-grpc` is one process serving gRPC, gRPC-Web, Connect (protobuf and JSON), server
reflection and `GET /health` on a single port (default `50051`). The Python, Node, Java,
Rust, Julia and MATLAB clients are thin wrappers over it; anything they can do is one RPC
on `sysml.SysMLService`. The contract is `api/proto/sysml.proto` in the OpenSysML
repository, documented in `docs/reference/api.md`, `docs/reference/service-transports.md`
and `docs/reference/wire-contract.md`. Coding-agent hosts (Claude Code, Cursor, …) do not
talk to `sysml-grpc` directly: they run `sysml-mcp`, the MCP server built from the same
tree, which exposes the same operations as MCP tools.

Verified against `sysml v0.10.1-1266-gdada45c11` (a `develop` build; the last release is
v0.10.1). Everything marked *nightly* below is absent from a v0.10.1 service and arrives
in nightly builds and the release after 0.10.1.

## Start it

```bash
sysml-grpc                                  # :50051, logs to stderr
sysml-grpc -port 0 -report-address          # pick a free port and print it on stdout
sysml-grpc -port 50051 -health-port 0 -log-level warn
sysml-grpc -exit-with-parent                # die with the process that spawned it
sysml-grpc -transport stdio                 # Connect over stdin/stdout for embedding
sysml-grpc -cors-allowed-origins https://app.example.org -tls-cert cert.pem -tls-key key.pem
```

Flags (`sysml-grpc -help`): `-port`, `-health-port` (deprecated separate listener; `0`
disables it), `-log-level`, `-report-address`, `-exit-with-parent`,
`-transport connect|grpc|stdio` (`connect`, the default, serves gRPC, gRPC-Web and Connect
on one port; `grpc` is grpc-go only), `-cors-allowed-origins` (exact origins,
comma-separated; browsers need this), `-tls-cert`/`-tls-key`, `-cache-size`,
`-serve-external-engines`, `-version`, `-man`.

Clients start a **private** service by default (a child process on a free port, closed
with the connection). Point them at a **shared** service instead with
`OPENSYSML_SERVICE=host:port` (Node, Julia, MATLAB and Rust honour it directly; Python
`opensysml.connect(host, port)`, Java `Connection.open(address)`). A shared service holds
parsed models by `modelHash`, so several clients can reuse one parse.

## Probe it with curl (Connect JSON)

```bash
curl -s http://127.0.0.1:50051/health
# {"service":"sysml-grpc","status":"ok","version":"v0.10.1"}

curl -s -X POST http://127.0.0.1:50051/sysml.SysMLService/GetServerInfo \
     -H 'Content-Type: application/json' -d '{}'
# {"version":"v0.10.1", "capabilities":["type_facts","convert","verification",...]}

curl -s -X POST http://127.0.0.1:50051/sysml.SysMLService/ParseFile \
     -H 'Content-Type: application/json' \
     -d '{"content":"package P { part def A { attribute x : Nope; } }"}'
# {"modelHash":"52e2...", "root":{"kind":"RootNamespace", "childIds":["P"]},
#  "diagnostics":[{"severity":"error", "message":"unresolved reference: Nope — did you mean OOSEM::Node or DiagramLayout::Note?",
#                  "span":{"file":"<content>", "startLine":1, "startCol":40, "endLine":1, "endCol":44},
#                  "code":"unresolved"}]}
```

A nightly build answers `/health` with its own string, e.g. `"version":"v0.10.1-1266-gdada45c11"`;
that build advertised these 71 capabilities, in this order (a v0.10.1 service advertises 63: all but the eight named below):

```
type_facts convert verification query oslc_query enum_values evaluate_subject
symbol_attributes unset_value feature_values apply_edits authoring inline_language
strict_conformance document_query render_document parse_sources complex_values
structured_values measurement_refs function_values set_values tensor_values
verification_verdicts infinity_value diagnostic_codes schedule case_evaluations
schedule_explore final_time engines metaobject_values undetermined_value edit_documents
performer render_document_html connection_authoring satisfy_authoring
requirement_constraint_authoring member_modifiers transition_authoring
verification_questions verification_arguments verification_objective_authoring runs
self_check record_run metadata_authoring metadata_prefix_authoring sequence_authoring
implicit_parameters constraint_body_authoring state_action_authoring import_authoring
documentation_authoring comment_authoring action_body_statement_authoring migrate
big_int_values rational_values state_trace render_view export_graphs import_data
compare_results check convert_documents convert_compact parse_sources_affected
render_document_file_name order_dependence
```

Of these, `runs`, `self_check`, `record_run`, `import_data`, `compare_results`, `check`,
`render_document_file_name` and `order_dependence` are nightly; a v0.10.1 service does not
list them.

Unary Connect paths are `/sysml.SysMLService/<Method>`; `Content-Type: application/json`
selects JSON, `application/proto` protobuf. The 31 RPCs are `GetServerInfo`, `ParseFile`,
`ParseSources`, `GetSymbol`, `GetDiagnostics`, `Evaluate`, `Instantiate`, `ExecuteAction`,
`ExecuteState`, `Convert`, `Migrate`, `ApplyEdits`, `VerifyConstraint`, `VerifyRequirement`,
`VerifySatisfaction`, `ValidateInstance`, `EvaluateCalc`, `RunAnalysis`, `RunSweep`,
`ListEngines`, `Query`, `RunDocumentQuery`, `RenderDocument`, `RenderView`, `ExportGraphs`
and, nightly, `CheckBehavior`, `RunRuns`, `SelfCheck`, `RecordRun`, `ImportData`,
`CompareResults`. Request/response field names come from the proto (`model_hash` is
`modelHash` in JSON); `grpcurl -plaintext 127.0.0.1:50051 describe sysml.SysMLService`
lists them via reflection.

Most calls after `ParseFile` take the returned `modelHash`, e.g.
`{"modelHash":"...","expression":"P::a.x"}` for `Evaluate` (optional `contextSymbolId`,
`subjectSymbolId` scope the evaluation).

## The nightly surface, by request

| RPC / field | Capability | What it does |
|---|---|---|
| `CheckBehavior {actionSymbolId \| stateMachineSymbolId, performerSymbolId, inputs, checkProperty, checkDiverge, checkInput, checkAssume, checkWitness, checkDepth, checkStates, checkUnroll, checkTimeout, engine}` | `check` | Searches every schedule as `sysml -check-property` does; answers `verdict` (`holds`/`fails`/`undecided`), `lines`, `search {states, moves, maxDepth, status}`, `violations`, `divergences`, `finals`, `standing` |
| `RunRuns {actionSymbolId \| analysisSymbolId, runs, seed, draws, clockStep, observe, inputs, subject…}` | `runs` | Repeated runs / Monte Carlo samples with each observable's distribution; unseeded random runs are refused: `the runs draw at random; set seed, or fix the draws as min, max or average` |
| `SelfCheck {selfCheckPackage}` | `self_check` | Checks the model against the `SysMLValidation` rule constraints; answers `status`, `findings`, counts and the `summary` line |
| `RecordRun {analysisSymbolId, subjectSymbolId, recordInto, ranges, runs, seed, acceptDocuments}` | `record_run` | Records a case's run/sweep/sample into the model; answers the generated `source` and a new `modelHash` |
| `ImportData {imports:[{name, content, importFormat, importMap}], importAs, importDryRun, acceptDocuments}` | `import_data` | Sets the feature values a CSV/TSV/JSON/JSON Lines file assigns; answers `files`, edited `content`/`documents` and the new `modelHash` |
| `CompareResults {results, actions, runs, seed, draws, clockStep, observe, engine}` | `compare_results` | Runs the configurations a SysML v1 tool's results sidecar names and tables its distributions beside ours |
| `GetDiagnostics.disableLint` / `enableLint` | — | Lint selection; names are `undeclared-signal`, `port-type-mismatch`, `deferred-keeper-unmarked`, `rounded-real-literal` (an unknown name is `invalid_argument`) |
| `ExecuteAction` / `ExecuteState` `advance`, `seed`, `draws` (`min`/`max`/`average`), `clockStep` | — | The CLI's `-advance`, `-seed`, `-draws`, `-clock-step` |
| `RunAnalysisRequest.toolDryRun` → `RunAnalysisResponse.toolDryRun` | — | Previews the first external tool call (`action`, `tool`, `executable`, `args`, `env`, `cwd`, `stdin`, `inputs`, `outputs`, `lines`) instead of making it |
| `ListEnginesRequest.probe` | `engines` | Starts each external engine to report `ready`/`unavailable`, as `sysml -engines -probe` does |
| `RenderViewRequest.show`, `depth` → `RenderViewResponse.shown`, `notices` | `render_view` | `show` adds optional notation elements (`parameter-symbols`, `port-symbols`, `compartments`, `edge-labels`, `keywords`, `multiplicities`, `typings`, `qualifiers`, `all`); `depth` bounds nesting; `shown` lists what was drawn and `notices` says why a rendering is empty |
| `RenderDocumentResponse.fileName` | `render_document_file_name` | The file a rendered set writes the document to |
| `VerificationVerdict.instanceId` / `instanceTypeId` | — | The object a per-object case verdict ran on (`0` when it ran on no object) |

## Rules every caller must follow

- **Negotiate capabilities.** `GetServerInfo.capabilities` is a list of names such as
  `convert`, `verification`, `oslc_query`, `apply_edits`, `render_document_html`,
  `big_int_values`, `rational_values`, `parse_sources`, `check`, `runs`. Check for the name
  before using an optional method or reading an optional response field; older services
  omit both (a v0.10.1 service answers HTTP 404 `page not found` to `/sysml.SysMLService/CheckBehavior`). The official
  clients raise `MissingCapabilityError` for you.
- **JSON follows proto3 rules.** 64-bit integers (`runs`, `seed`, `instanceId`) are JSON
  *strings*; absent fields mean default values; enums are names. Use protobuf for large
  responses (instance trees, Turtle conversions) — JSON is for debugging and `curl`.
- **Errors** arrive as an HTTP status plus `{"code":"not_found","message":"..."}`
  (Connect error codes: `invalid_argument`, `not_found`, `failed_precondition`,
  `unimplemented`, `resource_exhausted`, `deadline_exceeded`, ...). A model with
  diagnostics is *not* an error — `ParseFile` succeeds and reports them in `diagnostics`;
  a failing check or verdict is an answer with `verdict: "fails"`.
- **Held objects.** Instances created by `Instantiate` live in the service;
  `OPENSYSML_GRPC_MAX_HELD_OBJECTS` caps them and `OPENSYSML_GRPC_INDEX_POOL` sizes the
  parse cache. Close connections (or let private services exit) to release them.
- **Browsers** need the exact page origin in `-cors-allowed-origins` and, for anything
  other than `localhost`, TLS (`-tls-cert`/`-tls-key`). Private services cannot be
  spawned from a browser; run `sysml-grpc` yourself or use the WASM transport
  (`opensysml-wasm`).

## Troubleshooting

- `connection refused`: the service is not listening on that port; run with
  `-report-address` to learn the chosen port, and check nothing else holds `50051`.
- Client says the service is stale (`StaleServiceError`): the binary predates the
  client's pinned version; upgrade the service or set `OPENSYSML_GRPC_BINARY` to a
  matching build (`opensysml-install`).
- HTTP 404 from curl, or `MissingCapabilityError` from a client, on a method in the table
  above: the service is v0.10.1 or older; use a nightly build.
- Verification calls hang or exit with `resource_exhausted`: raise/lower the
  `OPENSYSML_MAX_*` budgets in the *service's* environment, not the client's.
- SMT-backed calls report no solver: `OPENSYSML_SMT` must be set where `sysml-grpc` runs.
- `health_port=8081` warning at startup: the separate health listener is deprecated; pass
  `-health-port 0` and use `/health` on the main port.
