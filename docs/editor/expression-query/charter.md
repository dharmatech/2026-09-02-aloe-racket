# Charter — Expression query (type and messages at a span)

**Status.** Handoff from the editor-support brainstorm into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/editor/README.md`](../README.md).

**Your job.** Turn this charter into a specification for "what is
the type of this expression, and what messages does it understand?"
Then **stop**. Do not write checkpoints. Do not implement. Do not
design LSP or VS Code. Do not reopen source-locations or
signatures-of-type unless their law is impossible to compose.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority in §5.
2. Confirm the two predecessor projects are ready (§2). If they are
   not, **stop** and tell the human. Do not specify spans or the
   type catalog here.
3. Resolve the open questions in §4.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **editor-expression-query 000**, `001`, …
   under `docs/editor/expression-query/checkpoints/`.
5. Stop. The human reviews it. Do not write those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. JSON-RPC, a VS Code
command, unclosed-buffer recovery, and wrap-the-preceding-form are
defects in this document.

## 2. Predecessors (do not start without these)

| Project | Ready when |
|---|---|
| [`../source-locations/`](../source-locations/) | At least 000 green: `read-program` expressions have `srcloc` |
| [`../signatures-of-type/`](../signatures-of-type/) | `spec.md` exists (implementation may still be in flight if the spec is enough to name the query) |

This project **composes** them. Given a complete program and a
source span (or equivalent address), find the expression, `type-of`
it in the file's type environment, and return signatures-of-type
for that type.

That is the philosophy sentence as a function. A CLI is allowed if
the spec wants a non-Racket consumer. LSP is not this project.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. A documented Racket function answers, for a well-formed file and
   an address inside it, the expression's type and its signature
   rows.
2. It uses source-locations to find the node and signatures-of-type
   to list rows. It does not walk `class-info-methods` itself.
3. A complete `examples/point.aloe` (or a smaller fixture) has at
   least one documented span whose rows include `Point`'s methods
   (`+`, `dist2`, …) with params and return, not names only.
4. `parse-datum` / location-less trees are defined (error, or
   "no address") rather than guessed.
5. Incomplete / unclosed input is **out of scope**. The spec may
   say "require a well-formed prefix" and stop.
6. No LSP method names, no VS Code, no editor plugin.

## 4. Open questions (resolve these)

1. **Address.** Byte offset, character offset, `line:column`, or a
   `srcloc` already in hand? Pick one for the function. A CLI, if
   any, is a thin wrapper.
2. **Which node.** Cursor on a token, between tokens, on a selector,
   on a parenthesis, on whitespace after a complete form. Define
   "innermost expression containing this point" or a tighter rule.
   Selector holes (`(receiver |`) are in or out by name.
3. **Environment.** Always bootstrap `List` / `String` libraries?
   `load` graph? Host injection? The spec must say what environment
   `examples/point.aloe` sees.
4. **CLI.** Is `./bin/aloe messages path:line:column` in this
   experiment or deferred? If in, one output format, tested.
5. **Failures.** Unknown file, span not in an expression, type
   error in the file. Do not typecheck past the first error unless
   the spec explicitly chooses best-effort (likely not).

## 5. Authority

- `docs/philosophy.md` — the editor question
- `SPEC.md` — send, types, `load`
- Predecessor specs / 000 checkpoints (read what exists; do not
  rewrite them)
- `aloe/main.rkt` / `aloe/driver.rkt` — how files are checked today
- `docs/editor/README.md`

## 6. Non-goals

- LSP, JSON-RPC, VS Code, Emacs
- Wrap-preceding-expression
- Unclosed paren recovery, incremental parse
- Macros
- Changing the type checker to continue after errors (unless §4.5
  explicitly picks a tiny, tested rule)
- Gel
