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


**0.12.0 in this client.** A service that requires a bearer token takes it as `token=` on `opensysml.connect(host, port, …)` (a call
without it fails `unauthenticated`); `convert` takes `compact`, `omit_derived`/`keep_derived`,
`include_check_diagnostics`, `id_form` and `include_library_stubs` in the client's spelling
(capabilities `convert_compact`, `convert_check_diagnostics`, `convert_library_stubs`);
`render_document` takes the `asciidoc` form (`render_document_asciidoc`); an action run carries
its trace (`action_trace`); a verdict carries its notes (`verdict_notes`). QVTS: the document-query
call `model.run_document_query(query_id, bindings=)` runs a `calc def … :> DocumentQueries::Query` and answers typed rows, but no 0.12.0
client decodes the `QueryOutcome` error detail — a query the model cannot answer is the service's
`failed_precondition` error whose message holds the outcome lines (`query X reads feature mass of
…, which has no such feature`); run `sysml -run-query … -json` for the structured record
(`opensysml-qvts`).
In nightly builds and the release after v0.12.1, `model.query(oslc=…)` / `model.query(where=…, select=…)` compiles the structured `Query` or OSLC text into the same document-query plans the QVTS evaluator runs: values compare typed, every property the metamodel declares is queryable by name and nests by `.` (`owner.qualifiedName`), an unknown property is the service's `invalid_argument` carrying the `QueryOutcome` detail (read the message; the client does not decode it), and `@type` naming an element IRI (`<urn:sysmlv2:element:Garage__Wheel>`, OSLC `rdf:type=elmt:Garage__Wheel`) selects the held objects of that element, each answered under `QueryElement.path` (`Garage::car.wheels[2]`; empty for a declared element). OSLC `or` stays refused (`OSLC Query has no "or"`); scoped terms, nested `oslc.select`, `oslc.select=*`, `oslc.searchTerms` and `sysx:multiplicityLower`/`sysx:multiplicityUpper` are accepted (`docs/reference/oslc-query.md`).

Nightly builds and the release after v0.12.1 also run a query body written inline, with no
`calc def` in the model: `model.run_document_query(inline_query="Project(…)")` (keyword only; exclusive with `query_id`), guarded by `CAPABILITY_INLINE_DOCUMENT_QUERY`. The client checks the server's
`inline_document_query` capability first (`GetServerInfo`); the named and inline forms are
exclusive, an inline text takes no bindings, and a fault in the text is the service's
INVALID_ARGUMENT positioned `inline query <line>:<col>` (`opensysml-qvts`).

Verified against the 0.12.0 release build (`sysml v0.11.0-1980-g72c5b132f`, built from `release/0.12.0`) with the client installed from `client/python` of the same checkout.
Rows marked *nightly* arrived after 0.10.1 and are in `opensysml==0.12.0` on PyPI: the
`opensysml==0.10.1` package has no `check_action` (`AttributeError`), whatever service it talks
to. For an unreleased commit install the night's client by
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
| Queries | `model.query(where=..., select=..., scope=..., order_by=...)` or `model.query(oslc="oslc.where=…")` → `QueryElement` (`.id`, `.type`, `.properties`, `.path`), `model.run_document_query(query_id, bindings=)` |
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

results_json = json.dumps({"source": "probe.xmi", "configurations": [{
    "id": "_c1", "name": "Cfg::'Group 1'", "runs": 2, "target": "target", "behavior": "run",
    "resultLocation": "Results", "observables": ["total"],
    "snapshots": [{"id": "_r1", "values": {"total": 3}}, {"id": "_r2", "values": {"total": 5}}]}]})
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
