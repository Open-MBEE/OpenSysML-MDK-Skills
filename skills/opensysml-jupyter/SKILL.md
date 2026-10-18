---
name: opensysml-jupyter
description: Install and use the OpenSysML Jupyter kernel (`jupyter-opensysml-kernel` on PyPI, kernelspec `sysml`) — write notebook cells that mix SysML declarations, `%` REPL commands and expressions, draw elements with `%viz`, reuse other notebooks with `%load`, get rich (Mermaid/Markdown/HTML) output, interrupt long runs, and load .ipynb files from the CLI. Use when a task involves SysML v2 notebooks, JupyterLab, or converting between notebook and .sysml workflows.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# OpenSysML in Jupyter

The kernel is the `sysml` REPL (`opensysml-repl`) speaking the Jupyter protocol: every cell
is split exactly as the prompt splits input, state (loaded packages, instantiated objects,
running state machines) persists across cells, and `%` commands are the REPL's.

## Install

```bash
pip install jupyter-opensysml-kernel      # wheel bundles sysml-jupyter-kernel for the platform
jupyter kernelspec list                   # must list: sysml
pip install jupyterlab && jupyter lab     # JupyterLab extension (highlighting) ships in the wheel
```

Install with the *same* Python that runs the notebook server. If the kernel is not listed,
register it where the server looks: `python -m jupyter_opensysml_kernel install --user`
(or `--prefix PREFIX`).

Without pip — a binary installed by `install.sh --tools sysml-jupyter-kernel`, Homebrew or
`make build` — register the kernelspec from the binary itself:

```bash
sysml-jupyter-kernel -install              # writes the kernelspec (kernel.json and logos) for the current user
sysml-jupyter-kernel -install -user -name sysml-dev -display-name "SysML v2 (dev)"   # a second kernelspec beside it
sysml-jupyter-kernel -install -prefix "$CONDA_PREFIX"   # into an environment's share/jupyter/kernels
sysml-jupyter-kernel -print-kernelspec     # show the kernel.json instead
sysml-jupyter-kernel -connection-file F [-verbose]   # how Jupyter starts it; -verbose logs dropped or failing protocol traffic to stderr
```

The kernelspec names the binary's absolute path, `display_name` `SysML v2 (OpenSysML)`,
`language` `sysml` and `interrupt_mode` `message` (interrupts go over the control channel,
so Windows is interrupted the same way). Exit statuses: `0` normal shutdown, `1` a channel
could not be bound, `2` a command-line or connection-file error. Verified with
`sysml-jupyter-kernel` from `sysml v0.10.1-1266-gdada45c11`.

## Cells

A cell may mix declarations, `%` commands and expressions; the kernel runs each part in
order and stops at the first failure:

```sysml
package Vehicles {
  private import ScalarValues::*;
  part def Wheel { attribute diameter : Real; }
  part def Car {
    attribute mass : Real default = 1500.0;
    part wheels : Wheel[4] { attribute :>> diameter = 0.65; }
  }
  part sedan : Car { attribute :>> mass = 1800.0; }
}
```

```sysml
Vehicles::sedan.mass + 100.0        // bare expression → cell output: 1900.0
```

```text
%instantiate Vehicles::sedan
%features Vehicles::sedan
%constraint Vehicles::Car::massLimit
%state Modes rover1
%send Go to rover1
%advance 2
```

Cell language is `sysml` (or `kerml`). A redeclared package replaces the earlier one, so
re-running a definition cell updates the model.

## Drawing and documents

`%viz [--view=VIEW] [--style=STYLE...] [FORM] NAME...` draws any element without declaring
a view, in the grammar of the OMG pilot kernel's `%viz`, so pilot notebooks run unchanged.
`%render VIEW`, `%render-document NAME` and `%render-run timeline|sequence` work as in the
REPL; the kernel sends rich MIME types alongside text and JupyterLab shows the richest form
it can: `%viz` and Mermaid renders as `text/vnd.mermaid` (plus `text/vnd.graphviz`, and
`image/svg+xml` when Graphviz `dot` is on the kernel's `PATH`), `%render VIEW dot` as
`text/vnd.graphviz`, `%render VIEW markdown` and `%render-document` as `text/markdown`,
`%render-document NAME ... html` as `text/html` (the HTML fragment). Other image forms
(`plantuml`, `d2`) need the matching tool installed (`opensysml-documents`).
`%explain-code <code>` explains a diagnostic's code in a cell (`opensysml-repl`).

## Reusing notebooks and files

- `%load other.ipynb` runs another notebook's code cells into this session (in order);
  `%load --cells 1,3-5 other.ipynb` or `--cells tag:setup` selects cells.
- `%load model.sysml` and `%load dir/` load ordinary files.
- The CLI accepts notebooks too: `sysml -validate analysis.ipynb` or
  `sysml -e 'Vehicles::sedan.mass' analysis.ipynb` runs the code cells as a model, which is
  how to check a notebook in CI without Jupyter.
- `%save model.sysml` writes the session model to a file.

## Interrupting and restarting

Interrupt (stop button) ends a running `%continue`, `%step`, sweep or solver query at its
next step with `KeyboardInterrupt`; the model is unchanged and the next cell continues.
Parsing a declaration is not interruptible. Restart the kernel to clear everything
(`%clear` does the same inside the session).

## Troubleshooting

- Kernel not listed: see Install; `jupyter kernelspec list` shows the paths searched.
- Kernel dies at start: `sysml-jupyter-kernel -version` must run; on a hand-built kernelspec
  check the `argv` path in `kernel.json` (`-print-kernelspec`); start the server with the
  kernel's `-verbose` in `argv` to see protocol messages it drops.
- Output only as text: the front end lacks the Mermaid/HTML renderer; JupyterLab 4 with the
  bundled extension shows them, classic Notebook shows text.
- Models that validate in a notebook but not from `sysml FILE`: notebooks accumulate state
  across cells; export with `%save` and validate the `.sysml` to catch ordering issues.
