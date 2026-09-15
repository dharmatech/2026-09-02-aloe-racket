# Charter — VS Code client (hover)

**Status.** Handoff from the editor-support brainstorm into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/editor/README.md`](../README.md).

**Your job.** Turn this charter into a specification for a thin VS
Code extension that **starts the existing Aloe language server and
shows hover**. Then **stop**. Do not write checkpoints. Do not
implement. Do not change `aloe/lsp.rkt`, the expression query, or
the signature catalog. Do not specify completion, diagnostics,
TextMate grammar, snippets, or wrap-the-preceding-expression.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority in §5.
2. Confirm [`../lsp/spec.md`](../lsp/spec.md) exists and that
   editor-lsp 000–009 are implemented. Confirm the documented
   launch command is `racket -l aloe/lsp`. If any of that is
   missing, **stop**.
3. Record the locked decisions in §4 in the spec. Resolve only the
   leftover packaging details in §4.7. Do not reopen §4.1–4.6.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **editor-vscode 000** under
   `docs/editor/vscode/checkpoints/` (not `docs/checkpoints/0118`,
   not `docs/editor/lsp/checkpoints/`).
5. Stop. The human reviews it. The spec conversation does not write
   those checkpoint files and does not create `editors/vscode/`.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A marketplace listing, an
Electron test harness, a TypeScript build, a second Aloe parser in
JavaScript, and IntelliSense are defects in this document.

## 2. Why this experiment exists

Editor-lsp already answers `textDocument/hover` with the expression
query's type and typed message rows. Recorded protocol tests are
the smoke client. VS Code does not attach that server by itself.

This project is the first human client: register `.aloe`, start the
documented stdio command, let `vscode-languageclient` forward
hover. The popup is the philosophy question in the editor. It is
not a new language feature.

If hover cannot be answered, the bug is in the query or the LSP
adapter, not in this extension. Do not copy `Point` rows, kernel
tables, or `class-info-methods` into JavaScript.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. A VS Code extension lives in `editors/vscode/` (not under
   `aloe/`). Project docs stay in `docs/editor/vscode/`.
2. Opening a `*.aloe` file uses language id `aloe` and starts
   `{ command: <racket>, args: ["-l", "aloe/lsp"] }` on stdio.
   `<racket>` is `PATH`'s `racket` unless the user sets
   `aloe.racketPath`.
3. Hover on a well-formed expression shows the server's existing
   hover contents (type plus ordered `selector : params -> return`
   rows). The extension does not format a second catalog.
4. The first slice's proof is: in an Extension Development Host,
   open [`examples/point.aloe`](../../../examples/point.aloe),
   hover `(Point new 1 2)` or its `+`, and see the Point type and
   its four typed rows. That human check is the bar. Electron /
   `@vscode/test-electron` is out of 000.
5. No completion, diagnostics, grammar, themes, snippets, or
   wrap command. The server already refuses to advertise
   completion and diagnostics; the client must not pretend
   otherwise.
6. Node exists only inside `editors/vscode/`. 000 has no
   TypeScript compile step.

The specification must also say, as a prerequisite the human
performs rather than the extension: the Aloe package is installed
or linked so that same `racket` can run `racket -l aloe/lsp` with
no arguments. If that command fails outside VS Code, the extension
is not at fault.

## 4. Locked decisions (record these; do not reopen 4.1–4.6)

The brainstorm already picked these. The spec restates them as law.

### 4.1 Layout

| | Path |
|---|---|
| Spec, checkpoints | `docs/editor/vscode/` |
| Extension | `editors/vscode/` |

Do not put the extension under `aloe/`, `host/`, or `docs/`.

### 4.2 Language and launch

- Language id: `aloe`
- Filename: `*.aloe`
- Server command: `racket -l aloe/lsp` (editor-lsp 009)
- Setting: `aloe.racketPath` (string, default `racket`) when VS
  Code's environment has no `racket` on `PATH`
- Transport: stdio only. No TCP, no Node-owned copy of the server

### 4.3 First feature

Hover only. Milestone: open VS Code, open an Aloe file, hover an
expression, see type and messages. Completion is a later project
that starts from the query and LSP, not from this client.

### 4.4 Out of 000

- TextMate / semantic grammar, bracket config as a product goal
- Marketplace publish
- Completion, signature help, diagnostics, go-to-definition
- Source-locations 001
- Changing `query-expression-at` to take a string
- Generic third-party LSP clients as the deliverable

### 4.5 Tests and install

- 000 may check `package.json` / client command shape without
  launching VS Code
- Acceptance is the human hover on `examples/point.aloe`
- Run 000 via Extension Development Host (`F5`). A local `.vsix`
  is allowed later; it is not required to specify a publisher
  listing
- Do not add an Electron integration test harness in 000

### 4.6 Tooling

- JavaScript entry (`extension.js` or equivalent), 
  `vscode-languageclient`
- No TypeScript build in 000
- `package-lock.json` may be committed if the spec wants
  reproducible `npm install`; pick in §4.7

### 4.7 Leftover packaging details (resolve these)

1. **Extension identifiers.** `name`, `publisher` / `displayName`
   as they appear in `package.json`. Local-only is enough; do not
   design a Marketplace page.
2. **`engines.vscode`.** One minimum VS Code version compatible
   with the chosen `vscode-languageclient` major.
3. **Failure when `racket` is missing.** Show a VS Code error
   notification; do not hang. Do not auto-install Racket or the
   Aloe package.
4. **Activation.** `onLanguage:aloe` is the intended trigger.
   Confirm it in the spec.

Do not use §4.7 to add features.

## 5. Authority

- [`../lsp/spec.md`](../lsp/spec.md) — hover contents, launch
  command, capabilities (hover yes; completion and diagnostics
  no), UTF-16, full document sync
- [`../lsp/checkpoints/009-launch.md`](../lsp/checkpoints/009-launch.md)
- [`../expression-query/spec.md`](../expression-query/spec.md) —
  what hover is displaying, not a module this client may import
- [`../README.md`](../README.md)
- `docs/philosophy.md` — one catalog; the client does not own it
- VS Code Language Server extension guide only as needed for
  `vscode-languageclient` wiring

`SPEC.md` remains Aloe language law. This spec is not language law.

## 6. Non-goals

- Reimplementing Aloe in TypeScript or JavaScript
- Editing `aloe/lsp.rkt`, `aloe/expression-query.rkt`,
  `aloe/signature-catalog.rkt`, or the checker
- Completion / IntelliSense
- Diagnostics, `path:line:column` type errors
- Incomplete buffers, selector holes
- Grammar, themes, snippets, formatter
- Emacs, Neovim, or a generic LSP-client config as a requirement
- Gel UI
- Publishing to the Marketplace
- Wrap-the-preceding-expression
