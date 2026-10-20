---
name: opensysml-node
description: Use the `@openmbee/opensysml` TypeScript/JavaScript client in Node and browsers — load and validate SysML v2 models, read discriminated-union values, evaluate, instantiate, verify, execute, model-check, run Monte Carlo samples, self-check, record runs, import data, compare tool results, render, convert, migrate and edit, choose between a private `sysml-grpc` child, a shared service (OPENSYSML_SERVICE / address), or the in-process WASM module, negotiate capabilities and handle typed errors. Use when writing Node scripts, tests, web apps or VS Code/Electron tooling against OpenSysML.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML from TypeScript / JavaScript

```bash
npm install @openmbee/opensysml                   # Node 20+; ESM, typed
npm install @openmbee/opensysml-wasm@<same version>   # optional: in-process WASM (opensysml-wasm)
```

```ts
import { load } from "@openmbee/opensysml";

const model = await load("vehicle.sysml");          // starts a private sysml-grpc if needed
try {
  if (model.hasErrors) throw new Error(JSON.stringify(model.diagnostics));
  const mass = await model.eval("mass", { subject: "Vehicles::myCar" });
  if (mass.kind !== "real") throw new Error(`expected real, got ${mass.kind}`);
  console.log(mass.value.toFixed(1));               // 1300.0
} finally {
  await model.close();                              // or: await using model = await load(...)
}
```

`loads(source, options)` parses text; `connect(options)` returns a `Connection` whose
`load`/`loads`/`parseSources` share one service and one parse cache. Parse options:
`{ strictConformance: true }` (its alias `strict` is deprecated; passing both with different
values is refused) and `language: "kerml"`.

Verified against `sysml v0.10.1-1266-gdada45c11` (a `develop` build) with the client at
`client/node` of the same checkout (`@openmbee/opensysml@0.10.1`; `npm run build && npm test`
green). Anything marked *nightly* is a method of the client as well as an RPC of the service:
`@openmbee/opensysml@0.10.1` has no `checkAction`. Install `npm install @openmbee/opensysml@nightly`
(the `nightly` dist-tag, `<next>-nightly.<yyyymmdd>.g<commit>`; `latest` stays the release) — its
platform packages carry the same night's `sysml-grpc` — or depend on `client/node` of a `develop`
checkout after `npm run build`. A nightly client against a v0.10.1 service throws
`MissingCapabilityError`.

## Three ways to reach a service

| Mode | How | Lifecycle |
|---|---|---|
| Private child (default) | `connect()` with no address and `OPENSYSML_SERVICE` unset | One `sysml-grpc` per thread; first `connect()` starts it, last `close()` stops it; dies with the parent (`-exit-with-parent`) |
| Shared service | `connect({ address: "host:50051" })` or `OPENSYSML_SERVICE=host:port` | Never owned; `close()` only disconnects |
| In-process WASM | `connectWasm()` (Node) / `connectWasm` from `@openmbee/opensysml/browser` | No process, no network; parse/eval/instantiate/execute only (`opensysml-wasm`) |

The private child's binary is resolved via `OPENSYSML_GRPC_BINARY`, `~/.opensysml/bin/`, a
SHA-256-verified download of the client's pinned release, then `PATH`
(`opensysml-install`). `connect({ version: "v0.10.1" })` requires a service
version; `connect({ requireCapabilities: [CAPABILITY_CONVERT, CAPABILITY_DOCUMENT_QUERY] })`
refuses at connect time rather than at the first gated call. Every capability has a
constant; the nightly ones are `CAPABILITY_CHECK`, `CAPABILITY_RUNS`, `CAPABILITY_SELF_CHECK`,
`CAPABILITY_RECORD_RUN`, `CAPABILITY_IMPORT_DATA`, `CAPABILITY_COMPARE_RESULTS`,
`CAPABILITY_RENDER_DOCUMENT_FILE_NAME` (`opensysml-service` lists what each service advertises).

Browsers cannot spawn a child: run `sysml-grpc -cors-allowed-origins <origin>` (and TLS off
localhost) and `connect({ address })` from `@openmbee/opensysml/browser`, or use WASM. The
wire encoding is protobuf by default; JSON is for debugging (`opensysml-service`).

## Values are discriminated unions

`eval`, feature reads and results return `{ kind, value }` objects, never bare JS values —
`kind` is one of `"int"`, `"real"`, `"boolean"`, `"string"`, `"enum"`, `"quantity"`,
`"array"`, `"sequence"`, `"set"`, `"vector"`, `"instance"`, `"metaobject"`, `"function"`,
`"complex"`, `"infinity"`, `"absent"`, `"null"`, `"unset"`, `"undetermined"`. Narrow on
`kind` before using `value`; `int` carries a `bigint` when the service advertises
`big_int_values`. `"unset"`/`"undetermined"` are legitimate answers (see
`opensysml-sysml-authoring`), not errors.

## Operations on `Model`

- Validate: `model.hasErrors`, `model.diagnostics` (`severity`, `message`, `span`, `code`);
  `model.refreshDiagnostics({ disableLint: ["rounded-real-literal"], enableLint: [...] })`
  re-asks the service with lint selection (*nightly*; lint names are `undeclared-signal`,
  `port-type-mismatch`, `deferred-keeper-unmarked`, `rounded-real-literal`).
- Elements: `model.get("Pkg::x")`, `model.find("x")`, `model.root`.
- `instantiate(id)`, `eval(expr, { subject, contextSymbolId })`.
- Verification: `verifyConstraint(id, opts)`, `verifyRequirement(id, opts)`,
  `verifySatisfaction(id?)`, `validateInstance(id)` → verdicts with `holds`, `kind`,
  `engine`, `explain`; a case's `VerificationVerdict` carries `instanceId` (`bigint`) and
  `instanceTypeId` for the object it ran on, `0n` and `""` when none (*nightly*).
- Execution: `executeAction(id, { inputs, schedule, performer, advance, seed, draws, clockStep })`,
  `executeState(id, { events, trace, advance, seed, draws, clockStep })`, `explore*` variants
  for many schedules. *Nightly:* `advance` (seconds), `seed` (`bigint`), `draws`
  (`"min" | "max" | "average"`), `clockStep` are the CLI's `-advance`, `-seed`, `-draws`,
  `-clock-step`.
- Analysis: `calc(id, args)`, `runAnalysis(id, { subject, arguments, namedArguments, schedule, engine, toolDryRun })`,
  `runSweep(id, ranges, opts)`, `connection.listEngines({ probe })` → `EngineInfo[]`.
  *Nightly:* `toolDryRun: true` stops at the first external tool call and fills the result's
  `toolDryRun` (`action`, `tool`, `executable`, `args`, `env`, `cwd`, `stdin`, `inputs`,
  `outputs`, `lines`); `probe: true` starts each external engine once (`ready`, `unavailable`).
- Model checking (*nightly*, `check`): `checkAction(id, { inputs, performer, properties, diverge, freeInputs, assume, witness, depth, states, unroll, timeout, engine })`,
  `checkStateMachine(id, options)` → `CheckResult` (`verdict` `"holds" | "fails" | "undecided"`,
  `lines`, `search`, `violations`, `divergences`, `finals`, `witness`, `standing`).
- Repeated runs (*nightly*, `runs`): `runRuns({ action | analysis, runs, seed, draws, clockStep, observe, inputs, performer, subject, arguments, namedArguments, engine })`
  → `RunsResult` (`rows`, `observables`, `distributions`, `lines`, `outputs`, `verdicts`,
  `seed`); `runs`/`seed` accept `bigint | number`; unseeded random runs are refused.
- Self-check (*nightly*, `self_check`): `selfCheck(packages = [])` → `SelfCheckResult`
  (`status`, `findings`, `elements`, `checks`, `violations`, `unevaluated`, `applications`, `summary`).
- Record a run (*nightly*, `record_run`): `recordRun(caseId, { subject, arguments, namedArguments, into, ranges, runs, seed, engine })`
  → `Recording` (`run | sweep | sample`, `package`, `definition`, `records`, `source`, `modelHash`).
- Data import (*nightly*, `import_data`): `importData([{ name, content, format?, map? }], { importAs, dryRun, acceptDocuments })`
  → `ImportResult` (`files`, `content`, `documents`, `modelHash`).
- Compare tool results (*nightly*, `compare_results`): `compareResults(resultsJson, { actions, runs, seed, draws, clockStep, observe, engine })`
  → `Comparison` (`source`, `configurations`, `standing`).
- Queries/documents: `query({ where, select, scope })`, `runDocumentQuery(id, bindings)`,
  `renderDocument(id, { form: "markdown" | "html" })` → `string` (the file name of
  `RenderDocumentResponse` is not surfaced by this client),
  `renderView(name, { ports, show, depth })` → `RenderedView` (`nodes`, `edges`, `rows`,
  `notices`, `shown`), `exportGraphs(subject)`. *Nightly:* `show` adds optional notation
  elements (`"parameter-symbols"`, `"port-symbols"`, `"compartments"`, `"edge-labels"`,
  `"keywords"`, `"multiplicities"`, `"typings"`, `"qualifiers"`, `"all"`), `shown` lists what
  was drawn, `depth` bounds nesting and `notices` says why a rendering is empty.
- Conversion/migration: `convert("ttl" | "api-json" | "sysml")`, `save(path)`,
  `connection.migrate("sysml", { path | content, report: true })`.
- Authoring: `model.edit()` collects `setValue`, `rename`, `move`, `delete`, `add*`
  operations and `apply()`s them in one `ApplyEdits`, rewriting only the edited spans.

## Errors are typed

All extend `OpenSysMLError`: connection/service (`ServiceUnavailableError`,
`ServiceTimeoutError`, `StaleServiceError`, `ServiceError`, `MissingCapabilityError`,
`UnsupportedOperationError`), model (`ModelFileNotFoundError`, `ModelNotFoundError`,
`SymbolNotFoundError`), values (`TypeMismatchError`, `UnsupportedValueError`,
`FeatureValueError`), execution/analysis (`ExecutionError`, `AnalysisRunError`,
`QueryError`, `DocumentQueryError`, `ConversionError`, `MigrationError`) and editing
(`EditError` with `InvalidEditError`, `OverlappingEditsError`, `MemberNameTakenError`,
`RenameReferencedError`, `DeleteReferencedError`, `MoveReferencedError`, `OwnerNotFoundError`,
…). Diagnostics in a model are data (`model.diagnostics`), not thrown.

## Patterns

```ts
// test suite: one service for all specs
import { connect } from "@openmbee/opensysml";
const connection = await connect();
afterAll(() => connection.close());
const model = await connection.load("model/vehicle.sysml");
expect((await model.verifySatisfaction()).every(v => v.holds)).toBe(true);
```

Budgets and solver variables (`OPENSYSML_MAX_*`, `OPENSYSML_SMT`) belong in the environment
of the Node process that spawns the child, or of the shared service
(`opensysml-troubleshooting`). Pin `@openmbee/opensysml` to a release; its version is the
service version it provisions.
