---
name: opensysml-migrate-v1
description: Migrate SysML v1 models (UML XMI 2.5.1 with the SysML profile, Eclipse UML2/Papyrus .uml, MagicDraw/Cameo .mdzip) to SysML v2 textual notation with `sysml -migrate`, read the mapped/approximated/unmapped/skipped report, finish the result by hand, check it with -validate and -strict, and run the migrated behaviors. Use when a task starts from a v1 export or a Cameo project and needs a v2 model, or when a migration report lists unmapped elements.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Migrating SysML v1 to v2

A v1 model is **migrated, not converted**: there is no lossless mapping, so `sysml -migrate`
writes the nearest v2 form and a report that classifies every v1 element. Treat the output
as a draft to review, never as a finished model. Verified with `sysml v0.10.1-1266-gdada45c11`
(a `develop` build); what is not in `CHANGELOG.md` under a released version is available in
nightly builds and the release after 0.10.1.

```bash
sysml Vehicle.xmi   -migrate sysml -o Vehicle.sysml           # OMG XMI 2.5.1 + SysML profile
sysml Vehicle.uml   -migrate sysml -o Vehicle.sysml           # Eclipse UML2 / Papyrus
sysml Vehicle.mdzip -migrate sysml -o Vehicle.sysml           # MagicDraw / Cameo project archive
sysml export.xml    -migrate sysml -o Vehicle.sysml -from xmi # extension does not say the format
sysml Vehicle.mdzip -migrate sysml                            # to stdout
```

`-o` writes the notation (`wrote Vehicle.sysml (sysml, 8253 bytes)`); the summary and an
`experimental` note go to stderr. Flags that go with `-migrate`:

| Flag | Writes |
|---|---|
| `-migration-report FILE` | one row per v1 element (`kind`, v1 qualified name, `xmi:id`, `-> v2 qualified name`, `(note)`) under `## unmapped`, `## approximated`, `## mapped` headings; JSON when `FILE` ends in `.json` (`entries[]` with `id`, `kind`, `name`, `target`, `verdict`, `note`) |
| `-migration-results FILE` | a JSON sidecar of the simulation tool's run configurations (`SimulationProfile::SimulationConfig`) and the result snapshots stored for each; `sysml Vehicle.sysml -compare-results FILE` later re-runs them in v2 and tables both distributions. `results of 0 run configuration(s): 0 with 0 stored snapshot(s)` when the model has none |
| `-layout FILE` | positions from an MTIP (HUDS XML) export of the same project as `DiagramLayout::Layout`/`Route` metadata in each view |
| `-portable` | appends the OpenSysML `library package`s the output refers to (`inlined 1 OpenSysML library package(s): MigrationMetadata`) so one file loads in a tool that ships only the standard library |
| `-strict` | writes none of the notation the pinned SysML v2 productions lack and refers to no OpenSysML library: every marker below becomes a line comment |

Over the service it is the `Migrate` RPC, and every client has `migrate(path or content)`
returning notation plus the report (`opensysml-python`, `opensysml-node`, …). The REPL has no
migrate command: migrate on the command line, then `%load` the result.

## What it writes

Measured on OpenSysML's `conformance/fixtures/vehicle.xmi` and the migrator's fixtures:

- A root `uml:Model` is `package <ModelName> { … }`; the report row reads `Model	Model	_model
  -> Model	(written as package Model)`.
- A block is a `part def`; its `Operation` is the block's composite usage `action <op> { in … }`
  carrying the parameters and the method's behaviour as body (`action start { in key :
  ScalarValues::Integer[1]; }`); the mapping reference writes a `CallOperationAction` as
  `perform action x ::> target.op;`.
- Every v1 association is a `connection def` with `end`s (`connection def WheelToCar { end
  wheels : Wheel crosses car.wheels; end car : Car crosses wheels.car; }`); an anonymous one
  is named `<End>To<End>` and listed in `metadata MigrationMetadata::SynthesizedName about …;`.
- A use case declares its actors as `actor` parameters after its `subject`, each subsetting the
  actor's package-level `part` with the end's multiplicity (`actor attendant [0..1] :>
  Context::Attendant;`); the actor is `approximated`: `a UML actor is written as a part usage`.
- An owned rule is a `constraint def` with `in ref context : <Owner>[1];` asserted by
  `assert constraint <rule> : <Def> { in ref :>> context = this; }`.
- An `InstanceSpecification` is a `part`/`constraint`/`item`/`occurrence`/`port`/`attribute`
  usage typed by its classifiers, slots as nested features (`occurrence panel : Panel;`; an
  instance of an actor, use case or requirement subsets its usage: `part alice :> Operator;`).
  No `individual part def` is written.
- A stereotype the v2 form does not carry is an `@MigrationMetadata::AppliedStereotype {
  stereotype = "Block"; tags = "isEncapsulated = true"; }` marker in the element's body
  (`profile = "<namespace>"` for a profile the migration did not write); a kept dependency is
  named by its kind: `dependency 'Speed Requirement traces Engine' from … to … { @MigrationMetadata::AppliedStereotype { stereotype = "Trace"; } }`.
  No `/* «Trace» */` comments. Under `-strict`: `// applied stereotype «Block»: isEncapsulated =
  true`, `// names the migration made up: vehicle`.
- A connector that carries nothing of its own is written as its flow alone (`flow cmd of Cmd
  from ctrl.bus.cmd to unit.bus.cmd;`, report note `the connector carries nothing of its own, so
  it is written as its flows cmd, tlm alone`); one that does keeps its `connection` beside the
  `flow`.
- A diagram is a `view` exposing what it showed (`written in package Model, which holds it`
  when it names no owner); geometry only comes from `-layout`.
- Units, quantity kinds and a «Verify» whose client is no test case are `/* not migrated: … */`
  comments where the element would have gone.

`MigrationMetadata`, `DiagramLayout` and the other OpenSysML extension libraries are
`library package`s. Keep the markers and hand the library to the other tool: pilot
`validate-sysml "$LIBS/MigrationMetadata.sysml" Vehicle.sysml` (library file before the model),
`validate-sysml-batch --extension-library "$LIBS" Vehicle.sysml`, SysON uploads a copy;
`-portable` inlines them when one file must stand alone (`opensysml-modeling-best-practices` §4).

## Reading the report

Each v1 element lands in one bucket:

| Bucket | Meaning | What to do |
|---|---|---|
| **mapped** | A faithful v2 form exists (block → `part def`, value property → `attribute`, requirement → `requirement def`, state machine → `state def`, activity → `action def`, operation → `action` usage, instance → typed usage, root model → `package`, …) | Review names and types only |
| **approximated** | Nearest v2 form with a noted difference: `a UML actor is written as a part usage`, `the anonymous Association is written as connection def EngineToVehicle`, `a trace is written as a plain dependency named by its kind`, `«Block» isEncapsulated = true has no v2 form`, `shared aggregation is written as a reference part`, `opaque expression copied verbatim (language SysML)`, `a diagram of unknown kind written as a view rendered asTextualNotation` | Read the note; decide whether the v2 form is what you meant |
| **unmapped** | No v2 form; a `/* not migrated: «Unit» InstanceSpecification 'kilogram' — units and quantity kinds are not migrated; use the SI and ISQ libraries … */` comment where it would have gone | Re-model by hand in v2 |
| **skipped** | Standard and tool profiles and libraries, the content they mark, and elements nothing in the model refers to | Nothing |

The summary counts each bucket: `migrated 95 element(s): 77 mapped, 15 approximated, 3
unmapped (2 skipped as profile, library or notation-only content, 0 as model elements nothing
refers to)` for `vehicle.xmi`. A migration with `0 unmapped` can still need hand work in the
approximated items. Keep the report next to the output in version control so reviewers see
what changed.

## Finishing by hand, then checking

1. `sysml -validate Vehicle.sysml` — the migrated notation analyses cleanly (every fixture
   above is exit 0); if yours does not, the approximated rows usually explain the diagnostic.
2. Replace approximations: opaque expressions kept as comments become real `calc`/
   `constraint` bodies; v1 `ValueType`s with units become `attribute m : MassValue = 10 [kg]`
   with `ISQ::*`/`SI::*` imports (`opensysml-sysml-authoring`). Rename what
   `SynthesizedName` lists, then drop the entry. Rename an operation named like an inherited
   occurrence feature (`start`, `done`): the pilot validator warns `Duplicate of inherited
   member name 'start' from Part` on it.
3. Run what migrated: `-instantiate`, `-constraint`, `-state 'Modes obj' -advance N`,
   `-action` (`opensysml-checking`); if the migration wrote `-migration-results results.json`,
   `sysml Vehicle.sysml -compare-results results.json` re-runs the tool's configurations.
4. For other SysML v2 tools: hand them the extension libraries, or migrate again with
   `-portable` (one file) or `-strict` (no OpenSysML library, markers as comments).
   `sysml -strict -validate Vehicle.sysml` judges the notation against the pinned productions;
   it does not report extension-library imports.
5. Documents and diagrams: a `document def` rendered with `-render-document ... plantuml cameo`
   style approximates Cameo's look (`opensysml-documents`).

## Where the mapping stops

- A stereotype from a profile the archive does not define is kept as an `AppliedStereotype`
  marker with its `profile`; a tool or standard profile itself is skipped.
- A diagram's geometry is not in the XMI; pass an MTIP (HUDS XML) export of the same project
  with `-layout FILE`. Without it, or if you delete the metadata, OpenSysML lays the view out
  itself and the model is unchanged.
- An item flow with no flow property typed alike on both ends of its connector, and a control
  flow into an action no value reaches, are `/* not migrated: … */` comments.
- Semantics that v2 defines differently (e.g. some activity/state-machine edge cases) are
  approximated; verify behaviour by running it rather than by reading the notation.
- The feature is experimental: mapping rules, the report format and bucket boundaries can
  change between releases (stderr says so on every run); pin the `sysml` version used for a
  migration project.

Reference: `docs/guide/11-migrating-from-sysml-v1.md`, `docs/reference/sysml-v1-migration.md`
and `docs/project/transformation-census.md` in the OpenSysML repository document each mapping
rule and the report format.
