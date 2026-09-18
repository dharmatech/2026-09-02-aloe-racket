# Charter — Selector completion

**Status.** Handoff from the editor-support brainstorm into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/editor/README.md`](../README.md).

**Your job.** Turn this charter into a specification for **selector
completion**: given a buffer and a cursor in a send's selector
position, return the receiver's typed message rows and insert a
selector. Then **stop**. Do not write checkpoints. Do not implement.
Do not specify highlighting, diagnostics, wrap-the-preceding-form,
top-level name completion, or a blank-file class list.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority in §5.
2. Confirm predecessors in §2 exist. If not, **stop**.
3. Record the locked decisions in §4. Resolve only §4.6.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **editor-completion 000**, `001`, … under
   `docs/editor/completion/checkpoints/` (not `docs/checkpoints/0118`,
   not a rewrite of editor-lsp 000–009 as a new hover series).
5. Stop. The human reviews it. Do not write those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A second Aloe parser, a
TypeScript method table, IntelliSense ranking research, and
completion of `define-class` / `fn` / `let` are defects.

## 2. Predecessors (do not start without these)

| Project | Ready when |
|---|---|
| [`../expression-query/`](../expression-query/) | `query-expression-at` exists |
| [`../signatures-of-type/`](../signatures-of-type/) | `type-signature-specs` is the catalog |
| [`../lsp/`](../lsp/) | editor-lsp 000–009; hover only; **no** `completionProvider` today |
| [`../vscode/`](../vscode/) | Thin client already launches `racket -l aloe/lsp` |

Hover answers “what is **this expression**?” Completion at a selector
hole answers “what can I send **the receiver**?” Those are different
cursors. Do not specify completion as `query-expression-at` at the
cursor. Hovering `dist2` types the **send** (a number). Completing
there must type the **receiver** (`Point`).

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. There is a documented Racket function (new or an extension of the
   expression-query module) that, given source and a cursor, returns
   an ordered list of completion items whose labels are selectors and
   whose detail is `params -> return`, from **`type-signature-specs`
   of the enclosing send's receiver**. It does not walk
   `class-info-methods` itself and does not invent a second catalog.
2. **Unit tests are the first consumer**, not VS Code. Each test is a
   snippet (fixture file or string) plus a documented cursor, and
   asserts the selector list (order and signatures). At least:
   - Point: cursor on `+` or `dist2` in a complete send whose
     receiver is `(Point new 1 2)` / `(Point new 1.0 2.0)` yields
     that Point instance's rows (fields then methods, same order as
     hover).
   - Boids: cursor on a send to a `Boid` or `(Point Float)` in
     [`examples/boids.aloe`](../../../examples/boids.aloe) (now
     monomorphic) yields that receiver's rows.
   - Prefix: a partial selector (`d`, `dist`) filters the same list;
     insert text is the selector symbol only.
   - **One incomplete selector-hole snippet** under the recovery
     rule §4.6 names (for example an unclosed
     `((Point new 1.0 2.0) |`). 000 must not ship as “complete files
     only, replace an existing selector.”
3. LSP `textDocument/completion` calls that function. Initialize
   advertises `completionProvider`. Hover behavior does not change.
   Recorded protocol tests exist; they are not the only tests.
4. No TypeScript/JavaScript copy of Aloe dispatch. The existing VS
   Code client should forward completion once the server advertises
   it. Specify an extension change **only** if the current client
   would ignore `completionProvider`.
5. Special forms, wrap-preceding-expression, blank-file / top-level
   class lists, MPL host injection, and highlighting are **out**.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 What 000 completes

Selector position of a **send**: `(receiver |` or `(receiver partial|`
or cursor on an existing selector token. Items are the receiver's
signature rows. Insert the selector. Detail shows types, not names
only.

Not in 000: completing `Point` after `(`, `define-class`, `fn`,
`let`, `if`, argument positions, or a form after a finished
expression with no wrapping send.

### 4.2 Catalog

Same `signature-spec` rows hover uses. `define-methods List` appears
because the type environment grew. Point's rigid `T` may still show
the assumed numeric rows; do not reopen constraints.

### 4.3 Tests over GUI

Snippet + cursor + expected rows. Fixtures may live under
`tests/editor/completion/`. Manual VS Code on Point, Boids, and later
a blank file is **human** review after 000, not the spec's proof.
Blank-file typing is allowed as a later report; 000 must not claim it.

### 4.4 Thin adapter

`aloe/lsp.rkt` may grow `textDocument/completion`. It must not parse
Aloe or build method tables. Prefer a query module the adapter
imports, the way hover imports `query-expression-at`.

### 4.5 Out of this experiment

- TextMate / semantic tokens / themes
- Diagnostics, source-locations 001
- Wrap-the-preceding-expression
- Top-level environment completion
- New reader / Go rewrite / macros
- Changing Boids back to `(Boid T)`
- Electron tests as the bar

### 4.6 Incomplete buffer (resolve this)

Hover requires a complete readable file. Completion cannot.

The spec **must name one recovery rule for 000**, with tests, and
must not write a second grammar. Candidates (pick one, or a tighter
variant of one):

1. **Close unmatched `)` from the cursor to EOF**, then
   `read-syntax` / the existing program reader, then find the send
   whose selector span contains the original cursor (or the hole
   after a complete receiver).
2. **Receiver-complete only:** if the form immediately before the
   cursor is a complete expression (balanced), type that expression
   in the file's environment even when the outer list is unclosed.
   Spell how the environment is built if the whole file still does
   not read.
3. **Last successful program + current prefix** — only if you can
   specify it without a second AST.

Do not leave this as “later.” Do not require a full incremental
parser. If recovery fails, return no items (empty list / LSP none),
not a fake catalog. Do not hang.

Also specify: UTF-16 cursor from LSP vs 1-based `srcloc-position`
(reuse editor-lsp conversion). Trigger characters if any (` ` is
enough to consider; do not invent `.`).

## 5. Authority

- [`../expression-query/spec.md`](../expression-query/spec.md)
- [`../signatures-of-type/spec.md`](../signatures-of-type/spec.md)
- [`../lsp/spec.md`](../lsp/spec.md) — hover contents, launch,
  UTF-16, document sync; completion is currently forbidden there,
  this spec **amends that prohibition** for this experiment only
- [`../source-locations/`](../source-locations/) — `selector-loc`
- `examples/point.aloe`, `examples/boids.aloe` (monomorphic `Boid`)
- `docs/philosophy.md` — one catalog
- `SPEC.md` — send is `(receiver selector arg ...)`

`SPEC.md` remains Aloe language law. This spec is not language law.

## 6. Non-goals

- Syntax highlighting
- Completing special forms or constructors as a separate UI
- Snippet templates (`new` filling two fields)
- Signature help while filling arguments (nice later; not 000)
- Ranking by popularity
- Gel, host capabilities, evaluating the buffer
