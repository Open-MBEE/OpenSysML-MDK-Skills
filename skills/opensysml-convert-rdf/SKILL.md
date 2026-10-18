---
name: opensysml-convert-rdf
description: Convert SysML v2 models between textual notation, RDF Turtle and the SysML v2 API JSON element form with OpenSysML (`sysml -convert`, REPL `%save`, client `convert`), round-trip them, import tabular data into feature values, and know the experimental status and refusals (no conversion of a model with parse errors). Use when a task needs a model as a knowledge graph, as API JSON for another SysML v2 tool, or back from those into notation.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Converting models (notation ↔ RDF ↔ API JSON)

OpenSysML stores one model and writes it in three interchangeable forms:

| Form | Extension | `-convert` name | Notes |
|---|---|---|---|
| SysML v2 / KerML textual notation | `.sysml`, `.kerml` | `sysml`, `kerml` | Canonical; what `-validate` checks |
| RDF Turtle | `.ttl` | `ttl` (`turtle`, `rdf`) | Experimental mapping; a graph with structural predicates |
| SysML v2 API element JSON | `.json` | `api-json` | Element-form JSON of the OMG Systems Modeling API |

```bash
sysml model.sysml -convert ttl -o model.ttl        # notation → RDF
sysml model.ttl   -convert sysml -o model.sysml    # RDF → notation
sysml model.sysml -convert api-json -o model.json  # notation → API JSON
sysml model.json  -convert sysml -o model.sysml    # API JSON → notation
sysml model.sysml -convert ttl                     # to stdout
sysml model.sysml -convert ttl -id uuid            # derived element ids as UUIDs instead of qualified names
sysml export.dat  -convert sysml -from ttl         # -from names the input format when the extension does not
sysml model.sysml -convert kerml -o model.kerml    # KerML notation; -o reports: wrote model.kerml (sysml, 580 bytes)
```

Verified with `sysml v0.10.1-1266-gdada45c11`; `-id`, `-bundle`/`-unbundle` and `.kpar`
input are in nightly builds and the release after 0.10.1.

The REPL does the same with `%save model.ttl` / `%save model.json` / `%save model.sysml`,
and every client exposes `convert(model, "ttl")` (`to_turtle`, `to_api_json`, `to_sysml` in
Rust; `Convert` RPC over the service, with `ConvertFile`/`ConvertSource` helpers in Go).
`-from fmu` reads a Functional Mock-up Unit's model description as a model. A SysML v2 API
branch URL (`flexo://project/branch`, or the endpoint's `https://` URL) is accepted as the
input or `-o` of `-convert`, with `-sync-state FILE` recording the last-seen commit and the
token read from `FLEXO_INTEROP_TOKEN`; the live `-sync-diff`/`-sync-apply` change-set
workflow is summarised in `opensysml-cli`.

## Rules

- **A model with syntax errors is not converted.** `-convert` and `%save` refuse when the
  parser recovered only part of the tree, because a graph built from it would silently drop
  declarations; exit is `2`, nothing is written, and the diagnostics say what to fix.
  Semantic diagnostics (an unresolved reference, a type mismatch) do *not* block conversion
  — the structure is complete — so run `-validate` first if the output must be clean.
- **Experimental.** `-convert ttl` and `api-json` print a notice that the RDF/JSON mapping is
  experimental: it covers model structure, and the vocabulary can change between releases. Pin the `sysml` version in pipelines and do not
  hand-edit `.ttl` expecting it to round-trip.
- **Round trip is structural.** notation → Turtle → notation reproduces the declarations and
  values; comments and layout are not guaranteed, and names that needed quoting stay
  quoted. The project keeps a per-file round-trip ratchet over its example corpus
  (`TestCorpusRoundTrip`), so regressions are known, not silent.
- **Ids**: `-id qualified` (default) spells a derived element id from the qualified name,
  `-id uuid` as a UUID; pick one and keep it across a pipeline, since the other side keys
  on it.
- **Exit status**: `0` written, `2` refused or usage error. Nothing is written on refusal.
  The experimental notice goes to stderr (`note: RDF conversion — Turtle and the API's JSON
  element form alike — is experimental: ...`); the output is on stdout or in `-o`.
- Large models: prefer the file output (`-o`) over stdout, and protobuf transport over JSON
  when converting through the service (`opensysml-service`).

## Importing tabular data into a model

`-import` sets feature values from CSV/TSV/JSON/JSON Lines before `-convert` writes the
result — the way to merge a spreadsheet of masses or parameters into the notation:

```bash
sysml model.sysml -import masses.csv -import-as values -convert sysml -o model.out.sysml
sysml model.sysml -import masses.csv -import-dry-run            # show what would change
sysml model.sysml -import rows.json -import-format json -import-map mapping.json -convert sysml -o out.sysml
```

The element column names the element (qualified name) and each other column a feature;
`-import-map FILE` maps arbitrary headers onto elements/features; `-import-as` chooses
whether rows set `values` or create elements. REPL: `%import FILE [map FILE]`.

## Project interchange archives (`.kpar`)

A directory holding a `.project.json` is an OMG project-interchange project; `-bundle`
zips it as a `.kpar` and `-unbundle` unpacks one. Archives are read wherever a project
directory is (named beside a model, under `-library-root`, as `OPENSYSML_LIBRARY_PATH`):

```bash
sysml -bundle proj -o widgets.kpar      # wrote widgets.kpar (Widgets 1.0.0, 4 files); without -o: <name>-<version>.kpar
sysml -unbundle widgets.kpar -o widgets # wrote widgets (Widgets 1.0.0, 4 files)
sysml -validate model.sysml widgets.kpar
```

Members are sorted and carry a fixed timestamp, so bundling twice gives the same bytes.

## Checking a conversion

```bash
sysml model.sysml -convert ttl -o a.ttl && sysml a.ttl -convert sysml -o b.sysml && sysml -validate b.sysml
sysml -e 'Pkg::car.mass' b.sysml      # same value as from model.sysml
```

Compare `-json -validate` outputs or specific `-e` values before and after rather than
diffing text, which legitimately changes layout.
