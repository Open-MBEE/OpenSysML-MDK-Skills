# Verification record

Every example under [`examples/`](examples/) was run with the commands below. Tools:

- OpenSysML `sysml v0.10.0-48-g6ea8e8658` (built from the `develop` branch with `make build`;
  `sysml-lsp` reports the same version).
- OMG pilot validator from OpenSysML's `scripts/download-pilot-validator.sh`
  (`build/pilot-validator/validate-sysml`, pilot release `2026-08`, artifact `0.62.0`).
  It writes `log4j:WARN …` and `Reading …/sysml.library/…` lines that are not diagnostics.
- Spec texts: SysML v2.0 Beta 4 (`ptc/2025-04-05`), KerML 1.0 Beta 4 (`ptc/2025-04-01`), the
  SysML v1-to-v2 transformation model (`ptc/25-04-10`, `SysMLv1Tov2.xmi`).

`[validate]` is `sysml -validate FILE` (exit `0` clean, `2` errors). `[pilot]` is
`validate-sysml FILE` (exit `0` clean, `1` errors). Column positions are omitted below.

## 1. Use cases and actors

| File | validate | pilot |
|---|---|---|
| `01-actors-reused.sysml` | exit 0, no errors | exit 0 |
| `01-actors-pure-v2.sysml` | exit 0 | exit 0 |
| `01-wrong-no-actor-parameter.sysml` | exit 0 (vacuous pass) | exit 0 (vacuous pass) |
| `01-wrong-missing-parameter.sysml` | exit 2: `error: unresolved member: operator` | exit 1: `error: Couldn't resolve reference to Feature 'operator'.` |

`01-actors-pure-v2.sysml` with only `actor :>> operator = …` in the `include use case` body
(no `subject :>>` line): validate exit 0; pilot exit 1, `error: Subject must be first parameter.`

`sysml -render "'Lab Use Cases'::'Lab Use Cases'" -render-form dot 01-actors-reused.sysml` (the
view and its package share a name; the bare name reports `'Lab Use Cases': not a view`): each use
case is a cluster containing one `«actor»` node per actor parameter (`operator`, `administrator`,
`technician`); every edge runs from a package-level `«part»` to one of those parameter nodes.
`sysml -render 'Actor-less Diagram' -render-form dot 01-wrong-no-actor-parameter.sysml`: the
`'Acquire Image'` cluster contains only `subject`, and the connection edge ends at the cluster.

## 3. Associations

| File | validate | pilot |
|---|---|---|
| `03-associations.sysml` | exit 0 | exit 0 |
| `03-wrong-connect-defs.sysml` | exit 2: `error: Must be a valid feature` (both ends) | exit 1: `error: Couldn't resolve reference to Feature 'Detector'.`, `… Feature ''Scanning Electron Microscope''.` |

## 4. Stereotypes and portability

| File | validate | pilot |
|---|---|---|
| `04-stereotype-metadata.sysml` | exit 0 | exit 0 |
| `04-wrong-stereotype-comment.sysml` | exit 2: `error: unresolved reference: Stereotypes::Subsystem` | exit 1: `error: Couldn't resolve reference to Type 'Stereotypes::Subsystem'.` |
| `04-opensysml-library.sysml` | exit 0 | exit 1: `error: Couldn't resolve reference to Namespace 'MigrationMetadata'.`, `… Type 'StandIn'.`, `A metadata usage must be typed by one metadata definition.` |

- `sysml -render 'Subsystems only' -render-form text 04-stereotype-metadata.sysml` →
  `part def Stereotypes::'Vacuum System'` (the one element the `#Subsystem` keyword annotates).
- `sysml -strict -validate 04-opensysml-library.sysml` → `✓ … no errors`, exit 0: `-strict` does
  not report OpenSysML-only library imports.
- `sysml -help` lists `-strict` and `-portable` (`-portable` only "With -migrate"); there is no
  `-standalone` flag.
- The vendored `MigrationMetadata.sysml` on this version defines `SynthesizedName`,
  `DeferredEvent`, `DeferredKeeper`, `LibraryNameAvoided` and `StandIn`; there is no
  `AppliedStereotype`, so the example defines its own.

## 5. Constraints

| File | validate | pilot |
|---|---|---|
| `05-constraints.sysml` | exit 0 | exit 0 |
| `05-wrong-unevaluated-calc.sysml` | exit 0 (vacuous pass) | exit 0 (vacuous pass) |

```text
$ sysml -constraint "'Mass Constraints'::'Positive Mass'(1350.5 [SI::kg])" 05-constraints.sysml
  standing: holds (observed: 1 run under reverse)                       # exit 0
$ sysml -constraint "'Mass Constraints'::'Positive Mass'(-1 [SI::kg])" 05-constraints.sysml
✗ Constraint 'Mass Constraints'::'Positive Mass'(-1 [SI::kg]) failed
  Assertion evaluated to false: m > 0 [kg]
  standing: violated (witnessed: 1 run under reverse)                   # exit 1
$ sysml -instantiate "'Mass Constraints'::car" -constraint "'Mass Constraints'::Vehicle::positiveMass" 05-constraints.sysml
  standing: holds (observed: 1 run under reverse)                       # exit 0
$ sysml -instantiate "'Mass Constraints'::brokenCar" -constraint "'Mass Constraints'::Vehicle::positiveMass" 05-constraints.sysml
✗ Constraint 'Mass Constraints'::Vehicle::positiveMass failed (on 'Mass Constraints'::brokenCar ID: 1)
  Assertion evaluated to false: m > 0 [kg]                               # exit 1
$ sysml -instantiate "'Constraint Without Result'::brokenCar" -constraint "'Constraint Without Result'::Vehicle::positiveMass" 05-wrong-unevaluated-calc.sysml
? Constraint 'Constraint Without Result'::Vehicle::positiveMass could not be evaluated (on 'Constraint Without Result'::brokenCar ID: 1)
  Error: constraint positiveMass: no condition to evaluate               # exit 2
```

A root package named `Constraints` draws `warning: Root namespace `Constraints` has the name of
a standard library package`, hence `'Mass Constraints'`.

## 6. Operations

| File | validate | pilot |
|---|---|---|
| `06-operations-action.sysml` | exit 0 | exit 0 |
| `06-operations-perform.sysml` | exit 0 | exit 0 |
| `06-operations-actiondef.sysml` | exit 0 | exit 1: `error: Couldn't resolve reference to Element 'count'.` (twice, on `target.count`) |
| `06-operations.sysml` | exit 2: `error: An action must be typed by action definitions.` (twice); `warning: then <target>; after a member that is not an action node is an OpenSysML extension` | exit 1: parse errors at `then`, plus `An action must be typed by action definitions.` |

```text
$ sysml -action OperationsAction::Controller::run -trace 06-operations-action.sysml
[trace] stmt assign count
[trace]     eval feature count -> 0
[trace]     eval feature delta -> 2
[trace] stmt assign count
[trace]     eval feature count -> 2
[trace]     eval feature delta -> 3
    a.delta = 2
    b.delta = 3
  standing: value (observed: 1 run under reverse)

$ sysml -action OperationsPerform::Controller::run -trace 06-operations-perform.sysml
[trace]   stmt assign count
[trace]       eval feature count -> 0
[trace]       eval feature delta -> ()
sysml: execution failed: eval performer of c.inc: usage c: performed action inc of object #1: eval assignment RHS: type mismatch: operator '+' is not defined for an Integer and a sequence
  standing: not covered (execution failed: …)
```

## 7. Instances

| File | validate | pilot |
|---|---|---|
| `07-instances.sysml` | exit 0 | exit 0 |
| `07-wrong-individual.sysml` | exit 2: `error: An individual must be typed by one individual definition.` | exit 1: same message |

## 8. Views and layout

| File | validate | pilot |
|---|---|---|
| `08-views-layout.sysml` | exit 0 | exit 0 |
| `08-views-layout-placed.sysml` | exit 0, no warnings | exit 1: `Couldn't resolve reference to Type 'DiagramLayout::Layout'.`, `… 'DiagramLayout::Route'.`, `… 'DiagramLayout::Canvas'.`, and one per attribute |
| `08-wrong-ambiguous-name.sysml` | exit 0 (also under `-strict`) | exit 0 |

- `sysml -render 'Microscope Interconnection' -render-form dot` on the two layout files: the
  placed output adds `// layout: neato -n2`, `layout=neato`, two invisible canvas points and
  `pos="…!"` on every node; node and edge lists are identical.
- An earlier draft wrote `about microscope.detector`: OpenSysML `error: expected '{' or ';'
  after declaration`, pilot `no viable alternative at input '.'`. With `about Microscope::detector`
  but `expose microscope::**` (the usage, not the definition) OpenSysML warned `Layout positions
  part Instrument Structure::Microscope::detector, which the interconnection rendering of view …
  does not draw as a node`, and the DOT output carried no positions.
- `sysml -render 'Detector View' -render-form text 08-wrong-ambiguous-name.sysml` →
  `part def Definitions::Detector`: the simple name resolved to the first import without a
  diagnostic in either tool.

## 10. Migration

```text
$ sysml -migrate sysml -migration-report report.txt vehicle.xmi > vehicle.sysml    # OpenSysML's conformance/fixtures/vehicle.xmi
# migrated 93 element(s): 77 mapped, 13 approximated, 3 unmapped (2 skipped as profile, library or notation-only content, 0 as model elements nothing refers to)
```

`vehicle.sysml` holds three `/* not migrated: … */` comments (two for «Unit»/«QuantityKind»
instance specifications, one for a «Verify» abstraction whose client is not a test case) and a
`view 'Vehicle BDD'` with no `DiagramLayout` metadata, since XMI carries no geometry.
