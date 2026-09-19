# Charter — LSP adapter (thin host skin)

**Status.** Handoff from the editor-support brainstorm into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/editor/README.md`](../README.md).

**Your job.** Turn this charter into a specification for a small
language server that **calls the expression query**. Then **stop**.
Do not write checkpoints. Do not implement. Do not re-specify
spans, signatures-of-type, or the query. Do not build a VS Code
extension in this experiment unless the spec names a **smoke
client** that cannot work without one — prefer no client, or the
smallest client that proves stdio.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority in §5.
2. Confirm [`../expression-query/spec.md`](../expression-query/spec.md)
   exists and names a callable query. If not, **stop**.
3. Resolve the open questions in §4.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **editor-lsp 000**, `001`, … under
   `docs/editor/lsp/checkpoints/`.
5. Stop. Do not write those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A full language server
(rename, formatting, semantic tokens, workspace index), a second
Aloe parser in TypeScript, and Gel-in-VS-Code are defects.

## 2. Why this experiment exists

Projects 1–3 put knowledge in the checker. This project is the host
skin: JSON-RPC over stdio, like `gel-run.rkt` for Gel.

VS Code is the first **client**, not the design center. If
completion or hover cannot be answered by the expression query, the
feature is out of scope or the query spec is wrong — take that back
to expression-query. Do not add a method table here.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. The server is a Racket process speaking LSP over stdio.
2. `textDocument/completion` and/or `textDocument/hover` (spec picks
   which in the first slice) call the expression query. Selector
   plus types, not names only, if completion is in.
3. No TypeScript/JavaScript copy of Aloe dispatch.
4. Diagnostics, if included at all, are the existing type checker
   on a complete file, with source-locations 001 error format if
   that exists. Incomplete buffers may yield no diagnostics.
5. A test talks to the query or a recorded LSP message without
   requiring a human to click VS Code. A VS Code extension, if any,
   is a later slice or a later project.

## 4. Open questions (resolve these)

1. **First methods.** Hover only, completion only, or both in slice
   000? Diagnostics in or out?
2. **Position encoding.** UTF-8 vs UTF-16. Map from LSP positions
   to the `srcloc` coordinates source-locations stored. Do not
   change the reader.
3. **Document sync.** Full text on change is enough. Incremental
   sync is not required for v0.
4. **Launch.** How a client finds `racket` and this package. One
   documented command line.
5. **VS Code.** Specify "no extension in this experiment" or "one
   smoke extension that only launches the server and registers
   `.aloe`." Do not specify themes, snippets, or wrap-form commands
   here. Wrap-preceding-expression is a later product, not LSP
   core.

## 5. Authority

- `docs/editor/expression-query/spec.md` (required)
- `docs/editor/README.md`
- LSP spec only as needed for the chosen methods
- `docs/philosophy.md` — one catalog

## 6. Non-goals

- Reimplementing Aloe in the client
- Incomplete-buffer recovery
- Rename, go-to-definition, formatting, semantic tokens
- Macros
- Gel UI
- Wrap-preceding-expression
- Emacs / Neovim as a requirement for 000 (the server must not
  assume VS Code APIs)
