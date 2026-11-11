---
name: opensysml-matlab
description: Use the MATLAB/Octave client under client/matlab (`+opensysml` package, no toolboxes) to parse, validate, evaluate, verify, execute, analyse, model-check, run Monte Carlo samples, self-check, record runs, import data, compare tool results, render, convert and edit SysML v2 models — `opensysml.connect`, `opensysml.external`, `opensysml.private`, parseFile/parseSource, values, errors, and the Octave+curl path. Use when calling OpenSysML from MATLAB scripts, Simulink callbacks, or Octave in CI.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML from MATLAB / Octave

```matlab
addpath('/path/to/OpenSysML/client/matlab');     % the +opensysml package; no toolboxes required
```

MATLAB uses `matlab.net.http`; Octave shells out to `curl` (the path CI exercises). The
transport is Connect **JSON**, so answers compare directly with `curl` against
`sysml-grpc` (`opensysml-service`).

```matlab
conn = opensysml.connect();                       % OPENSYSML_SERVICE, otherwise a private child
cleanup = onCleanup(@() conn.close());
model = opensysml.parseFile(conn, 'vehicle.sysml');
if ~model.ok()
    disp(opensysml.diagnostics(model))
    error('The model has errors.')
end
mass = opensysml.evaluate(model, 'mass', 'subject', 'Vehicles::myCar');
fprintf('%.1f\n', mass);                          % 1300.0
```

## Connections

```matlab
conn = opensysml.connect();                                    % env-driven
conn = opensysml.external('localhost:50051');                  % service someone else runs; close() only disconnects
conn = opensysml.private('binary', '/path/to/sysml-grpc', 'timeout', 30);   % explicit child
```

- `opensysml.private` needs Java (MATLAB's process control); MATLAB without Java and Octave
  configurations that cannot spawn should use `opensysml.external` or `OPENSYSML_SERVICE`.
- Binary resolution for a private child: the `'binary'` argument, `OPENSYSML_GRPC_BINARY`,
  `~/.opensysml/bin/sysml-grpc`, then `PATH`. The MATLAB client does **not** download
  releases — install the binary first (`opensysml-install`).
- `opensysml.capabilities(conn)` reports what the service advertises; `opensysml.lastError()`
  returns the last service error struct.

Verified against the 0.12.0 release build (`sysml v0.11.0-1980-g72c5b132f`, built from `release/0.12.0`) with the package at `client/matlab` of the same checkout. Anything marked
*nightly* arrived after 0.10.1 and is in the 0.12.0 package: `addpath` the `client/matlab` of a
checkout of the `v0.12.0` tag or newer (a `v0.10.1` checkout has no `opensysml.checkAction`) and
run a service of the same release; a newer package against an older service raises
`opensysml:missingCapability`.

**0.12.0 in this client.** A service that requires a bearer token takes it as the connection's `'token'` option (a call
without it fails `unauthenticated`); `convert` takes `compact`, `omit_derived`/`keep_derived`,
`include_check_diagnostics`, `id_form` and `include_library_stubs` in the client's spelling
(capabilities `convert_compact`, `convert_check_diagnostics`, `convert_library_stubs`);
`render_document` takes the `asciidoc` form (`render_document_asciidoc`); an action run carries
its trace (`action_trace`); a verdict carries its notes (`verdict_notes`). QVTS: the document-query
call `opensysml.runDocumentQuery` runs a `calc def … :> DocumentQueries::Query` and answers typed rows, but no 0.12.0
client decodes the `QueryOutcome` error detail — a query the model cannot answer is the service's
`failed_precondition` error whose message holds the outcome lines (`query X reads feature mass of
…, which has no such feature`); run `sysml -run-query … -json` for the structured record
(`opensysml-qvts`).
In nightly builds and the release after v0.12.1, `opensysml.query(model, 'oslc text')` / `opensysml.query(model, 'where', …)` compiles the structured `Query` or OSLC text into the same document-query plans the QVTS evaluator runs: values compare typed, every property the metamodel declares is queryable by name and nests by `.` (`owner.qualifiedName`), an unknown property is the service's `invalid_argument` carrying the `QueryOutcome` detail (read the message; the client does not decode it), and `@type` naming an element IRI (`<urn:sysmlv2:element:Garage__Wheel>`, OSLC `rdf:type=elmt:Garage__Wheel`) selects the held objects of that element, each answered as its declaring usage (the wire's additive `QueryResultElement.path` is not surfaced by this client yet). OSLC `or` stays refused (`OSLC Query has no "or"`); scoped terms, nested `oslc.select`, `oslc.select=*`, `oslc.searchTerms` and `sysx:multiplicityLower`/`sysx:multiplicityUpper` are accepted (`docs/reference/oslc-query.md`).

In nightly builds and the release after v0.12.1, the service can write a query's answer as a `QVTS::QueryResult` view (`as_view` on `RunDocumentQueryRequest`/`QueryRequest` → `result_view.text`, capability `query_result_view`) and render one as a document (`RenderViewRequest.form`); this client does not bind either yet — use `sysml -as-view`, or call the RPC over Connect JSON (`opensysml-service`, `opensysml-qvts`).

Nightly builds and the release after v0.12.1 also run a query body written inline, with no
`calc def` in the model: `opensysml.runDocumentQuery(model, '', 'inlineQuery', 'Project(…)')`. The client checks the server's
`inline_document_query` capability first (`GetServerInfo`); the named and inline forms are
exclusive, an inline text takes no bindings, and a fault in the text is the service's
INVALID_ARGUMENT positioned `inline query <line>:<col>` (`opensysml-qvts`).


## Parsing and models

`opensysml.parseFile(conn, path)`, `opensysml.parseSource(conn, text)`,
`opensysml.parseSources(conn, docs)` (`opensysml.SourceDocument`s); `model.ok()`,
`opensysml.diagnostics(model)` (struct array with `severity`, `message`, `span`, `code`),
`model.hash`, `opensysml.getSymbol(model, 'Pkg::x')` → `opensysml.Symbol`.

## Operations

Name/value pairs for options: `opensysml.evaluate(model, expr, 'subject', id)`,
`opensysml.instantiate(model, id)`, `opensysml.verifyConstraint(model, id, 'subject', id)`,
`opensysml.verifyRequirement`, `opensysml.verifySatisfaction(model)`,
`opensysml.validateInstance`, `opensysml.calc(model, id, args)`,
`opensysml.runAnalysis(model, id, 'subject', ..., 'engine', ...)`,
`opensysml.runSweep(model, id, ranges)`, `opensysml.executeAction(model, id, 'inputs', ...)`,
`opensysml.executeState(model, id, 'events', {...}, 'trace', true)`,
`opensysml.query(model, 'where', ...)`, `opensysml.runDocumentQuery`,
`opensysml.renderDocument(model, id, 'form', 'markdown')` → text,
`opensysml.renderView(model, name, 'ports', 'full', 'show', {'edge-labels', 'typings'})` →
`opensysml.RenderedView` (`nodes`, `edges`, `rows`, `notices`, `shown`; `'show'` and `shown`
are *nightly*, values `parameter-symbols`, `port-symbols`, `compartments`, `edge-labels`,
`keywords`, `multiplicities`, `typings`, `qualifiers`, `all`), `opensysml.exportGraphs`, `opensysml.convert(model, opensysml.FORMAT_TURTLE)` (also
`FORMAT_SYSML`, `FORMAT_API_JSON`; result is an `opensysml.Conversion`),
`opensysml.migrate(conn, 'Model.mdzip', ...)` → `opensysml.Migration` (`opensysml.isV1(path)`
tells whether a file needs migration), `opensysml.listEngines(conn)`.

Values: reals/ints become `double` (64-bit ints beyond `flintmax` are returned as `int64`
or strings per capability), booleans `logical`, strings `char`, arrays cell/numeric
arrays; enum literals, quantities, instance references and the unset/undetermined answers
come back as typed values built by `opensysml.quantity`, `opensysml.enumLiteral`,
`opensysml.instanceRef`, `opensysml.infinity`, `opensysml.metaobject`, `opensysml.functionRef`
(use the same constructors to pass inputs) — check the class before arithmetic.
`opensysml.Verdict` has `holds`, `standing`, `engine`, `explain`, and for a case verdict
`instanceId`/`instanceTypeId` naming the object it ran on (`0` when none; *nightly*).

## Checking, runs, recording, import and comparison (nightly)

Name/value options as everywhere else; results are structs with the response's fields:

| Need | Call |
|---|---|
| Model checking (`check`) | `opensysml.checkAction(model, id, 'inputs', s, 'performer', p, 'properties', {...}, 'diverge', {...}, 'freeInputs', {...}, 'assume', {...}, 'witness', true, 'depth', n, 'states', n, 'unroll', n, 'timeout', s, 'engine', e)`, `opensysml.checkStateMachine(model, id, ...)` → struct with `verdict` (`holds`/`fails`/`undecided`), `lines`, `search`, `violations`, `divergences`, `finals`, `standing` |
| Repeated runs / Monte Carlo (`runs`) | `opensysml.runRuns(model, 'action', id` or `'analysis', id, 'runs', n, 'seed', n, 'draws', 'min', 'clockStep', s, 'observe', {...}, 'inputs', s, 'performer', p, 'subject', id, 'arguments', {...}, 'namedArguments', s, 'engine', e)` → struct with `rows`, `observables`, `distributions`, `outputs`, `verdicts`, `seed`; unseeded random runs are refused |
| Self-check (`self_check`) | `opensysml.selfCheck(model, 'packages', {'SysMLValidation'})` → struct with `status`, `findings`, `elements`, `checks`, `violations`, `unevaluated`, `evaluationErrors`, `applications`, `summary` |
| Record a run (`record_run`) | `opensysml.recordRun(model, caseId, 'subject', id, 'arguments', {...}, 'namedArguments', s, 'into', pkg, 'ranges', ..., 'runs', n, 'seed', n, 'engine', e, 'acceptDocuments', true)` → struct with `run`, `package`, `definition`, `records`, `source`, `content`, `documents`, `modelHash` |
| Data import (`import_data`) | `opensysml.importData(model, imports, 'dryRun', true, 'acceptDocuments', true)` with `imports` a struct array of `name`, `content` and optional `format`, `map` → struct with `files` (`name`, `values`, `elements`, `assignments`), `content`, `documents`, `modelHash` |
| Compare tool results (`compare_results`) | `opensysml.compareResults(model, resultsJson, 'actions', {...}, 'runs', n, 'seed', n, 'draws', d, 'clockStep', s, 'observe', ..., 'engine', e)` → struct with `source`, `configurations`, `diagnostics` |

Not in this client: `depth` on `renderView`, lint selection on `opensysml.diagnostics`,
`advance`/`seed`/`draws`/`clockStep` on `executeAction`/`executeState`, `toolDryRun` on
`runAnalysis`, `probe` on `listEngines`, and the rendered document's file name — send those
request fields with `curl` (`opensysml-service`).

## Authoring edits

`opensysml.setValue(model, id, value)` is the one-shot form; for several operations build an
`opensysml.Editor`, add operations, and send them with `opensysml.applyEdits(...)` — one
`ApplyEdits` call returning an `opensysml.EditResult`; refusals report the referrers.

## Errors

Errors use identifiers under `opensysml:` — `opensysml:transport`, `opensysml:staleService`,
`opensysml:missingCapability`, `opensysml:unsupported`, `opensysml:argument`,
`opensysml:featureValue`, `opensysml:encode`/`opensysml:decode`, `opensysml:experimental`
(RDF/migration warnings) — catch with `try … catch err, switch err.identifier`; service
refusals carry the canonical code in `opensysml.lastError()`. Diagnostics and false
verdicts are return values (`opensysml.Verdict`, `opensysml.Standing`).

Not available in MATLAB/Octave: in-process execution, protobuf transport, release download,
typed stub generation (see `client/matlab/README.md`). CI pattern:

```bash
sysml-grpc -port 50051 &                                  # or OPENSYSML_SERVICE=localhost:50051
octave --no-gui --eval "addpath('client/matlab'); run_tests"
```
