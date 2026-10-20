---
name: opensysml-cli
description: Drive the `sysml` command non-interactively — validate SysML v2/KerML files (text, JSON, SARIF or JUnit reports, baselines, warnings as errors, the GitHub Action), evaluate expressions, instantiate parts, check constraints and requirements, run actions/states and analyses (repeated runs, clock step, external tools), read order-dependence markers, explain diagnostic codes with -explain, and interpret exit statuses 0/1/2/3. Use when scripting or CI needs to validate or question a model from the shell, when an agent must check its own edits to a .sysml file, or when a `sysml` invocation returns an unexpected status or "did not analyse cleanly".
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Using the `sysml` CLI

`sysml [options] [file...]` loads every file named (`.sysml`, `.kerml`, directories, globs,
`.ipynb` notebooks, API element-form `.json`, `.kpar` project archives), then performs the
operation the flags select. With no operation flag and no stdin, it opens the REPL (see
`opensysml-repl`). Each file is a document of its own, but the files named are indexed
together, so one file's reference to a package another declares resolves; a root-level
`import` serves only the file it is written in. The standard library (`ScalarValues`, `ISQ`,
`SI`, ...) is bundled and always available to `import`.

Install first if `sysml -version` fails (see `opensysml-install`). `sysml -man` is the full
manual; `sysml -help` lists every flag. Verified with `sysml v0.10.1-1266-gdada45c11`
(a development build after the v0.10.1 release); features marked *nightly* below are in
nightly builds and the release after 0.10.1, not in v0.10.1.

## Exit status is the verdict

| Exit | Meaning |
|---|---|
| `0` | The model answered and the answer is positive (no errors, constraint holds, ...) |
| `1` | The model answered negatively (constraint false, requirement violated, ...) |
| `2` | No decision: parse/semantic errors, unbound subject, usage error, unresolved tool, budget exhausted |
| `3` | `-render-documents` wrote some documents and failed on others |

Diagnostics go to stderr as `file:line:col: severity[code]: message` followed by the source
line and a caret (*nightly*: earlier builds print no `[code]`):

```text
broken.sysml:2:5: error[import-visibility]: import without a visibility indicator: SysML v2 requires public, private or protected before 'import'
    import ScalarValues::*;
    ^~~~~~
broken.sysml:5:14: error[unresolved]: unresolved reference: Engine
    part e : Engine;
             ^~~~~~
sysml: broken.sysml did not analyse cleanly; no check was made
```

The last line means the model has errors and the requested operation did not run — fix the
errors first; the exit is `2`, not `1`. `sysml -explain <code>` (repeatable) prints what a
code means, how to resolve it and the specification clause behind it; bare `sysml -explain`
lists every code with a one-line summary, grouped by pass (Syntax, Name resolution, ...).
When piping through other tools remember the pipeline's exit is the last command's.

## Validating

```bash
sysml -validate model.sysml                     # parse + name resolution + typing + constraints
sysml -validate -strict model.sysml             # strict OMG conformance: notation leniencies become errors
sysml -validate -warnings-as-errors model.sysml # exit 2 on a warning too (severity stays "warning" in the report)
sysml -validate -enable-lint rounded-real-literal model.sysml   # opt-in lint; -disable-lint CODE silences one
sysml -validate=Pkg::car -instantiate Pkg::car model.sysml      # check every assertion about that object
```

A clean run prints `✓ package Vehicles` per root package and `✓ model.sysml: no errors`.
Lints that are on by default: `undeclared-signal`, `port-type-mismatch`,
`deferred-keeper-unmarked`; opt-in: `rounded-real-literal`. `-validate=<object>` reports
`? <object> states no assertion to validate` (exit `2`) when the object has nothing to check.

### Reports for CI (`-format`, `-o`, `-baseline`)

```bash
sysml -validate -json model.sysml                           # one JSON object on stdout (same as -format json)
sysml -validate -format sarif -o sysml.sarif model.sysml    # SARIF 2.1.0 for GitHub code scanning
sysml -validate -format junit -o sysml.xml model.sysml      # JUnit XML for a CI test tab
sysml -validate -json -o baseline.json model.sysml          # record today's findings ...
sysml -validate -baseline baseline.json model.sysml         # ... and suppress them later (same code, file, message; any line)
```

`-format text|json|sarif|junit` (*nightly*) applies to any check, not only `-validate`; `-o`
writes the non-text report to a file instead of stdout. A SARIF report carries one rule per
diagnostic code (`ruleId`), each finding's severity as its `level` and its file relative to the
working directory. A JUnit report has one `<testsuite>` per file with a `<testcase>` per
finding (`import-visibility at 2:5`) and a run-level `<error>` when analysis stopped. With
`-baseline`, `N known finding(s) suppressed by FILE` is printed; a *baselined error* still
stops analysis (`an error the baseline knows stopped analysis before the later tiers ran`),
so the exit stays `2` — baselines are for warnings and for findings you are tracking, not a
way to pass a broken model.

The composite GitHub Action `Open-MBEE/OpenSysML@<tag>` (*nightly*; `action.yml` at the
repository root) installs a release and runs `sysml -validate`; inputs `path`, `format`
(default `sarif`), `baseline`, `warnings-as-errors`, `strict`, `library-path`, `version`,
`install`, `upload-sarif`, `sarif-file`; outputs `exit-code` and `sarif-file`:

```yaml
- uses: Open-MBEE/OpenSysML@v0.10.1
  with:
    path: model/
    warnings-as-errors: "true"
```

## Questioning a model

```bash
sysml -e 'Pkg::car.mass' -e '2 + 3 * 4' model.sysml   # evaluate expressions (repeatable -e)
sysml -instantiate Pkg::car model.sysml         # build an instance tree and report it
sysml -constraint Pkg::Car::massLimit model.sysml      # check one constraint; exit 0 holds / 1 fails
sysml -requirement Pkg::massReq model.sysml     # check a requirement usage (needs a bound subject)
sysml -satisfy=Pkg::massReq model.sysml         # one `satisfy ... by ...` assertion; bare -satisfy checks all
sysml -calc 'Pkg::Range(50.0)' model.sysml      # invoke a calculation with arguments
sysml -analysis 'Pkg::rangeStudy()' model.sysml # run an analysis or verification case
sysml -query 'oslc.where=sysml:type="PartDefinition"' model.sysml   # OSLC query
sysml -run-query "Reports::Violated root=Pkg::car" model.sysml      # a DocumentQueries query, rows and columns
sysml -self-check model.sysml                   # the model's own SysMLValidation rules, reflectively
```

Names use `::` paths; quote names containing spaces or punctuation:
`-instantiate "Pkg::'SA-506'"`. Output lines start with `✓` (holds / done), `✗` (false),
`?` (undecided) and include a `standing:` line explaining how the verdict was reached:

```text
✓ Constraint Vehicles::Car::massLimit passed
  standing: holds (observed: 1 run under reverse)
✗ Constraint F::Car::lim failed
  Assertion evaluated to false: mass < 1000.0
  standing: violated (witnessed: 1 run under reverse)
```

`-run-query` binds query parameters as `name=expression` (`root=Pkg::car`; an object
`-instantiate` created is bound by its name while the run holds it) and prints
`✓ Query Reports::Violated returned 12 rows`, the `Columns:` line and one block per row; a
parameter left unbound is refused with `query X requires binding root`.

`-json` (or `-format json`) emits a single object for scripting; pair it with a check:

```bash
sysml -json -validate model.sysml
# {"status":"holds","exit":0,"checks":null,"diagnostics":null,"output":[...],"errors":null}
```

`status` is `holds`, `fails` or `unresolved`; `diagnostics[]` entries carry
`severity`, `message`, `file`, `line`, `column`, `pass` and `code`; `checks[]` entries carry
`subject`, `status`, `values`, `lines`, `rows` and the engine `plan` with its `standing`.

## Running behavior

```bash
sysml -instantiate Pkg::rover1 -action 'Pkg::Rover::Drive Pkg::rover1' model.sysml   # action on an object
sysml -instantiate Pkg::rover1 -state 'Pkg::Rover::Modes Pkg::rover1' -advance 10 model.sysml  # state machine for 10 time units
sysml -action Pkg::Race -trace model.sysml      # print every step
sysml -action Pkg::Race -runs 20 -seed 7 -observe x -observe clock model.sysml   # repeat, table and distribute
sysml -action Pkg::Race -runs 20 -draws min model.sysml    # no seed needed when draws are fixed (min|max|average)
sysml -action Pkg::Race -clock-step 1 model.sysml          # fixed-step clock: waits come due on the next multiple
sysml -tool-dry-run 'Pkg::thermalCase() Pkg::sat' model.sysml   # preview an external tool's call without starting it
sysml -record-run 'Pkg::rangeStudy()' -record-into Pkg::Records model.sysml   # record an analysis run into the model
sysml -compare-results results.json -runs 100 -seed 1 migrated.sysml   # rerun a tool's stored configurations and table the differences
```

Use cases execute under `-action` like actions (*nightly*). A default run of a behavior with
concurrent, conflicting writes reports its values only up to the order the Kernel Semantic
Library fixes and marks the rest:

```text
✓ Action completed
  Final state: Completed
  2 choice points; %trace on to see them
  Results:
    x = 1 (order-dependent; 2 choice points — explore shows the set)
    y = 2 (order-dependent; 2 choice points — explore shows the set)
  standing: value (observed: 1 run under reverse)
```

`-schedule explore -action Pkg::Race` then tables every outcome
(`outcome | linearizations | probability | witness`) with
`standing: outcomes (proved over schedules: 3 linearizations, inputs as written)`.

`-runs <n>` prints `runs Pkg::Race — 20 run(s), seed 7`, a `run | x | clock | time` table
and a `min/mean/max/p50/p90` line plus histogram per observed feature (`standing: table
(observed: 20 rows)`); `-observe` without `-runs`, or `-runs` without `-seed` or a fixed
`-draws`, is refused with a message naming the missing flag. `-tool-dry-run` reports
`no ToolExecution-annotated action was reached; nothing to preview` when the case names no
external tool. `-runs`, `-observe`, `-clock-step`, `-tool-dry-run`, `-record-into` and
`-compare-results` are *nightly*; `-compare-results` reads the JSON `-migrate
-migration-results` wrote (see `opensysml-migrate-v1`).

## Behavior and verification controls

- `-schedule reverse|declared|seed:N|explore[:runs=N,depth=N]|replay:FILE` chooses how
  concurrent choices are ordered; `explore` runs every linearization and reports the set.
- `-engine auto|run|explore|check|smt|sweep|solve|all|tool:<name>` selects how a constraint or
  requirement is decided; `-engines [-probe]` lists engines and whether an SMT solver was
  found (`opensysml-analysis-engines`). Install `z3` or `cvc5` for `check`/`smt`/`solve`.
- `-check-property NAME`, `-check-diverge`, `-check-input`, `-check-assume`, `-check-witness`,
  `-check-depth N`, `-check-unroll N`, `-check-states N`, `-check-timeout DUR` configure
  bounded model checking of actions/states; a counterexample witness is replayable with
  `-schedule replay:FILE` (`opensysml-checking`).
- `-sweep 'n=1..8:2'` (several ranges allowed) runs `-analysis`/`-calc` once per value,
  `-samples N -seed N` draws values instead; `-jobs N` parallelises independent work.
- Resource budgets come from `OPENSYSML_MAX_STEPS`, `OPENSYSML_MAX_ACTION_STEPS`,
  `OPENSYSML_MAX_EVENTS`, `OPENSYSML_MAX_ELEMENTS`, `OPENSYSML_MAX_CALC_DEPTH`,
  `OPENSYSML_MAX_SWEEP_RUNS`, `OPENSYSML_MAX_INTEGER_BITS`; a run that hits one exits `2`
  with `execution failed: execution exceeded max steps (N steps; raise
  OPENSYSML_MAX_ACTION_STEPS to allow more)` rather than hanging.

## Projects, libraries and archives

- A directory holding a `.project.json` is an OMG project-interchange project (*nightly*);
  naming it loads its files and the installed projects its `usage` entries name, looked for
  under the project's own library directory (`.sysand/lib`) and under every directory
  `-library-root DIR` adds (repeatable or `PATH`-style; also `OPENSYSML_LIBRARY_ROOTS`).
- `.kpar` archives are read wherever a project directory is: beside a model on the command
  line, under a library root, or as `OPENSYSML_LIBRARY_PATH` in place of the bundled library.
  `sysml -bundle proj -o widgets.kpar` writes one (`wrote widgets.kpar (Widgets 1.0.0, 4
  files)`; without `-o`, `<name>-<version>.kpar`); `sysml -unbundle widgets.kpar -o dir`
  unpacks it.
- `OPENSYSML_LIBRARY_PATH` replaces the bundled standard library with a directory, a `.kpar`
  archive or a directory of the OMG archives.

## Other operations (each has its own skill)

- Conversion/export: `-convert sysml|kerml|ttl|api-json [-id qualified|uuid] -o OUT`
  (`opensysml-convert-rdf`).
- SysML v1 migration: `-migrate sysml -o OUT model.xmi` (`opensysml-migrate-v1`).
- Documents and diagrams: `-render-document NAME -doc-form markdown|html|pdf`, `-render VIEW`
  with `-render-form`, `-render-show`, `-render-depth`, `-render-lines`, `-render-run
  timeline|sequence=PATH`, `-list [-list-kind KIND]` (`opensysml-documents`).
- Imports from tables: `-import data.csv -import-as values` (with `-import-map`,
  `-import-format`), then `-convert sysml -o OUT` writes the result; `-import-dry-run` previews.
- Code generation: `-compile Pkg::Fib -target c|go -o fib`; `-source` writes the generated
  source to `-o` instead of an executable.
- Flexo MMS / SysML v2 API sync: `-sync-diff REPO` (a `.ttl` graph or an API branch URL;
  never writes), `-sync-apply URL` (token from `FLEXO_INTEROP_TOKEN`), with `-sync-base FILE`
  (last-seen graph, so repository changes surface as conflicts), `-sync-state FILE` (default
  `<model>.sync.json`), `-sync-confirm-deletes`, `-sync-mint-ids` and `-sync-annotate FILE`;
  a conflicting change set exits `1`.
- Diagnostics: `-debug`, `-quiet`, `-memstats`, `-cpuprofile FILE`, `-memprofile FILE`.

## Agent workflow for editing a model

1. Run `sysml -validate FILE` after every edit; stop on exit `2` and read the first
   diagnostic — later ones are often consequences of it. `sysml -explain <code>` when the
   message is not enough.
2. Confirm values with `-e` before asserting constraints; `<undetermined>` means the
   expression depends on an unbound feature, `<unset>` means no value was given.
3. Use `-constraint`/`-requirement` with the *usage* or *definition* path the model declares;
   requirements need a subject (`subject c = part` in the model, or check via
   `-satisfy`), otherwise the result is `not covered` with exit `2`.
4. For reproducibility in CI, pin the binary version (`sysml -version`) and prefer `-json`,
   `-format sarif` or `-format junit` over parsing text.

## Pitfalls

- Passing a file that imports another package without passing that package's file yields
  `error[unresolved]: unresolved reference: X`; pass both files or the directory.
- `-e` on an unbound attribute of a *definition* returns its default, not an instance value;
  evaluate on the usage (`Pkg::car.mass`) for the configured value.
- `-json` without a check flag returns `status: unresolved` and exit `2` by design.
- Exit `0` printed after a pipe through `head` is `head`'s status, not `sysml`'s.
- `-format sarif|junit` still prints `did not analyse cleanly` on stderr; the report is on
  stdout (or in `-o`).
