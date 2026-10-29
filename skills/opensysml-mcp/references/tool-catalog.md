# `sysml-mcp` tool catalog

Generated from the server's own `tool_catalog` and `tools/list` answers (`sysml-mcp v0.10.1-1266-gdada45c11`, every group served: 82 tools).
*Stands for* is the `sysml-grpc` RPC and/or `sysml` flag the tool performs (`none` for a tool with no service counterpart). *Writes* is `yes` when the tool's `readOnlyHint` annotation is false: an `lsp` tool then writes files only with `"apply": true`; a `session` tool changes the session's state (declarations, objects, a run), not files, unless it says so. *Does* is the first sentence of the tool's description as `tools/list` returns it; the full description, with every argument, is what the agent reads.

## Every group (1)

| Tool | Does | Stands for | Writes |
|---|---|---|---|
| `tool_catalog` | List the tools this server serves: each tool's name, group, the sysml-grpc RPC or `sysml` CLI flag it stands for, and a one-line summary. | none | no |

## `lsp` — the workspace under `-root` (21)

| Tool | Does | Stands for | Writes |
|---|---|---|---|
| `apply_model_edit` | Edit a model by operations on its elements rather than by text: setValue, rename, addMember, addConnection, addSequence (action-body items), delete, move, and the diagram-layout annotations setLayout, setRoute, setCanvas, setStyle. | none | yes |
| `close_document` | Release a document held open by open_document: the server goes back to the file on disk (or forgets the document when there is no file). | none | yes |
| `code_actions` | List the quick fixes and refactorings available for a range of a document, each with the edits it would make. | none | no |
| `completion` | Propose completions at a position: keywords, names in scope and members of the type being accessed. | none | no |
| `definition` | Find where the name at a position is declared. | none | no |
| `document_symbols` | Outline a document: the elements it declares, nested as they are owned, with their kinds and ranges. | none | no |
| `documents` | List the document definitions (doc def) declared across the workspace, which render_document renders to Markdown. | none | no |
| `format` | Format a SysML v2 / KerML document, or only the lines of a range, in the canonical style. | none | yes |
| `hover` | Explain the element at a position: its kind, qualified name, type, value and documentation, as Markdown. | none | no |
| `inlay_hints` | List the inferred types and values the editor would show inline for the features of a document or range. | none | no |
| `open_document` | Hold a document open with the given text, as an editor buffer the server analyzes instead of the file on disk, so text can be checked (diagnostics, hover, render) before it is written. | none | yes |
| `references` | Find every place in the workspace that refers to the element at a position. | none | no |
| `rename` | Rename the element declared or referenced at a position, everywhere in the workspace. | none | yes |
| `render_document` | Render a document definition (doc def) to Markdown, its queries evaluated over the workspace and its diagrams embedded. | none | no |
| `render_view` | Render a diagram or table of a document: a declared view or a pseudo-view, as Mermaid, Graphviz dot, PlantUML, D2, draw.io (diagrams.net XML), text, Markdown, CSV or TSV. | none | no |
| `signature_help` | Describe the invocation enclosing a position: the callable's parameters and which one the position is at. | none | no |
| `update_document` | Replace the text of a document held open by open_document and re-analyze it. | none | yes |
| `views` | List the views a document declares and the pseudo-views (#tree, #interconnection, ...) render_view can draw of it. | none | no |
| `workspace_diagnostics` | Analyze a SysML v2 / KerML document, or the whole workspace, and list the errors, warnings and hints: syntax, unresolved names, type and constraint violations. | none | no |
| `workspace_info` | Describe the SysML v2 workspace the server has indexed: its root folder and the model documents found under it. | none | no |
| `workspace_symbols` | Search the workspace's declared elements by name substring. | none | no |

## `runtime` — one-shot service, one tool per RPC (31)

| Tool | Does | Stands for | Writes |
|---|---|---|---|
| `apply_edits` | Apply source-preserving edits to a parsed model and return the edited notation (the ApplyEdits RPC): set a value, rename with every reference, add a member, import, documentation, comment, connection, transition, satisfy or metadata, delete, move. | rpc ApplyEdits | no |
| `compare_results` | Run every configuration a SysML v1 tool's results sidecar indexes against the migrated model (the CompareResults RPC, the CLI's -compare-results with -action, -runs, -seed, -draws, -clock-step and -observe): each on its target, for its recorded run count under its duration mode, or the runs and draws given, and table the tool's and OpenSysML's min, mean, p50, p90 and max of each observable with their relative difference. | rpc CompareResults, sysml -compare-results | no |
| `convert` | Convert a SysML v2 model between the representations OpenSysML writes — textual notation, RDF Turtle, the API's JSON element form — (the Convert RPC, the CLI's -convert). | rpc Convert, sysml -convert, sysml -from, sysml -id, sysml -include-library-stubs | no |
| `diagnostics` | Report every diagnostic of a parsed model (the GetDiagnostics RPC), as `sysml -validate` does: each with its severity, code, message and position. | rpc GetDiagnostics, sysml -validate, sysml -disable-lint, sysml -enable-lint | no |
| `explain_diagnostic` | Explain a diagnostic code (as the CLI's -explain does): what it means, how to resolve it and the specification clause or validation constraint behind it. | sysml -explain | no |
| `evaluate` | Evaluate a SysML expression against a parsed model (the Evaluate RPC, the REPL's %eval): arithmetic, feature reads, quantities with units, collection operators. | rpc Evaluate, sysml -eval | no |
| `evaluate_calc` | Invoke a calculation (the EvaluateCalc RPC, the REPL's %calc): a calc definition with positional arguments answers its `result`; a calc usage named with no arguments binds its inputs from its own members and answers every output feature in `outputs`. | rpc EvaluateCalc, sysml -calc | no |
| `execute_action` | Run an action definition or usage to completion and report its output parameters (the ExecuteAction RPC, the REPL's %run). | rpc ExecuteAction, sysml -action, sysml -schedule, sysml -advance, sysml -seed, sysml -draws, sysml -clock-step | no |
| `execute_state` | Run a state machine over a sequence of events and report the states visited, the final context and the simulation clock (the ExecuteState RPC, the REPL's %run on a state). | rpc ExecuteState, sysml -state | no |
| `export_graphs` | Export the lowered graph of an action or state machine — the subject's and every behavior it performs — as the canonical graphs:<version> JSON external analysis engines read (the ExportGraphs RPC). | rpc ExportGraphs, sysml -graphs | no |
| `import_data` | Set the feature values a CSV, TSV, JSON or JSON Lines file assigns, one row per element (the ImportData RPC, the CLI's -import with -import-as, -import-map, -import-format and -import-dry-run): a feature the element declares has its value set, one it inherits is redefined in the element's body with the value, as one edit per file; a value the model refuses leaves every row unapplied and answers `error`. | rpc ImportData, sysml -import, sysml -import-as, sysml -import-map, sysml -import-format, sysml -import-dry-run | no |
| `instantiate` | Build an object of a part definition or usage and report its feature values (the Instantiate RPC, the REPL's %instantiate): every attribute's value or default, nested parts as instance ids, with every reachable instance in `instances`. | rpc Instantiate, sysml -instantiate | yes |
| `list_engines` | List the analysis engines this build registers (the ListEngines RPC, as the CLI's -engines does): each with the questions it answers (evaluate, outcomes, holds, sensitive, satisfiable, sweep, compute), the strongest evidence it can produce, the bounds it takes, and whether it can run here. | rpc ListEngines, sysml -engines, sysml -probe | no |
| `migrate` | Migrate a SysML v1 model — UML XMI with the SysML profile, an Eclipse UML2 .uml file or a Cameo/MagicDraw .mdzip archive — to SysML v2 in one of the representations convert writes (the Migrate RPC, the CLI's -migrate). | rpc Migrate, sysml -migrate, sysml -migration-report, sysml -migration-results, sysml -layout, sysml -image-base-url | no |
| `parse` | Parse SysML v2 / KerML documents as one model and return its modelHash, the root namespace of each document and every diagnostic (the ParseSources RPC). | rpc ParseFile, rpc ParseSources, sysml -strict | no |
| `query` | Select elements of a parsed model with a SysML v2 API & Services Query — scope, select, where, orderBy — or OSLC query text (the Query RPC). | rpc Query, sysml -query | no |
| `render_model_document` | Render a named document of a model given by modelHash, paths or sources (the workspace group's render_document renders by name over the root) — a part def specializing DocumentQueries::Document — to Markdown, HTML or AsciiDoc (the RenderDocument RPC, the CLI's -render-document), byte for byte what the CLI writes. | rpc RenderDocument, sysml -render-document, sysml -doc-form | no |
| `record_run` | Run an analysis case — once, over the rows of a sweep (`ranges`), or as a Monte Carlo sample (`runs`) — and record the runs into the model as AnalysisRecords declarations (the RecordRun RPC, the CLI's -record-run/-record-into, the REPL's %record). | rpc RecordRun, sysml -record-run, sysml -record-into | no |
| `render_model_view` | Render a declared view or a targeted pseudo-view of a model given by modelHash, paths or sources as diagram data (the RenderView RPC; the workspace group's render_view renders by name over the root): nodes flattened parents first, edges with their ports, table columns and rows, canvas, notes and notices. | rpc RenderView, sysml -render, sysml -render-ports, sysml -render-show, sysml -render-depth, sysml -render-compartments | no |
| `check_behavior` | Search every schedule of an action or state machine (the CheckBehavior RPC, the REPL's %check-property/%check-diverge settings about %action/%state): a property false at a stable state, a deadlock, a failure or a feature whose final value the schedule decides is witnessed and replayed. | rpc CheckBehavior, sysml -check-property, sysml -check-diverge, sysml -check-input, sysml -check-assume, sysml -check-witness, sysml -check-depth, sysml -check-states, sysml -check-unroll, sysml -check-timeout | no |
| `run_analysis` | Run an analysis case (the RunAnalysis RPC, the REPL's %analysis): its subject and inputs bound from the arguments and its own declarations, its body run, every declared output answered with the verdict of its objective and of each assertion in its body; a verification case also answers its own verdict. | rpc RunAnalysis, sysml -analysis, sysml -engine, sysml -tool-dry-run | no |
| `run_document_query` | Run a named document query with parameter bindings and answer its typed rows (the RunDocumentQuery RPC, the REPL's %run-query). | rpc RunDocumentQuery, sysml -run-query | no |
| `run_runs` | Run an action, or a Simulation::MonteCarlo analysis case, a number of times (the RunRuns RPC, the CLI's -runs/-observe, the REPL's %runs): every run is an ordinary run in a context of its own, drawing its modeled randomness from a seed derived from `seed`. | rpc RunRuns, sysml -runs, sysml -observe | no |
| `run_sweep` | Run an analysis case or calc once per row of a parameter sweep (the RunSweep RPC, the CLI's -sweep): each row an ordinary run with the swept parameters bound to that row's values, stepped through the ranges' cartesian product or drawn with samples and seed. | rpc RunSweep, sysml -sweep, sysml -samples | no |
| `self_check` | Apply the SysMLValidation constraints, and those of any rule packages named, reflectively to every element of a model (the SelfCheck RPC, the CLI's -self-check and -self-check-package): each element is handed to every constraint whose input its metaclass conforms to. | rpc SelfCheck, sysml -self-check, sysml -self-check-package | no |
| `server_info` | Report the OpenSysML runtime's version and the named capabilities this build supports. | rpc GetServerInfo | no |
| `symbol` | Describe one element of a parsed model by qualified name (the GetSymbol RPC): its kind, metadata, children, attributes with their declared values, static type facts, multiplicity and specializations. | rpc GetSymbol | no |
| `validate_instance` | Validate an object of a part as a whole (the ValidateInstance RPC, the REPL's %validate): every assertion about an object of symbolId and about the objects it holds — asserted constraints of their types, the requirements they carry, the satisfactions they are the subject of — each answered on the concrete object, with a `summary` verdict about the object as a whole. | rpc ValidateInstance | no |
| `verify_constraint` | Ask whether a constraint holds (the VerifyConstraint RPC, the REPL's %constraint): against its declared values, or against an object of subjectSymbolId built for the call. | rpc VerifyConstraint, sysml -constraint | no |
| `verify_requirement` | Ask whether a requirement is satisfied (the VerifyRequirement RPC, the REPL's %requirement): its require constraints evaluated against declared values or against an object of subjectSymbolId. | rpc VerifyRequirement, sysml -requirement | no |
| `verify_satisfaction` | Evaluate the satisfy assertions a model states (the VerifySatisfaction RPC, the REPL's %satisfy): each against an object of its subject built for the call, answering one Verdict per assertion in declaration order. | rpc VerifySatisfaction, sysml -satisfy | no |

## `session` — persistent REPL sessions (29)

| Tool | Does | Stands for | Writes |
|---|---|---|---|
| `advance` | Advance the debuggers' simulation clock (%advance), running every state event, action token, change-condition poll and do behavior that comes due, in due order, and report what ran and where the debuggers stand. | none | yes |
| `check` | Ask an SMT solver whether a constraint, requirement or satisfaction can be satisfied at all (%check, experimental), with a satisfying assignment when it can. | none | no |
| `configure` | Ask an SMT solver which variants an element's conditions permit (%configure, experimental): a consistent selection, the check of the selections given, or every consistent selection up to a limit. | none | no |
| `debug_breakpoints` | Set breakpoints at nodes of the debugged action (%break), optionally clearing the earlier ones, and report the breakpoints it then has; with nothing to set, lists them. | none | yes |
| `debug_continue` | Run the debugged action to completion, or to the first breakpoint a token reaches (%continue), and report its results. | none | yes |
| `debug_current` | Report where the debugging session stands without changing it: the action's execution state, tokens, breakpoints and feature values (%tokens), or the machine's current state, clock, event queue, signals in flight and state data (%current, %events). | none | no |
| `debug_start` | Start a debugging session on an action (%action) or a state machine (%state), performed by an object when one is named. | none | yes |
| `debug_step` | Advance the debugged action one token step, or the debugged state machine one step (%step): one event dispatched, one change event, one round of do actions. | none | yes |
| `debug_stop` | End the debugging session (%stop), letting go of its run; objects the session holds stay. | none | yes |
| `explain` | Ask an SMT solver which conditions of an unsatisfiable element conflict (%explain, experimental): a minimal set of conditions, each with the element declaring it and its location. | none | no |
| `features` | Show an object's feature values and what its behaviors are doing (%features): the values its attributes hold, the objects its parts and ports hold, its connectors, and the state of each machine it exhibits and action it performs. | none | no |
| `instances` | List the objects a session holds (%instances): each with its id, type and lifetime, the ones a later instantiation displaced included. | none | no |
| `optimize` | Ask an SMT solver for the best values an analysis case's objectives admit (%optimize, experimental), each objective improved as its trade-study definition says, within the case's conditions. | none | no |
| `render_run` | Render the run a session recorded as a state timeline or a message sequence (%render-run), in a text, diagram or SVG form. | none | no |
| `repl_command` | Run one sysml prompt command (a % line) in a session and return what it printed. | none | yes |
| `runs` | Run an action count times, each run's modeled randomness seeded on its own, and return the table of the observables with each one's distribution (%runs); or run a Simulation::MonteCarlo analysis case count times on fresh subjects and conclude it. | none | yes |
| `send` | Send a signal to an object through the runtime's message bus (%send), for the state machine it exhibits or the action parked at a matching accept to take; by default to the object whose behavior is being debugged. | none | yes |
| `session_clear` | Reset a session, as %clear does: every declaration, object and debugging session goes; the session stays open and empty. | none | yes |
| `session_close` | Close a REPL session, discarding its model, instances and any run in progress. | none | yes |
| `session_eval` | Evaluate an expression in a session, as %eval does: a literal, a declared feature or qualified name, an enumeration literal, a unit, or a compound expression over the session's declarations. | none | no |
| `session_list` | List the open REPL sessions. | none | no |
| `session_load` | Load model files into a session, as %load does: files, directories or globs, resolved against the workspace root and refused outside it. | none | yes |
| `session_open` | Open a named REPL session: an empty model that declarations, instances and runs accumulate into across calls. | none | yes |
| `session_print` | Print a session's model as SysML notation, or one named element with its body, as %print does. | none | no |
| `session_run` | Run a behavior in a session to completion and report what it produced: an action (%action then %continue), a state machine (%state, then %advance when a duration is given), a calc (%calc) or an analysis case (%analysis). | none | yes |
| `session_save` | Write a session's model to a file under the workspace root, as %save does: .sysml notation with comments preserved, or .ttl/.json RDF (experimental). | none | yes |
| `session_submit` | Submit SysML declarations to a session, as typing them at the prompt does: the text joins the model, the whole model is re-analyzed, and what it declared and the diagnostics about it come back. | none | yes |
| `solve` | Ask an SMT solver for values satisfying an element's conditions (%solve, experimental), keeping the values the model already fixes; reports the conflict when the fixed values admit none. | none | no |
| `sweep` | Run a calc or analysis case once per row of the ranges given (%sweep), or over rows drawn from them (%samples), and return the table: each row's inputs, outputs, verdicts and timing. | none | yes |
