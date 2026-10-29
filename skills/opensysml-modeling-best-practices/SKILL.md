---
name: opensysml-modeling-best-practices
description: Model in SysML v2 so the result is spec-correct, analyses clean in OpenSysML and the OMG pilot validator, executes and renders — use-case actors as `actor` parameters, associations as `connection def`s, stereotypes as metadata, constraints that are asserted and evaluated, operations as performed actions, instances as typed usages, views with optional layout — with the spec clause, a correct snippet, the wrong shape and the diagnostic each produces. Use when writing or reviewing .sysml by hand, when repairing a model migrated from Cameo/MagicDraw SysML v1, or when a model passes one validator and fails another.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Modeling practice for SysML v2

The model is the truth; diagrams, comments and tool acceptance are not. Every rule below
names its clause in SysML v2.0 Beta 4 (OMG `ptc/2025-04-05`; KerML 1.0 Beta 4 is
`ptc/2025-04-01`; the OMG SysML v1-to-v2 transformation is `ptc/25-04-10`), gives the
correct shape, the wrong shape and what each tool says about it. Every snippet lives under
[`references/examples/`](references/examples/) and was run through `sysml -validate`
(OpenSysML `sysml v0.10.1-1266-gdada45c11`, a `develop` build) and the OMG pilot validator (pilot release `2026-08`,
`validate-sysml` from OpenSysML's `scripts/download-pilot-validator.sh`); the recorded
commands and outputs are in [`references/verification.md`](references/verification.md).
Syntax and diagnostics in general: `opensysml-sysml-authoring`. Checking: `opensysml-checking`.
Rendering: `opensysml-documents`. Migration: `opensysml-migrate-v1`.

## 1. Use cases and actors

**Spec.** §7.22.1: "A case definition or usage may also have one or more actor parameters that
represent roles played by an entity external to the subject of the case … An actor parameter is
a part usage representing an entity that plays a designated actor role for the case. A case may
have multiple actors representing the same kind of entity playing different roles." §7.22.2:
"Actor parameters are part usages, so they must be (explicitly or implicitly) defined by part
definitions." §7.25.3: an include use case usage "is also a kind of perform action usage", and
"actor parameters of the included use case may be bound to corresponding actor parameters of the
containing use case".

**Why.** The actors of a use case are its `actor` parameters and nothing else. A `connection`
from a part to a use case is a part-to-part link; it does not make the part an actor, so the
use case cannot name, bind or navigate to it. A `/* «actor» */` comment is not a model element.

**Reuse one actor across many use cases** — declare each actor once as a package-level part and
let each use case declare its own parameter that subsets it. The parameter is the use case's own
slot, not a second actor; a connection, if a diagram needs the line, ends at the parameter
([`01-actors-reused.sysml`](references/examples/01-actors-reused.sysml), both validators clean):

```sysml
package 'Lab Use Cases' {
    part Operator;
    part Administrator;
    use case 'Acquire Image'        { subject; actor operator :> Operator; }
    use case 'Configure Instrument' { subject; actor operator :> Operator; actor administrator :> Administrator; }
    connection 'Operator to Acquire Image' connect Operator to 'Acquire Image'.operator;
    connection 'Operator to Configure Instrument' connect Operator to 'Configure Instrument'.operator;
    connection 'Administrator to Configure Instrument' connect Administrator to 'Configure Instrument'.administrator;
    view 'Lab Use Cases' {
        expose Operator; expose 'Acquire Image'; expose 'Operator to Acquire Image'; // … one expose per element
        render Views::asInterconnectionDiagram;
    }
}
```

Choose this shape when the actors are shared across a diagram's worth of use cases (the v1
use-case-diagram situation). Choose the **pure v2 shape** when actors are roles with a type and
nothing outside the use case needs a line to them: a `use case def` with typed, optionally
multiplicity-bounded actor parameters, and `include use case` binding the inner actors to the
outer ones ([`01-actors-pure-v2.sysml`](references/examples/01-actors-pure-v2.sysml)):

```sysml
use case def 'Acquire Image' { subject instrument : Instrument; actor operator : Operator; actor attendant [0..1] : Operator; }
use case def 'Run Session' {
    subject instrument : Instrument;
    actor operator : Operator;
    include use case acquire : 'Acquire Image' {
        subject :>> instrument = 'Run Session'::instrument;
        actor :>> operator = 'Run Session'::operator;
    }
}
```

**Wrong shapes.**
- `connection connect Operator to 'Acquire Image';` with no `actor` in the use case
  ([`01-wrong-no-actor-parameter.sysml`](references/examples/01-wrong-no-actor-parameter.sysml)):
  both validators accept it (exit `0`) — the error is semantic, so no tool will tell you. The
  use case has no actor, and the picture does not show it either: `sysml -render 'Actor-less
  Diagram' -render-form dot` draws the same `«part»`-to-`«use case»` edge the correct model
  draws (§2). Only the text tells them apart.
- `connect Operator to 'Acquire Image'.operator` when the parameter is missing
  ([`01-wrong-missing-parameter.sysml`](references/examples/01-wrong-missing-parameter.sysml)):
  OpenSysML `error: unresolved member: operator` (exit `2`); pilot `Couldn't resolve reference to
  Feature 'operator'.`
- Binding only the actor in an `include use case` body: the pilot reports `Subject must be first
  parameter.`; OpenSysML accepts it. Redefine `subject :>> …` first, as above — the spec's own
  §7.25.3 example omits it, so this is pilot behavior, not a spec rule.

The v1 migrator on this build (nightly builds and the release after 0.10.1) writes each actor
association of a use case as an `actor` parameter nested in the use case after its `subject`,
subsetting the actor's one package-level `part` with the end's multiplicity:

```sysml
use case 'Park Car' {
    subject garage : Context::Garage;
    actor driver :> Context::Driver;
    actor attendant [0..1] :> Context::Attendant;
}
```

(`subject;` is written first when the use case has actors but no subject.) The actor itself is a
`part` usage the report marks *approximated* (`a UML actor is written as a part usage`). Output
of 0.10.1 and earlier wrote the actor lines as connections to the use case with no actor member;
repair that by adding the `actor … :> Part;` parameters and re-pointing the connections at them.

## 2. Graphical notation is optional

**Spec.** §7.26.5: "Definition and usage nodes can include symbols on the boundary of the node to
represent ports and parameters." *Can*, not *must*: an actor parameter drawn as a boundary box
on the use case, listed in a compartment, or shown as a line to the use case node are all
renderings of the same model. OpenSysML's interconnection rendering on this build draws each
use case as one `«use case»` node and runs the connection from the actor's `«part»` node to it;
the actor parameters are not drawn (`sysml -render "'Lab Use Cases'::'Lab Use Cases'"
-render-form dot`; the view shares its package's name, so a bare `'Lab Use Cases'` is `not a view`).

**Rule.** Never add, remove or rename a model element to change a picture; change the `view`
(`expose`, `filter`, `render`) or the renderer flags. The flags this version accepts are
`-render`, `-render-all`, `-render-form`, `-render-style pilot|cameo`, `-render-palette`,
`-render-ports`, `-render-overlay`, `-render-link` and `-render-unplaced omit|strip`
(`sysml -help`); there is no flag that chooses how actors are drawn.

## 3. Associations are `connection def`s

**Spec.** §7.13.1: "A connection definition is both a relationship and a kind of part definition
… that classifies connections"; "A connection usage is a part usage … connecting usage elements".
§7.13.2 declares the ends as `end` features. Mapping `ptc/25-04-10`: an association class
(`AssociationBlock_Mapping`, `AssociationClass_Mapping`) becomes a `ConnectionDefinition`, a
plain association (`AssociationCommon_Mapping`) its KerML base `Association` — in SysML notation
both are `connection def`; a composite end becomes the part usage on the whole.

```sysml
part def 'Scanning Electron Microscope' {
    part 'electron Gun' : 'Electron Gun';          // the v1 composition: a part usage, nothing else
}
connection def DetectorToMicroscope {               // the v1 reference association, typed ends
    end detector : Detector;
    end microscope : 'Scanning Electron Microscope';
}
part detector : Detector;
part sem : 'Scanning Electron Microscope';
connection 'detector to sem' : DetectorToMicroscope connect detector to sem;
```

([`03-associations.sysml`](references/examples/03-associations.sysml), both clean.) One anonymous
v1 association is one `connection def` and one `connection`; do not also draw the composition as
a connection — the part usage already is the whole–part relationship, and a second element would
be a second relationship with its own instances.

**Wrong shape.** `connect Detector to 'Scanning Electron Microscope'` between definitions
([`03-wrong-connect-defs.sysml`](references/examples/03-wrong-connect-defs.sysml)): OpenSysML
`error: Must be a valid feature` on each end (exit `2`); pilot `Couldn't resolve reference to
Feature 'Detector'.` Connections join usages; declare the usages first.

## 4. Stereotypes and profiles are metadata, not comments

**Spec.** §7.27.2: a metadata definition "is declared like an item definition … using the
keyword `metadata def`", applied with `@` or `metadata … about …`. §7.27.4: "A user-defined
keyword is the (possibly qualified) name … of a metadata definition … preceded by the symbol `#`.
Such a keyword can be used in package, dependency, definition and usage declarations." §7.3.2: a
dependency "may also optionally have a body containing any annotating elements".

**Rule.** If v2 already says it, use the v2 construct: «Block» → `part def`, a profile
stereotype that specializes Block (Cameo «Subsystem») → `part def` plus a keyword, «Trace» →
`dependency`. What the construct does not carry goes in metadata the model defines, so filters,
queries and views can see it; a `/* «Subsystem» */` comment is invisible to all of them
([`04-stereotype-metadata.sysml`](references/examples/04-stereotype-metadata.sysml), both clean):

```sysml
metadata def Subsystem;
metadata def AppliedStereotype { attribute stereotype : String; attribute profile : String[0..1]; }
#Subsystem part def 'Vacuum System';
dependency 'Controller traces Stage' from Controller to Stage {
    @AppliedStereotype { stereotype = "Trace"; profile = "SysML"; }
}
view 'Subsystems only' { expose Stereotypes::*[@Subsystem]; render Views::asTreeDiagram; }
```

`sysml -render 'Subsystems only' -render-form text` lists exactly `part def
Stereotypes::'Vacuum System'`. With the comment instead
([`04-wrong-stereotype-comment.sysml`](references/examples/04-wrong-stereotype-comment.sysml)) the
filter has nothing to name: `error: unresolved reference: Stereotypes::Subsystem` in both tools.

**Libraries travel with the model.** OpenSysML ships extension libraries the language is meant
to be extended with (`MigrationMetadata` with `SynthesizedName`, `StandIn`, `LibraryNameAvoided`,
`DeferredEvent`, `DeferredKeeper`; `DiagramLayout`; `StateMachines`; `Stochastic`;
`DocumentQueries`; the directory `internal/workspace/libs/stdlib/OpenSysML Libraries/` in the
OpenSysML tree, maintained upstream at Open-MBEE/OpenSysML-Extensions-Library). Use them, and
when the file goes to a tool that does not bundle them, hand that tool the library too — the
pilot only knows the standard library, so on its own
[`04-opensysml-library.sysml`](references/examples/04-opensysml-library.sysml) fails with
`Couldn't resolve reference to Namespace 'MigrationMetadata'.` Three ways that pass (§9 has the
commands): list the library file *before* the model on the `validate-sysml` command line; load the
whole directory as an extension library with `validate-sysml-batch --extension-library DIR`; or,
as an option when one file must stand alone, inline the `library package` after the model
(what `sysml -migrate sysml -portable` does for a migration; `-strict` instead writes no
extension at all). `-strict -validate` in OpenSysML does **not** report extension-library use
(exit `0` on that file) — it judges notation; there is no `-standalone` flag.

The v1 migrator on this build writes a stereotype the v2 form does not carry as an
`@MigrationMetadata::AppliedStereotype { … }` marker in the element's body, and names a kept
dependency by its kind — no `/* «Trace» */` comments (those are 0.10.1 and earlier output):

```sysml
dependency 'Speed Requirement traces Engine' from 'Speed Requirement' to 'Vehicle Design'::Engine {
    @MigrationMetadata::AppliedStereotype { stereotype = "Trace"; }
}
part def Vehicle {
    @MigrationMetadata::AppliedStereotype { stereotype = "Block"; tags = "isEncapsulated = true"; }
}
```

`profile = "<namespace>"` names a profile the migration did not write; `tags` keeps the tag
values no v2 feature holds. Under `-strict` the marker is the line comment `// applied
stereotype «Block»: isEncapsulated = true`. Keep the markers and hand `MigrationMetadata.sysml`
to the other tool as above (or `-portable` inlines it); a stereotype that is part of your own
vocabulary is better re-declared as a `metadata def` of yours, as `#Subsystem` is.

## 5. Constraints that assert something

**Spec.** §7.20.2: "any directed usages declared in the body of a constraint definition … are
considered to be owned parameters"; "the result expression must be Boolean valued". §7.20.3:
"By default, an assert constraint usage asserts that it must evaluate to true at all times."
Mapping: `ConstraintBlock` → `ConstraintDefinition`.

```sysml
constraint def 'Positive Mass' { in m : MassValue; m > 0 [kg] }    // result expression last
part def Vehicle {
    attribute mass : MassValue;
    assert constraint positiveMass : 'Positive Mass' { in :>> m = mass; }
}
part car : Vehicle { attribute :>> mass = 1350.5 [kg]; }
part brokenCar : Vehicle { attribute :>> mass = -1 [kg]; }
```

([`05-constraints.sysml`](references/examples/05-constraints.sysml), both clean.) A constraint
def nobody asserts and binds is a predicate nobody applies. Evaluate it, do not assume it:

```bash
sysml -constraint "'Mass Constraints'::'Positive Mass'(-1 [SI::kg])" 05-constraints.sysml   # violated, exit 1
sysml -instantiate "'Mass Constraints'::car" -constraint "'Mass Constraints'::Vehicle::positiveMass" 05-constraints.sysml        # holds, exit 0
sysml -instantiate "'Mass Constraints'::brokenCar" -constraint "'Mass Constraints'::Vehicle::positiveMass" 05-constraints.sysml  # ✗ … Assertion evaluated to false: m > 0 [kg], exit 1
```

**Wrong shape.** The expression inside a nested `calc` with no result expression on the
constraint ([`05-wrong-unevaluated-calc.sysml`](references/examples/05-wrong-unevaluated-calc.sysml)):
both validators accept it, and the check says `? Constraint … could not be evaluated … no
condition to evaluate` (exit `2`) — the assertion asserts nothing. Verdicts, standings and the
SMT/explore modes: `opensysml-checking`.

## 6. Operations are performed actions

**Spec.** §7.17.6: "A perform action usage is a kind of event occurrence usage … for which the
event occurrence is an action usage, known as the performed action … if the perform action usage
has no such reference subsetting, then the performed action is the perform action usage itself."
"If a perform action usage is used in the body of a part definition or usage, then the part is
considered to be the performer"; in an action body "it acts like a referential 'call'". Library:
`Parts::Part::performedActions : Action[0..*]`. Mapping: `Operation` → `PerformActionUsage`.

**What executes.** Declare the operation once as an action owned by the part definition and let
each caller perform *that* action through a feature chain
([`06-operations-action.sysml`](references/examples/06-operations-action.sysml)):

```sysml
part def Counter {
    attribute count : Integer = 0;
    action inc { in delta : Integer; assign count := count + delta; }
}
part def Controller {
    part c : Counter;
    action run {
        perform action a ::> c.inc { in :>> delta = 2; }
        then perform action b ::> c.inc { in :>> delta = 3; }
    }
}
```

`sysml -action OperationsAction::Controller::run -trace 06-operations-action.sysml` shows
`count` go `0 → 2 → 5`: `eval feature count -> 0`, `delta -> 2`, then `count -> 2`, `delta -> 3`.

This is the shape the v1 migrator writes on this build: a block's `Operation` becomes the
owner's composite usage `action <op> { in … }` carrying the operation's parameters and its
method behaviour as the body (`action start { in key : ScalarValues::Integer[1]; }` inside
`part def Vehicle`), not a separate `action def` plus a typed usage. The pilot validator warns
`Duplicate of inherited member name 'start' from Part` on an operation named like an inherited
occurrence feature (`start`, `done`); rename such an operation after migrating.

**Measured difference.** The mapping's literal form, `perform action inc { in delta … }` on the
part def with the same callers
([`06-operations-perform.sysml`](references/examples/06-operations-perform.sysml)), is accepted by
both validators but does not run in OpenSysML: the def-owned perform usage is the performance
itself, so the caller's `in :>> delta = 2` never reaches it — `eval feature delta -> ()` and
`execution failed: … operator '+' is not defined for an Integer and a sequence`. Use
`action` on the definition for an operation that takes arguments; keep `perform action op;` on
the def for a parameterless performance the part itself owns.

**The heavier alternative** — one `action def Inc { in target : Counter; in delta : Integer;
assign target.count := … }` plus a typed usage per call
([`06-operations-actiondef.sysml`](references/examples/06-operations-actiondef.sysml)) — is right
when the behavior is shared by unrelated part definitions. OpenSysML runs it; the pilot
validator reports `Couldn't resolve reference to Element 'count'` on the chained assignment
target, so it does not round-trip to the pilot as written. `action a : Counter::inc` is not an
option: `error: An action must be typed by action definitions.` (both tools,
[`06-operations.sysml`](references/examples/06-operations.sysml)).

## 7. Instance specifications are typed usages

**Spec.** §7.9.4: an occurrence usage declared `individual` "must have exactly one definition
that is an individual definition". Mapping: `InstanceSpecification` → `PartUsage`, `Slot` → a
feature redefinition.

```sysml
part sem1 : SEM { attribute :>> mass = 10 [kg]; }            // one instance, slot values bound
part sem2 : SEM, Calibrated { attribute :>> mass = 12 [kg]; } // multiply classified: several definitions
```

([`07-instances.sysml`](references/examples/07-instances.sysml), both clean.) `individual` is for
a thing with an identity across time (§7.9.4's `individual part def TestPlane_1 :> Aircraft;`),
not a synonym for "instance". **Wrong shape:** `individual part sem1 : SEM`
([`07-wrong-individual.sysml`](references/examples/07-wrong-individual.sysml)) — `error: An
individual must be typed by one individual definition.` in both tools.

The v1 migrator on this build writes an `InstanceSpecification` this way: a `part`,
`constraint`, `item`, `occurrence`, `port` or `attribute` usage typed by its classifiers, slots
as nested features; an instance of an actor, use case or requirement subsets the classifier's
usage (`part alice :> Operator;`). It writes no `individual part def`.

## 8. Views and layout

**Spec.** §7.26.2: "a view usage can specify which elements are actually to be exposed by the
view. This is done using expose relationships, which are a special kind of import
relationships"; rendering is the `render` member, standard renderings come from `Views`.
§7.26.5: a diagram "is also a view usage". KerML §8.2.3.5.3: "If the Namespace is well formed, then
there can be at most one Membership that is the local resolution of any given name."

```sysml
view 'Microscope Interconnection' {
    expose Microscope::**;
    render Views::asInterconnectionDiagram;
}
```

([`08-views-layout.sysml`](references/examples/08-views-layout.sysml), both clean; `sysml -render
'Microscope Interconnection' -render-form dot` lays it out.) This version renders
`Views::asInterconnectionDiagram`, `asTreeDiagram`, and the state, action, requirement and
table renderings `opensysml-documents` lists.

**Layout is optional and lives in an extension library.** Geometry goes in the view body as
`metadata DiagramLayout::Layout about <qualified name> { x; y; width; height; }` and
`metadata DiagramLayout::Route about <qualified name> { points = (…); }`
([`08-views-layout-placed.sysml`](references/examples/08-views-layout-placed.sysml)). The DOT
output differs from the unplaced file only by pinned `pos="…!"` coordinates and `layout=neato`;
the nodes and edges are the same, and a `-render-form drawio` export puts the same geometry in
each `<object fqn="…">` cell's `mxGeometry`; a node dragged in draw.io comes back through
`-import-diagram` as the same `metadata Layout about …` line, in absolute coordinates, with
nothing else in the file rewritten (nightly builds and the release after v0.11.0;
`opensysml-drawio`). Delete the metadata and the model is unchanged and auto-laid
out. Two traps: `about` takes qualified names, not feature chains (`about microscope.detector`
is a parse error in both tools); and the named element must be one the rendering draws, else
OpenSysML warns `Layout positions part …, which the interconnection rendering of view … does not
draw as a node` and ignores it. The pilot needs `DiagramLayout` handed to it (§4, §9); alone it
reports `Couldn't resolve reference to Type 'DiagramLayout::Layout'`.

**Qualify colliding names.** When a definition and a usage share a name across imported
packages, `expose Detector;` is accepted by both validators and each tool picks one silently —
OpenSysML's render shows `part def Definitions::Detector`, the first import
([`08-wrong-ambiguous-name.sysml`](references/examples/08-wrong-ambiguous-name.sysml)). Write
`expose Definitions::Detector;` / `expose Usages::Detector;`.

**Edge labels.** On a BDD the association-end name is the `end` feature's name in the
`connection def` (§3); renderers draw it on the edge. Do not model it as a separate element.

## 9. Validation discipline

1. `sysml -validate model.sysml; echo $?` — `0` clean, `2` errors (`opensysml-cli`).
2. The pilot: `./scripts/download-pilot-validator.sh` in an OpenSysML checkout builds
   `build/pilot-validator/validate-sysml`; `validate-sysml model.sysml; echo $?` — `0` clean,
   `1` on errors, GNU `file:line:col: severity: message` on stderr (ignore its `log4j:WARN` and
   `Reading …` lines). It loads only the standard library, so give it every extension library
   the model uses, library first: `validate-sysml "$LIBS/DiagramLayout.sysml" model.sysml` (model
   first, or a directory holding both, leaves the references unresolved — files load in argument
   order), or `scripts/download-pilot-sysml-validator.sh` and
   `validate-sysml-batch --extension-library "$LIBS" model.sysml`, where `$LIBS` is
   `internal/workspace/libs/stdlib/OpenSysML Libraries` in an OpenSysML checkout. To ship one
   file, append the `library package` to it (`cat model.sysml "$LIBS/DiagramLayout.sysml"`);
   OpenSysML then warns that the root namespace `DiagramLayout` has a library's name and still
   analyses it clean. A migration does this with `-migrate … -portable`.
3. `sysml -strict -validate` for notation no OMG production admits (OpenSysML's `choice`/
   `junction`/`history` shorthand, indistinguishable member names) — not for library use.
4. Acceptance by either tool is evidence, not proof: `01-wrong-no-actor-parameter.sysml` and
   `05-wrong-unevaluated-calc.sysml` pass both and are wrong. Cite the clause.
5. A diagnostic only the editor shows is usually a stale server: compare `sysml-lsp -version`
   with `sysml -version` (both print version, commit and build time) before touching the model.

## 10. Migration hygiene

`sysml model.xmi -migrate sysml -o model.sysml -migration-report report.txt` writes one row per
v1 element in four buckets; the summary reads `migrated 95 element(s): 77 mapped, 15
approximated, 3 unmapped (2 skipped as profile, library or notation-only content, 0 as model
elements nothing refers to)` for OpenSysML's `vehicle.xmi`. A root `uml:Model` is written as
`package <ModelName> { … }` (row `Model … (written as package Model)`); associations are
`connection def`s (§3), use-case actors `actor` parameters (§1), operations composite `action`
usages (§6), instance specifications typed usages (§7), owned rules a `constraint def` asserted by
a usage with `in ref :>> context = this;` (§5), stereotypes `AppliedStereotype` markers (§4).
**mapped**: review names and types. **approximated**: read the note — `a UML actor is written as
a part usage`, `the anonymous Association is written as connection def EngineToVehicle`, `a trace
is written as a plain dependency named by its kind`, `the connector carries nothing of its own, so
it is written as its flow … alone`, `«Block» isEncapsulated = true has no v2 form`. **unmapped**:
the element is a `/* not migrated: «Unit» InstanceSpecification 'kilogram' — units and quantity
kinds are not migrated; use the SI and ISQ libraries … */` comment at the place it would have
gone; re-model it by hand. **skipped**: profiles, libraries and content nothing refers to;
nothing to do. Diagrams become `view`s; their geometry comes only from an MTIP export
(`-layout`), never from the XMI. Names the migrator made up are listed in a `metadata
MigrationMetadata::SynthesizedName about …;` marker — rename, then delete the entry. Keep
repairs general: fix the shape for every element of the kind, never one named element. Workflow,
`-strict`, `-portable`, `-migration-results`: `opensysml-migrate-v1`.

## Re-verifying

```bash
cd skills/opensysml-modeling-best-practices/references/examples
for f in *.sysml; do sysml -validate "$f"; echo "$f exit $?"; done
for f in *.sysml; do validate-sysml "$f" 2>&1 | grep -v 'log4j\|^Reading'; echo "$f exit ${PIPESTATUS[0]}"; done
```

Files named `*-wrong-*` are meant to fail or to pass vacuously, as recorded in
[`references/verification.md`](references/verification.md).
