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
as a draft to review, never as a finished model.

```bash
sysml Vehicle.xmi   -migrate sysml -o Vehicle.sysml           # OMG XMI 2.5.1 + SysML profile
sysml Vehicle.uml   -migrate sysml -o Vehicle.sysml           # Eclipse UML2 / Papyrus
sysml Vehicle.mdzip -migrate sysml -o Vehicle.sysml           # MagicDraw / Cameo project archive
sysml export.xml    -migrate sysml -o Vehicle.sysml -from xmi # extension does not say the format
sysml Vehicle.mdzip -migrate sysml                            # to stdout
```

`-o` writes the notation; the report goes to stderr. Over the service it is the `Migrate`
RPC, and every client has `migrate(path or content)` returning notation plus the report
(`opensysml-python`, `opensysml-node`, …). The REPL has no migrate command: migrate on the
command line, then `%load` the result.

## Reading the report

Each v1 element lands in one bucket:

| Bucket | Meaning | What to do |
|---|---|---|
| **mapped** | A faithful v2 form exists (block → `part def`, value property → `attribute`, requirement → `requirement def`, state machine → `state def`, activity → `action def`, …) | Review names and types only |
| **approximated** | Nearest v2 form with a noted difference (e.g. a v1 construct with no v2 equivalent semantics, units and quantity kinds mapped to ISQ/SI, opaque behaviors kept as comments) | Read the note; decide whether the approximation is acceptable |
| **unmapped** | No v2 form; left out and listed with its v1 type and name | Re-model by hand in v2 |
| **skipped** | Standard and tool profiles and libraries, the content they mark, and elements nothing in the model refers to | Nothing |

The summary line counts each bucket, e.g. `migration: migrated 93 element(s): 78 mapped,
12 approximated, 3 unmapped (2 skipped as profile, library or notation-only content, ...)`;
a migration with `0 unmapped` can still need hand work in the approximated items. Keep the report next to the output in version control so
reviewers see what changed.

## Finishing by hand, then checking

1. `sysml -validate Vehicle.sysml` — the migrated notation should analyse cleanly; if not, the
   report's approximated items usually explain the diagnostic.
2. Replace approximations: opaque expressions kept as comments become real `calc`/
   `constraint` bodies; v1 `ValueType`s with units become `attribute m : MassValue = 10 [kg]`
   with `ISQ::*`/`SI::*` imports (`opensysml-sysml-authoring`).
3. Run what migrated: `-instantiate`, `-constraint`, `-state 'Modes obj' -advance N`,
   `-action` (`opensysml-checking`); the migrator maps v1 run configurations and their
   recorded results so you can compare them with the v2 run.
   Approximations this version writes that `opensysml-modeling-best-practices` shows how to
   repair: use-case actor lines as connections to the use case (add `actor` parameters), «Trace»
   as a `/* «Trace» */` comment (make it metadata).
4. `sysml -validate -strict Vehicle.sysml` for notation other SysML v2 tools will load; the
   migrator can emit nonstandard shorthand that `-strict` flags.
5. Documents and diagrams: a `document def` rendered with `-render-document ... plantuml cameo`
   style approximates Cameo's look (`opensysml-documents`).

## Where the mapping stops

- Profile-specific or tool-specific stereotypes with no SysML v1 standard meaning are
  skipped or unmapped.
- A diagram becomes a `view` that exposes what it showed. Its geometry is not in the XMI; pass
  an MTIP (HUDS XML) export of the same project with `-layout FILE` and the migrator writes
  `DiagramLayout::Layout`/`Route` metadata into the view (OpenSysML-only; `-portable` inlines
  the library, `-strict` writes none). Without it, or if you delete the metadata, OpenSysML
  lays the view out itself and the model is unchanged.
- Semantics that v2 defines differently (e.g. some activity/state-machine edge cases) are
  approximated; verify behavior by running it rather than by reading the notation.
- The feature is experimental: mapping rules, the report format and bucket boundaries can
  change between releases; pin the `sysml` version used for a migration project.

Reference: `docs/guide/11-migrating-from-sysml-v1.md` and `docs/project/transformation-census.md`
in the OpenSysML repository document each mapping rule and the report format.
