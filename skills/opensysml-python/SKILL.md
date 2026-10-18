---
name: opensysml-python
description: Use the `opensysml` Python package (PyPI) to load, validate, evaluate, instantiate, verify, execute, analyse, model-check, run Monte Carlo samples, self-check, record runs, import data, compare tool results, render, convert and edit SysML v2 models from Python — including how it provisions and starts a private `sysml-grpc`, connects to a shared service, checks capabilities, and raises typed errors. Use when writing Python scripts, tests, pipelines or notebooks against OpenSysML, or when the package reports ConnectionError, ChecksumMismatchError, StaleServiceError or MissingCapabilityError.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML from Python

`pip install opensysml` (Python 3.9+). The package is a client for the `sysml-grpc` service
(`opensysml-service`): on first use it starts a **private** service on a free port, finding
the binary via `OPENSYSML_GRPC_BINARY`, then `~/.opensysml/bin/`, then a SHA-256-verified
download of the release pinned in the package, then `PATH`. Set `OPENSYSML_GRPC_BINARY` in
CI/offline environments (`opensysml-install`). If `OPENSYSML_SERVICE=host:port` is set, or
`host`/`port` are given, the package connects to that shared service instead of spawning one.

```python
import opensysml

model = opensysml.load("vehicle.sysml")          # private service, parse, return Model
if not model.ok:
    for d in model.diagnostics:                   # Diagnostic(severity, message, span, code)
        print(d)
    raise SystemExit(2)
print(model.eval("mass", subject="Vehicles::myCar"))   # 1300.0 (plain Python value)
```

- `opensysml.load(path, host="localhost", port=None, strict=False, strict_conformance=False)`
- `opensysml.loads(content, ..., language=None)` for source text (`language="kerml"` for KerML)
- `opensysml.connect(host="localhost", port=None, auto_start=True, version=None, require_capabilities=None)`
  returns a `Connection`; with no address and `OPENSYSML_SERVICE` unset it starts a private
  service; `opensysml.connect("localhost:50051")` or `connect("localhost", 50051)` connects to
  an existing one that the client does not manage.
  `conn.load(path)`, `conn.load_from_content(text)`, `conn.parse_sources({...})` return
  `Model`s that share the service; `conn.close()` (or a `with` block) stops a private service.
- `model.raise_for_errors()` raises on error diagnostics; `model.errors` filters them.
  `model.diagnostics` re-reads them; lint selection (`disable_lint`/`enable_lint` on
  `GetDiagnostics`) is not exposed by this client — call the RPC over Connect JSON for that
  (`opensysml-service`).

Verified against `sysml v0.10.1-1266-gdada45c11` (a `develop` build) with the client installed
from `client/python` of the same checkout; package version `0.10.1`. Rows marked *nightly*
are methods of the *client* as well as RPCs of the service: the `opensysml==0.10.1` package has
no `check_action` (`AttributeError`), whatever service it talks to. Install the night's client by
exact version (`pip install opensysml==<next>.dev<yyyymmdd>`, listed in PyPI's release history;
`pip install --pre opensysml` takes the newest) — it provisions the same night's `sysml-grpc` —
or `pip install -e client/python` from a `develop` checkout. A nightly client against a v0.10.1
service raises `MissingCapabilityError`.

## `Model` operations

| Need | Call |
|---|---|
| Value of an expression | `model.eval(expr, context_symbol_id=None, subject=None)` |
| Element lookup | `model.get("Pkg::part")`, `model.find("name")`, `model.root`, `model.roots` |
| Object | `model.instantiate("Pkg::usage")` → object handle for `subject=` arguments |
| Constraint / requirement / satisfy | `model.verify_constraint(id, subject=None, engine=None)` and `model.verify_requirement(...)` → `Verdict` (`.holds`, `.kind`, `.engine`, `.explain`, `.diagnostics`, `.error`); `model.verify_satisfaction(id=None)` → list of `Verdict`s, `model.satisfied()` → bool |
| Instance vs type | `model.validate_instance(id)` |
| Calculation / analysis / sweep | `model.calc(id, arguments=[...])`, `model.run_analysis(id, subject=, arguments=, named_arguments=, schedule=, engine=, tool_dry_run=False)`, `model.run_sweep(id, ranges={"n": "1..8:2"}, samples=0, seed=0)`; *nightly:* `tool_dry_run=True` stops at the first external tool call and fills `result.tool_dry_run` (`ToolDryRun`: `.action`, `.tool`, `.executable`, `.args`, `.env`, `.cwd`, `.stdin`, `.inputs`, `.outputs`, `.lines`) |
| Behavior | `model.execute_action(id, inputs=, schedule=, performer=, advance=None, seed=None, draws=None, clock_step=0.0)`, `model.execute_state(id, events=[...], trace=False, advance=, seed=, draws=, clock_step=)`; `explore_action`/`explore_state`/`explore_analysis` run many schedules. *Nightly:* `advance`/`seed`/`draws` (`"min"`, `"max"`, `"average"`)/`clock_step` are the CLI's `-advance`, `-seed`, `-draws`, `-clock-step` |
| Model checking (*nightly*, `check`) | `model.check_action(id, inputs=, performer=, properties=[...], diverge=[...], free_inputs=, assume=, witness=False, depth=, states=, unroll=, timeout=, engine=)`, `model.check_state_machine(id, performer=, properties=, ...)` → `CheckResult` (`.verdict` `holds`/`fails`/`undecided`, `.lines`, `.search`, `.violations`, `.divergences`, `.finals`, `.witness`, `.standing`, `.reason`) |
| Repeated runs / Monte Carlo (*nightly*, `runs`) | `model.run_runs(action=id` or `analysis=id, runs=1, seed=None, draws=None, clock_step=0.0, observe=[...], inputs=, performer=, subject=, arguments=, named_arguments=, engine=)` → `RunsResult` (`.rows`, `.observables`, `.distributions` with `.min/.mean/.max/.deviation/.percentiles/.histogram`, `.lines`, `.outputs`, `.verdicts`, `.seed`) |
| Self-check (*nightly*, `self_check`) | `model.self_check(packages=())` → `SelfCheckResult` (`.status` `holds`/`fails`/`unresolved`, `.findings`, `.elements`, `.checks`, `.violations`, `.unevaluated`, `.applications`, `.summary`) |
| Record a run (*nightly*, `record_run`) | `model.record_run(case_id, subject=, arguments=, named_arguments=, into=None, ranges=None, runs=0, seed=None, engine=None)` → `Recording` (`.run`/`.sweep`/`.sample`, `.package`, `.definition`, `.records`, `.source`, `.documents`, `.model_hash` of the model with the records) |
| Data import (*nightly*, `import_data`) | `model.import_data([(name, content)` or `(name, content, format, map)...], import_as="values", dry_run=False, accept_documents=False)` → `ImportResult` (`.files` of `ImportedFile(name, values, elements, assignments)`, `.content`, `.documents`, `.model_hash`) |
| Compare tool results (*nightly*, `compare_results`) | `model.compare_results(results_json, actions=(), runs=0, seed=None, draws=None, clock_step=None, observe=, engine=)` → `Comparison` (`.source`, `.configurations`, `.standing`) |
| Queries | `model.query(where=..., select=..., scope=...)`, `model.run_document_query(query_id, bindings=)` |
| Rendering | `model.render_view(name, ports="minimal", show=None, depth=0)` → `RenderedView` (`.nodes`, `.edges`, `.rows`, `.notices`, `.shown`), `model.render_document(doc_id, form="markdown")` → `str`, `model.export_graphs(subject)`, `model.documents`. *Nightly:* `show=["parameter-symbols", "port-symbols", "compartments", "edge-labels", "keywords", "multiplicities", "typings", "qualifiers"]` or `["all"]` adds optional notation elements and `.shown` lists what was drawn; `depth=n` bounds nesting; `.notices` says why a rendering is empty |
| Engines | `conn.list_engines(probe=False)` → `EngineInfo` (`.name`, `.authority`, `.answers`, `.bounds`, `.ready`, `.unavailable`, `.kind`, `.protocol`); *nightly:* `probe=True` starts each external engine once, as `sysml -engines -probe` does |
| Conversion | `model.to_turtle()`, `model.to_api_json()`, `model.to_sysml()`, `model.convert("ttl")`, `model.save("out.ttl")` |
| Editing | `e = model.edit(); e.set_value(...); e.rename(...); e.add_attribute(...); result = e.apply()` — operations are collected and applied in one `ApplyEdits` call that rewrites only the edited spans |
| Migration | `conn.migrate("sysml", file_path="Model.mdzip", report=True)` |

Symbol ids are qualified names (`"Vehicles::Car::massLimit"`). Values come back as Python
types: `float`, `int`, `bool`, `str`, `Array`, `EnumLiteral`, `ElementRef`; big integers and
rationals need the `big_int_values` / `rational_values` capabilities. A `VerificationVerdict`
(from `run_analysis`/`run_runs` verdicts) carries `.instance_id` / `.instance_type_id` — the
object a per-object case verdict ran on, `0` and `""` when it ran on no object (nightly).

## The nightly methods, as they answer

Run against the conformance fixtures of the OpenSysML checkout (`conformance/fixtures/`):

```python
tank = conn.load("conformance/fixtures/tank.sysml")
r = tank.check_action("Plant::Tank::fill", performer="Plant::tank",
                      properties=["Plant::Tank::low"], diverge=["this.level"])
r.verdict, len(r.violations), len(r.divergences), str(r.standing)
# ('fails', 1, 1, 'witnessed by check')
r.lines[:3]
# ['✗ Action Plant::Tank::fill: violation (11 states, 10 moves, depth 6)',
#  '  violation: Plant::Tank::low is false after 3 moves (probability 1)',
#  '  divergent: this.level ends as 1 or 2']

mc = conn.load("conformance/fixtures/monte_carlo.sysml")
rr = mc.run_runs(action="MC::Settle", runs=4, seed=7, observe=["t"])
len(rr.rows), rr.observables, rr.seed, rr.lines[0]
# (4, ['t'], 7, 't: 4 run(s), min 1.1747..., mean 2.1245..., max 3.7291..., p50 1.7381..., p90 3.7291...')
mc.run_runs(action="MC::Settle", runs=2)
# InvalidRequestError: the runs draw at random; set seed, or fix the draws as min, max or average

sc = mc.self_check()
sc.status, sc.summary
# ('holds', 'Self-model check: 33 elements, 280 checks, 0 violations, 0 unevaluated')

rec = mc.record_run("MC::Cost", subject="MC::p")
rec.package, rec.definition, rec.records, str(rec.run)
# ('Records', 'Records::CostRun', ['Records::Cost_run1'], 'total = 6.0')   # rec.model_hash holds the recorded model

imp = conn.load("conformance/fixtures/import.sysml")
ir = imp.import_data([("fleet.csv", "element,count,label\nV::vehicle,7,fast\nV::car,9,\n")])
ir.files        # [ImportedFile('fleet.csv', values=3, elements=2)]; ir.content is the edited source
imp.import_data([("fleet.tsv", "element\tcount\nV::vehicle\t7\n")], dry_run=True).model_hash   # ''

cmp = conn.load("conformance/fixtures/probe.sysml").compare_results(results_json, seed=7)
cmp.source, str(cmp.configurations[0])[:60]
# ('probe.xmi', "compare Cfg::'Group 1' — 2 stored run(s) in Results; 2 run(s)")

[(e.name, e.ready) for e in conn.list_engines(probe=True)][:3]
# [('check', True), ('explore', True), ('run', True)]
mc.execute_action("MC::Settle", seed=7, draws="min")      # ActionOutputs {'t': 1.0}
```

## Capabilities and errors

```python
info = conn.server_info()                 # .version, .capabilities
if opensysml.CAPABILITY_CONVERT_DOCUMENTS not in info.capabilities: ...
conn = opensysml.connect(require_capabilities=[opensysml.CAPABILITY_RATIONAL_VALUES])
```

Constants exist for every capability the service advertises; the nightly ones are
`CAPABILITY_CHECK`, `CAPABILITY_RUNS`, `CAPABILITY_SELF_CHECK`, `CAPABILITY_RECORD_RUN`,
`CAPABILITY_IMPORT_DATA`, `CAPABILITY_COMPARE_RESULTS`, `CAPABILITY_RENDER_DOCUMENT_FILE_NAME`
(`opensysml-service` lists what a v0.10.1 service and a nightly one advertise).

Typed exceptions: `ConnectionError` (service unreachable or binary not provisioned),
`ChecksumMismatchError`, `UnpinnedReleaseError`, `UnsignedReleaseError`,
`SigstoreUnavailableError`, `StaleServiceError`, `ServiceError`, `ServiceTimeoutError`,
`MissingCapabilityError`, `InvalidRequestError`, `ExecutionError`, `AnalysisRunError`,
`ConversionError`, `DocumentQueryError`, `EditError` (+ `EditTargetError`,
`EditResultError`, `DeleteReferencedError`), and `ExperimentalFeatureWarning` on RDF/
migration paths. Model *diagnostics* are data, not exceptions — check `model.ok`.

## Patterns

```python
# pytest gate
def test_mass_requirement():
    model = opensysml.load("model/vehicle.sysml"); model.raise_for_errors()
    assert all(v.holds for v in model.verify_satisfaction())

# one service for many files
with opensysml.connect() as conn:
    models = [conn.load(p) for p in paths]

# shared service started elsewhere (sysml-grpc -port 50051)
conn = opensysml.connect("localhost", 50051)
```

Budgets and solver variables (`OPENSYSML_MAX_*`, `OPENSYSML_SMT`) must be in the
environment of the Python process that spawns the private service, or of the shared
service (`opensysml-troubleshooting`). Pin `opensysml==X.Y.Z`; the package version is the
service version it provisions. Jupyter users: prefer the kernel (`opensysml-jupyter`) for
exploration and this package for pipelines.
