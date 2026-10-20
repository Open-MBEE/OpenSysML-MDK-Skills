---
name: opensysml-analysis-engines
description: Choose, inspect and register OpenSysML analysis engines — `sysml -engines [-probe]`, `-engine auto|<name>|all`, built-in engines (run, check, explore, smt, solve, sweep, tool:fmi), the standing/strength vocabulary attached to every verdict (observed, witnessed, bounded, proved, not covered), `-check-*` bounds, external engine manifests under OPENSYSML_ENGINES, and SMT solver setup. Use when a verdict's standing is weaker than needed, when an engine reports unavailable or refuses a question, or when adding a solver or external engine.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML analysis engines

Every check (`-constraint`, `-requirement`, `-satisfy`, `-action`, `-state`, `-analysis`,
`-sweep`, `-calc`) is a question put to an **analysis engine**, and every verdict carries a
**standing** — the claim, the strength of the evidence, and what earned it:

```text
✓ Constraint Rover::MassBudget passed
  standing: holds (observed: 1 run under reverse)
✗ Constraint Rover::Overweight failed
  Assertion evaluated to false: 250.0 <= 200.0
  standing: violated (witnessed: 1 run under reverse)
```

Strengths, weakest first: **not covered** (no claim; the reason follows — engine refused,
solver `unknown`, witness did not replay), **observed** (one execution or an exploration
stopped at its budget), **witnessed** (an existential claim an execution replayed — a
violation, a satisfying assignment), **bounded** (every case within a stated budget),
**proved** (every case). A budget that was reached is named in the standing and lowers the
strength; a reached budget is never a proof.

## List what this build has

```bash
sysml -engines            # table: name, kind, protocol, authority, answers, status
sysml -engines -probe     # also start each external engine, compare its `describe` to the manifest
```

Verified with `sysml v0.10.1-1266-gdada45c11`; a `tool:` engine's manifest details follow
the table (`tool:fmi: tool`).

```text
engine    kind      protocol  authority  answers                     status
check     built-in  -         bounded    outcomes, holds, sensitive  ready
explore   built-in  -         proved     outcomes                    ready
run       built-in  -         observed   evaluate                    ready
smt       built-in  -         proved     holds, sensitive            ready (z3 at /usr/bin/z3)
solve     built-in  -         proved     satisfiable, holds          ready (z3 at /usr/bin/z3)
sweep     built-in  -         observed   sweep                       ready
tool:fmi  tool      fmi/1     observed   compute                     unavailable: OPENSYSML_FMI_RUNNER is not set…
```

- `run` — the interpreter: one execution, *observed*. What `-e`, `-constraint` and
  `-action` use by default.
- `explore` — every linearization of an action/state machine (`-schedule explore`,
  budget `explore:runs=N,depth=D`); *proved* over schedules when it finishes.
- `check` — bounded state-space search with `-check-property`, `-check-diverge`,
  `-check-depth`, `-check-states`, `-check-timeout`, `-check-witness <dir>`; *bounded*.
- `smt` / `solve` — Z3/cvc5-backed proof of constraints/requirements and satisfiability
  (`-check-input`, `-check-assume`, `-check-unroll`); *proved*, or *not covered* on
  `unknown`. Status shows the solver found (`OPENSYSML_SMT=/path/to/z3`, `opensysml-install`).
- `sweep` — `-sweep 'x=1..10:1' -samples N -seed S -draws <policy>` tables; *observed*.
  `-runs N -seed S -observe x` (nightly builds and the release after 0.10.1) repeats one
  action or a `Simulation::MonteCarlo` analysis and distributes each observable
  (`standing: table (observed: N rows)`); `-clock-step S` fixes the clock's step.
- `tool:fmi` — evaluates a `calc def` imported from an FMU through `OPENSYSML_FMI_RUNNER`
  (a `fmpy`-based runner program); see `docs/reference/fmi.md`. `-tool-dry-run CALL`
  shows what any `ToolExecution`-annotated case or action would hand its tool (manifest,
  argv, environment, stdin, reply mapping) without starting it; `no ToolExecution-annotated
  action was reached; nothing to preview` when the call names none.

The REPL equivalents are `%engines`, `%engines probe` and `%engine <name>`; the service
exposes `ListEngines` and an `engine` field on verification requests, and (nightly) takes
the run options too — `advance`, `seed`, `draws`, `clock_step` on execution requests,
`tool_dry_run` on `RunAnalysis`, `RunRuns` for `-runs`; clients pass `engine=` /
`WithEngine(...)` (`opensysml-service`, library skills).

## Selecting an engine

```bash
sysml -constraint Rover::MassBudget model.sysml                   # -engine auto (default)
sysml -engine smt -requirement Rover::MassReq model.sysml         # this engine alone
sysml -engine all -constraint Rover::MassBudget model.sysml       # every covering engine, composed
sysml -engine explore -action Rover::Drive -instantiate Rover::r1 model.sysml
sysml -engine check -action Rover::Drive -instantiate Rover::r1 \
      -check-property Rover::Safe -check-depth 200 -check-timeout 30s model.sysml
```

- `auto`: the engine of highest authority that covers the question answers; one that
  refuses or answers *not covered* is passed over for the next (each kept in the `plan`).
  External engines are reached only after every built-in engine refused.
- `-engine tool:<name>` names one external tool engine; `-engine <name>`: that engine alone; its refusal **is** the verdict (exit 2,
  `? … could not be evaluated … standing: not covered (explore refused: explore does not
  answer evaluate questions)`). Match the engine to the question kinds it `answers`.
- `-engine all`: composes — a witnessed violation beats any universal claim; agreeing
  universal claims stand at the strongest strength any earned; differing observed values
  become a witnessed sensitivity; a universal claim refuted by an execution is demoted with a
  **disagreement** recorded. The standing lists each engine's part: `…; all: run holds (observed)`.
- `-jobs <n>` runs independent rows/linearizations/engines concurrently.
- An unknown name is refused before anything runs (exit 2).
- `-json` adds `plan` and `results[]` per check so a pipeline can assert on the strength
  (`opensysml-cli`), e.g. require `proved` for safety requirements and accept `observed`
  for smoke checks.

## External engines

An external engine is a process speaking the `stdio/1` protocol, registered by a JSON
manifest in the directory `OPENSYSML_ENGINES` names (one file per entry, read at startup):

```json
{
  "kind": "engine",
  "name": "spin-bridge",
  "version": "1.4.0",
  "command": ["spin-bridge", "--serve"],
  "protocol": 1,
  "answers": ["outcomes", "holds"],
  "witness": "schedule",
  "authority": "bounded"
}
```

`command` paths are relative to the manifest's directory unless absolute; unknown members
are refused; `-engines -probe` verifies `describe` against `version`/`protocol`/`answers`
and reports `ready (…; describe agrees)` or the first disagreement. An external answer
stands only at the strength the interpreter's **replay of its witness** earns, never at
what it claimed; a process that does not answer within `OPENSYSML_TOOL_TIMEOUT` is reported
as such. Full protocol, result shape, failures and bounds: `docs/reference/external-engines.md`.

## Troubleshooting standings

| Symptom | Meaning / action |
|---|---|
| `standing: not covered (… refused …)` | Wrong engine for the question; use `auto` or one whose `answers` include it |
| `not covered (solver answered unknown)` | Increase `-check-timeout`/`-check-unroll`, simplify the constraint, or accept `check`'s bounded answer |
| `(reached)` in the standing | Budget hit: raise `-check-depth` (10000 under `check`, 40 under `smt`)/`-check-states` (1000000)/`explore:runs=`; the claim is only observed/bounded |
| `x = 1 (order-dependent; 2 choice points — explore shows the set)` | The `run` engine's value stands on an unordered choice; `-schedule explore` tables every outcome with `standing: outcomes (proved over schedules: …)` |
| `unavailable: … z3 …` | Install Z3 or cvc5 and set `OPENSYSML_SMT`; `smt`/`solve` then show `ready (z3 at …)` |
| `unavailable: OPENSYSML_FMI_RUNNER is not set` | Only matters for FMU-backed calcs; set the runner or ignore |
| Exit 2 with `?` verdicts in CI | Undecided is not false — decide whether the gate needs a stronger engine or should treat undecided as failure (`opensysml-checking`) |
