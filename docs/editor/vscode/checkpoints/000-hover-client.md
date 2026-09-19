# Editor VS Code 000 — Local Hover client

**Status.** Implemented and reviewed; closed successfully. The extension-local
8-test suite and both required Extension Development Host hand checks are
green. The recursive suite retains exactly the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` failures and no additional failure.

## Goal

Add the complete thin local VS Code client described by the VS Code client
specification. Opening a local `*.aloe` document assigns language id `aloe`,
activates one `vscode-languageclient` client, and starts the already installed
Aloe language server as exactly:

```text
<effective aloe.racketPath> -l aloe/lsp
```

The language client uses the child process's stdin and stdout as its effective
stdio transport. It forwards the server's accepted full-document
synchronization and Hover behavior to VS Code without parsing Aloe or
formatting a second Hover result.

This one slice includes the extension manifest, reproducible local Node
package, CommonJS client, Extension Development Host launch configuration,
small Node tests, and the successful and failed-start hand checks. It adds no
other editor feature.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `docs/editor/vscode/spec.md` is the local design authority. Its package,
  contribution, wiring, failure, proof, and non-goal decisions are fixed.
- `docs/editor/lsp/spec.md` owns the protocol, advertised capabilities,
  synchronization, UTF-16 positions, Hover result, failure behavior, and
  server lifecycle. This extension consumes those decisions and does not
  reinterpret them.
- Editor-lsp 000–009 are implemented and reviewed. In particular,
  `docs/editor/lsp/checkpoints/009-launch.md` owns the installed-module command
  `racket -l aloe/lsp` and rejection of every additional argument.
- The normative hand-check file is
  `tests/editor/lsp/fixtures/point.aloe`. Do not create a VS Code copy and do
  not substitute `examples/point.aloe`.
- `SPEC.md` remains Aloe language law. No JavaScript in this extension parses,
  checks, evaluates, or changes Aloe.

Identity is `(editor-vscode, 000)`, spoken **editor-vscode 000**. This is a
local editor checkpoint, not a global Aloe checkpoint and not an editor-lsp
checkpoint. Do not edit `CHECKPOINTS.md`, add a file under
`docs/checkpoints/`, or continue the editor-lsp numbering.

## Exact project layout

Create the extension wholly under `editors/vscode/`:

```text
editors/vscode/
  .gitignore
  .vscode/
    launch.json
  client-options.js
  extension.js
  package.json
  package-lock.json
  test/
    000-hover-client.test.js
```

`node_modules/` is extension-local and ignored by the extension-local
`.gitignore`; never commit it. Do not create a repository-root `package.json`,
lockfile, Node test, launcher, or ignore rule. Do not put extension source or
packaging under `aloe/`, `host/`, or `docs/`.

The filenames above are fixed for this checkpoint. Do not add TypeScript,
compiled output, a bundler configuration, an Electron harness, or a copied
server.

## Exact extension manifest

`editors/vscode/package.json` is a VS Code extension manifest and an npm
package manifest with these exact identities:

| Field | Value |
|---|---|
| `name` | `aloe-language-client` |
| `displayName` | `Aloe` |
| `publisher` | `aloe-local` |
| extension id | `aloe-local.aloe-language-client` |
| `version` | `0.0.1` |
| `main` | `./extension.js` |
| `engines.vscode` | `^1.82.0` |

Use ordinary CommonJS. Do not set `type` to `module`, add a compile step, or
add `vscode:prepublish`.

The manifest's `activationEvents` array contains exactly:

```json
["onLanguage:aloe"]
```

Its `contributes.languages` array contains exactly one language contribution:

```json
{
  "id": "aloe",
  "aliases": ["Aloe"],
  "extensions": [".aloe"]
}
```

Its configuration contribution contains exactly one property with this
meaning and shape:

```json
"aloe.racketPath": {
  "type": "string",
  "default": "racket",
  "scope": "machine",
  "description": "The Racket executable used to start the Aloe language server."
}
```

A configuration title such as `Aloe` is permitted metadata; it does not add a
second setting. Contribute no grammar, language configuration, snippet,
theme, command, menu, keybinding, debugger, task, or other editor feature.

The sole direct runtime dependency is pinned exactly, with no range operator:

```json
"dependencies": {
  "vscode-languageclient": "9.0.1"
}
```

The VS Code API is supplied by the Extension Host and is not an npm runtime
dependency. Tests use Node's built-in test runner, so this checkpoint needs no
development dependency. Set the npm `test` script to run the extension-local
tests with `node --test`; add no build, lint, package, publish, or Electron
script.

Generate `package-lock.json` from this manifest with an extension-local
`npm install` and commit the lockfile. The root package entry and resolved
`vscode-languageclient` entry must retain the exact direct version `9.0.1`.
Transitive packages selected by that dependency are allowed; no second direct
runtime package is.

## Side-effect-free options seam

Add `client-options.js` as a small CommonJS module that can be required by
plain Node without VS Code or an Extension Host. It exports only the helpers
needed to construct:

```text
createServerOptions(undefined)
  => { command: "racket", args: ["-l", "aloe/lsp"] }

createServerOptions(configuredPath)
  => { command: configuredPath, args: ["-l", "aloe/lsp"] }

createClientOptions()
  => { documentSelector: [{ scheme: "file", language: "aloe" }] }
```

Only an absent value defaults to `racket`. A configured executable path or
command name is one opaque string. Do not trim, split, shell-parse, expand, or
append to it. Return a fresh argument array so one caller cannot mutate later
options.

The production `extension.js` must call these helpers. They are a test seam,
not parallel test-only configuration. `client-options.js` must not require
`vscode`, `vscode-languageclient`, `child_process`, an Aloe module, or a
repository file, and it performs no I/O.

### Locked executable transport shape

The executable server options have exactly two own properties:

```text
{
  command: <effective aloe.racketPath>,
  args: ["-l", "aloe/lsp"]
}
```

There is deliberately **no `transport` property**. There is also no
`options`, `shell`, `cwd`, `env`, `runtime`, `module`, `run`, or `debug`
property.

Omitting `transport` selects the pinned client's default executable path,
which communicates over the child process's stdin and stdout. Effective
transport is therefore stdio even though the server-options object does not
name it.

Do not import or use `TransportKind` and do not set
`transport: TransportKind.stdio`. `vscode-languageclient` 9.0.1 would append
`--stdio` to an executable configured that way, producing
`racket -l aloe/lsp --stdio`. Editor-lsp 009 rejects that extra argument with
status 1. The child argv in this checkpoint contains only the two separate
arguments `-l` and `aloe/lsp`.

Do not work around this lock with a shell, a custom `child_process.spawn`, a
function-valued `ServerOptions`, a wrapper program, `PLTCOLLECTS`, a source
path to `aloe/lsp.rkt`, a workspace scan, or another transport.

## Activation and language-client lifecycle

`extension.js` is ordinary CommonJS and exports VS Code's `activate` and
`deactivate` functions. It requires the VS Code API, `LanguageClient` from
`vscode-languageclient/node`, and the local options seam. It does not require
`TransportKind`.

On activation:

1. Read the machine setting through the `aloe` configuration namespace and
   the `racketPath` key, with `racket` as the absent-value default.
2. Build server options through `createServerOptions` and client options
   through `createClientOptions`.
3. Construct one language client. Use id `aloe` and display name `Aloe`.
4. Start it exactly once and await the result. Do not fire and forget the
   start promise.
5. Retain the successfully started client for deactivation. A second call or
   overlapping activation path must not create a second client or server.

The sole document selector is `{ scheme: "file", language: "aloe" }`.
Do not add a wildcard, untitled-document selector, file watcher,
synchronization override, middleware, initialization option, or client-side
capability. The language client forwards only the behavior advertised by the
server. Production JavaScript contains no Point declaration, type row,
selector catalog, parser, checker, query, Hover formatter, sort, or range
conversion.

On deactivation, await stopping the retained client so the library performs
the accepted shutdown/exit lifecycle, then clear the retained reference. If
activation did not leave a running client, deactivation is a settled no-op.
Do not terminate Racket directly, send protocol frames yourself, or invent a
second shutdown path.

Changing `aloe.racketPath` does not restart the client. Do not register a
configuration-change listener or contribute a restart command. The user
reloads the Extension Development Host after changing the setting.

## Spawn failure behavior

The Aloe package and Racket executable are human prerequisites. The extension
does not install Racket, install or link Aloe, edit a Racket package database,
or derive a repository path. The effective executable must already be able to
resolve the installed module in the command:

```text
<effective executable> -l aloe/lsp
```

If the executable is missing or the operating system cannot spawn it,
activation settles promptly, does not retry, retains no running client, and
shows exactly one error notification for that activation:

```text
Aloe could not start Racket: "<racket>". Install Racket or set aloe.racketPath to a working executable.
```

Substitute the effective configured string for `<racket>`. Do not change the
setting, start an installer, offer an action button, or turn the failure into
a diagnostic or Hover result.

The pinned language client can emit its own generic forced notification when
connection creation rejects. The required missing-executable path must not
show that generic notification in addition to the exact Aloe notification.
A narrow client subclass or equivalent local handling may suppress only that
duplicate spawn-failure notification. Do not globally suppress language-client
errors, output, initialization failures, or failures after Racket has started.
Do not preflight by spawning a second process.

Once Racket has spawned, server initialization, protocol, or later process
failures remain owned by `vscode-languageclient` and editor-lsp. The extension
does not translate them into the missing-Racket message and does not retry
them.

## Extension Development Host launch

Add `editors/vscode/.vscode/launch.json` with one Extension Development Host
launch configuration. It uses VS Code's `extensionHost` debug type, a launch
request, and passes:

```text
--extensionDevelopmentPath=${workspaceFolder}
```

With `editors/vscode/` opened as the VS Code folder, `F5` therefore launches
that folder as the extension. Add no build task, pre-launch task, compiled
output path, Racket launcher, server argument, environment override, or second
debug configuration.

This file launches VS Code for local development only. It is not an alternate
launcher for the Aloe server.

## Exact implementation file scope

Implementation may add only:

- `editors/vscode/.gitignore`;
- `editors/vscode/.vscode/launch.json`;
- `editors/vscode/package.json`;
- `editors/vscode/package-lock.json`;
- `editors/vscode/client-options.js`;
- `editors/vscode/extension.js`; and
- `editors/vscode/test/000-hover-client.test.js`.

Do not edit:

- `docs/editor/vscode/spec.md`, its charter, README, or this checkpoint;
- `aloe/lsp.rkt`, any other file under `aloe/`, or any Racket package
  metadata;
- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`;
- the editor-lsp, expression-query, signatures-of-type, or source-locations
  projects;
- `tests/editor/lsp/fixtures/point.aloe` or any repository Racket test; or
- `gel/`, `lib/`, `host/`, `examples/`, or another editor implementation.

If the exact installed-module command cannot launch through the two-property
executable options, if Hover needs client-side transformation, if the server
must be changed, or if one exact missing-executable notification cannot be
preserved without globally hiding later client failures, stop and return the
checkpoint for design review.

## Required automated tests

Add `test/000-hover-client.test.js` using only `node:test`, `node:assert`, and
other built-in Node modules. The tests run outside an Extension Host. They do
not import `extension.js`, `vscode`, or `vscode-languageclient/node`, launch
VS Code or Electron, download a VS Code build, start Racket, or speak LSP.

Cover at least:

1. Parse `package.json` and assert the exact name, display name, publisher,
   version, CommonJS entry, `^1.82.0` VS Code engine, and computed extension id.
2. Assert `activationEvents` is exactly `onLanguage:aloe`; there is exactly
   one language contribution with id `aloe`, alias `Aloe`, and extension
   `.aloe`; and the configuration contains exactly the one machine-scoped
   string setting `aloe.racketPath` with default `racket` and the specified
   description.
3. Assert the manifest contributes no command, grammar, language
   configuration, snippet, theme, menu, keybinding, debugger, task, or other
   feature. Its contribution keys are only `languages` and `configuration`.
4. Assert the sole direct runtime dependency is exact
   `vscode-languageclient` version `9.0.1`, there is no VS Code API dependency
   and no development dependency, and the test script uses Node's built-in
   runner without a build or prepublish script.
5. Parse `package-lock.json`. Assert its root package agrees with the manifest,
   its direct dependency is pinned to `9.0.1`, and the installed
   `node_modules/vscode-languageclient` lock entry is version `9.0.1`. Assert
   the lock contains no `@vscode/test-electron`, TypeScript compiler, or
   bundler package introduced directly by this project.
6. Require the side-effect-free `client-options.js`. Assert both absent and
   configured executable values produce the exact two-property server options
   and exact two-element argument array. Use a configured path containing a
   space to prove it remains one opaque `command` string. Assert there is no
   `transport`, `options`, `shell`, environment, cwd, wrapper, or extra argv,
   and that separate calls do not share a mutable argument array.
7. Assert `createClientOptions()` returns exactly one file/Aloe document
   selector and no synchronization override, middleware, or other option.
8. Parse `.vscode/launch.json` and assert there is exactly one
   `extensionHost` launch configuration with the extension development path
   set to `${workspaceFolder}` and no build task, output path, Racket command,
   or environment override.
9. Assert the local `.gitignore` ignores `node_modules/`. Inspect production
   JavaScript narrowly enough to prove `extension.js` consumes the tested
   options seam and contains no `TransportKind`, `--stdio`, custom spawn,
   shell, `PLTCOLLECTS`, source-file launch, Point rows, kernel rows, or Aloe
   parser/checker/query implementation. Do not ban the required `aloe/lsp`
   argument or language-client import.
10. Check the JavaScript files with Node's syntax checker. The automated suite
    remains small and does not pretend to replace either Extension Development
    Host hand check below.

Tests compare parsed JSON objects and helper results rather than property or
file formatting. Do not make an internet request, modify the package or
lockfile, or rely on a globally installed npm package during `npm test`.

## Human success check

Before VS Code acceptance, install or link this checkout as an Aloe package in
the same Racket installation selected by `aloe.racketPath`. From an ordinary
shell, establish that the executable can resolve `-l aloe/lsp` without a
repository source path, `PLTCOLLECTS`, or extra argument. Premature EOF may
produce editor-lsp's accepted nonzero lifecycle status; a module-resolution
error is a failed prerequisite.

Then:

1. Open `editors/vscode/` as the VS Code folder and install its dependencies
   from the committed lockfile.
2. Press `F5` and let the one launch configuration open an Extension
   Development Host.
3. In that host, open
   `tests/editor/lsp/fixtures/point.aloe` from this checkout.
4. Confirm VS Code identifies the file's language as `Aloe`.
5. Hover the final `(Point new 1 2)` expression or its literal `new` selector.

The popup displays exactly this server-owned plaintext, including row order
and types:

```text
type: (Point Int)
messages:
  x : () -> Int
  y : () -> Int
  + : ((Point Int)) -> (Point Int)
  dist2 : ((Point Int)) -> Int
```

There is no extension-formatted heading, reordered row, diagnostic, command,
or second Hover. This hand check crosses filename association, activation,
the exact installed-module child argv, effective stdin/stdout transport,
document synchronization, the real server query, and unchanged Hover
rendering.

## Human failed-start check

In the Extension Development Host's machine settings, set
`aloe.racketPath` to a known nonexistent executable name. Reload the host and
open the same Aloe fixture so the extension activates.

Confirm promptly:

- exactly one error notification appears for that activation;
- its complete text is the required `Aloe could not start Racket` message
  with the nonexistent value quoted;
- there is no second generic language-client startup notification;
- activation does not hang, retry, or leave a Racket process running; and
- no diagnostic or Hover substitutes for the failure.

Restore `aloe.racketPath` after the check. Reloading after restoration may
start one fresh client normally; the failed activation itself does not retry.

## Verification and acceptance

During implementation, run `npm install` only inside `editors/vscode/` to
produce the lockfile and local ignored `node_modules/`. Final verification is:

```sh
cd editors/vscode
npm test
cd ../..
raco test tests
git diff --check
git status --short
```

Do not add a repository-root npm command. Do not substitute
`raco test tests/*.rkt`; that glob skips nested editor tests. `node_modules/`
must not appear in `git status`, and no file outside the exact implementation
scope may change.

The checkpoint is complete when the extension-local Node suite is green, the
recursive Racket suite has no new failure, both human checks pass, the server
is launched with only `-l` and `aloe/lsp` over child stdin/stdout, missing
Racket produces exactly one settled notification, and the source and lockfile
remain confined to `editors/vscode/`. Stop for review without committing. Do
not update the VS Code README or issue another checkpoint.

## Explicit non-goals

- No completion, IntelliSense, selector holes, signature help, diagnostics,
  or diagnostic publication
- No definition, references, rename, formatting, code actions, semantic
  tokens, or source-locations work
- No TextMate or semantic grammar, language configuration, brackets, themes,
  snippets, or wrap-the-preceding-expression
- No JavaScript or TypeScript Aloe reader, parser, checker, evaluator,
  expression query, signature catalog, method table, or Hover formatter
- No change to Aloe syntax, dispatch, types, source locations, Expression
  Query, editor-lsp, or its installed-module launcher
- No non-file document selector, workspace scan, file watcher,
  configuration-change restart, custom synchronization policy, or additional
  client capability
- No explicit language-client transport property, `--stdio`, shell, wrapper,
  custom spawn, alternate argv, TCP, socket, IPC, or extension-owned server
- No TypeScript, compile step, generated output directory, bundler, Electron
  integration runner, Marketplace metadata/publication, or required `.vsix`
- No Racket/package auto-installation, package-database mutation, telemetry,
  logging feature, command, or settings UI
- No Gel, host-capability, evaluation, Boids, or global-checkpoint work
