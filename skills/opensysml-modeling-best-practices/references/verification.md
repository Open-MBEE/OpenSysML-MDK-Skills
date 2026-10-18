# Verification record

Every example under [`examples/`](examples/) was run with the commands below. Tools:

- OpenSysML `sysml v0.10.1-1266-gdada45c11` (built from the `develop` branch with `make build`;
  `sysml -version` also prints `Commit: dada45c11`). Where a behaviour below is not in
  `CHANGELOG.md` under a released version it is what nightly builds and the release after
  0.10.1 do.
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
view and its package share a name; the bare name reports `'Lab Use Cases': not a view`): three
`«part»` nodes, five `«use case»` nodes (`style="rounded,filled"`, keyword line over the name)
and eight `arrowhead=none` edges, each from a `«part»` to the `«use case»` whose actor parameter
the connection names; the actor parameters are not drawn as nodes on this build.
`sysml -render 'Actor-less Diagram' -render-form dot 01-wrong-no-actor-parameter.sysml`: one
`«part»`, one `«use case»` and one edge between them — the same picture, so the rendering does
not tell the two models apart; only the text does.

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
  `Stereotypes::'Subsystems only' - tree rendering (render Views::asTreeDiagram)` then
  `part def 'Vacuum System'` (the one element the `#Subsystem` keyword annotates; the text
  rendering prints simple names on this build).
- `sysml -strict -validate 04-opensysml-library.sysml` → `✓ … no errors`, exit 0: `-strict` does
  not report extension-library imports.
- With the library handed over (`LIBS=…/internal/workspace/libs/stdlib/OpenSysML Libraries`):
  `validate-sysml "$LIBS/MigrationMetadata.sysml" 04-opensysml-library.sysml` → exit 0;
  `validate-sysml 04-opensysml-library.sysml "$LIBS/MigrationMetadata.sysml"` (model first) → exit 1,
  the same unresolved-reference errors; `validate-sysml-batch --extension-library "$LIBS"
  04-opensysml-library.sysml` → exit 0.
- `sysml -help` lists `-strict` and `-portable` (`-portable` only "With -migrate"); there is no
  `-standalone` flag.
- The vendored `MigrationMetadata.sysml` on this build is a `library package` and defines
  `SynthesizedName`, `DeferredEvent`, `DeferredKeeper`, `LibraryNameAvoided`, `AppliedStereotype`
  (`stereotype : String`, `profile : String[0..1]`, `tags : String[0..*]`) and `StandIn`. The
  example defines its own metadata def for a stereotype of its own; `AppliedStereotype` is what
  the migrator writes for a v1 stereotype the v2 form does not carry (§10).

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

A root package named `Constraints` draws OpenSysML's `warning[library-root-name]: Root namespace
`Constraints` has the name of a standard library package, so qualified names starting with it may
resolve to the library`, hence `'Mass Constraints'`. The same warning names a root
`DiagramLayout` or `MigrationMetadata` package — OpenSysML's extension libraries are now
`library package`s, and the warning still treats their names as reserved (§8, §10). The pilot
has no such warning.

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

- `validate-sysml "$LIBS/DiagramLayout.sysml" 08-views-layout-placed.sysml` → exit 0;
  `validate-sysml 08-views-layout-placed.sysml "$LIBS/DiagramLayout.sysml"` → exit 1; a directory
  holding copies of both files → exit 1 (alphabetical load order puts the model first);
  `validate-sysml-batch --extension-library "$LIBS" 08-views-layout-placed.sysml` → exit 0.
  `cat 08-views-layout-placed.sysml "$LIBS/DiagramLayout.sysml" > inlined.sysml`: `validate-sysml
  inlined.sysml` → exit 0, no warning; `sysml -validate inlined.sysml` → `✓ package 'Instrument
  Structure'`, exit 0, with `warning[library-root-name]: Root namespace `DiagramLayout` has the
  name of a standard library package, so qualified names starting with it may resolve to the
  library` on the inlined `library package DiagramLayout {` line (the same for an inlined
  `MigrationMetadata` and for the migrator's own `-portable` output, §10).
- `sysml -render 'Microscope Interconnection' -render-form dot` on the two layout files: the
  placed output adds `// layout: neato -n2`, `layout=neato`, two invisible canvas points and
  `pos="…!"` on every node; node and edge lists are identical.
- An earlier draft wrote `about microscope.detector`: OpenSysML `error: expected '{' or ';'
  after declaration`, pilot `no viable alternative at input '.'`. With `about Microscope::detector`
  but `expose microscope::**` (the usage, not the definition) OpenSysML warned `Layout positions
  part Instrument Structure::Microscope::detector, which the interconnection rendering of view …
  does not draw as a node`, and the DOT output carried no positions.
- `sysml -render 'Detector View' -render-form text 08-wrong-ambiguous-name.sysml` →
  `'Ambiguous View'::'Detector View' - tree rendering (render Views::asTreeDiagram)` then
  `part def Detector`: the simple name resolved to the first import without a diagnostic in
  either tool (`-strict -validate` is also exit 0).

## 10. Migration

Probes are OpenSysML's `conformance/fixtures/vehicle.xmi` and the migrator's own fixtures under
`tests/migrate/testdata/xmi/`; every migrated file below is `sysml -validate` exit 0.

```text
$ sysml vehicle.xmi -migrate sysml -o vehicle.sysml -migration-report report.txt
note: SysML v1 migration is experimental: …; see docs/reference/sysml-v1-migration.md § Status
wrote report.txt (migration report: migrated 95 element(s): 77 mapped, 15 approximated, 3 unmapped (2 skipped as profile, library or notation-only content, 0 as model elements nothing refers to))
wrote vehicle.sysml (sysml, 8253 bytes)
```

`report.txt` opens with `# SysML v1 to v2 migration report: vehicle.xmi`, `# exported by
Example UML Tool` and the `# migrated …` summary, then `## unmapped (3)`, `## approximated
(15)`, `## mapped (77)`, one tab-separated row per element: `kind`, `v1 qualified name`, `xmi:id`,
`-> v2 qualified name`, `(note)`. Rows on this build:

```text
Model	Model	_model	-> Model	(written as package Model)
Diagram	Vehicle BDD	_diag_bdd	-> Model::'Vehicle BDD'	(a diagram of unknown kind written as a view rendered asTextualNotation; the diagram names no owner; written in package Model, which holds it; …)
«Trace» Abstraction	Requirements::<Abstraction>	_dep_trace	-> Model::Requirements::'Speed Requirement traces Engine'	(a trace is written as a plain dependency named by its kind)
Association	Vehicle Design::<Association>	_assoc_vehicle_engine	-> Model::'Vehicle Design'::EngineToVehicle	(the anonymous Association is written as connection def EngineToVehicle; its one usage is …)
Actor	Vehicle Design::Driver	_actor_driver	-> Model::'Vehicle Design'::Driver	(a UML actor is written as a part usage)
«Block» Class	Vehicle Design::Vehicle	_blk_vehicle	-> Model::'Vehicle Design'::Vehicle	(«Block» isEncapsulated = true has no v2 form)
```

and, from `flow_only.xmi` (35 elements: 33 mapped, 1 approximated, 1 unmapped), the connector
rows: `Connector	Power::Sys::<Connector>	_c_pwr	-> Model::Power::Sys::'supply.pwr out to load.pwr in'
(the connector carries nothing of its own, so it is written as its flow 'supply.pwr out to
load.pwr in' alone)` and `… _c_bus -> Model::Power::Sys::cmd (… written as its flows cmd, tlm
alone)`; a connector that carries something stays `connection 'spare feed' connect
supply.'pwr out' to spare.'pwr in';` beside its `flow 'spare pwr' of Pwr …`.
`-migration-report report.json` writes the same rows as JSON (`source`, `exporter`, `entries[]`
with `id`, `kind`, `name`, `target`, `verdict`, `note`).

`vehicle.sysml` (`package Model { … }` at the root, since the v1 root is a `uml:Model` named
`Model`) holds three `/* not migrated: … */` comments (two for «Unit»/«QuantityKind» instance
specifications, one for a «Verify» abstraction whose client is not a test case), a `view
'Vehicle BDD'` with no `DiagramLayout` metadata (XMI carries no geometry), and these forms:

```sysml
dependency 'Speed Requirement traces Engine' from 'Speed Requirement' to 'Vehicle Design'::Engine {
    @MigrationMetadata::AppliedStereotype {
        stereotype = "Trace";
    }
}
constraint def 'Positive mass' {
    in ref context : Vehicle[1];
    context.mass > 0
}
assert constraint 'positive mass' : 'Positive mass' {
    in ref :>> context = this;
}
action start {                                   // the block's Operation, inside part def Vehicle
    in key : ScalarValues::Integer[1];
}
metadata MigrationMetadata::SynthesizedName about EngineToVehicle, WheelToVehicle, drives, 'engine to vehicle', 'wheel to vehicle';
```

A «Block» with `isEncapsulated = true` carries `@MigrationMetadata::AppliedStereotype {
stereotype = "Block"; tags = "isEncapsulated = true"; }`; a stereotype from a profile the
migration did not write adds `profile = "http://example.com/profiles/Safety"`.

Other fixtures (`sysml FILE -migrate sysml -o out.sysml`):

- `parking_usecases.xmi` (44: 26 mapped, 15 approximated, 3 unmapped): `use case 'Park Car' {
  subject garage : Context::Garage; actor driver :> Context::Driver; actor attendant [0..1] :>
  Context::Attendant; … }` — actors are `actor` parameters after the `subject`, subsetting the
  actor's package-level `part`, with the association end's multiplicity.
- `anonymous_associations.xmi` (35: 25 mapped, 10 approximated, 0 unmapped): every association is
  a `connection def` — `connection def WheelToCar { end wheels : Wheel crosses car.wheels; end car
  : Car crosses wheels.car; }` — named `<End>To<End>` when the v1 association had no name and
  listed in a `SynthesizedName` marker.
- `tree_constraints.xmi` (30: 20 mapped, 7 approximated, 3 unmapped): each owned rule is a
  `constraint def` with an `in ref context : <Owner>[1];` parameter, asserted by `assert
  constraint <rule> : <Def> { in ref :>> context = this; }`.
- `root_model_defs.xmi` (13: 12 mapped, 0 approximated, 1 unmapped): `package SEM { doc /* … */
  … }` — the root `uml:Model` named `SEM` is written as `package SEM`; report row `Model	SEM	_m
  -> SEM	(written as package SEM)`.
- `classifier_usages.xmi` (33: 16 mapped, 17 approximated, 0 unmapped): an
  `InstanceSpecification` is a typed usage (`part alice :> Operator;` for an instance of an
  actor, `occurrence panel : Panel;`); no `individual part def` is written.
- `operation_extra_params.xmi` (20: 12 mapped, 7 approximated, 1 unmapped): an `Operation` is the
  owner's composite usage `action adjust { in x : ScalarValues::Real[0..1]; … }` with its method
  as the body; no separate `action def` per operation.
- `stereotype_filters.xmi` (161: 122 mapped, 37 approximated, 2 unmapped),
  `tool_block_stereotypes.xmi` (20: 14 mapped, 6 approximated, 0 unmapped): stereotypes become
  `AppliedStereotype` markers, never `/* «Name» */` comments.

Checking the migrated vehicle in both tools (`LIBS` as in §4):

- `sysml -validate vehicle.sysml` → `✓ package Model`, exit 0.
- `validate-sysml vehicle.sysml` → exit 1: `error: Couldn't resolve reference to Type
  'MigrationMetadata::AppliedStereotype'.`, `… Feature 'stereotype'.`, `… Feature 'tags'.`;
  `validate-sysml "$LIBS/MigrationMetadata.sysml" vehicle.sysml` → exit 0 with `warning: Duplicate
  of inherited member name 'start' from Part` (five times, for the `action start` operation and
  the actions that chain to it; OpenSysML prints no warning for it).
- `sysml vehicle.xmi -migrate sysml -strict -o vehicle.strict.sysml` → 7727 bytes, no
  `MigrationMetadata` reference: the markers are `// applied stereotype «Block»: isEncapsulated =
  true` and `// names the migration made up: vehicle` line comments and the trace is a bare
  `dependency … ;`. `sysml -strict -validate vehicle.strict.sysml` → exit 0; `validate-sysml
  vehicle.strict.sysml` → exit 0 (the same five `start` warnings).
- `sysml vehicle.xmi -migrate sysml -portable -o vehicle.portable.sysml` → `inlined 1 OpenSysML
  library package(s): MigrationMetadata`, 11132 bytes, `library package MigrationMetadata { … }`
  appended after a `// OpenSysML library packages the model refers to, inlined so the file loads
  with the standard library alone.` comment. `validate-sysml vehicle.portable.sysml` → exit 0;
  `sysml -validate vehicle.portable.sysml` → exit 0 with `warning[library-root-name]` on the
  inlined `library package MigrationMetadata {` line.
- `sysml vehicle.xmi -migrate sysml -o vehicle.sysml -migration-results vehicle.results.json` →
  `wrote vehicle.results.json (results of 0 run configuration(s): 0 with 0 stored snapshot(s))`:
  the fixture has no `SimulationConfig`, so the sidecar `-compare-results` reads is empty.
