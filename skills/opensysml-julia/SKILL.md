---
name: opensysml-julia
description: Use the Julia package `OpenSysML` (client/julia/OpenSysML in the OpenSysML repo, Connect-JSON over HTTP.jl) to parse, validate, evaluate, verify, execute, analyse, model-check, run Monte Carlo samples, self-check, record runs, import data, compare tool results, render, convert and edit SysML v2 models from Julia — `connect()`, `external(address)`, `private()`, binary provisioning variables, capability negotiation and typed errors. Use when scripting OpenSysML from Julia, Pluto or DrWatson projects.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML from Julia

The package lives in the OpenSysML repository (not yet in the General registry):

```julia
using Pkg
Pkg.develop(path = "client/julia/OpenSysML")     # from a checkout; or Pkg.add(url=..., subdir="client/julia/OpenSysML")
using OpenSysML
```

```julia
conn = connect()                                  # $OPENSYSML_SERVICE if set, else a private sysml-grpc child
try
    model = parse_file(conn, "vehicle.sysml")
    if !isok(model)
        foreach(println, diagnostics(model))
        error("The model has errors.")
    end
    println(evaluate(model, "mass"; subject = "Vehicles::myCar"))   # 1300.0
finally
    close(conn)                                   # stops a private child; external ones keep running
end
```

`parse_source(conn, text)` parses a string; `parse_sources(conn, Dict(name => text))` parses
several documents into one model.

Verified against `sysml v0.10.1-1266-gdada45c11` (a `develop` build) with the package at
`client/julia/OpenSysML` of the same checkout. Anything marked *nightly* needs a service newer
than v0.10.1 (nightly builds and the release after 0.10.1) and throws `MissingCapabilityError`
against a v0.10.1 service.

## Connections

- `connect(; timeout=30, version=nothing, require_capabilities=[])` — `OPENSYSML_SERVICE`
  when set, otherwise a private child. `version` refuses a service of another version;
  `require_capabilities` refuses one missing a capability at connect time.
- `external(address; ...)` — a service owned by another process (`"localhost:50051"`).
- `private(; binary=nothing, ...)` — start a child directly. Julia has no fork model, so each
  `private()` connection owns its own child; `close(conn)` stops it.
- Binary resolution: `OPENSYSML_BINARY`, `OPENSYSML_GRPC_BINARY`, `~/.opensysml/bin/sysml-grpc`,
  `PATH`; no implicit download. `OPENSYSML_GRPC_VERSION=latest` or a release tag enables a
  download from `OPENSYSML_GITHUB_REPO` (default `Open-MBEE/OpenSysML`), with
  `OPENSYSML_ALLOW_UNPINNED_DOWNLOAD` governing unpinned trust (`opensysml-install`).
- `server_info(conn)` / `has_capability(conn, name)` report what the service advertises;
  `resolve_binary()`, `ensure_binary()`, `download_binary()` manage the child's binary.

Transport is Connect **JSON** over `HTTP.jl` (not protobuf), so it is the easiest client to
compare against `curl` (`opensysml-service`); 64-bit integers arrive as strings and are
converted for you.

## Models, values and RPCs

Functions take the model (or connection) first, Julia-style keywords for options:
`isok`, `diagnostics`, `raise_for_errors`, `root`/`roots`, `get_symbol(model, "Pkg::x")`,
`find`, `symbol`, `children`, `attributes`/`features`/`parts`, `facts`/`attribute_facts`
(type facts: multiplicity, specializations), `evaluate(model, expr; subject)`,
`instantiate(model, id)`, `feature_value`/`get_feature`/`get_attr` on instances,
`verify_constraint(model, id; subject, engine)`, `verify_requirement`,
`verify_satisfaction(model)`, `satisfied`, `validate_instance`, `calc(model, id, args)`,
`run_analysis(model, id; ...)`, `run_sweep(model, id, ranges)`,
`execute_action(model, id; inputs, schedule)`, `execute_state(model, id; events)`,
`explore_analysis`, `query(model; ...)`, `documents(model)`, `export(...)` for graphs,
`convert_model(model, "ttl")`/`to_turtle`/`to_api_json`/`to_sysml`/`save(model, path)`,
`convert_file`/`convert_source`, `list_engines(conn)`, `server_info(conn)`,
`has_capability(conn, name)`. Verdicts answer `holds`, `violated`, `undecided`, `valid`;
runs expose `failures`. A case's `VerificationVerdict` carries `instance_id`/`instance_type_id`
for the object it ran on (`0`/`""` when none; *nightly*).

Rendering: `render_document(model, id; form="markdown")` → `String`;
`render_view(model, name; ports="minimal", show=String[])` → `RenderedView` whose `shown`
lists what was drawn and `notices` says why a rendering is empty. *Nightly:* `show` adds
optional notation elements (`"parameter-symbols"`, `"port-symbols"`, `"compartments"`,
`"edge-labels"`, `"keywords"`, `"multiplicities"`, `"typings"`, `"qualifiers"`, `"all"`).
The Julia client has no `depth` keyword, no lint selection on `diagnostics`, no
`advance`/`seed`/`draws`/`clock_step` on `execute_action`/`execute_state`, no
`tool_dry_run` on `run_analysis` and no `probe` on `list_engines`; use `curl` against the
service for those request fields (`opensysml-service`).

## Checking, runs, recording, import and comparison (nightly)

| Need | Call |
|---|---|
| Model checking (`CAPABILITY_CHECK`) | `check_action(model, id; inputs=Dict(), performer, properties=(), diverge=(), free_inputs=(), assume=(), witness=false, depth=0, states=0, unroll=0, timeout=0.0, engine)`, `check_state_machine(model, id; kwargs...)` → `CheckResult` (`verdict` `"holds"`/`"fails"`/`"undecided"`, `lines`, `search`, `violations`, `divergences`, `finals`, `witness`, `standing`, `reason`; `holds(result)`) |
| Repeated runs / Monte Carlo (`CAPABILITY_RUNS`) | `run_runs(model; action=id` or `analysis=id, runs=1, seed=nothing, draws=nothing, clock_step=0.0, observe=(), inputs=Dict(), performer, subject, arguments=Any[], named_arguments=Dict(), engine)` → `RunsResult` (`rows`, `observables`, `distributions`, `outputs`, `verdicts`, `unconcluded`, `seed`, `standing`); unseeded random runs are refused |
| Self-check (`CAPABILITY_SELF_CHECK`) | `self_check(model; packages=())` → `SelfCheckResult` (`status`, `findings`, `elements`, `checks`, `violations`, `unevaluated`, `evaluation_errors`, `applications`, `summary`) |
| Record a run (`CAPABILITY_RECORD_RUN`) | `record_run(model, case_id; subject, arguments=Any[], named_arguments=Dict(), into=nothing, ranges=nothing, runs=0, seed=nothing, engine)` → `Recording` (`run`/`sweep`/`sample`, `package`, `definition`, `records`, `source`, `content`, `documents`, `model_hash`) |
| Data import (`CAPABILITY_IMPORT_DATA`) | `import_data(model, imports; dry_run=false, accept_documents=false)` → `ImportResult` (`files`, `documents`, `content`, `model_hash`, `changed`) |
| Compare tool results (`CAPABILITY_COMPARE_RESULTS`) | `compare_results(model, results_json; actions=(), runs=0, seed=nothing, draws="", clock_step=nothing, observe=(), engine)` → `Comparison` (`source`, `configurations`, `standing`) |

Every capability name has an exported `CAPABILITY_*` constant (also
`CAPABILITY_RENDER_DOCUMENT_FILE_NAME`, whose `file_name` this client does not surface);
`opensysml-service` lists what a v0.10.1 service and a nightly one advertise.

Values map to Julia types: `Float64`, `Int64`/`BigInt`, `Rational`, `Bool`, `String`,
`Vector`, plus exported structs `Quantity` (with `Unit`; `in_unit`, `to_unit`,
`same_value`), `EnumLiteral`, `InstanceRef`, `FunctionRef`, `Metaobject`, `ArrayValue`,
`VectorValue`, `MeasurementRef`, `Infinity`, and the `Unset`/`Undetermined` answers —
`as_quantity`/`as_enum_literal`/`as_object`/`as_str`/`as_typed` narrow before arithmetic.

## Authoring

`edit(model)` opens an editor; operations are collected and sent in one `ApplyEdits`, which rewrites only the edited spans;
refusals are typed (`EditError` and subtypes such as `RenameReferencedError`,
`DeleteReferencedError`, `MemberNameTakenError`, `OverlappingEditsError`,
`OwnerNotFoundError`) and name the referrers (`Referrer`). `generate_source`/`generate_main`
produce typed Julia modules from a model (see the README's "Typed generation").

## Errors

Julia exceptions subtype `OpenSysMLError`: `ConnectError`, `TransportError`,
`ServiceError`/`ServiceCallError` (canonical code), `ServiceUnavailableError`,
`ServiceTimeoutError`, `StaleServiceError`, `MissingCapabilityError`,
`UnsupportedOperationError`, `ChecksumMismatchError`, `UnpinnedReleaseError`,
`ModelError`, `ModelNotFoundError`, `ModelFileNotFoundError`, `SymbolNotFoundError`,
`DiagnosticError` (from `raise_for_errors`), `ExecutionError`, `WrongKindError`,
`ConversionError`, `MigrationError`, `QueryError`, `DocumentQueryError`,
`TypeMismatchError`, `UnsupportedValueError`, `IncommensurableUnitsError`, `EditError`.
A model with diagnostics or a false verdict is a value, not an exception — test
`isok(model)` and `holds(verdict)`.

Not provided: in-process execution, protobuf transport, typed stub generation (see the
package README's "Not provided"). Budgets/solver variables (`OPENSYSML_MAX_*`, `OPENSYSML_SMT`)
go in the environment of the Julia process (private child) or of the shared service
(`opensysml-troubleshooting`). Run `Pkg.test("OpenSysML")` with `OPENSYSML_SERVICE` or a
local `bin/sysml-grpc` to confirm the setup.
