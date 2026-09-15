# Editor LSP 009 — Installed-module stdio launch

**Status.** Implemented and reviewed. The focused 5-test suite, the retained
96 tests from editor-lsp 000–008, and the required installed-package hand check
are green. The recursive suite retains exactly the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` failures and no additional failure.

## Goal

Finish the local editor-lsp series with its only process-launch slice. Add a
`main` submodule to `aloe/lsp.rkt` so an installed or linked Aloe package runs
the accepted serial server over the process's current standard ports with:

```text
racket -l aloe/lsp
```

The command accepts no arguments. With no arguments, the process exits with
the exact status returned by `run-lsp-server`. With any argument, it does not
start or read the server and exits nonzero. Requiring the normal module remains
inert and its public surface remains unchanged.

This checkpoint adds no protocol or language behavior. It proves that the
already accepted in-process adapter can be found through Racket's installed
collection paths and that its lifecycle status reaches the operating system.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. Launch changes no Aloe syntax, parsing,
  checking, loading, evaluation, type, signature, or send behavior.
- `docs/editor/lsp/spec.md` is the local design authority. Section 8 defines
  the one supported command and process statuses. Section 9 requires both an
  inert normal require and a real stdio launch without a human editor action.
- Editor-lsp 005 owns fatal framing and EOF status 1. Editor-lsp 007 owns the
  lifecycle statuses: valid exit after shutdown is 0, and exit before shutdown
  is 1. Editor-lsp 008 is the final accepted in-process Hover behavior.
- The repository's existing `info.rkt` already declares a multi-collection
  package and the required `base`, `net-lib`, and test dependency metadata.
  This checkpoint consumes that package layout; it does not redesign it.

Identity is `(editor-lsp, 009)`, spoken **editor-lsp 009**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit `CHECKPOINTS.md`,
add a file under `docs/checkpoints/`, or begin another feature.

## Preserve accepted behavior

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

Requiring that normal module must not inspect command-line arguments, read or
write a port, start the server, register an exit hook, spawn work, or terminate
the process. The private `run-lsp-server/with-query` test seam retains its
four-argument arity and behavior. A `main` submodule is a launch entry point,
not a new normal-module export.

Keep all accepted framing, JSON-RPC validation, lifecycle precedence,
capabilities, synchronization, UTF-16 conversion, snapshot/query behavior,
Hover rendering, adapter-failure recovery, response ordering, and open-port
behavior unchanged. Do not move server logic into the launcher or create a
second dispatcher.

All 96 tests from editor-lsp 000–008 must remain green. The sole authorized
predecessor-test migration is stated below; no other prior expectation is
superseded by 009.

## Exact launch behavior

Add a `main` submodule in `aloe/lsp.rkt`. On instantiation it inspects
`(current-command-line-arguments)` exactly once for the launch decision.

### No command-line arguments

When the vector is empty, call the existing public `run-lsp-server` exactly
once with, in order:

```racket
(current-input-port)
(current-output-port)
(current-error-port)
```

Pass its exact integer result to Racket's `exit`. Do not reinterpret, clamp,
negate, log, or replace the status. In particular:

- a valid initialize/open/hover/shutdown/exit exchange exits 0;
- valid exit before shutdown exits 1;
- EOF before lifecycle completion exits 1; and
- fatal framing exits 1.

Null Hover, query failure, snapshot failure, adapter failure, Parse Error, and
other recoverable responses do not acquire launcher-specific exit behavior;
the existing server decides whether processing continues.

The launcher must not catch a break, output failure, server exception, or
other control transfer. It must not retry the server or attempt a second
protocol write after failure. Process termination may close process-owned
stdio normally, but the in-process entry point and an intercepted in-process
`main` invocation continue to demonstrate that server code does not close
caller-owned ports.

### One or more command-line arguments

When the vector is nonempty, exit with exact status 1 without calling
`run-lsp-server`, reading standard input, parsing a frame, writing a protocol
response, or changing a document. No option or positional argument is
accepted, including an empty-string argument.

Standard output must remain empty. The tests need not pin exact human-facing
standard-error prose, but it must not contain a framed JSON-RPC response,
source contents, a snapshot path, or a continuation trace. A silent rejection
is valid.

## One supported command

After the repository is installed or linked as a package in the selected
Racket installation, the supported runtime command is exactly:

```text
racket -l aloe/lsp
```

Here `racket` is resolved through `PATH`, and `aloe/lsp` is resolved as a
library through that executable's package/collection configuration. The
implementation must not depend on the caller's working directory or on the
repository itself being the current directory.

Do not add or advertise any alternative invocation. In particular, do not
add a shell script, executable Racket wrapper, `-t`/`-m` file command,
`PLTCOLLECTS` launcher, Node/TypeScript process, configuration file, workspace
scan, TCP listener, or editor extension. The test-only environment isolation
and package-link setup described below are not alternate user commands.

## Authorized predecessor-test migration

Editor-lsp 007 deliberately proved that its pre-launch production source did
not contain a process exit call. Its final source-shape test includes the
forbidden substring:

```racket
"(exit "
```

That single assertion is now superseded because the required `main` submodule
must exit with the server's status. Edit
`tests/editor/lsp/007-lifecycle.rkt` only to remove `"(exit "` from that
forbidden-source list. Retain every other assertion, forbidden substring, and
runtime expectation in the file unchanged.

This authorization does not permit changing editor-lsp 007's status tests,
normal-module inertness test, open-port assertions, checkpoint document, or
any other predecessor test. If anything else conflicts with this checkpoint,
stop and return it for design review.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`;
- `tests/editor/lsp/009-launch.rkt` (new); and
- `tests/editor/lsp/007-lifecycle.rkt`, solely for the exact migration above.

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, tests 000–006 or 008,
  or any fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

Tests may create isolated temporary directories and files and must remove them
unconditionally. They may read the existing Point fixture and repository root.
If installed-module resolution requires changing package metadata, a wrapper,
an environment-specific source path, or another predecessor expectation, stop
and return the checkpoint for design review.

## Required tests

Add `tests/editor/lsp/009-launch.rkt`. It is three directories below the
repository root, so use `../../../aloe/...` for repository-root module paths.
Use direct subprocess arguments, never a shell command string. Bound every
child wait, terminate a timed-out child, close its process ports, and clean up
temporary state with an unconditional action.

Cover at least:

1. Require the normal module in a fresh namespace with instrumented current
   input/output/error ports, command-line arguments, and exit handler. Assert
   the require is silent, does not read input or invoke exit, leaves ports open,
   and exports exactly `run-lsp-server` with arity 3.
2. Instantiate the `main` submodule in a fresh namespace while intercepting
   Racket's exit handler. With an empty argument vector and a complete framed
   initialize/shutdown/exit exchange, assert exact exit status 0, exact two
   canonical responses, empty error output, trailing input unread, and all
   caller-owned ports open. This proves use of the current standard ports and
   propagation of the server result without terminating the test process.
3. In a separate fresh namespace, instantiate `main` with at least one
   argument and valid framed server input waiting. Assert exact exit status 1,
   zero input consumption, empty standard output, no server response or query,
   and open ports. Include an empty-string argument or otherwise prove that
   argument contents are not parsed as options.
4. Locate both `racket` and `raco` through `PATH`. Create one temporary
   `PLTUSERHOME` and a separate empty launch working directory. In that
   isolated user home, directly run the selected `raco` executable to link the
   absolute repository root as a temporary package using a unique fixed test
   package name, batch mode, dependency failure rather than network fetching,
   no setup, and user scope. Assert package-link success before launch.
5. Using that same isolated `PLTUSERHOME`, launch the selected `racket`
   executable from the empty directory with the command arguments exactly
   `-l` and `aloe/lsp`. Do not set `PLTCOLLECTS` or pass a repository source
   path. Feed a raw initialize/didOpen/Hover/shutdown/exit exchange using the
   checked-in Point fixture. Assert process status 0, empty standard error,
   exact three canonical response frames in order, exact capabilities, the
   real public-query `(Point Int)` Hover with ordered `x`, `y`, `+`, `dist2`
   rows, and range 9:0–9:15.
6. In that process proof, assert notifications receive no responses; stdout
   contains only framed JSON-RPC bytes and exposes no repository, source, or
   temporary path, diagnostic, logging line, banner, prompt, or unframed byte.
   The launch directory must remain empty.
7. Run separate exact `racket -l aloe/lsp` children in the same isolated
   package environment for: empty input/EOF, valid exit before shutdown, and
   fatal framing. Assert each exits with status 1, emits no fabricated response
   or unframed stdout, and does not hang. Retain any response genuinely due
   before a later terminal condition if the chosen exchange has one.
8. Run `racket -l aloe/lsp -- unexpected` with valid server input available.
   Assert status 1, empty stdout, and no evidence that the input was processed.
   This is the same module command with a rejected argument, not a supported
   alternate launch form.
9. Prove terminal processing remains immediate at process level: include a
   valid-looking frame after the successful exit in the status-0 input and
   assert it receives no response. In-process test 2 remains the proof that
   those bytes are unread rather than merely unanswered.
10. Snapshot the repository paths relevant to the package-link test before and
    after it, or otherwise prove the launch setup does not rewrite source,
    fixtures, metadata, or create a checked-in launcher/build artifact. Delete
    the isolated `PLTUSERHOME` and launch directory even after failure. Because
    the package database is isolated there, do not uninstall or mutate the
    developer's ordinary user or installation package database.
11. Read production source narrowly enough to prove there is exactly one
    `main` submodule, no alternate launcher/transport, no command-line option
    parser, and no duplicated server/dispatcher. Runtime module and process
    tests are primary; do not pin harmless helper names or whitespace.
12. All prior LSP suites remain green after only the authorized 007 assertion
    migration. Their in-process statuses, inert require, open ports, framing,
    lifecycle, Hover, snapshot, and failure behavior retain their exact
    semantics.

For child processes, copy the current environment and change only the isolated
variables needed for deterministic Racket user-package state, chiefly
`PLTUSERHOME`. Do not erase `PATH`, platform library variables, or the selected
Racket installation's normal collection configuration. The package setup must
be offline: installed dependencies may be used, but tests must not access a
catalog or network and must fail clearly if required dependencies are absent.

The package name is test scaffolding, not public identity. Do not assert that
the linked package's package name is `aloe`; assert that its collection module
is found as `aloe/lsp`.

## Baseline suite note

The current branch has two unrelated failures already present before this
checkpoint, both in `tests/gel/presentations/003-doc-law.rkt`. They assert
older Gel-presentations handoff wording and experiment shape.

Do not edit or weaken those tests or their documentation. Require all focused
LSP suites to be completely green and the recursive suite to retain exactly
those two failures with no new failure. If that baseline contradiction has
been repaired before implementation starts, require a completely green
recursive suite.

## Hand check and acceptance

After automated tests, perform one manual process interaction from a temporary
working directory outside the repository, using the same isolated package-link
method as the test:

- invoke `racket -l aloe/lsp` with no command-line arguments;
- send raw initialize/didOpen/Hover/shutdown/exit frames for the Point fixture;
- inspect exact capabilities, real Point Hover text and range, protocol-only
  stdout, empty stderr, and process status 0;
- include a valid-looking trailing request after exit and inspect that it gets
  no response; and
- confirm the temporary package state and working directory are removed and
  repository files are unchanged.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests/editor/lsp/003-buffer-snapshots.rkt
raco test tests/editor/lsp/004-hover-results.rkt
raco test tests/editor/lsp/005-framing.rkt
raco test tests/editor/lsp/006-json-rpc.rkt
raco test tests/editor/lsp/007-lifecycle.rkt
raco test tests/editor/lsp/008-adapter-failures.rkt
raco test tests/editor/lsp/009-launch.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when the normal module remains inert, its `main`
submodule accepts only zero arguments, the exact installed-module command
runs the real Point exchange over stdio from outside the repository, server
status reaches the process unchanged, invalid arguments are rejected before
input, the isolated package proof leaves no residue, all prior suites remain
green, and the recursive suite has no new failure. Stop for review without
committing. The planned editor-lsp series is then complete.

## Explicit non-goals

- No protocol, lifecycle, document, URI, position, snapshot, query, Hover,
  failure-classification, or response-rendering change
- No new normal-module export or public API beyond the accepted
  `run-lsp-server`
- No package metadata/dependency change, installation script, shell wrapper,
  executable file, alternate module path, or source-file launch command
- No configuration file, command-line option, logging mode, workspace scan,
  TCP/WebSocket transport, Node/TypeScript process, or editor extension
- No additional LSP method/capability, completion, diagnostics, or diagnostic
  publication
- No request concurrency, worker pool, cancellation execution, request
  reordering, or progress messages
- No incremental synchronization, dirty loaded-document overlay, workspace
  indexing, or caching
- No changes to Expression Query, selection, source locations, checking,
  loading, type/signature datums, or valid Hover text
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
