---
name: opensysml-drawio
description: Round-trip a SysML v2 view through draw.io with OpenSysML — export it as an editable diagrams.net file (`sysml -render-form drawio`, REPL `%render … drawio`, LSP/MCP `render_view`, VS Code export), move, resize, collapse, re-route or recolour it in draw.io desktop, diagrams.net or the VS Code draw.io extension, and import the edit back into the model as `DiagramLayout` metadata (`sysml -import-diagram`, LSP `opensysml/importDiagram`, MCP `import_diagram`, VS Code *Import layout from draw.io…*), reviewing the `Layout`/`Route`/`Style`/`Canvas` lines in the diff. Use when a diagram's layout should be edited by hand in a drawing tool and kept in the model, when a `.drawio` export looks wrong, or when an import reports cells it did not write.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Round-tripping a view through draw.io

OpenSysML writes a view as a diagrams.net (draw.io) file and reads the file back after a user
edited it: the model stays the source of truth, the drawing tool only moves things. Each cell the
writer emits is an `<object>` carrying the element's qualified name (`fqn`), so an edit is matched
to the model by name, not by position, and only what differs from a fresh export becomes an edit.
Verified with `sysml v0.11.0-1279-g1d8066d15` (develop plus the draw.io import branch): the CLI,
LSP and MCP exports stamp the same `fqn` on every cell (a port by its declaring definition,
`fqn="PumpStation::Tank::outlet" link="pump-station.sysml:8"`), and an untouched export from
any of them imports on any of them with no edit and no report. The export and its edge routing
are in nightly builds and the release after v0.11.0, the import follows them.
Forms and what a draw.io file contains: `opensysml-documents`; the layout metadata itself:
`opensysml-modeling-best-practices` §8.

## The loop

```bash
sysml pump-station.sysml -render PumpStation::stationView -render-form drawio -o stationView.drawio
#   wrote stationView.drawio (drawio, 5751 bytes)
#   … edit stationView.drawio in draw.io desktop / diagrams.net / the VS Code draw.io extension …
sysml pump-station.sysml -import-diagram stationView.drawio -dry-run     # plan + unified diff, writes nothing
#   Layout about PumpStation::station::tank
#   dry run: 1 edits planned, nothing written
#   -        metadata Layout about station::tank { x = 80; y = 160; width = 120; height = 80; }
#   +        metadata Layout about station::tank { x = 100; y = 190; width = 120; height = 80; }
sysml pump-station.sysml -import-diagram stationView.drawio              # pump-station.sysml: written
sysml pump-station.sysml -render PumpStation::stationView -render-form drawio -o stationView.drawio
sysml pump-station.sysml -import-diagram stationView.drawio -dry-run     # nothing differs …; nothing to import
```

The model is [pump-station.sysml](../opensysml-documents/references/examples/pump-station.sysml)
(an interconnection view with ports and `Layout` lines); the export is
[pump-station.drawio](../opensysml-documents/references/examples/pump-station.drawio). The edit
above dragged `tank` 20 px right and 30 px down inside `station`: a cell's `mxGeometry` is
relative to its parent, the `Layout` the import writes is absolute (`station` sits at 40, 40).

1. **Export.** Name the form — the `-o` extension does not choose it. A native `sysml` routes
   the edges before writing (exact anchors and bend waypoints, as the VS Code diagram panel draws
   them); a `js`/`wasip1` build writes them unrouted under a notice and draw.io routes them on
   open (`opensysml-wasm`). Sequence and timeline renderings have no draw.io form, and
   `-diagram-form drawio` is refused: draw.io is a view form, not a document diagram form.
2. **Edit in draw.io.** Move, resize, collapse, re-route, recolour, resize the page, add or move a
   note or picture. Keep the cells the writer made: an `fqn` is how an edit finds its element.
   The compressed form draw.io desktop saves by default is read as the uncompressed one.
3. **Import, dry run first.** The view is rendered and exported again and the file compared with
   that export cell by cell. What differs is written through the same model editor a drag in the
   VS Code diagram panel uses, into the view's body: a moved, resized or collapsed node →
   `Layout`; a re-routed edge → `Route` (a straightened one clears it); a recoloured cell →
   `Style` (`metadata DiagramLayout::Style about PumpStation::station::pump { fill = "#DAE8FC"; }`);
   a changed page → `Canvas`; a moved note or picture → `Note`/`Picture`. Positions within half a
   pixel are unchanged, so an untouched export imports nothing and the routes the writer computed
   are never written back unless the user moved them. `-view NAME` picks the page of a multi-page
   file (`no page of the file was rendered from X; the pages were rendered from Y` otherwise).
4. **Review the diff.** `-dry-run` prints `<Kind> about <element>` per edit and a unified diff per
   file; the only lines that change are `metadata … about …` lines in the view. Apply, then
   re-export: the new file imports nothing.

## Reported, not imported

Nothing is created, deleted or renamed from a drawing. Each case is a line on stderr (CLI), an
entry of the LSP/MCP result, or part of the VS Code message:

| In the file | Report | Result field |
|---|---|---|
| A shape with no `fqn` (drawn in draw.io) | `cell free1 names no element; it is not imported` | `unknown` |
| An `fqn` the rendering lacks (renamed, filtered out, gone) | `… is not in the rendering; its cell is not imported` | `unmatched` |
| A cell the file lost | `… was deleted from the file; the element stays in the model` | `deleted` |
| A port moved along its owner's border | `PumpStation::Tank::outlet: a port is drawn on its owner's border; its position in the file is not imported` | `notices` |
| A port dragged onto another node | `PumpStation::Tank::outlet: a port was moved to another cell; it stays on its owner, so the move is not imported` | `notices` |
| A moved label, a recoloured port, a re-anchored note, a re-routed edge no `Route` steers (a typing edge) | a notice; no edit | `notices` |

## The same loop from a client

| Surface | Export | Import |
|---|---|---|
| CLI | `-render … -render-form drawio -o f.drawio` | `-import-diagram f.drawio [-view V] [-dry-run]` |
| REPL / Jupyter | `%render V drawio` (the XML on stdout / in the cell) | — (use the CLI) |
| LSP | `opensysml/render` `"form": "drawio"` → `artifact` | `opensysml/importDiagram {textDocument, path｜content, view?, inline?, dryRun}` → `edits`, `unmatched`, `unknown`, `deleted`, `notices`, `edit` (a `WorkspaceEdit` the client applies) |
| MCP | `render_view {"path", "view", "form": "drawio"}` → text + `structuredContent.artifact` | `import_diagram {"path", "file"｜"content", "view"?, "inline"?, "apply"?}` → `edits`, `changes`, `applied`; dry run until `"apply": true` |
| VS Code | *SysML: Export Diagram* → `.drawio` | *SysML: Import layout from draw.io…* (`opensysml.importDiagram`): pick the file, the edit is applied, reports in the message |

`inline` (LSP/MCP) writes the annotations beside the elements rather than in the view's body. The
real MCP exchanges are in
[opensysml-mcp/references/stdio-session.md](../opensysml-mcp/references/stdio-session.md); the
LSP's `edit` for the move above was one `newText` of `100; y = 19` over the old coordinates.

## When the file looks wrong

- Edges unrouted (`<!-- notice: edges not routed … -->`): a WASM build; re-export with a native
  `sysml`. One edge among routed ones with no anchors: the router found no path (ports on top
  borders with no room above); give the layout room or let draw.io route it.
- `OPENSYSML_LIBAVOID_WASM` swaps the embedded router module (`opensysml-troubleshooting`).
