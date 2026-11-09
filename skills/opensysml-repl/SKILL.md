---
name: opensysml-repl
description: Use the interactive `sysml` REPL — load models, search and print elements, instantiate objects, evaluate expressions, check constraints/requirements, step actions and drive state machines with signals and simulated time, run analyses and sweeps, render views, and record/replay runs — including how to script it non-interactively from stdin. Use when a task needs stateful exploration of a SysML model (objects that persist between questions), when sending events to a running state machine, or when a `%` command is reported unknown.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# The `sysml` REPL

`sysml` with no operation flag (and files optionally named on the command line) opens the
REPL:

```text
SysML v2 REPL — %help for commands, Ctrl-D to exit
Lines starting with % are commands; anything else is SysML notation.
```

Anything you type that does not start with `%` is parsed as SysML and added to the live
model, so you can declare a `package` or a `part` and immediately question it. Objects you
instantiate persist for the session — the main reason to prefer the REPL over repeated
`sysml -e` calls (see `opensysml-cli`). `sysml -man` and `%help` describe every command;
`%help <command>` gives one.

## Scripting it

Pipe commands on stdin; the REPL exits at EOF and its status is `0` unless a command
failed. Prefer this to expecting a TTY:

```bash
printf '%%load vehicle.sysml\n%%instantiate Vehicles::myCar\n%%eval myCar.mass\n%%constraint Vehicles::Car::massLimit\n' | sysml
```

Pass `-strict` to load under strict conformance; the banner goes to stderr. Verified with
the 0.12.0 release build (`sysml v0.11.0-1980-g72c5b132f`, built from `release/0.12.0`).

## Session and model commands

| Command | Effect |
|---|---|
| `%load [--cells SEL] PATH...` | Load files/dirs/globs (`.sysml`, `.kerml`, `.ipynb`, `.json`, `.kpar`); `--cells 1,3-5` or `tag:<tag>` picks notebook cells |
| `%load [--id=ID] [--name=NAME] [--branch=B] [NAME]` | Load a repository project's model from the `%repo` server |
| `%print [NAME]` | Pretty-print the model or one element in SysML notation |
| `%search SUBSTRING` | Find elements by name |
| `%list`, `%documents`, `%views [diagrams] [kind...]` | Session declarations; documents by the names `%render-document` reads; views (and their kinds) by the names `%render` reads |
| `%workspace` | The directory a root namespace nothing declares is looked for under: a submission naming `Vehicles::car` loads the `.sysml`/`.kerml` file under it that declares `Vehicles`, as `%load` would, in the same submission |
| `%builtins` | List the bundled standard-library packages |
| `%save FILE` | Write the live model (`.sysml`, `.ttl`, `.json` by extension) |
| `%clear` | Drop the model and all objects |
| `%strict [on\|off]`, `%lint [CODE on\|off]`, `%verbosity quiet\|normal\|debug`, `%trace on\|off` | Session settings; `%lint` alone lists the lints and their state |
| `%explain-code [CODE...]` | Explain a diagnostic code (`unresolved: error (name-resolution)` …, with the specification clause); bare, list every code |
| `%query OSLC` | OSLC Query text over the session's model (`%query oslc.where=rdf:type=sysml:PartUsage and sysml:owner{sysml:name="Car"}&oslc.select=sysml:name`); in nightly builds and the release after v0.12.1 it runs as a document-query plan, and `rdf:type=elmt:<id>` (`elmt:Garage__Wheel`, the RDF export's id of the qualified name) selects the objects `%instantiate` created of that element, each printed under its path — `Garage::car.wheels[1]  Garage::Car::wheels  PartUsage  sysx:pressure=30` — with `sysx:<feature>` reading the object's own features; an unknown property is refused naming the nearest (`error: query %query references unknown property pressur — did you mean pressure?`), OSLC `or` with `OSLC Query has no "or"`; `%run-query NAME [p=expr...]` runs a QVTS query (a `calc def … :> DocumentQueries::Query`) and prints its rows, or the `path error at …`/model-error lines when the model cannot answer it (`opensysml-qvts`) |
| `%repo [URL]`, `%projects`, `%publish [-d] [--project=P] [--branch=B] NAME` | SysML v2 API repository workflow (`FLEXO_SYSMLV2_URL`, token in `FLEXO_INTEROP_TOKEN`) |
| `%quit` (also `%exit`) | Exit |

## Objects and values

```text
%instantiate Vehicles::myCar          # object #1 of the usage (or of a definition)
%instances                            # list live objects with their ids
%features myCar [all|depth N] [json]  # feature values of an object; json writes the object graph as the API does
%eval myCar.mass                      # expression in the model scope
%eval in myCar : mass * 2.0           # expression evaluated inside an object
%invoke myCar <op> [<expr>...]        # call an operation on an object
%validate myCar                       # validate an object against its type and multiplicities
```

`%eval` reports `<undetermined>` for values that depend on unbound features and `<unset>`
for features without a value (see `opensysml-sysml-authoring`). A `= …` result line shows
the values the result holds in its effective multiplicity: `2 + 2` answers `4`, `add(2, 2)`
(a calc returning `[0..*]`) answers `[4]`, and a `[0..*]` feature nothing binds answers `[]`.
`%instantiate` of the same usage twice makes two objects (`#1`, `#2`), each checked on its own.

## Checking

```text
%constraint Vehicles::Car::massLimit  # ✓ holds / ✗ false / ? undecided, with a `standing:` line
%requirement Vehicles::massReq        # evaluates the requirement and its verification cases
%satisfy [name]                       # all `satisfy ... by ...` assertions, or one
%check NAME                           # bounded model checking (needs an SMT solver)
%explain NAME                         # ask the SMT solver which conditions of an assertion fail (not %explain-code)
%solve NAME | %configure NAME [v=variant...] | %optimize NAME   # SMT-backed
%engines [probe] | %engine NAME|auto|all                        # choose analysis engine
%check-property NAME | %check-diverge | %check-input | %check-assume | %check-witness DIR | %check-bounds depth=N states=N unroll=N timeout=DUR
%replay WITNESS                       # replay a counterexample from %check-witness
```

## Running behavior

```text
%action Drive rover1                  # run an action to completion on an object
%step | %continue | %tokens | %break NODE | %stop     # single-step an action
%state Modes rover1                   # start a state machine on an object
%current                              # current state(s)
%send Go to rover1                    # queue a signal; %send Go(speed=2.0) to rover1 passes attributes
                                      # then %step or %advance T dispatches it
%events                               # pending events
%advance 5                            # advance the shared simulated clock
%schedule reverse|declared|seed:N     # choice-point policy; %seed N fixes draws
%draws random|min|max|average | %clock-step SECONDS | %budget | %jobs N
```

Behavior commands take the *definition or usage name* followed by the object to run on. A
state machine stays alive between commands, so `%send` / `%advance` / `%current` form a
conversation with it (`%advance 5` answers `No pending work - simulation time is now 5.0`
and why it quiesced). `%schedule explore` is refused in the REPL — exploration replays a
behavior once per linearization, which the stepping `%action`/`%state` cannot do; run
`sysml -schedule explore -action NAME` instead. A default run marks values that depend on
the order of concurrent steps: `x = 1 (order-dependent; 2 choice points — explore shows
the set)`.

## Analyses, sweeps, rendering

```text
%calc Range 50.0                      # calculation with positional arguments
%analysis rangeStudy(10) rover1       # analysis or verification case on an object
%record rangeStudy(10) rover1 into Pkg    # run and record AnalysisRecords into the model
%sweep rangeStudy() rover1 n=1..8:2   # one run per value; %samples N SEED name draws instead
%runs 20 7 Race x clock               # run an action 20 times (seed 7; no seed under %draws min|max|average), table and distribute x and the clock
%run-query Reports::Violated root=car # a QVTS/DocumentQueries query, rows and columns (opensysml-qvts)
%run-query inline Project(WhereType(Descendants(Named("Pkg")), "PartUsage"), ("name", "mass"))   # the query body inline (reported as `Inline query`)
%tool case|action(args) [object]      # run via an external tool (OPENSYSML_TOOLS)
%import data.csv [map map.json] [format csv|tsv|json|jsonl] [dry-run]   # set feature values from a table
%view NAME | %graphs NAME | %render NAME [form [palette] [style] [ports] [link=T] [depth=N]]
%render NAME drawio                   # the diagrams.net (draw.io) file on stdout
%viz [--view=TREE|STATE|...] [--style=S...] [form] NAME...   # draw elements with no view declared
%render-document NAME [mermaid|dot|plantuml|d2 [pilot|cameo]]
%render-run timeline|sequence [form] [link=T]   # diagram of the recorded run (needs %trace on before the run)
```

`%render` prints the text form by default (`V::carTree - tree rendering (render
asTreeDiagram)`, an indented tree, then `not represented:`); `depth=1` marks deeper
elements `(nested deeper than 1 level; not shown)`. `%render-run` without a trace answers
`error: the session records no trace; %trace on before the run`. Rendering to images and
documents can need external tools; see `opensysml-documents`.

## Failure modes

- `unknown command "%foo" (try %help)`: commands are lowercase with hyphens
  (`%check-property`, `%render-document`).
- `error: no instance of "Pkg::rover1" (use %instantiate first)`: behavior and object
  commands need an object; `%instantiate X` first, then refer to it by name or `#id`.
- `error: unresolved reference: Nope — did you mean ...?`: the name is not in the loaded
  model; `%search` finds the spelling, `%explain-code unresolved` the rule. A root namespace
  no loaded file declares is looked for under `%workspace` first (a file declaring it there
  loads on its own), so an unexpected load means a stray file under that directory.
- `%run-query` answers `query X names no element …` / `reads feature m of …, which has no
  such feature`: the query is wrong about the model (a path error), not the session — the
  `nearest:` hint names the spelling; `returned 0 rows` is a valid empty answer.
- `%run-query inline <expression>` runs the body without a named query; the word `inline` is
  only the inline form when what follows is an expression — `%run-query inline root=car`
  (first argument shaped `<parameter>=<expression>`) runs a query actually named `inline`. A
  fault in the text is positioned within it (`inline query 1:30: expected ')'`).
- A `%send` is ignored: the signal type must be one a transition `accept`s and the state
  machine must have been started with `%state`; check `%current` and `%events`.
- Infinite-looking `%action`: budgets (`%budget`, `OPENSYSML_MAX_ACTION_STEPS`) stop it and
  report a budget diagnostic; lower them while exploring.
