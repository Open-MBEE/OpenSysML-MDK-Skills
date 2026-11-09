---
name: opensysml-qvts
description: Write and run QVTS (Query, View, Transformation for SysML v2) queries with OpenSysML — author `calc def … :> Query` queries over the bundled `DocumentQueries` library (Named, Descendants, WhereType, WhereFeature, Project, OrderBy, Differ, Verdicts, reflection over metamodel properties), run them with `sysml -run-query`, `%run-query`, the `RunDocumentQuery` RPC and the MCP `run_document_query` tool, read the three QVTS outcomes (a value, a path error, a model error), their `-json` records and tables, tolerate missing features, feed query rows into document tables, and know the behaviours OpenSysML 0.12.0 still documents as limits. Use when a task asks a model a question that should return rows, when `-run-query` exits 2 with `path error at …`, when a query returns zero rows and you need to know whether that is an answer or a failure, or when a report needs a query-backed table.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# QVTS queries with OpenSysML

QVTS (Query, View, Transformation for SysML v2) is the Open-MBEE specification of model
queries that either **answer** or **fail for a stated reason**. OpenSysML 0.12.0 implements
its query part: a query is a `calc def` specializing `DocumentQueries::Query` built from the
operations of the bundled `OpenSysML Libraries/DocumentQueries.sysml` library, and every
run ends in exactly one of three outcomes (QVTS-Core §3; cite the section, the specification
text itself is not redistributed here):

| Outcome | Meaning | CLI | Exit |
|---|---|---|---|
| **value** | Rows, possibly none — an empty selection is an answer, not a failure | `✓ Query X returned N rows` | `0` |
| **path error** | The *query* is wrong about the model: a name, feature, metaclass, relationship kind or column the model does not provide | `sysml: query X …` then `path error at <Step>(…)` lines, one per failing element | `2` |
| **model error** | The *model* violates a constraint the query needs: an ambiguous name, a duplicate key | `sysml: query X names 2 elements …` (a finding; a model error at a step) | `2` |

Verified with the 0.12.0 release build (`sysml v0.11.0-1980-g72c5b132f`, built from
`release/0.12.0`). The models and queries used below are copied from OpenSysML's
`examples/qvts/` into [references/examples/](references/examples/) (Apache-2.0):
`lander.sysml` (a lander with payload masses), `duplicates.sysml` (a package declaring
`repeated` twice) and `queries.sysml` (package `QVTSDemo`). The OpenSysML handbook page is
`docs/guide/qvts.md`; the example README `examples/qvts/README.md` records every command and
its output, pinned by `tests/qvts`.

## Writing a query

```sysml
package QVTSDemo {
    private import DocumentQueries::*;

    calc def CabinMass :> Query {
        Project(
            source = Named(qualifiedName = "Lander::lander::cabin"),
            properties = ("qualifiedName", "mass")
        )
    }

    calc def MassTable :> Query {
        Project(
            source = WhereType(
                source = Descendants(source = Named(qualifiedName = "Lander::lander")),
                type = "PartUsage",
                exact = true            // the metaclass itself, not its specializations
            ),
            properties = ("qualifiedName", "mass")
        )
    }
}
```

The body is one expression over the library's operations; the last one's rows are the
result. Names are quoted strings in `::` form, a segment that needs quoting in notation is
quoted inside the string (`"Vehicle::'Spare Parts'::Pad"`), and a parameter that takes
several values takes a sequence (`qualifiedName = ("A::x", "A::y")`). A query may declare
`in` parameters; `-run-query` binds them as `name=expression`, and an object created by
`-instantiate` in the same run is bound by its name.

### The `DocumentQueries` operations

| Group | Operation (parameters) |
|---|---|
| Sources | `Named(qualifiedName)`, `OwnedElements(source)`, `Descendants(source)`, `Ancestors(source, maxDepth)`, `Objects(type)` (objects `-instantiate`/the session created), `Verdicts(source, kind = all\|constraint\|requirement\|satisfaction\|verification)`, `States(source)`, `InState(…)`, `Events(source)`, `RelatedElements(source, relationshipKind, direction, maxDepth)` |
| Filters | `WhereType(source, type, exact = false)`, `WhereMetadata(…)`, `WhereName(…)`, `WhereText(…)`, `WhereFeature(source, feature, operator, value, tolerate = false)`, `WhereRelated(source, relationshipKind, direction, maxDepth, exists = true)`, `Distinct(source)`, `Except(…)`, `Union(…)` |
| Shaping | `Project(source, properties, columns, tolerate = false)` — `columns` take `Column(name, expression \| cell \| path)` and `RelatedColumn(name, relationshipKind, direction, maxDepth, aggregate, targets)`; `OrderBy(source, property, direction, missing = first\|last\|error, multiple = first\|…)`; `Tree(source, ancestors)` |
| Comparison | `Differ(left, right, key, column)` → rows `(key, left, right)` where the column differs |

`WhereFeature`'s `operator` is a string: `"="`, `"<"`, `">"`, `"<="`, `">="`, `"in"`,
`"instanceOf"` (the seven primitive constraints of the SysML v2 API & Services Query, which
the service's `Query` RPC also accepts in full since 0.12.0). `Project` reads a feature's
value when the row has the feature, else a **metamodel property** through reflection
(`elementId`, `declaredName`, `isComposite`, `isAbstract`, `direction`, `ownedRelationship`,
`type`, `general`, …): `properties = ("qualifiedName", "elementId", "isComposite", "declaredName")`
answers for every `PartUsage`. A property the metamodel has but this build does not derive
is a path error of kind `unserved-property`; one the metamodel lacks names the nearest
spelling. `sysml -metamodel-table` (no model needed) writes the pinned pilot metamodel as JSON
(`{"name": "PartUsage", "abstract": false, "parents": ["ItemUsage"]}` …) — the vocabulary
reflective queries and `WhereType` names come from; `-metaclass-graph` draws it.

## Running a query

```bash
sysml lander.sysml queries.sysml -run-query QVTSDemo::CabinMass
#   ✓ Query QVTSDemo::CabinMass returned 1 row
#     Columns: qualifiedName, mass
#     Row 1: Lander::lander::cabin
#       qualifiedName = "Lander::lander::cabin"
#       mass = 320.0
sysml lander.sysml queries.sysml -run-query QVTSDemo::EmptySelection      # ✓ … returned 0 rows, exit 0
sysml lander.sysml queries.sysml -run-query QVTSDemo::CabinMass -json      # checks[0].table
printf '%%run-query QVTSDemo::CabinMass\n' | sysml lander.sysml queries.sysml   # REPL, same lines
```

Pass every file the query reaches (the model *and* the file declaring the query). The
`-json` object (`opensysml-cli`) carries a successful query as `checks[].table`:

```json
"table": {
  "columns": ["qualifiedName", "mass"],
  "rows": [{"element": "Lander::lander::cabin", "cells": [["\"Lander::lander::cabin\""], ["320.0"]]}]
}
```

(`rows`/`values` keep the formatted lines; a successful run has no `outcome` member — see
Limits.) Other surfaces:

- **REPL**: `%run-query NAME [p=expr…]` (`opensysml-repl`); the same `✓`/`path error` lines.
- **gRPC**: `RunDocumentQuery(model_hash, query_id, bindings[])` answers typed rows
  (`DocumentValue`: `element_id`, strings, numbers, `quantity`, `verdict`, `object`, `state`,
  `event`); `NOT_FOUND` when the model declares no such query, `INVALID_ARGUMENT` when the
  name is not a query. A query that fails attaches a `QueryOutcome` error detail
  (`kind` `pathError`|`modelError`, `step`, `failures[] {step, expected, frontier {at,
  members, features, kinds, nearest}}`, `findings[] {step, element, constraint, observed}`,
  `path_failures[]`); in nightly builds and the release after v0.12.1 each frontier list on
  the wire holds at most eight names (nearest spellings first) with the whole count in
  `membersTotal`/`featuresTotal`/`kindsTotal`, while `-json` and `%run-query` keep the whole
  list; `RenderDocument` carries it too when a section's query fails.
  Capability `document_query` (`opensysml-service`).
- **MCP**: `run_document_query` (runtime group; the RPC's bindings and rows) and `query`
  (API & Services Query with `orderBy`); `render_document`/`render_model_document` for
  documents (`opensysml-mcp`).
- **OSLC text and the API `Query`** (`sysml -query`, `%query`, the `Query` RPC, the MCP
  `query` tool, every client's `query`): in nightly builds and the release after v0.12.1 these
  are translators into the same plans — `rdf:type`/`@type` → `WhereType`, `sysml:name` →
  `WhereName`, any other metamodel property → `WhereFeature(tolerate)`, `oslc.select` →
  `Project`, `oslc.orderBy` → `OrderBy`, `oslc.searchTerms` → `WhereText`, `rdf:type=elmt:<id>`
  → `Objects` over the held objects — run by this evaluator, so they share its typed comparison,
  reflective properties and `QueryOutcome` failures (`docs/reference/oslc-query.md`,
  `opensysml-cli`, `opensysml-service`).
- **Clients**: every language client runs a query (`model.run_document_query(query_id,
  bindings)` in Python, `runDocumentQuery` in Node/Java, `RunDocumentQuery` in Go,
  `run_document_query` in Rust/Julia/MATLAB) and answers typed rows, but in 0.12.0 **none
  decodes the `QueryOutcome` detail** — a failed query surfaces as the service's status error
  with the outcome lines in its message, not as a typed result. Parse the CLI's `-json` when a
  pipeline needs the structured record.

## Reading a failure

A **path error** names the step, what it expected and the *frontier* — the last element that
resolved and what it offers instead, with the nearest spelling:

```text
sysml: query QVTSDemo::MisspelledName names no element Lander::lander::cabni: Lander::lander has no member cabni — did you mean cabin?
  path error at Named(Lander::lander::cabni): expected exactly one element with that qualified name
    at Lander::lander; members: [cabin (PartUsage), cabinEngine (ConnectionUsage), engine (PartUsage), …]; nearest: cabin
```

A step over many elements fails once **per element** (fan-out), so one run shows every
offender — here `Project` asked connections for a `mass` they do not have:

```text
sysml: query QVTSDemo::MissingMassProject reads feature mass of Lander::lander::cabinEngine, which has no such feature (also absent on Lander::lander::engineBay)
  path error at Feature(mass): expected a feature named mass on the element
    at Lander::lander::cabinEngine; features: []
  path error at Feature(mass): expected a feature named mass on the element
    at Lander::lander::engineBay; features: []
```

A **model error** reports a finding about the model (`name-conflict` warnings precede it):

```text
sysml: query QVTSDemo::AmbiguousPart names 2 elements Duplicates::repeated: Duplicates::repeated (declared 2 times)
```

With `-json` the record is `checks[].outcome`
([failing-query-json.json](references/examples/failing-query-json.json),
[model-error-json.json](references/examples/model-error-json.json)):

```json
"outcome": {
  "outcome": "pathError",
  "step": "Feature(mass)",
  "failures": [{"step": "Feature(mass)", "expected": "a feature named mass on the element",
                "frontier": {"at": "Lander::lander::cabinEngine", "features": [], "nearest": null}}]
}
```

```json
"outcome": {
  "outcome": "modelError",
  "step": "Named(Duplicates::repeated)",
  "findings": [{"step": "Named(Duplicates::repeated)", "element": "Duplicates::repeated",
                "constraint": "ambiguousName", "observed": {"namespace": "Duplicates", "count": 2}}]
}
```

Path-error kinds: `unknown-element`, `missing-feature`, `unknown-property`,
`unserved-property`, `unknown-classification` (a `WhereType` metaclass), `unknown-relationship`,
`unknown-column` (`Differ(elementIdd, mass)`: `the left rows project no column elementIdd
(columns: elementId, mass)` … `nearest: elementId`). Model-error constraints: `ambiguousName`
(the finding records the owning namespace and count), `duplicateKey`.

### Missing is not unvalued

A feature that exists but has no value is a **value**: `scienceBay` declares `mass : Real[1]`
without a binding, so `QVTSDemo::UnvaluedMass` returns one row with `mass = (none)` and exits
`0`; a connection with no `mass` feature at all is the path error above. In the Markdown table
an unvalued cell is empty; in JSON it is `[]`.

### Tolerating a missing feature

When rows legitimately differ in shape, say so in the query instead of dropping the step:
`Project(…, tolerate = true)` keeps the row with an empty cell (`ToleratedMassProject`: 5 rows,
`cabinEngine … mass = (none)`), and `WhereFeature(…, tolerate = true)` drops the row whose
feature is absent instead of failing (`ToleratedMassFilter`: `cabin` and `engine`, 2 rows).
Without `tolerate` a missing feature is always a path error (QVTS-Core §3.3). Tolerated cells
are not marked apart from unvalued ones in 0.12.0 output.

## Query-backed documents

A `Document`'s `Table` takes its rows from a query; the document form of the same data:

```sysml
part def MassReport :> Document {
    attribute redefines title = "Lander Mass Report";
    part masses : Table {
        attribute redefines caption = "Mass values in the lander";
        calc rows : MassTable;
    }
}
```

```bash
sysml lander.sysml queries.sysml -render-document QVTSDemo::MassReport            # Markdown on stdout
sysml lander.sysml queries.sysml -render-document QVTSDemo::MassReport -doc-form html -o report.html
```

```markdown
| qualifiedName | mass |
| --- | --- |
| Lander::lander::cabin | 320 |
| Lander::lander::engine | 145 |
| Lander::lander::scienceBay |  |
```

A query that fails fails the document the same way (exit `2`, the outcome lines on stderr;
`-render-documents` exits `3` when other documents rendered). `Table` also takes `groupBy`,
`columnWidths` and `columnLabels`; `Verdicts(...)` rows make a verification table; forms and
toolchain are in `opensysml-documents`.

## Reflection and comparison

```bash
sysml lander.sysml queries.sysml -run-query QVTSDemo::MetamodelProperties   # elementId, isComposite, declaredName per PartUsage
sysml lander.sysml queries.sysml -run-query QVTSDemo::ChangedMasses         # Differ: (elementId, left mass, right mass)
sysml -metamodel-table | head                                                # the metaclass table queries are checked against
sysml lander.sysml -convert ttl -o lander.ttl                                # the same facts as RDF, for SPARQL (opensysml-convert-rdf)
```

`ChangedMasses` compares two projections keyed on `elementId` — the right side computes
`mass` with `Column(name = "mass", cell = { in row : Lander::Payload; row.mass + 1.0 })` —
and lists the rows whose `mass` differs; a misspelled `key` is the `unknown-column` path error.

## Limits in 0.12.0 (documented in `docs/guide/qvts.md`)

- An unknown metaclass in `WhereType`, an unknown property name, an unknown relationship kind
  or direction exits `2` with the message but **no** `outcome` record in `-json`.
- `Named` with several missing names reports only the first.
- `OrderBy(missing = "error")` reports it could not evaluate, without an outcome record.
- A successful query has no `outcome: value` member; the presence of `table` is the signal.
- Two values for a `[1]` feature return the first value where QVTS specifies a multiplicity
  model error (`QVTSDemo::DoubleMassValue`).
- Tolerated cells/rows are not marked in the output.

## Pitfalls

- `returned 0 rows` is a **value** (exit `0`): the selection is empty. Check the filter's
  `type`/`feature` spelling against `-metamodel-table` or `-list` before assuming a bug.
- `names no element …` after a rename: queries hold qualified names as strings, so
  `-validate` does not catch a stale `Named`; running the query does.
- Forgetting `exact = true`: `WhereType(type = "PartUsage")` also matches specializations.
- A `Project` over mixed element kinds fails on the first kind lacking the feature — narrow
  the source with `WhereType`/`WhereFeature`, or state `tolerate = true` deliberately.
- Quote qualified names inside the query string, not with `'…'` around the whole string.
