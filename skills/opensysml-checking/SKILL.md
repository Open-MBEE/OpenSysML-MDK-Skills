---
name: opensysml-checking
description: Verify SysML v2 models with OpenSysML — evaluate constraints, requirements, satisfy assertions, calculations and analysis/verification cases, choose between the run, explore, check (SMT), solve and sweep engines, read `standing:` lines, do bounded model checking of actions and state machines with counterexample witnesses, and script verdicts into CI with exit codes and -json. Use when a task asks whether a model satisfies its requirements, when a constraint comes back undecided, or when selecting an engine or solver.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Checking constraints, requirements and behavior

OpenSysML answers a check with a verdict and a *standing* that says how the verdict was
reached. A verdict is `✓` (holds), `✗` (false) or `?` (undecided / not covered); the
process exit mirrors it (`0`/`1`/`2`; a model that does not analyse cleanly exits `2`
with `error[<code>]` diagnostics before any check). Every check works from the CLI (`opensysml-cli`),
the REPL (`opensysml-repl`) and every language client (`verify_constraint`,
`verify_requirement`, `verify_satisfaction`, `validate_instance`, `run_analysis`).

```text
✓ Constraint Vehicles::Car::massLimit passed
  standing: holds (observed: 1 run under reverse)
```

`observed: N run(s)` means the `run` engine evaluated concrete values under schedule
`reverse`; `proved` means an SMT engine established it for all values in bounds;
`not covered (...)` means no engine could apply, and the parenthesis says why.

## What to check and how

| Model construct | CLI | Notes |
|---|---|---|
| `constraint c { expr }` in a part | `-constraint Pkg::Part::c` | Evaluated with the definition's defaults; add `-instantiate Pkg::usage` to evaluate on a configured object |
| `constraint def C { in x; ... }` | `-constraint 'Pkg::C(3.0)'` | Arguments positional |
| `requirement def R { subject s : T; require constraint {...} }` | `-requirement Pkg::r` on a *usage* `requirement r : R;` | Undecided until the subject is bound |
| `satisfy r by part;` | `-satisfy` (all) or `-satisfy=Pkg::r` | The reliable way to check requirements against parts |
| `calc def F { in a; return : Real = ...; }` | `-calc 'Pkg::F(3, 4)'` | Prints `= value` |
| `analysis def A { ... }` / `verification def V { ... }` | `-analysis 'Pkg::a()'`, `-analysis 'Pkg::V() Pkg::object'` | Reports outputs and the verdict of the case's `verify` |
| Every assertion an object states | `-validate=Pkg::usage` with `-instantiate Pkg::usage` | `? X states no assertion to validate` (exit `2`) when it has none; multiplicity and redefinition mismatches are `-validate` diagnostics (`warning[redefinition-multiplicity]`) |
| Model's own validation rules | `-self-check`, `-self-check-package Pkg` | Applies `SysMLValidation` constraints reflectively |

Several checks can be combined in one invocation; the exit is the worst verdict. Always
pass every file the checked elements depend on. A false constraint prints the assertion:

```text
✗ Constraint F::Car::lim failed
  Assertion evaluated to false: mass < 1000.0
  standing: violated (witnessed: 1 run under reverse)
```

A behavior run reports values that depend on the order of concurrent steps with a marker
(nightly builds and the release after 0.10.1):

```text
  Results:
    x = 1 (order-dependent; 2 choice points — explore shows the set)
```

`-schedule explore -action Pkg::Race` tables every outcome
(`outcome | linearizations | probability | witness`, `complete (3 runs)`) with
`standing: outcomes (proved over schedules: 3 linearizations, inputs as written)`;
`-runs N -seed S -observe x` repeats a run and distributes each observed feature
(`standing: table (observed: N rows)`); see `opensysml-cli`.

## Engines

`sysml -engines` lists what the build knows; `-engines -probe` also starts each external
engine to confirm it works.

| Engine | Decides by | Needs |
|---|---|---|
| `run` (default under `auto`) | Executing the model once with concrete values | nothing |
| `explore` | Many runs under different schedules (`-schedule explore[:runs=N,depth=N]`) | nothing |
| `check` | Bounded model checking of actions/states | SMT solver |
| `smt` | Satisfiability over symbolic values (`%solve`, `%configure`, `%optimize`) | SMT solver |
| `solve` | Satisfiability and configuration (`%solve`, `%configure`, `%optimize`) | SMT solver |
| `sweep` | Parameter ranges (`-sweep 'n=1..8:2'`, `-samples N -seed N`) | nothing |
| `tool:<name>` (`tool:fmi`), external | `OPENSYSML_TOOLS` / `OPENSYSML_ENGINES` manifests (FMI runners, scripts); `-tool-dry-run CALL` previews the call | the tool |

Select with `-engine NAME` (`auto`, `all`, or one name). `auto` lets the engine of highest
authority that covers the question answer (`opensysml-analysis-engines`). For a solver install `z3` or `cvc5`; point
`OPENSYSML_SMT` at it when it is not on PATH, and bound it with `OPENSYSML_SMT_TIMEOUT`.

## Bounded model checking of behavior

```bash
sysml -instantiate Pkg::rover1 -action 'Pkg::Rover::Drive Pkg::rover1' \
      -check-property Pkg::Rover::batteryNonNegative \
      -check-depth 50 -check-unroll 4 -check-states 1000 -check-timeout 60s \
      -check-witness witnesses/ model.sysml
```

- `-check-property NAME`: evaluate a constraint/requirement at every stable state across
  all schedules; a violation prints the schedule and, with `-check-witness DIR`, writes a
  replayable witness. Reproduce with `-schedule replay:witnesses/<file>` or the REPL's
  `%replay`.
- `-check-diverge [feature...]`: report features whose final value depends on schedule.
- `-check-input [feature...]`: treat these inputs symbolically (range over all values).
- `-check-assume NAME`: constraints assumed true while checking.
- `-check-depth` (default 10000 under `check`, 40 under `smt`), `-check-unroll` (4),
  `-check-states` (1000000), `-check-timeout`: bounds; a result within bounds is
  `holds (bounded ...)`, not an unbounded proof, and a reached bound is named `(reached)`.

## Schedules and determinism

Choice points (concurrent actions, overlapping transitions) are resolved by `-schedule`:
`reverse` (default, deterministic), `declared`, `seed:N` (random but reproducible),
`explore`, `replay:FILE`. A value printed with `(order-dependent; …)` under `reverse` or
`declared` is schedule-dependent — usually a modeling defect worth a `-schedule explore` or
`-check-diverge` run. `-record-run` captures an analysis run into the model as
`AnalysisRecords` elements (`-record-into PKG` chooses the package) for later comparison;
`-clock-step S` makes every run tick like a fixed-step simulation tool.

## CI pattern

```bash
set -e
sysml -validate -warnings-as-errors -format sarif -o sysml.sarif model/   # structural gate, SARIF for code scanning
sysml -json -satisfy model/ > satisfy.json || status=$?
python3 - <<'PY'
import json; r=json.load(open("satisfy.json")); print(r["status"]); assert r["status"]=="holds"
PY
```

`-json` emits one object with `status` (`holds`/`fails`/`unresolved`), `exit`, `checks`
(each with `subject`, `status`, `lines` and its engine `plan`), `diagnostics`, `output`,
`errors`. Treat `unresolved` as a failure in CI: it means the gate did not run, not that it
passed. `-format sarif|junit`, `-baseline FILE` (suppress known findings) and
`-warnings-as-errors` are in nightly builds and the release after 0.10.1, as is the
composite GitHub Action `Open-MBEE/OpenSysML@<tag>` that runs the validation gate
(`opensysml-cli`). Pin the `sysml` version (`sysml -version`; this skill was verified with
`sysml v0.10.1-1266-gdada45c11`) and set `OPENSYSML_JOBS`/`-jobs` for speed; keep budgets
explicit (`opensysml-troubleshooting`).
