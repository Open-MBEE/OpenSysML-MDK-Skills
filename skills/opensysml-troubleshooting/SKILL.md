---
name: opensysml-troubleshooting
description: Diagnose OpenSysML problems — read `standing:` lines and ✓/✗/? verdicts, tell "false" from "undecided" from "not covered", fix unresolved references and multi-file loading, tune the OPENSYSML_* environment variables (resource budgets, SMT solver, external engines, library path, parallelism), and recover from client/service version mismatches. Use when `sysml` exits 2 unexpectedly, a check is `?`/undecided, a run hits a step/element/event budget, a solver or external tool is not found, or a language client raises a provisioning, checksum, stale-service or missing-capability error.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Troubleshooting OpenSysML

Work top-down: (1) does the model analyse cleanly? (2) did the check decide? (3) was the
decision what you expected? Each layer has its own signal.

## 1. The model did not analyse cleanly (exit 2)

`sysml: FILE did not analyse cleanly; no check was made` — nothing downstream ran. Read the
*first* diagnostic (`file:line:col: severity[code]: message`); later ones are often
consequences. Every code is explained by `sysml -explain <code>` (REPL `%explain-code`),
with the specification clause behind it; bare `sysml -explain` lists them all (nightly
builds and the release after 0.10.1; verified with `sysml v0.10.1-1266-gdada45c11`).

| Diagnostic | Usual cause / fix |
|---|---|
| `error[unresolved]: unresolved reference: X — did you mean Views::X? To use the bare name, import its package: private import Views::*;` | Missing `import` (stdlib names need `private import ScalarValues::*;` etc.), typo, or the file that declares `X` was not passed to `sysml`. Pass every file or the directory. |
| `error[import-visibility]: import without a visibility indicator` | Write `private import` (or `public import`); a bare `import` is KerML notation. |
| `error[feature-value-overriding]: cannot override the binding value of Pkg::Car::mass ... write it as `default =`` | Definition used `= value`; change to `default = value` so usages can redefine. |
| `error[relationship-target-kind]: satisfy target must be a requirement usage, found requirementDef` / `error[subsetting-featuring-types]: Must be an accessible feature (use dot notation for nesting)` | `satisfy` needs a `requirement r : Def;` usage visible from the `satisfy`, not a def or a nested path. |
| `error[syntax]: expected a namespace member` (and other `error[syntax]`) | Stray `;`, missing `;` or `}`; OpenSysML never fails to parse but reports the error node. Under `-strict`, notation outside the OMG grammar is an error too (`nonstandard-notation`). |
| `warning[redefinition-multiplicity]: Redefining feature should not have smaller multiplicity lower bound` | A usage narrows `[n..m]` below its definition's; fix the usage or the definition. Warnings exit `0` unless `-warnings-as-errors`. |
| `-format bogus is not a report format; the formats are text, json, sarif and junit`, `-render-show: unknown notation element "pins"; the elements are ...` | Usage errors (exit `2`) list the values the flag takes; `sysml -help` has every flag. |

`sysml -validate` on every edit is the cheapest guard; `-json -validate` gives the same
diagnostics structured (`severity`, `message`, `file`, `line`, `column`, `pass`, `code`),
`-format sarif|junit -o FILE` writes them for a CI service, and `-baseline FILE` suppresses
findings a recorded JSON report already knows (an error the baseline knows still stops
analysis, so the exit stays `2`).

## 2. The check did not decide (`?`, exit 2)

The `standing:` line says why:

- `not covered (requirement r: c subject is unbound: bind it (`subject c = <element>`),
  check it on an object, or assert `satisfy r by <element>`)` — do one of the three;
  `-satisfy` is the usual answer.
- `no instance of "X" (use %instantiate first)` — add `-instantiate X` to the
  command, or `%instantiate` in the REPL before `%action`/`%state`.
- `? X states no assertion to validate` from `-validate=X` — the object has no constraint or
  requirement to check; `-validate` without `=X` reports multiplicity and typing findings.
- `undecided` with `<undetermined>` values — an attribute in the expression has neither a
  value nor a default; give one or evaluate on a usage that binds it.
- `undecided (no engine could decide ...)` — the `run` engine needs concrete values; the
  `check`/`smt`/`solve` engines need a solver. `sysml -engines -probe` reports each engine's
  status; install `z3`/`cvc5` and set `OPENSYSML_SMT=/path/to/z3` if it is not on PATH.
  `OPENSYSML_SMT_TIMEOUT` (duration, e.g. `30s`) bounds solver time.
- `execution failed: execution exceeded max steps (N steps; raise OPENSYSML_MAX_ACTION_STEPS
  to allow more), possible infinite loop` — a budget; see §4.
- `-runs draws each run's randomness from a seed; name one, as -seed <number>, or fix the
  draws, as -draws min|max|average` and `-observe names what -runs reports; ask for the runs,
  as -runs <number>` — repeated runs need both flags.
- `-engine NAME` refused the question (`standing: not covered (explore refused: ...)`) — use
  `auto` or an engine whose `answers` cover it (`opensysml-analysis-engines`).

## 3. The check decided, but wrongly

- `✗` with `standing: violated (witnessed: 1 run under reverse)`: the verdict is a real
  evaluation under the default `reverse` schedule, and the line above it names the
  assertion (`Assertion evaluated to false: mass < 1000.0`).
- A result printed as `x = 1 (order-dependent; 2 choice points — explore shows the set)`
  depends on how concurrent steps were ordered: run `-schedule explore` for the whole set,
  `-check-diverge` for the features that diverge, or fix the model's ordering.
- Empty rendering: `note: V::x renders empty` precedes a diagram with nothing in it and the
  reason (nothing exposed, the filter rejects everything, nothing resolves, or nothing the
  view exposes is shown by a rendering of this kind); `-list all` shows what the view is.
- A constraint on a *definition* evaluated with defaults rather than the usage's values:
  check the usage (`-instantiate Pkg::car -constraint Pkg::Car::massLimit`).
- Float surprises: `1500` is an `Integer`; `rounded-real-literal` lint (opt-in) flags
  inexact decimal literals.
- Stdlib behaving unexpectedly: `OPENSYSML_LIBRARY_PATH` overrides the bundled library — unset
  it unless you mean to.

## 4. Resource budgets and performance

Every budget is an environment variable read by `sysml`, `sysml-lsp`, `sysml-grpc` (and
therefore by every language client's private service). Exceeding one produces a budget
diagnostic and exit `2`, never a hang.

| Variable | Governs |
|---|---|
| `OPENSYSML_MAX_STEPS` | Total execution steps per run |
| `OPENSYSML_MAX_ACTION_STEPS` | Steps for one action execution |
| `OPENSYSML_MAX_DO_STEPS` | Steps inside a state's `do` behavior |
| `OPENSYSML_MAX_EVENTS` | Queued/dispatched events for a state machine |
| `OPENSYSML_MAX_ELEMENTS` | Elements created by instantiation |
| `OPENSYSML_MAX_CALC_DEPTH` | Recursion depth of calculations |
| `OPENSYSML_MAX_SWEEP_RUNS` | Runs of one `-sweep` |
| `OPENSYSML_MAX_INTEGER_BITS` | Size of big integers before refusing |
| `OPENSYSML_JOBS` | Default for `-jobs`: concurrent runs/files |
| `OPENSYSML_SMT`, `OPENSYSML_SMT_TIMEOUT` | Solver binary and per-call timeout |
| `OPENSYSML_LIBRARY_PATH`, `OPENSYSML_LIBRARY_ROOTS` | Replace the bundled standard library (a directory or `.kpar`); extra directories to find installed `.project.json` projects under (`-library-root`) |
| `OPENSYSML_RECORD_CACHE=0` | Disable the on-disk record cache (`-no-record-cache`) |
| `FLEXO_INTEROP_TOKEN` | Token `-sync-apply` and branch-URL `-convert` present to a SysML v2 API endpoint |
| `OPENSYSML_TOOLS`, `OPENSYSML_ENGINES`, `OPENSYSML_TOOL_TIMEOUT`, `OPENSYSML_TOOL_MAX_OUTPUT` | External analysis tools/engines, their timeout and output cap |
| `OPENSYSML_GRPC_MAX_HELD_OBJECTS`, `OPENSYSML_GRPC_INDEX_POOL` | Service-side instance and parse-cache limits |
| `OPENSYSML_WEASYPRINT`, `OPENSYSML_PANDOC`, `OPENSYSML_MMDC`, `OPENSYSML_MMDC_PUPPETEER` | PDF/diagram toolchain for `-render-document` |

Set them where the *process doing the work* runs: for a Python/Node client that spawns a
private `sysml-grpc`, that is the client's environment; for a shared service, the
service's. Use `-memstats`, `-cpuprofile FILE`, `-trace` to see where time goes; `-jobs N`
parallelises independent checks and file loads. The full list is
`docs/reference/environment.md` in the OpenSysML repository and `sysml -man`.

## 5. Clients and services

| Symptom | Fix |
|---|---|
| `BinaryNotFoundError` / cannot provision `sysml-grpc` | Install it (`opensysml-install`) and set `OPENSYSML_GRPC_BINARY`, or allow the client's verified download (needs network). |
| `ChecksumMismatchError` | Corrupt or wrong download; delete `~/.opensysml/bin/sysml-grpc*` and retry; never bypass the check. |
| Unpinned-download refusal | A development build of the client; set `OPENSYSML_ALLOW_UNPINNED_DOWNLOAD=1` only for local development, or pin a release binary. |
| `StaleServiceError` / version mismatch | Service older than the client; upgrade the binary or `OPENSYSML_GRPC_BINARY`. |
| `MissingCapabilityError` | The service lacks that feature; check `server_info()` / `GetServerInfo.capabilities` and upgrade or avoid the call (`opensysml-service`). |
| `connection refused` on `OPENSYSML_SERVICE` | Service not running on that address; start `sysml-grpc -port N` and check `/health`. |
| Browser: CORS or mixed-content error | `sysml-grpc -cors-allowed-origins <origin>` and TLS (`-tls-cert/-tls-key`) for non-localhost. |
| Instances disappear between calls | Objects are held by the service; reuse the same `Connection`/model handle and keep it open. |

## 6. Getting help

`sysml -version` identifies the build (include commit and Go version in reports);
`sysml -debug` prints internal diagnostics; `sysml -explain <code>` quotes the clause a
diagnostic enforces, which belongs in a bug report about it. Issues: https://github.com/Open-MBEE/OpenSysML/issues.
Documentation: `docs/guide/10-troubleshooting.md`, `docs/reference/environment.md`.
