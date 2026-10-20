---
name: opensysml-sysml-authoring
description: Write SysML v2 / KerML textual notation that OpenSysML accepts and can execute — packages, imports from the bundled standard library, part/attribute/port definitions and usages, defaults vs fixed values, constraints, requirements with bound subjects, actions, states and calculations — and fix the diagnostics `sysml -validate` reports. Use when generating or editing .sysml/.kerml files for OpenSysML, when a model fails to analyse cleanly, or when a value evaluates to <undetermined> or <unset>.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Authoring SysML v2 for OpenSysML

OpenSysML implements the OMG SysML v2 / KerML textual notation. Validate every edit
with `sysml -validate FILE` (exit `0` clean, `2` errors; see `opensysml-cli`) and read the
first diagnostic first. Every diagnostic carries a stable kebab-case code
(`error[unresolved]: …`; nightly builds and the release after 0.10.1), and
`sysml -explain <code>` (REPL `%explain-code <code>`) prints what it means, how to resolve it
and the specification clause behind it. `sysml -validate -strict` additionally rejects notation the OMG
grammars do not admit; use it when the file must also load in other tools. This skill is
about notation the tool accepts; for how to *shape* the model (actors, associations,
stereotypes, constraints, instances, views) see `opensysml-modeling-best-practices`.

## Skeleton that validates and runs

```sysml
package Vehicles {
    private import ScalarValues::*;          // Real, Integer, Boolean, String
    private import ISQ::*;                   // quantity kinds such as MassValue
    private import SI::*;                    // units such as kg, m

    part def Wheel { attribute diameter : Real; }

    part def Car {
        attribute mass : Real default = 1200.0;   // `default =` lets usages override
        part wheels : Wheel[4];
        constraint massLimit { mass < 1500.0 }
        requirement def MassReq {
            subject c : Car;
            require constraint { c.mass < 1500.0 }
        }
    }

    part myCar : Car { attribute :>> mass = 1300.0; }   // redefine the default
    requirement massReq : Car::MassReq;                 // a usage is what `satisfy` targets
    satisfy massReq by myCar;                           // binds the subject
}
```

```bash
sysml -validate vehicle.sysml     # ✓ package Vehicles / ✓ vehicle.sysml: no errors
sysml -e 'Vehicles::myCar.mass' vehicle.sysml          # = 1300.0
sysml -constraint Vehicles::Car::massLimit vehicle.sysml   # ✓ Constraint Vehicles::Car::massLimit passed
sysml -satisfy vehicle.sysml      # ✓ satisfy massReq by myCar holds (on Vehicles::myCar ID: 1)
```

Verified with `sysml v0.10.1-1266-gdada45c11`.

## Rules the checker enforces that trip generated models

- **`import` needs a visibility.** `import ScalarValues::*;` is KerML notation;
  SysML v2 wants `private import` (or `public import` to re-export):
  `error[import-visibility]: import without a visibility indicator: SysML v2 requires
  public, private or protected before 'import'`.
- **`=` is fixed, `default =` is overridable.** `attribute mass : Real = 1200.0;` on a
  definition cannot be redefined with `:>> mass = ...` in a usage:
  `error[feature-value-overriding]: cannot override the binding value of Pkg::Car::mass: a
  value written with `=` is fixed for every feature redefining it; write it as `default =`
  on Pkg::Car::mass to allow overriding, or remove this value`. Use `default =` on
  definitions, `=` on the usage that pins the value.
- **Imports are per package and per file.** `ScalarValues::Real` is not visible until the
  package (or an enclosing one) imports `ScalarValues::*` or qualifies the name; a root-level
  import serves only the file it is written in. Unresolved names report
  `error[unresolved]: unresolved reference: X — did you mean Views::X? To use the bare name,
  import its package: private import Views::*;`.
- **Files are indexed together, not merged.** Pass every dependent file to `sysml` (or the
  directory); a reference to a package another named file declares resolves. Two files that
  both declare a root `package A` are two root packages of that name, not a merge.
- **Requirements need a subject.** `-requirement` on a requirement usage with an unbound
  `subject` reports `? Requirement Pkg::massReq could not be evaluated` and
  `standing: not covered (requirement massReq: c subject is unbound: bind it (`subject c =
  <element>`), check it on an object, or assert `satisfy massReq by <element>`)`, exit `2`.
  Declare a usage beside the parts (`requirement r : R;`), assert `satisfy r by part;` and
  check it with `-satisfy`. `satisfy` targets a usage, not a def
  (`error[relationship-target-kind]: satisfy target must be a requirement usage, found
  requirementDef`), and the usage must be reachable as a plain feature from the `satisfy` —
  declaring it inside the part def and writing `satisfy Car::r` fails with
  `error[subsetting-featuring-types]: Must be an accessible feature (use dot notation for
  nesting)`.
- **Running behavior on an object needs the object.** `-action`/`-state 'Name object'`
  report `no instance of "Pkg::rover1" (use %instantiate first)` unless the same command
  also passes `-instantiate Pkg::rover1`.
- **Multiplicities are checked on redefinition and instantiation.** `part wheels : Wheel[4]`
  instantiates four wheels; redefining it as `Wheel[1]` draws
  `warning[redefinition-multiplicity]: Redefining feature should not have smaller
  multiplicity lower bound` (an error under `-warnings-as-errors`).
- **A stray token is a syntax error with a code too**: `part x : Car;;` gives
  `error[syntax]: expected a namespace member`; the parser never stops, so later
  diagnostics may be consequences.
- **Names with spaces or punctuation** are quoted with single quotes in the model
  (`part 'SA-506' : Stage;`) and on the command line (`-instantiate "Pkg::'SA-506'"`).
- **Values**: `<undetermined>` means the expression depends on something unbound (an
  attribute with neither value nor default, an input parameter), `<unset>` means the
  feature exists but has no value. Give defaults or bind on the usage.
- **Real literals**: `1500` is an `Integer`; comparing an `Integer` literal with a `Real`
  attribute works, but `1500.0` keeps the type explicit. The opt-in lint
  `rounded-real-literal` warns about literals that cannot be represented exactly.
- **Units and quantities**: `attribute mass : MassValue = 1300 [kg];` requires importing
  `ISQ::*` and `SI::*`. Arithmetic across incompatible quantity kinds is rejected.

## Behavior that the runtime executes

```sysml
package Mission {
    private import ScalarValues::*;
    part def Rover {
        attribute battery : Real default = 100.0;
        action def Drive { in distance : Real; }
        action drive : Drive;
        state def Modes {
            entry; then Idle;
            state Idle;
            state Driving;
            transition Idle_to_Driving first Idle accept Go then Driving;
            transition Driving_to_Idle first Driving accept Stop then Idle;
        }
        exhibit state modes : Modes;
    }
    attribute def Go; attribute def Stop;   // signals are attribute defs accepted by transitions
    part rover1 : Rover;
}
```

```bash
sysml -instantiate Mission::rover1 -state 'Mission::Rover::Modes Mission::rover1' -advance 5 mission.sysml
sysml -instantiate Mission::rover1 -action 'Mission::Rover::Drive Mission::rover1' mission.sysml
```

- Actions run to completion (`✓ Started action executor for "Mission::Rover::Drive"`,
  `State: Completed`); use cases run under `-action` too. `-schedule explore` and the
  `-check-*` flags cover every schedule; a value that depends on the order of concurrent
  steps prints as `x = 1 (order-dependent; 2 choice points — explore shows the set)`.
  State machines take their initial transition and then wait for events
  (`Current state: Idle`, `✓ Advanced to 5.0 (0 event(s) processed)`); send them with the
  REPL's `%send Go to rover1` or drive time with `-advance`.
- Calculations: `calc def Range { in battery : Real; return : Real = battery * 2.0; }`
  invoked as `sysml -calc 'Mission::Range(50.0)'`.
- Constraints in a `constraint def` take `in` parameters; a `constraint` usage inside a
  part reads the part's features directly, as `massLimit` above does.

## Lints that stay warnings

`undeclared-signal` (a transition accepts a type never sent), `port-type-mismatch`,
`deferred-keeper-unmarked`, and `nonstandard-notation` (becomes an error under `-strict`);
`rounded-real-literal` is opt-in (`-enable-lint rounded-real-literal`). Silence one
deliberately with `-disable-lint NAME` and say why in the model's documentation; a CI gate
that must stay clean runs `-validate -warnings-as-errors`.

## Checking your own work

```bash
sysml -validate model.sysml && sysml -json -validate model.sysml | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])'
```
`sysml -explain` with no code lists every diagnostic code with a one-line summary. For
larger models open the REPL (`opensysml-repl`): `%load model.sysml`, then `%search`,
`%instantiate`, `%features`, `%eval` to inspect before committing changes.
