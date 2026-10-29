---
name: opensysml-documents
description: Generate documents and diagrams from a SysML v2 model with OpenSysML — render `document def`s to Markdown, HTML or PDF with `-render-document`/`-render-documents`, render views to text, Mermaid, DOT, PlantUML, D2 or CSV with `-render`/`-render-all`, list what a model can render, choose palettes/styles/port display, and provision the external PDF and diagram toolchain. Use when a task asks for a report, diagram, table or publication built from a model, or when a render fails because a converter is missing.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Documents and diagrams

OpenSysML renders two kinds of thing declared *in the model*: **views** (`view def` /
`view` with a `render` member — interconnection, tree, state, action, requirement, table
views) and **documents** (`document def`s whose sections run model queries and embed
views). Nothing is drawn by hand; change the model, re-render. Verified with
`sysml v0.10.1-1266-gdada45c11`; `-render-show`, `-render-depth`, `-render-lines`, the
`svg`/`svg-animated` run forms, the `-html-*` options and the empty-rendering notice are in
nightly builds and the release after 0.10.1.

```bash
sysml -list all model.sysml                 # documents, views, diagrams, pseudo-views by name
sysml -list views -list-kind state,action model.sysml
sysml -list documents -list-form tsv model.sysml   # text (default), tsv or json
```

```text
view      tree             V::carTree
document  RoverChecks::RoverReport
```

## Views → diagrams

```bash
sysml -render Pkg::systemView model.sysml                    # kind the view's `render` member states; Mermaid on stdout
sysml -render Pkg::systemView -render-form mermaid -o sys.mmd model.sysml
sysml -render Pkg::stateView -render-form dot -render-style pilot -render-palette okabe-ito model.sysml
sysml -render '#state:Pkg::Rover::Modes' model.sysml         # pseudo-view: one element, no view declared
sysml -render '#tree' model.sysml                            # pseudo-view over every file loaded
sysml -render Pkg::systemView -render-show typings,multiplicities -render-depth 2 -render-lines ortho model.sysml
sysml -render-all out/ -render-form plantuml model.sysml     # every declared view
sysml -graphs Pkg::Rover::Drive -o drive.json model.sysml    # lowered action/state graph (graphs:1 JSON) for debugging
```

- `-render-form`: `text`, `mermaid`, `markdown`, `dot`, `plantuml`, `d2`, `drawio`, `csv`,
  `tsv` (`csv`/`tsv` for a table or matrix); without it `-render` writes the text form to a
  terminal and the kind's machine form (Mermaid for a diagram) to a file or pipe — the `-o`
  extension does not choose the form (`-o view.drawio` alone writes Mermaid; say `-render-form
  drawio`) — and `-render-all` writes each kind's machine form.
- `drawio` (`sysml v0.11.0-1195-g14e53c052`; in nightly builds and the release after v0.11.0) writes an uncompressed
  diagrams.net (draw.io) file that draw.io desktop, diagrams.net and the VS Code draw.io
  extension open and edit as it is: `<mxfile host="OpenSysML" compressed="false">`, one
  `<diagram>` named for the view, every node, port and edge an `<object>` carrying the
  element's `fqn`, `kind` and `view` beside draw.io's `label`, stated `Layout` geometry as each
  cell's `mxGeometry` (relative to the parent cell), an unplaced view on a grid for *Arrange ›
  Layout* ([pump-station.sysml](references/examples/pump-station.sysml) →
  [pump-station.drawio](references/examples/pump-station.drawio)). A native `sysml` routes every
  edge the view leaves unrouted before writing (libavoid, the router the VS Code diagram panel
  uses): exact `exitX`/`exitY`/`entryX`/`entryY` anchors and the bends as `<mxPoint>`
  waypoints, so the file opens the same in every editor; the `js`/`wasip1` builds write them
  unrouted under a notice and draw.io routes them on open (`opensysml-wasm`). It is a view form,
  not a document diagram form: `-diagram-form drawio` is refused (`unknown diagram form
  "drawio"; -diagram-form takes mermaid, dot, plantuml, d2`) because the HTML and PDF backends
  turn diagram source into images and nothing rasterizes a draw.io file. Every graph kind has it
  but `sequence` (`-render '#sequence' -render-form drawio` answers `a sequence rendering is
  not written as drawio; ask for text, mermaid, plantuml or d2`). Nothing reads an edited `.drawio` back into
  `Layout`/`Route` metadata yet; the LSP's `setLayout`/`setRoute` do (`opensysml-lsp`).
  Graph forms are source for Mermaid/Graphviz/PlantUML/D2, which
  `-doc-form html|pdf` turns into images when the tool is installed; a tree asked for as
  `svg` is refused (`a tree rendering is not written as svg; ask for text, mermaid, dot,
  plantuml or d2`).
- Pseudo-view kinds: `tree`, `interconnection`, `state`, `action`, `case`, `mixed`,
  `sequence`, `table`, `matrix`, as `#<kind>` or `#<kind>:<element>`.
- Every node draws its `«keyword»` line by default (`«part def» Car`); the optional notation
  elements are opt-in through `-render-show`, comma-separated: `parameter-symbols`,
  `port-symbols`, `compartments`, `edge-labels`, `keywords`, `multiplicities`, `typings`,
  `qualifiers` or `all` (port symbols, compartments and keywords are on by default; a wrong
  name is refused with the list). `-render-depth N` stops at N nesting levels and marks the
  rest `nested deeper than N level; not shown`; `-render-lines splines|ortho|polyline`
  routes edges (DOT `splines=ortho`).
- `-render-style pilot|cameo` draws like the OMG Pilot visualizer by default;
  `-render-palette` picks node colours by keyword family (`okabe-ito`, `tol-bright`,
  `tol-muted`, `tol-light`, `brewer-set2`, `brewer-dark2`, `viridis`, `cividis`);
  `-render-ports minimal|full` controls port detail; `-render-overlay verdicts` adds
  verdicts over requirement renderings; `-render-unplaced omit|strip` handles elements a
  `Layout` omits.
- Geometry is optional `DiagramLayout::Layout`/`Route` metadata in the view body; `DiagramLayout`
  is an OpenSysML extension library, so hand it to other tools with the model — see
  `opensysml-modeling-best-practices`.
- `-render-link TEMPLATE` makes nodes link to source (`{file}`, `{line}`, `{col}`,
  `{qname}`, `{id}`), useful for HTML output in a repository viewer.
- A run's trace is drawn with `-render-run timeline=PATH` or `sequence=PATH` (`-` is
  stdout) after `-action`/`-state`/`-advance` in the same command; the form comes from the
  extension or `-render-form`, and `svg` (a self-contained drawing) or `svg-animated` (an
  SMIL replay of the run) are for `-render-run` only. The REPL's `%render-run` needs
  `%trace on` before the run.

## Documents

```bash
sysml -render-document Pkg::SystemReport -o report.md model.sysml          # Markdown (default): wrote report.md (markdown, 1519 bytes)
sysml -render-document Pkg::SystemReport -doc-form html -doc-toc -doc-number-sections -o report.html model.sysml
sysml -render-document Pkg::SystemReport -doc-form html -html-theme nasa -html-mermaid cdn -html-math cdn -o report.html model.sysml
sysml -render-document Pkg::SystemReport -doc-form html -html-fragment -o fragment.html model.sysml   # the <article> alone, for a host page
sysml -render-document Pkg::SystemReport -doc-form pdf -pdf-engine weasyprint -doc-title-page -doc-number-figures -o report.pdf model.sysml
sysml -render-document Pkg::SystemReport -diagram-form plantuml -o report.md model.sysml   # diagrams as PlantUML instead of Mermaid
sysml -render-documents site/ -doc-form html model.sysml                   # every document, cross-linked; exit 3 if some failed
```

- `-doc-form markdown|html|pdf`; `-diagram-form mermaid|dot|plantuml|d2` chooses the
  diagram source embedded; `-doc-title-page`, `-doc-toc`, `-doc-number-sections`,
  `-doc-number-figures` shape HTML and PDF only (asked of Markdown they are refused with
  `ask for one with -doc-form html or -doc-form pdf`; the `-pdf-title-page`, `-pdf-toc`,
  `-pdf-number-sections` spellings are deprecated aliases).
- HTML: `-html-theme default|acm|ieee|modern|nasa|print|report`, `-html-css FILE|URL` adds a
  stylesheet, `-html-no-default-css` drops the built-in one, `-html-default-css` prints it
  for copying, `-html-mermaid cdn|URL` and `-html-math cdn|URL` load the Mermaid and math
  renderers in the page; `-html-fragment` writes the `<article class="sysml-document">`
  alone and cannot be combined with `-html-theme`.
- PDF: `-pdf-engine weasyprint|pandoc|prince`; a missing engine is reported as
  `the weasyprint engine needs weasyprint, which was not found; install it ... and point
  OPENSYSML_WEASYPRINT at it, or select another engine with -pdf-engine` (exit `2`).

A document's sections run document queries (`-query`-style selections, tables of
elements, verdict tables of constraints and requirements) and embed views; `-render-document`
compiles the definition, runs the queries against the model as loaded (so pass every file,
and `-instantiate`/`-action` when a section reports on objects or runs) and writes one file.
`-doc-form markdown` needs no external tools and is the right form for CI artifacts and
agent consumption.

## External toolchain (HTML images and PDF)

| Output | Tool | Pointer when not on PATH |
|---|---|---|
| PDF | WeasyPrint (or Prince) | `OPENSYSML_WEASYPRINT`, `OPENSYSML_PRINCE` |
| Markdown → HTML conversion of embedded content | pandoc | `OPENSYSML_PANDOC` |
| Mermaid diagrams to SVG | mermaid-cli (`mmdc`) + a Puppeteer config | `OPENSYSML_MMDC`, `OPENSYSML_MMDC_PUPPETEER` |
| DOT | Graphviz `dot` | `OPENSYSML_DOT` |
| PlantUML | `plantuml.jar` + Java | `OPENSYSML_PLANTUML_JAR`, `OPENSYSML_JAVA` |
| D2 | `d2` | `OPENSYSML_D2` |
| Formulas | KaTeX | `OPENSYSML_KATEX`, `OPENSYSML_KATEX_CSS` |

In an OpenSysML checkout `./scripts/download-doc-pdf-toolchain.sh` provisions pinned copies
under `build/doc-pdf/`; export the variables it prints. A missing tool is reported as a
diagnostic naming the variable, and the diagram stays as its text source in the output
rather than failing the whole document — check stderr before shipping a PDF.

## REPL and clients

REPL: `%list`, `%documents`, `%views [diagrams] [kind...]`, `%view NAME`,
`%render NAME [form [palette] [style] [ports] [link=T] [depth=N]]`,
`%render-document NAME [mermaid|dot|plantuml|d2 [pilot|cameo]]`, `%render-run`,
`%run-query NAME [p=expr...]`, `%viz`. Clients: `render_view`/`renderView` and
`render_document`/`renderDocument` return the text of the chosen form, `drawio` included (`opensysml-python`,
`opensysml-node`, …); HTML needs the service to advertise `render_document_html`; the
`sysml-wasm` module serves `RenderView` too (`opensysml-wasm`). Jupyter shows Mermaid/HTML
inline (`opensysml-jupyter`).

## Troubleshooting

- `no view named X` / `no document named X`: `-list all` shows exact qualified names.
- `note: V::x renders empty` before an empty diagram says why: the view exposes nothing,
  its filter rejects every element (named as written), what it exposes does not resolve,
  or nothing it exposes is shown by a rendering of this kind. `-render-form text` lists
  the selected elements and a `not represented:` section.
- `-render-show: unknown notation element "pins"; the elements are parameter-symbols, …`:
  use a name from the list.
- `-doc-form pdf` produced a file but diagrams are literal text: the converter was not
  found; set the variable from the table above.
- Large models: render single views rather than `-render-all`, and prefer `mermaid`/`dot`
  sources over images in CI.
