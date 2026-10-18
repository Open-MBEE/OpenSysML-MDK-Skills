---
name: opensysml-go
description: Use the Go API `github.com/Open-MBEE/OpenSysML/client/opensysml` — embed the OpenSysML engine in-process with `opensysml.New()`, or reach a `sysml-grpc` service with `opensysml.Dial(address)` through the identical `Client` interface; parse files and sources, read diagnostics, evaluate typed values, instantiate, verify, execute, model-check, run analyses and Monte Carlo samples, self-check, record runs, import data, compare tool results, query, render, convert, migrate and apply edits, and use `OpenSession` for stateful stepping. Use when writing Go programs, tests or tools (CI gates, build plugins, services) on top of OpenSysML.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML from Go

```bash
go get github.com/Open-MBEE/OpenSysML@latest        # Go 1.23+; module root, package client/opensysml
```

The Go client is the only one that can run the engine **in-process** — no `sysml-grpc`,
no binary download. `New()` and `Dial(address)` return the same `Client` interface and are
held to identical behavior by the conformance suite, so code written against one works
against the other.

```go
import (
    "context"
    "fmt"
    "github.com/Open-MBEE/OpenSysML/client/opensysml"
)

func check(ctx context.Context) error {
    client, err := opensysml.New()                 // in-process; or opensysml.Dial("localhost:50051")
    if err != nil { return err }
    defer client.Close()

    model, err := client.ParseFile(ctx, "vehicle.sysml")
    if err != nil { return err }                   // I/O or transport failure
    if errs := model.Errors(); len(errs) != 0 {    // model diagnostics are data, not errors
        return fmt.Errorf("model diagnostics: %v", errs)
    }
    mass, err := client.Evaluate(ctx, model, "mass", opensysml.WithSubject("Vehicles::myCar"))
    if err != nil { return err }
    fmt.Println(mass)                              // typed Value; prints as SysML notation: 1300.0
    return nil
}
```

## Parsing

- `ParseFile(ctx, path, opts...)`, `ParseSource(ctx, content, opts...)`,
  `ParseFiles(ctx, paths...)` (one model, imports resolve across files),
  `ParseDocuments(ctx, docs...)` mixing `opensysml.File(path)` and `opensysml.Source(name, text)`.
- Options: `WithStrictConformance()`, `WithLanguage(opensysml.LanguageKerML)`.
  Formats: `FormatSysML`, `FormatTurtle`, `FormatAPIJSON`.
- `model.OK()`, `model.Errors()`, `model.Diagnostics()` (severity, message, span, code),
  `client.Diagnostics(ctx, model, DisableLint("rounded-real-literal"), EnableLint(...))`
  (lint selection is nightly), `client.LookupSymbol(ctx, model, "Pkg::x")`.
- A syntax error is a diagnostic, not an `error`; a missing file is an `error`.

Verified against `sysml v0.10.1-1266-gdada45c11` (a `develop` build; `go test ./client/opensysml/`
green). Anything marked *nightly* is absent from a v0.10.1 `sysml-grpc` and arrives in nightly
builds and the release after 0.10.1; an in-process `New()` client built from the same tree always
has it, a `Dial`ed one refuses it when the service does not advertise the capability.

## Operations on `Client`

| Need | Method |
|---|---|
| Values | `Evaluate(ctx, model, expr, WithSubject(id), WithContextSymbol(id))`, `EvaluateCalc(ctx, model, id, CalcArguments(...), CalcEngine(name))` |
| Objects | `Instantiate(ctx, model, id)`; refer to held objects with `ObjectByID(n)` / `ObjectByPath(path)`, run behavior on one with `PerformedBy(path)` |
| Verification | `VerifyConstraint`, `VerifyRequirement` (with `Subject(id)`, `Engine(name)`, `Asking(question)`), `VerifySatisfaction`, `ValidateInstance` → verdicts carrying their standing; a `Verification`/`VerificationVerdict` names the object it ran on in `InstanceID`/`InstanceTypeID` (`0`/`""` when none; *nightly*) |
| Execution | `ExecuteAction(ctx, model, id, Arguments(...), Schedule(policy), PerformedBy(path), WithAdvance(seconds), WithSeed(n), WithDraws("min"\|"max"\|"average"), WithClockStep(seconds))`, `ExecuteState(ctx, model, id, ..., WithTrace())` with the same run options, `ExploreAction/ExploreState/ExploreAnalysis` for every outcome under exploring schedules (`WithAdvance`…`WithClockStep` are *nightly*) |
| Model checking (*nightly*, `check`) | `CheckAction(ctx, model, id, CheckInputs(map), CheckPerformer(path), CheckProperties(names...), CheckDiverge(features...), CheckFreeInputs(...), CheckAssume(...), CheckWitnessFiles(), CheckBounds(depth, states, unroll, timeout), CheckEngine(name))`, `CheckStateMachine(ctx, model, id, opts...)` → `*Check` (`Verdict` `holds`/`fails`/`undecided`, `Lines`, `Search`, `Violations`, `Divergences`, `Finals`, `Standing`) |
| Analysis | `RunAnalysis(ctx, model, id, Argument(...), Subject(...), Engine(...), WithToolDryRun())` → `*Analysis` whose `ToolDryRun *ToolDryRun` (`Action`, `Tool`, `Executable`, `Args`, `Env`, `Cwd`, `Stdin`, `InputFile`, `Inputs`, `Outputs`, `Lines`) previews the first external tool call instead of making it (*nightly*); `Calculate(ctx, model, id, CalcArguments(...))`; `ListEngines(ctx, Probe())` → `[]EngineInfo` (`Name`, `Authority`, `Answers`, `Bounds`, `Ready`, `Unavailable`), `Probe()` starting each external engine once (*nightly*) |
| Repeated runs (*nightly*, `runs`) | `RunAction(ctx, model, actionID, count, RunsInputs(map), RunsPerformer(path), RunsSeed(n), RunsDraws(s), RunsClockStep(d), RunsObserve(features...), RunsEngine(name))`, `RunMonteCarlo(ctx, model, caseID, count, RunsSubject(id), RunsArguments(...), RunsArgument(name, v), ...)` → `*Runs` (`Rows`, `Observables`, `Distributions`, `Lines`, `Outputs`, `Verdicts`, `Unconcluded`, `Instances`, `Standing`, `Seed`); unseeded random runs are refused `invalid_argument` |
| Self-check (*nightly*, `self_check`) | `SelfCheck(ctx, model, rulePackages...)` → `*SelfCheck` (`Status`, `Findings`, `Elements`, `Checks`, `Violations`, `Unevaluated`, `Applications`, `Summary`, `Holds()`) |
| Record a run (*nightly*, `record_run`) | `RecordRun(ctx, model, caseID, RecordSubject(id), RecordArguments(...), RecordArgument(name, v), RecordEngine(name), RecordInto(pkg), RecordRange(param, start, end, step), RecordSample(count, seed))` → `*Recording` (`Run`/`Sweep`/`Sample`, `Package`, `Definition`, `Records`, `Source`, `Content`, `Documents`, `ModelHash` of the model holding the records) |
| Data import (*nightly*, `import_data`) | `ImportData(ctx, model, []DataImport{{Name, Content, Format, Map}}, ImportDryRun(), ImportAcceptDocuments())` → `*ImportResult` (`Files` of `ImportedFile`, `Content`, `Documents`, `ModelHash`; `""` on a dry run) |
| Compare tool results (*nightly*, `compare_results`) | `CompareResults(ctx, model, resultsJSON, CompareActions(names...), CompareRuns(n), CompareSeed(n), CompareDraws(s), CompareClockStep(d), CompareObserve(stored, feature), CompareEngine(name))` → `*Comparison` (`Source`, `Configurations`, `Standing`) |
| Query/documents | `Query(ctx, model, ...)`, `QueryOSLC(ctx, model, text)`, `RunDocumentQuery(ctx, model, id, Bind(...))`, `RenderDocument(ctx, model, id)` → the Markdown `string` (the Go client has no form argument and does not surface `RenderDocumentResponse.file_name`), `RenderView(ctx, model, name, WithFullPorts())` → `*RenderedView` (`Nodes`, `Edges`, `Rows`, `Canvas`, `Notes`, `Notices`; the `show`/`depth` request fields and the `shown` answer have no Go counterpart yet), `ExportGraphs(ctx, model, subject)` |
| Conversion | `Convert(ctx, model, opensysml.FormatTurtle)`, `ConvertFile(ctx, path, format, WithFromFormat(...))`, `ConvertSource(...)`, `WithTolerateSyntaxErrors()` |
| Migration | `MigrateFile(ctx, path, format, WithMigrationReport(), WithMigrationResults(), WithLayoutFile(...), WithImageBaseURL(...))`, `MigrateSource` |
| Editing | `ApplyEdits(ctx, model, ops...)`, `ApplyDocumentEdits(...)` — all-or-nothing, refusals name the referrers |
| Service | `ServerInfo(ctx)` (version, capabilities), `Close()` |

Values are a typed sum (`Value` with Real/Integer/Boolean/String/Enum/Quantity/Array/
Set/Instance/Metaobject/Function/Complex/Undetermined/Unset…); construct inputs with
`NewInteger(*big.Int)`, `NewRational(*big.Rat)`; compare with `opensysml.Equal`. Predicates
for document queries: `Equals`, `Greater`, `Less`, `All`, `Any`, `Against`.

## In-process vs `Dial`

- `New(opts...)` embeds `internal/frontend/grpc.Service` directly: no process, no port,
  same budgets via `OPENSYSML_MAX_*`; `WithCacheSize(n)` sizes the parse cache. Prefer it
  for CLIs, tests and build tooling.
- `Dial(address, opts...)` talks Connect/protobuf to a running `sysml-grpc`
  (`WithJSONBody()` for JSON, `WithHTTPClient(c)` for TLS/proxies). The service's
  capability list gates optional features; the client omits a field or refuses an
  option the service does not advertise, so check `ServerInfo` when behavior differs.
- `OpenSession(client, model)` is **in-process only**: a stateful session that holds
  an object, performs actions turn by turn, sets features, changes schedule, dispatches
  events and reports transitions — what the REPL's `%step`/`%send` do. A `Dial`ed client
  cannot open one.

Every call takes a `context.Context`; a cancelled context refuses the call, an expired
deadline is `DeadlineExceeded`. `Client` is safe for concurrent use; after `Close()` every
operation is refused.

## Errors

Transport and refusal errors carry a canonical code (`invalid_argument`, `not_found`,
`failed_precondition`, `unimplemented`, `unavailable`, `deadline_exceeded`) you can match
with `errors.As`; a verdict of false, a failed run, or a model with diagnostics is an
*answer*, returned without error. Read the result's standing/outcome instead.

Reference: `client/opensysml/README.md` (stability policy: `Client`, `New`, `Dial` and the
option functions are stable) and `go doc github.com/Open-MBEE/OpenSysML/client/opensysml`.
