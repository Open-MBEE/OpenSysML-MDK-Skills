---
name: opensysml-install
description: Install the OpenSysML REDK binaries (sysml, sysml-lsp, sysml-grpc, sysml-jupyter-kernel, sysml-mcp) with the release install script, Homebrew, Scoop, the Windows MSI, go install, or a source build, pin a release or the nightly, verify checksums, and locate the binaries the language clients auto-download. Use when a task needs the `sysml` command, a `sysml-grpc` service or the `sysml-mcp` server and it is not yet on PATH, when choosing a release version or `--tools`, or when a client reports it cannot find or verify a binary.
license: Apache-2.0
metadata:
  project: OpenSysML
  upstream: https://github.com/Open-MBEE/OpenSysML
---

# Installing OpenSysML

OpenSysML ships five executables from one release:

| Binary | Purpose | Release asset |
|---|---|---|
| `sysml` | CLI, REPL, validator, execution runtime, document generator | `opensysml-<os>-<arch>.tar.gz` (`.zip` on Windows) bundle, with `sysml-lsp` |
| `sysml-lsp` | Language Server Protocol server for editors | the same bundle |
| `sysml-grpc` | Service process the Python/Node/Java/Rust/Julia/MATLAB clients talk to | bare `sysml-grpc-<os>-<arch>` binary + `.sha256` (from v0.9.0) |
| `sysml-jupyter-kernel` | Jupyter kernel backed by the REPL | bare `sysml-jupyter-kernel-<os>-<arch>` binary + `.sha256` (from v0.10.0) |
| `sysml-mcp` | Model Context Protocol server for coding agents | its own `sysml-mcp-<os>-<arch>.tar.gz`/`.zip` with its manual page (the release after 0.10.1, and nightlies built from a `develop` commit that carries it) |

Releases live at https://github.com/Open-MBEE/OpenSysML/releases. The tag `nightly` is a
rolling snapshot of `develop` (published as `nightly-<yyyymmdd>-<commit>`, kept 14 days);
`latest` is the newest tagged release, v0.10.1 at the time of writing. Each release carries a
`SHA256SUMS.txt` manifest covering every archive and bare binary, and the install paths below
verify downloads against it. Verified with `install.sh --help` and `make build` of a `develop`
build (`sysml v0.10.1-1266-gdada45c11`).

## Pick a route

1. **Release install script (recommended).** No root required; verifies checksums.
   ```bash
   curl -fsSL https://opensysml.org/install.sh | sh
   ```
   Installs `sysml` and `sysml-lsp` to `/usr/local/bin` when writable, else `~/.local/bin`,
   with man pages under `share/man/man1`; runs each installed binary's `--version`. It never
   edits a shell profile; add the directory to `PATH` if told to. Needs `curl` or `wget`;
   `sha256sum`, `shasum` or `openssl`; `tar` only when an archive is fetched. Options go after
   `sh -s --` (environment variable equivalents in parentheses):
   - `--version v0.10.1 | latest | nightly` (`OPENSYSML_VERSION`); `0.10.1` is accepted and
     prefixed with `v`
   - `--tools sysml,sysml-lsp,sysml-grpc,sysml-jupyter-kernel,sysml-mcp | all`
     (`OPENSYSML_TOOLS`); default `sysml,sysml-lsp`
   - `--prefix DIR` (binaries under `DIR/bin`, pages under `DIR/share/man/man1`) or
     `--bin-dir DIR` (binaries only, no pages) (`OPENSYSML_PREFIX`, `OPENSYSML_BIN_DIR`)
   - `--base-url URL` for a release mirror (`OPENSYSML_DOWNLOAD_BASE`)
   - `--dry-run` prints the tools, directories and asset URLs, installs nothing;
     `--verify-signature` also checks the manifest's cosign bundle against the identity that
     signs the releases (needs `cosign` on PATH)
   - `--os linux|darwin|windows` / `--arch amd64|arm64` stage another platform's build without
     running it (no windows/arm64 build is published)

   **`--tools` semantics.** Only the assets the named tools come from are downloaded and
   verified: the `opensysml-<platform>` bundle is fetched only when `sysml` or `sysml-lsp` is
   asked for, so `--tools sysml-grpc` alone downloads just that binary. `all` stands alone and
   is resolved against the chosen release's `SHA256SUMS.txt`: it installs every tool that
   release published for the platform and says which it lacks
   (`--tools all: v0.10.1 publishes no sysml-mcp for linux-amd64`, then installs the other four),
   whereas a tool named explicitly on a release that lacks it fails
   (`SHA256SUMS.txt of v0.10.1 does not list sysml-mcp-linux-amd64.tar.gz; … sysml-grpc is
   published from v0.9.0 and sysml-jupyter-kernel from v0.10.0, and sysml-mcp has its own
   archive only from the release that introduced it`). An unknown tool name fails before
   anything is downloaded.
   ```bash
   # just the language server, nightly, into ~/bin
   curl -fsSL https://opensysml.org/install.sh | sh -s -- --tools sysml-lsp --bin-dir ~/bin --version nightly
   # everything the release publishes, pinned, with the manifest signature checked
   curl -fsSL https://opensysml.org/install.sh | sh -s -- --tools all --version v0.10.1 --verify-signature
   # the MCP server beside the defaults, from a release that publishes it
   curl -fsSL https://opensysml.org/install.sh | sh -s -- --tools sysml,sysml-lsp,sysml-mcp
   ```
   Windows (PowerShell 5.1+, no admin): `irm https://opensysml.org/install.ps1 | iex`, with
   `-Version`, `-Tools` (same list and `all` semantics), `-InstallDir`
   (`OPENSYSML_INSTALL_DIR`), `-BaseUrl`, `-Os`/`-Arch`, `-NoPath`, `-DryRun` parameters
   (`& ([scriptblock]::Create((irm https://opensysml.org/install.ps1))) -Tools sysml -Version v0.10.1`).
   Installs to `%LOCALAPPDATA%\Programs\OpenSysML` and adds it to the user PATH; prefers the
   SignPath-signed `opensysml-windows-amd64-signed.zip` when the release carries it and checks
   every executable's Authenticode signature. The zip has no solver.

2. **Homebrew (macOS/Linux).** Installs `sysml`, `sysml-lsp` and `sysml-mcp` with their man
   pages, and `z3` as a dependency.
   ```bash
   brew install Open-MBEE/tap/opensysml
   ```

3. **Windows MSI.** `opensysml-<x.y.z>-windows-amd64.msi` from the release page (a `-signed`
   variant when present): `sysml.exe`, `sysml-lsp.exe`, `sysml-grpc.exe` and `sysml-mcp.exe`
   into `C:\Program Files\OpenSysML` on the system PATH, with Z3 as the optional *SMT solver
   (Z3)* feature (`msiexec /i … REMOVE=Z3` or `REMOVE=Z3,GrpcService` to deselect). Scoop and
   winget manifests are maintained under `packaging/` of the repository (the Scoop manifest
   also installs `sysml-mcp`; the winget one carries the bundle only).

4. **Go toolchain (Go 1.25+).** Builds from source, so no checksum manifest applies.
   ```bash
   go install github.com/Open-MBEE/OpenSysML/cmd/sysml@latest
   go install github.com/Open-MBEE/OpenSysML/cmd/sysml-lsp@latest
   go install github.com/Open-MBEE/OpenSysML/cmd/sysml-grpc@latest
   go install github.com/Open-MBEE/OpenSysML/cmd/sysml-mcp@develop   # @latest only once a release after 0.10.1 carries cmd/sysml-mcp
   ```
   `@latest` is the newest tagged module (v0.10.1); a command that tag lacks fails with `does
   not contain package …`. `@develop` builds the `develop` head as a pseudo-version
   (`v0.10.2-0.<date>-<commit>`); `@<commit>` pins one.

5. **From a checkout.**
   ```bash
   git clone https://github.com/Open-MBEE/OpenSysML && cd OpenSysML
   make build            # bin/sysml, bin/sysml-lsp, bin/sysml-grpc, bin/sysml-jupyter-kernel, bin/sysml-mcp, with version ldflags
   make build-mcp        # one of them (build-sysml, build-lsp, build-grpc, build-jupyter-kernel, build-mcp)
   make build-wasm       # optional: bin/wasm/{wasip1,js}
   sudo make install-tree prefix=/usr/local   # the five binaries and their man pages, GNU paths (DESTDIR, bindir, man1dir honoured)
   ```
   `cmd/` also holds `sysml-core`, `sysml-engine`, `sysml-syntax`, `sysml-wasm`; build any with
   `go build -o bin/<name> ./cmd/<name>`.

Confirm with `sysml -version` (prints version, commit, build time, Go version; a checkout
build prints `v0.10.1-<n>-g<commit>`) and `sysml -man` for the manual page. Each binary has
`-version` and `-man`.

## Binaries the language clients download for themselves

The Python, Node, Java and Rust clients start a private `sysml-grpc` and resolve it in this
order: an explicit path (`OPENSYSML_GRPC_BINARY`, or a constructor argument), the shared cache
`~/.opensysml/bin/`, a verified release download matching the client's pinned version, then
`PATH`. Downloads are checked against SHA-256 digests baked into the client package; a
mismatch raises a `ChecksumMismatchError` rather than running the binary. Development
(unpinned) client builds refuse to download unless `OPENSYSML_ALLOW_UNPINNED_DOWNLOAD=1`.
Julia and MATLAB look at `OPENSYSML_GRPC_BINARY`, then the cache, then `PATH`, and do not
download. The Jupyter kernel package (`pip install jupyter-opensysml-kernel`) carries
`sysml-jupyter-kernel` in its platform wheels and verifies a download from the source
distribution the same way (see `opensysml-jupyter`).

To avoid any download in CI or offline, install `sysml-grpc` by one of the routes above and
export `OPENSYSML_GRPC_BINARY=/path/to/sysml-grpc`, or point every client at a shared running
service with `OPENSYSML_SERVICE=host:port` (see `opensysml-service`).

## Optional components

- **SMT solver** for `-check*`, `%solve`, `%configure`, `%optimize` and the `sysml-mcp` solver
  tools: install `z3` or `cvc5` and, if not on PATH, set `OPENSYSML_SMT=/path/to/z3`.
  `sysml -engines -probe` reports whether a solver was found. Homebrew and the MSI bring z3;
  `pip install z3-solver` puts a `z3` executable in the environment's `bin`.
- **Document rendering to PDF/HTML** needs external tools (WeasyPrint, pandoc, mermaid-cli,
  KaTeX, Graphviz, PlantUML, D2); see `opensysml-documents`.
- **Standard library**: bundled into the binary. `OPENSYSML_LIBRARY_PATH` overrides it with
  a directory of `.kerml`/`.sysml` library files, or the OMG's `.kpar` archives.
- **MCP host configuration**: `sysml-mcp -print-config <host>` writes the block an agent host
  reads; see `opensysml-mcp`.

## Failure modes

- `sysml: command not found` after the script: the install directory is not on `PATH`; the
  script printed the directory. Re-run with `--bin-dir` or export `PATH`.
- macOS Gatekeeper blocks a hand-downloaded archive: the script's `curl` download does not
  trigger it; for manual downloads use `xattr -d com.apple.quarantine <binary>`.
- Checksum mismatch (`does not match SHA256SUMS.txt … the download is corrupt or tampered
  with`): retry without `--base-url`, or pin `--version` to a tag that exists.
- `SHA256SUMS.txt of <release> does not list <asset>`: the tool was named explicitly on a
  release that predates it; use `--tools all`, drop the tool, or pick `nightly`.
- A client complains the cached binary is stale (`StaleServiceError` or a version mismatch):
  delete `~/.opensysml/bin/sysml-grpc*` and let it re-download, or set
  `OPENSYSML_GRPC_BINARY` to a binary built from the same release as the client.
