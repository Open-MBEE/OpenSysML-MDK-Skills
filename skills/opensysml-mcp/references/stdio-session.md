# `sysml-mcp` on the wire

Real exchanges with `sysml-mcp v0.10.1-1266-gdada45c11 -root ~/proj`, newline-delimited
JSON-RPC 2.0 over stdin/stdout, trimmed to what matters. The probe workspace held one file,
`models/probe.sysml`:

```sysml
package Probe {
    private import ScalarValues::*;
    part def Battery { attribute capacity : Real = 100.0; attribute mass : Real = 2.5; }
    part def Rover {
        part battery : Battery;
        attribute wheels : Integer = 6;
        attribute totalMass : Real = battery.mass + 10.0;
    }
    calc def Range { in capacity : Real; in draw : Real; return : Real = capacity / draw; }
    action def Drive {
        in distance : Real; out hours : Real;
        action plan { out h : Real = distance / 10.0; }
        bind plan.h = hours;
    }
    requirement def LightEnough { subject rover : Rover; require constraint { rover.totalMass < 20.0 } }
    part rover1 : Rover;
    view def Structure;
    view roverView : Structure { expose Probe::*; }
}
```

## Handshake

```json
→ {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}
← {"jsonrpc":"2.0","id":1,"result":{
     "protocolVersion":"2025-06-18",
     "capabilities":{"logging":{},"resources":{"listChanged":true},"tools":{"listChanged":true}},
     "serverInfo":{"name":"sysml-mcp","title":"OpenSysML","version":"v0.10.1-1266-gdada45c11","websiteUrl":"https://github.com/Open-MBEE/OpenSysML"},
     "instructions":"OpenSysML serves SysML v2 and KerML models. The workspace tools read and edit the model documents under the server's root folder … Positions in tool arguments are 1-based line and column numbers."}}
→ {"jsonrpc":"2.0","method":"notifications/initialized"}
→ {"jsonrpc":"2.0","id":2,"method":"tools/list"}
← {"jsonrpc":"2.0","id":2,"result":{"tools":[ … 82 tools, each with name, title, description, inputSchema, annotations … ]}}
```

Every list-typed argument is `"type": ["null", "array"]` in the schemas, and every schema has
`additionalProperties: false`, so a misspelt argument is refused before the tool runs:

```json
← {"result":{"content":[{"type":"text","text":"validating \"arguments\": validating root: unexpected additional properties [\"name\"]"}],"isError":true}}
```

## `tool_catalog`

```json
→ {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"tool_catalog","arguments":{"group":"session"}}}
← {"result":{
     "content":[{"type":"text","text":"tool_catalog (none): List the tools this server serves, each with the RPC or sysml flag it stands for.\nadvance (none): Advance the debugged state machine's clock by a duration, …"}],
     "structuredContent":{"groups":["session"],"tools":[
       {"name":"tool_catalog","operation":"none","summary":"List the tools this server serves, …"},
       {"group":"session","name":"advance","operation":"none","summary":"Advance the debugged state machine's clock by a duration, firing the timed transitions due."},
       … ]}}}
```

A `runtime` entry's `operation` reads `rpc GetDiagnostics, sysml -validate, sysml -disable-lint, sysml -enable-lint`.

## `diagnostics` and `evaluate` on a file under the root

```json
→ {"method":"tools/call","params":{"name":"diagnostics","arguments":{"paths":["models/probe.sysml"]}}}
← {"result":{
     "content":[{"type":"text","text":"model 013034ae60d283535cd450818fbf5d67dccf7f3d94b453e49af33ac6b287d237\nno diagnostics"}],
     "structuredContent":{"diagnostics":[],"error":"","modelHash":"013034ae60d2…b287d237"}}}

→ {"method":"tools/call","params":{"name":"evaluate","arguments":{"paths":["models/probe.sysml"],"expression":"Probe::rover1.totalMass"}}}
← {"result":{
     "content":[{"type":"text","text":"model 013034ae…\n12.5\n"}],
     "structuredContent":{"diagnostics":[],"error":"","modelHash":"013034ae…","result":{"realValue":12.5}}}}
```

A diagnostic, from an inline source with a syntax error:

```json
→ {"name":"diagnostics","arguments":{"sources":[{"path":"bad.sysml","text":"package B { part p : Missing; attribute a : Real = 1 +; }"}]}}
← "structuredContent":{"modelHash":"293714ab…","error":"","diagnostics":[
     {"code":"syntax","severity":"error","message":"expected an expression","independent":false,"orderDependent":[],
      "span":{"file":"bad.sysml","startLine":1,"startCol":55,"endLine":1,"endCol":56}}]}
```

(The syntax tier failed, so the name-resolution tier that would report `Missing` did not run;
fix the syntax error and call again.)

A path that leaves the root:

```json
→ {"name":"diagnostics","arguments":{"paths":["../etc/passwd"]}}
← {"result":{"content":[{"type":"text","text":"INVALID_ARGUMENT: /home/u/etc/passwd is outside the workspace root /home/u/proj"}],"isError":true}}
```

## `execute_action`, `instantiate`, `verify_requirement`

```json
→ {"name":"execute_action","arguments":{"paths":["models/probe.sysml"],"actionSymbolId":"Probe::Drive","inputs":{"distance":{"realValue":50.0}}}}
← "content":[{"type":"text","text":"model 013034ae…\ndistance = 50\nhours = 5\nplan.h = 5\n"}],
  "structuredContent":{"diagnostics":[],"error":"","finalTime":0,"modelHash":"013034ae…","orderDependent":{},"outcomes":[],
     "outputs":{"distance":{"realValue":50},"hours":{"realValue":5},"plan.h":{"realValue":5}},"performerAttributes":{}}

→ {"name":"instantiate","arguments":{"paths":["models/probe.sysml"],"symbolId":"Probe::rover1"}}
← "content":[{"type":"text","text":"model 013034ae…\n#1 : Probe::rover1\n  battery = #2\n  …\n  totalMass = 12.5\n  …\n  wheels = 6\n2 instances reachable\n"}],
  "structuredContent":{"instance":{"featureValues":{"battery":{"featureName":"battery","materialized":true,"value":{"instanceId":"2"},…},…}},…}

→ {"name":"verify_requirement","arguments":{"paths":["models/probe.sysml"],"symbolId":"Probe::LightEnough","subjectSymbolId":"Probe::rover1"}}
← "content":[{"type":"text","text":"model 013034ae…\nrequirement Probe::LightEnough: holds [run, observed]\n"}]
```

`verify_requirement`'s arguments are `symbolId` (the requirement), `subjectSymbolId`,
`engine`, `question`, `arguments`, `namedArguments`; `symbolId` is the only required one.

## A session, end to end

```json
→ {"name":"session_open","arguments":{"session":"probe"}}
← "structuredContent":{"session":"probe"}

→ {"name":"session_load","arguments":{"session":"probe","paths":["models/probe.sysml"]}}
← "structuredContent":{"declared":["✓ package Probe"],"diagnostics":[],"errors":false,"files":["/home/u/proj/models/probe.sysml"],"text":"✓ package Probe"}

→ {"name":"session_eval","arguments":{"session":"probe","expression":"Probe::rover1.wheels * 2"}}
← "structuredContent":{"expression":"Probe::rover1.wheels * 2","output":"✓ Probe::rover1.wheels * 2\n  = 12","text":"12","value":{"intValue":"12"}}

→ {"name":"session_submit","arguments":{"session":"probe","text":"part rover2 : Probe::Rover { attribute redefines wheels = 4; }"}}
← "structuredContent":{"accepted":false,"declared":["rover2"],"notices":[],
     "diagnostics":[{"code":"feature-value-overriding","severity":"error","pass":"constraint","line":1,"column":57,
       "message":"cannot override the binding value of Probe::Rover::wheels: a value written with `=` is fixed for every feature redefining it; write it as `default =` on Probe::Rover::wheels to allow overriding, or remove this value"}],
     "text":"1:57: error[feature-value-overriding]: …"}

→ {"name":"session_eval","arguments":{"session":"probe","expression":"rover2.wheels"}}
← "structuredContent":{"text":"4","value":{"intValue":"4"},…}        // the rejected text still joined the model

→ {"name":"session_run","arguments":{"session":"probe","kind":"calc","name":"Probe::Range","arguments":["100.0","4.0"]}}
← "structuredContent":{"status":"holds","subject":"Probe::Range","values":[{"name":"result","value":"25.0"}],
     "text":"✓ Probe::Range(100.0, 4.0)\n  = 25.0\n  standing: value (observed: 1 run under reverse)"}

→ {"name":"session_run","arguments":{"session":"probe","kind":"action","name":"Probe::Drive","arguments":["50.0"]}}
← "structuredContent":{"status":"unresolved","subject":"Probe::Drive","values":[],
     "text":"error: execution failed: eval h of node plan: type mismatch: operator '/' is not defined for a sequence and a Rational\n  standing: not covered (…)"}
   // positional arguments bind a calc's parameters, not an action's `in` parameters: use execute_action's `inputs`

→ {"name":"session_save","arguments":{"session":"probe","path":"models/saved.sysml"}}
← "structuredContent":{"applied":false,"content":"package Probe {\n    private import ScalarValues::*;\n …"}   // nothing written

→ {"name":"session_save","arguments":{"session":"probe","path":"../escape.sysml","apply":true}}
← {"content":[{"type":"text","text":"/home/u/escape.sysml is outside the workspace root /home/u/proj; session tools only read and write under the root"}],"isError":true}

→ {"name":"session_save","arguments":{"session":"probe","path":"models/saved.sysml","apply":true}}
← "structuredContent":{"applied":true,"path":"/home/u/proj/models/saved.sysml","text":"saved 958 bytes of sysml to /home/u/proj/models/saved.sysml"}

→ {"name":"session_list","arguments":{}}
← "structuredContent":{"sessions":["probe"]}
→ {"name":"session_close","arguments":{"session":"probe"}}
← "structuredContent":{"session":"probe"}
→ {"name":"session_eval","arguments":{"session":"probe","expression":"1"}}
← {"content":[{"type":"text","text":"no such session: \"probe\" (session_list names the open ones; session_open opens another)"}],"isError":true}
```

## Workspace (`lsp`) tools

```json
→ {"name":"workspace_diagnostics","arguments":{"path":"models/probe.sysml"}}
← "content":[{"type":"text","text":"1 documents: no diagnostics"}],
  "structuredContent":{"diagnostics":[],"documents":1,"errors":0,"warnings":0}

→ {"name":"render_view","arguments":{"path":"models/probe.sysml","view":"Probe::roverView","form":"mermaid"}}
← "content":[{"type":"text","text":"---\nconfig:\n  fontFamily: \"Helvetica, Arial, sans-serif\"\n  theme: base\n …\nflowchart TB\n …"}]
```

## Serving fewer groups

`tools/list` answered 22 tools with `-tools lsp`, 32 with `-tools runtime`, 30 with
`-tools session`, 53 with `-tools lsp,runtime` and 82 with the default `all`
(`tool_catalog` is always one of them). `-tools bogus` exits 2 with
`sysml-mcp: -tools: unknown tool group "bogus"; the groups are lsp, runtime and session`.

## Driving it yourself

A minimal Python client (what produced the exchanges above): start the process with
`-root`, write one JSON object per line to stdin, read one per line from stdout, match on
`id`; send `notifications/initialized` (no `id`) after `initialize`. Closing stdin ends the
server with exit status 0. Or use the reference inspector:

```bash
npx @modelcontextprotocol/inspector --cli /usr/local/bin/sysml-mcp --method tools/list
npx @modelcontextprotocol/inspector --cli /usr/local/bin/sysml-mcp --method tools/call --tool-name tool_catalog
```
