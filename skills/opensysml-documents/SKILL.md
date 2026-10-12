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
views). Nothing is drawn by hand; change the model, re-render.

```bash
sysml -list all model.sysml                 # documents, views, diagrams, pseudo-views by name
sysml -list views -list-kind state,action model.sysml
sysml -list documents -list-form tsv model.sysml
```

## Views → diagrams

```bash
sysml -render Pkg::systemView model.sysml                    # form the view's `render` member states
sysml -render Pkg::systemView -render-form mermaid -o sys.mmd model.sysml
sysml -render Pkg::stateView -render-form dot -render-style pilot -render-palette okabe-ito model.sysml
sysml -render-all out/ -render-form plantuml model.sysml     # every declared view
sysml -graphs Pkg::Rover::Drive -o drive.dot model.sysml     # lowered action/state graph for debugging
```

- `-render-form`: `text` (default), `mermaid`, `markdown`, `dot`, `plantuml`, `d2`, `csv`,
  `tsv`. Text forms are self-contained; graph forms are source for Mermaid/Graphviz/PlantUML/D2,
  which `-doc-form html|pdf` turns into images when the tool is installed.
- `-render-style pilot|...` draws like the OMG Pilot visualizer by default;
  `-render-palette` picks node colours by keyword family; `-render-ports minimal|...`
  controls port detail; `-render-overlay` adds verdicts/runs over requirement renderings;
  `-render-unplaced` places elements a `Layout` omits.
- Geometry is optional `DiagramLayout::Layout`/`Route` metadata in the view body (OpenSysML-only;
  the pilot cannot load it) — see `opensysml-modeling-best-practices` for views that stay portable.
- `-render-link TEMPLATE` makes nodes link to source (`{file}`, `{line}`, `{col}`,
  `{qname}`, `{id}`), useful for HTML output in a repository viewer.
- Views that depend on a run (`-render-run timeline|sequence` in the REPL) need the run
  first; in the CLI pair `-action`/`-state` with the render.

## Documents

```bash
sysml -render-document Pkg::SystemReport -o report.md model.sysml          # Markdown (default)
sysml -render-document Pkg::SystemReport -doc-form html -doc-toc -doc-number-sections -o report.html model.sysml
sysml -render-document Pkg::SystemReport -doc-form pdf -doc-title-page -doc-number-figures -o report.pdf model.sysml
sysml -render-documents site/ -doc-form html model.sysml                   # every document, cross-linked
```

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

REPL: `%list`, `%documents`, `%views`, `%view NAME`, `%render NAME [form [palette]]`,
`%render-document NAME [mermaid|dot|plantuml|d2 [pilot|cameo]]`, `%render-run`, `%viz`.
Clients: `render_view`/`renderView` and `render_document`/`renderDocument` return the text of
the chosen form (`opensysml-python`, `opensysml-node`, …); HTML needs the service to
advertise `render_document_html`. Jupyter shows Mermaid/HTML inline (`opensysml-jupyter`).

## Troubleshooting

- `no view named X` / `no document named X`: `-list all` shows exact qualified names.
- Empty diagram: the view's `expose`/filter selects nothing in the loaded files; check with
  `-render -render-form text` which lists the selected elements.
- `-doc-form pdf` produced a file but diagrams are literal text: the converter was not
  found; set the variable from the table above.
- Large models: render single views rather than `-render-all`, and prefer `mermaid`/`dot`
  sources over images in CI.
