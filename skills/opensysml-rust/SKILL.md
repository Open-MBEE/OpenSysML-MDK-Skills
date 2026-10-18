---
name: opensysml-rust
description: Use the `opensysml` Rust crate (crates.io, blocking API) to load, validate, evaluate, verify, execute, model-check, run Monte Carlo samples, self-check, record runs, import data, compare tool results, render, convert and edit SysML v2 models from Rust — `Connection::private()` for a child `sysml-grpc`, `Connection::external(host, port)` or OPENSYSML_SERVICE for a shared one, binary provisioning variables, capability negotiation and the typed `Value`/error surface. Use when writing Rust tools, tests or build scripts on top of OpenSysML.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML from Rust

```toml
[dependencies]
opensysml = "0.10"               # crates.io release (0.10.1), pinned to the matching sysml-grpc release
# development against a checkout:
# opensysml = { path = "../OpenSysML/client/rust/opensysml" }
# opensysml = { git = "https://github.com/Open-MBEE/OpenSysML.git", branch = "main" }
```

The API is **blocking** (no async runtime required; wrap in `spawn_blocking` from Tokio if
needed) and speaks Connect/protobuf to `sysml-grpc`; JSON is only a debugging encoding.

Verified against `sysml v0.10.1-1266-gdada45c11` (a `develop` build) with the crate at
`client/rust/opensysml` of the same checkout (`cargo test -p opensysml` green with
`OPENSYSML_GRPC_BINARY` pointing at that build). Anything marked *nightly* is a method of the
crate as well as an RPC of the service: `opensysml = "0.10"` from crates.io has no `check_action`
(compile error), and crates.io gets no snapshot — use the `git = "…", branch = "develop"` or `path`
dependency above until the release after 0.10.1. A nightly client against a v0.10.1 service is
refused with `Error::MissingCapability`.

```rust
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let model = opensysml::load("vehicle.sysml")?;          // private service, parse
    if !model.ok() {
        for diagnostic in model.diagnostics() { eprintln!("{diagnostic}"); }
        return Err("The model has errors.".into());
    }
    let result = model.evaluate(
        "mass",
        &opensysml::EvalOptions { subject: Some("Vehicles::myCar".into()), ..Default::default() },
    )?;
    if let opensysml::Value::Real(mass) = result.result { println!("{mass:.1}"); }  // 1300.0
    Ok(())
}
```

`opensysml::loads(source)` parses text. For several models, hold a `Connection`:

```rust
let conn = opensysml::Connection::connect()?;       // $OPENSYSML_SERVICE if set, else private child
let a = conn.load("a.sysml")?;
let b = conn.loads("package B { part def X; }")?;
drop(conn);                                         // stops a private child; external ones keep running
```

## Service lifecycle

- `Connection::private()` starts one `sysml-grpc` child per parent process
  (`-port 0 -exit-with-parent`); every `Connection` in the process shares it and its parse
  cache; the last drop stops it.
- `Connection::external(host, port)` connects to a service someone else runs and never
  stops it. `Connection::connect()` chooses based on `OPENSYSML_SERVICE`.
- Binary for the private child: `OPENSYSML_GRPC_BINARY` → `~/.opensysml/bin/sysml-grpc` →
  download of `OPENSYSML_GRPC_VERSION` (default: the crate's pinned release; `latest`
  allowed) from `OPENSYSML_GITHUB_REPO` (default `Open-MBEE/OpenSysML`) → `PATH`. SHA-256
  of the archive is checked against the release manifest; an unpinned (git/path) build
  refuses to download unless `OPENSYSML_ALLOW_UNPINNED_DOWNLOAD=1` (`opensysml-install`).
- Capabilities: the connection reads `GetServerInfo` once (`conn.capabilities()`); options the
  service does not advertise are refused client-side with `Error::MissingCapability` rather
  than failing inside the RPC.

## Typed surface

`Model` methods mirror the service (`opensysml-service`): `ok`, `diagnostics`, `errors`,
`hash`, `root`/`roots`, `get`, `find`, `lookup`, `contains`, `evaluate(expr, &EvalOptions)`,
`instantiate`, `verify_constraint`/`verify_requirement`/`verify_satisfaction`/`satisfied`/
`validate_instance` (`&VerifyOptions`/`&SatisfyOptions`; verdicts carry `holds` and a
standing), `calc(&CalcOptions)`, `run_analysis(&AnalysisOptions)`, `run_sweep(&SweepOptions)`,
`execute_action(id, &inputs, &RunOptions)`, `explore_action`/`explore_analysis`,
`query`/`query_oslc`, `render_document(id, DocumentForm)` → `String`,
`render_view(name)`/`render_view_with_ports(name, ports)`/`render_view_showing(name, ports, &["edge-labels"])`/
`render_view_bounded(name, ports, show, depth)` → `RenderedView` (`shown` lists what was drawn,
`notices` why a rendering is empty), `export_graphs`,
`convert(&ConvertOptions)`/`to_turtle`/`to_api_json`/`to_sysml`/`save`, `edit()` →
`Editor::apply()`. On `Connection`: `parse_file`, `parse_content`, `model_by_hash`,
`diagnostics(hash)` / `diagnostics_with_lints(hash, &disabled, &enabled)`, `apply_edits`,
`list_engines()` / `probe_engines()`, `capabilities`, `server_info`, `private_service_pid`;
migration lives in the `migration` module (`MigrateOptions`). `load_with`/`loads_with` take
`ParseOptions` (strict, conformance, language).

Nightly request fields: `RunOptions { advance: Option<f64>, seed: Option<u64>, draws: Option<String>` (`"min"`,
`"max"`, `"average"`)`, clock_step: f64, .. }` on `execute_action`/`execute_state`;
`AnalysisOptions { tool_dry_run: true, .. }` stops a case at its first external tool call;
`diagnostics_with_lints` selects lints (`undeclared-signal`, `port-type-mismatch`,
`deferred-keeper-unmarked`, `rounded-real-literal`); `probe_engines()` starts each external
engine once (`EngineInfo.ready`/`unavailable`); `render_view_showing`'s `show` names
(`parameter-symbols`, `port-symbols`, `compartments`, `edge-labels`, `keywords`,
`multiplicities`, `typings`, `qualifiers`, `all`) and `render_view_bounded`'s `depth`; a
`VerificationVerdict`'s `instance_id: i64` / `instance_type_id` name the object a per-object
case verdict ran on. The crate does not surface `RenderDocumentResponse.file_name`.

## Checking, runs, recording, import and comparison (nightly)

| Need | Call |
|---|---|
| Model checking (`CAPABILITY_CHECK`) | `model.check_action(id, &inputs, &CheckOptions { properties, diverge, free_inputs, assume, witness, depth, states, unroll, timeout, engine, performer, .. })`, `model.check_state_machine(id, &options)` → `CheckResult` (`verdict` `"holds"`/`"fails"`/`"undecided"`, `lines`, `search`, `violations`, `divergences`, `finals`, `witness`, `standing`) |
| Repeated runs / Monte Carlo (`CAPABILITY_RUNS`) | `model.run_runs(&RunsOptions { action: Some(id)` or `analysis: Some(id), runs, seed, draws, clock_step, observe, inputs, performer, subject, arguments, named_arguments, engine })` → `RunsResult` (`rows`, `observables`, `distributions`, `lines`, `outputs`, `verdicts`, `unconcluded`, `instances`, `standing`, `seed`); unseeded random runs are refused `invalid_argument` |
| Self-check (`CAPABILITY_SELF_CHECK`) | `model.self_check(&[])` or `self_check(&["SysMLValidation".into()])` → `SelfCheckResult` (`status`, `findings`, `elements`, `checks`, `violations`, `unevaluated`, `evaluation_errors`, `applications`, `summary`) |
| Record a run (`CAPABILITY_RECORD_RUN`) | `model.record_run(case_id, &RecordOptions { subject, arguments, named_arguments, into, ranges, runs, seed, engine })` → `Recording` (`run`/`sweep`/`sample`, `package`, `definition`, `records`, `source`, `content`, `documents`, `skipped`, `reasons`, `model_hash`) |
| Data import (`CAPABILITY_IMPORT_DATA`) | `model.import_data(&[DataImport { name, content, format: None, map: None }], &DataImportOptions { dry_run, accept_documents })` → `ImportResult` (`files`, `content`, `documents`, `model_hash`) |
| Compare tool results (`CAPABILITY_COMPARE_RESULTS`) | `model.compare_results(results_json, &CompareOptions { actions, runs, seed, draws, clock_step, observe: vec![(stored, feature)], engine })` → `Comparison` (`source`, `configurations`, `standing`) |

Every option struct implements `Default`, so `..Default::default()` fills the rest. The
capability constants are `opensysml::CAPABILITY_CHECK`, `CAPABILITY_RUNS`,
`CAPABILITY_SELF_CHECK`, `CAPABILITY_RECORD_RUN`, `CAPABILITY_IMPORT_DATA`,
`CAPABILITY_COMPARE_RESULTS`, `CAPABILITY_RENDER_DOCUMENT_FILE_NAME` (`opensysml-service`
lists what a v0.10.1 service and a nightly one advertise).

`Value` is an enum — `Real(f64)`, `Integer(i64)`, `BigInteger`, `Rational`, `Complex`,
`Boolean`, `Text`, `EnumLiteral`, `Quantity`, `VectorQuantity`, `TensorQuantity`,
`MeasurementRef`, `Array`, `Vector`, `Sequence`, `Set`, `InstanceRef`, `Metaobject`,
`Function`, `Infinity`, `Null`, `Unset`, `Undetermined` — `match` on it;
`Unset`/`Undetermined` are answers, not `Err`. `opensysml::Error` is one enum:
`Transport`, `Service(Status)` (canonical code), `ServiceStart`, `BinaryNotFound`,
`UnsupportedPlatform`, `BinaryDownload`, `ChecksumMismatch`, `UnpinnedRelease`,
`MissingCapability`, `Decode`, `Model`, `ModelErrors`, `InvalidRequest`, `SymbolNotFound`,
`UnsupportedValue`, `WrongKind`, `Execution`, `AnalysisRun`, `Conversion`, `Migration`,
`Unwritable`, `Edit`, `Query`, `Io`. A false verdict, a model with diagnostics or a failed
run is `Ok` with that result.

## Patterns

```rust
#[test]
fn requirements_hold() {
    let model = opensysml::load("model/vehicle.sysml").unwrap();
    assert!(model.ok(), "{:?}", model.diagnostics());
    assert!(model.satisfied(&Default::default()).unwrap());
}
```

Set `OPENSYSML_GRPC_BINARY` in CI to skip downloads; put budgets/solver variables
(`OPENSYSML_MAX_*`, `OPENSYSML_SMT`) in the environment of the process that spawns the
child or of the shared service (`opensysml-troubleshooting`). `client/rust/README.md` has
the conformance runner and release procedure; `cargo doc --open -p opensysml` for exact
signatures.
