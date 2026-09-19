# VS Code client

**Status.** Design specification for the local `editor-vscode` project. This
is not Aloe language law, an implementation checkpoint, or a global
checkpoint. A later checkpoint-manager conversation may slice
**editor-vscode 000** under `docs/editor/vscode/checkpoints/`. It must not use
`docs/checkpoints/` or `docs/editor/lsp/checkpoints/`.

**Authority.** [`../lsp/spec.md`](../lsp/spec.md) owns the protocol,
capabilities, document synchronization, UTF-16 positions, Hover contents,
failure behavior, and server lifecycle. Editor-lsp 000–009 are implemented
and reviewed; [`../lsp/checkpoints/009-launch.md`](../lsp/checkpoints/009-launch.md)
owns the installed-module launch. [`../expression-query/spec.md`](../expression-query/spec.md)
owns the type and signature answer displayed by Hover. `SPEC.md` remains Aloe
language law. This extension is only a client of those accepted layers and
does not reinterpret them.

---

## 1. Result and boundary

The result is a local VS Code extension in `editors/vscode/`. Its only
language feature is to attach the existing Aloe language server to local Aloe
documents so VS Code can display the server's existing Hover result.

Project documentation and later checkpoint files stay in
`docs/editor/vscode/`. Do not put extension code or Node packaging under
`aloe/`, `host/`, `docs/`, or the repository root. Any package manifest,
lockfile, JavaScript, tests, development configuration, local ignore file, and
installed `node_modules` used by this extension live under `editors/vscode/`.
Do not commit `node_modules`.

The extension contributes:

- language id `aloe`;
- filename extension `.aloe`;
- the setting `aloe.racketPath`; and
- activation on `onLanguage:aloe`.

It contributes no command and no other language or editor feature. Opening a
local `*.aloe` file assigns language id `aloe`, activates one language client,
and starts one Aloe server for that client. The client uses a file-document
selector for language `aloe`; non-file documents are not sent to this server.

## 2. Package decisions

The extension manifest has these identities:

| Field | Value |
|---|---|
| `name` | `aloe-language-client` |
| `displayName` | `Aloe` |
| `publisher` | `aloe-local` |
| extension id | `aloe-local.aloe-language-client` |
| initial `version` | `0.0.1` |
| `main` | `./extension.js` |
| `engines.vscode` | `^1.82.0` |

This identity is sufficient for local Extension Development Host use. It is
not a Marketplace identity or a promise to publish.

The sole runtime npm dependency is the exact stable version
`"vscode-languageclient": "9.0.1"`. That client version declares
`engines.vscode` `^1.82.0`, so the extension uses the same minimum. Commit the
generated `package-lock.json` and use it for reproducible installation. The
VS Code API module is supplied by the Extension Host rather than bundled as a
second runtime.

The entry point is ordinary CommonJS JavaScript. There is no TypeScript,
compile step, bundler, generated output directory, or `vscode:prepublish`
build. Development tests may use Node's built-in test facilities and must not
introduce an Electron harness.

The extension-local `.vscode/launch.json` supplies an Extension Development
Host launch configuration whose extension development path is
`editors/vscode/`, so `F5` from that folder runs the extension. This is local
development configuration, not another launcher for the Aloe server.

## 3. Manifest contributions

`package.json` declares `activationEvents` containing exactly
`onLanguage:aloe` for this slice. Its language contribution associates
`.aloe` with id `aloe` and display alias `Aloe`. It contributes no grammar,
language configuration, snippets, themes, commands, menus, keybindings, or
debug adapter.

The configuration contribution contains one property:

```text
aloe.racketPath
  type: string
  default: racket
  scope: machine
```

Its description says that the value is the Racket executable used to start
the Aloe language server. Machine scope is intentional because an executable
path is host-specific. The value is one executable path or command name, not
a shell command line; the extension does not split it, expand it, or run it
through a shell.

## 4. Exact server wiring

On activation, the extension reads `aloe.racketPath`. When the setting is
absent, its effective value is `racket`, resolved through the Extension
Host's `PATH`. It constructs the executable server options with exactly:

```text
{
  command: <effective aloe.racketPath>,
  args: ["-l", "aloe/lsp"]
}
```

Do not set `transport`. In `vscode-languageclient` 9.0.1, an executable
`transport` of stdio appends `--stdio` before spawn, which would run
`racket -l aloe/lsp --stdio`. Editor-lsp 009 requires a zero-argument
command and exits status 1 for any argument. Omitting `transport` still
uses process stdin and stdout (the library's default executable path) and
keeps the child argv exactly `-l` and `aloe/lsp`.

The arguments are separate child-process arguments. Do not use a shell,
append flags (including `--stdio`), set `PLTCOLLECTS`, derive a repository
path, scan the workspace, or start the server from `aloe/lsp.rkt` as a
source file. There is no TCP, socket, IPC, wrapper process, or
extension-owned copy of the server.

The `vscode-languageclient/node` client uses a document selector equivalent
to `{ scheme: "file", language: "aloe" }`. It forwards open, full-change,
close, lifecycle, and Hover protocol traffic according to the capabilities
advertised by the server. It does not add capabilities the server did not
advertise.

The extension does not parse Aloe, typecheck it, query declarations, format
Hover text, sort rows, or own a method catalog. VS Code displays the server's
plaintext `MarkupContent` and range unchanged. In particular, Point rows,
kernel rows, library selectors, and `class-info-methods` do not appear in
production JavaScript.

Deactivation stops the language client and lets it perform the accepted
shutdown/exit lifecycle. Activation starts at most one client. This slice
does not add configuration-change watching or a restart command; after
changing `aloe.racketPath`, the user reloads the Extension Development Host.

## 5. Launch prerequisite and failures

Before using the extension, the human installs or links the Aloe package into
the same Racket installation selected by `aloe.racketPath`. That executable
must be able to start the server outside VS Code, with no additional
arguments, using:

```text
racket -l aloe/lsp
```

When `aloe.racketPath` names another executable, substitute that executable
for `racket` but keep the arguments exactly `-l aloe/lsp`. If this command
cannot locate the Aloe package outside VS Code, the extension is not at
fault. The extension does not install Racket, link or install Aloe, mutate a
Racket package database, or offer an alternate launch form.

Client startup must observe and settle the process-start result. If the
configured Racket executable is missing or cannot be spawned, activation must
not hang or retry. It leaves no running client and shows one VS Code error
notification for that activation:

```text
Aloe could not start Racket: "<racket>". Install Racket or set aloe.racketPath to a working executable.
```

Here `<racket>` is the effective configured value. The notification does not
trigger installation or modify the setting. A later reload may try again.
Failures after Racket starts remain language-client/server failures; the
extension does not translate them into diagnostics or Hover prose.

## 6. Hover acceptance

The normative human proof uses
[`../../../tests/editor/lsp/fixtures/point.aloe`](../../../tests/editor/lsp/fixtures/point.aloe),
not `examples/point.aloe`.

After installing dependencies, launch an Extension Development Host with
`F5`, open that fixture, and confirm VS Code identifies it as Aloe. Hover the
final `(Point new 1 2)` expression or its literal `new` selector. The popup
must display exactly the server-owned plaintext content:

```text
type: (Point Int)
messages:
  x : () -> Int
  y : () -> Int
  + : ((Point Int)) -> (Point Int)
  dist2 : ((Point Int)) -> Int
```

The four rows retain their server order and types. The extension does not
special-case this fixture; it is only the accepted end-to-end proof that file
association, activation, stdio launch, synchronization, Hover forwarding, and
VS Code rendering meet at one human client.

As a separate failure hand check, set `aloe.racketPath` to a known nonexistent
executable, reload the Extension Development Host, and open the fixture. The
error notification from section 5 must appear promptly once, with no hung
server. Restore the setting after the check.

## 7. Automated proof for the later slice

The implementation change includes small extension-local tests. They may
inspect `package.json` and exercise a side-effect-free server-option seam
without launching VS Code. At minimum they prove:

- the package identity, `^1.82.0` engine, CommonJS entry, exact activation
  event, `.aloe` language association, and sole setting;
- the exact pinned runtime dependency and presence of `package-lock.json`;
- default and configured executable values both produce separate arguments
  `-l` and `aloe/lsp` only, with no `transport` property, no extra argv, and
  no shell; and
- the manifest contributes none of the excluded editor features.

Run the tests through an extension-local `npm test`. There is no
`@vscode/test-electron`, Electron download, VS Code integration runner, Racket
server re-test, TypeScript compiler, or repository-root Node package. The two
manual checks in section 6 are the acceptance bar that automated manifest and
command-shape tests do not replace.

## 8. Deferred work and non-goals

- Completion, IntelliSense, selector holes, signature help, diagnostics, and
  diagnostic publication
- Go-to-definition, references, rename, formatting, code actions, semantic
  tokens, or source-locations 001
- TextMate or semantic grammar, bracket configuration, themes, snippets, or
  wrap-the-preceding-expression
- A JavaScript or TypeScript Aloe reader, parser, checker, expression query,
  signature catalog, or Hover formatter
- Changes to `aloe/lsp.rkt`, `aloe/expression-query.rkt`,
  `aloe/signature-catalog.rkt`, the checker, Aloe syntax, or dispatch
- Incremental-sync policy, non-file documents, generic third-party client
  configuration, another editor, or another transport
- A TypeScript build, bundling, an Electron test harness, Marketplace
  metadata or publication, and a required `.vsix`
- Gel, evaluation, host capabilities, or Boids work
- Global Aloe checkpoints or implementation outside `editors/vscode/`

When this specification has been sliced and editor-vscode 000 meets its
automated and human proofs, stop for review. Later features begin from their
own query and LSP designs; they are not added opportunistically to this thin
client.
