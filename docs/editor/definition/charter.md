# Charter — Class-name definition

**Status.** Handoff from the editor discussion into a **design
conversation**. Not Aloe law. Not a checkpoint. Not an implementer
assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map: [`docs/editor/README.md`](../README.md),
project 8. Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Turn this charter into a specification for
**class-name definition**: from a class's own name, or from a type
that names a class, return the span of that class's name in its
`define-class` form. The first consumer is a Racket query. LSP
`textDocument/definition` is the skin a VS Code client already
running `racket -l aloe/lsp` will call. Then **stop**. Do not write
checkpoints. Do not implement.

If you have been told to read this file, this is the whole assignment.

This series does not grow a method-selector checkpoint. Selectors,
protocols, `define` names, and instances are a later project with
its own folder, not editor-definition 001.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Confirm the predecessors in §2. If one is missing, **stop**.
3. Record the locked decisions in §4. Do not reopen them.
4. Write `spec.md` in this folder. Choose the span representation
   §4.7 leaves to you, and record that choice. A later
   checkpoint-manager conversation slices **editor-definition 000**,
   `001`, … under `docs/editor/definition/checkpoints/` (not
   `docs/checkpoints/`, not a rewrite of editor-lsp 000–009).
5. Set this folder's README status to spec written, awaiting
   review, and set project 8's status cell on the parent map the
   same way.
6. Stop. The human reviews the spec. Do not write checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A definition index of the
workspace, a TypeScript parser, and jump-to-selector are defects.

Intended order, which the spec may pack or split to the checkpoint
size in [`docs/workflow.md`](../../workflow.md) and must not reorder:

1. The class name's span is stored for every file-defined class.
2. A public Racket query answers the positions in §4.1 and §4.2.
   Hover is unchanged.
3. `textDocument/definition` adapts that query. The VS Code
   extension is unchanged.

## 2. Predecessors (do not start without these)

| Predecessor | Ready when |
|---|---|
| [`../source-locations/`](../source-locations/) | Expression `srcloc` values exist. `read-program` keeps syntax long enough to take a name's span. `parse-datum` still produces `#f` locations. |
| [`../expression-query/`](../expression-query/) | `query-expression-at` exists, takes `#:document-path`, and returns `pathed-type`. |
| [`../lsp/`](../lsp/) | editor-lsp 000–009. Hover and completion are live. Initialize already advertises `hoverProvider` and `completionProvider`. |
| Defining path | `class-info` stores the resolved path of the file that defined the class, or `#f`. Hover prints that path on the `from:` line. |

Defining path is on this tree as of commit `28c0f26`. It is not a
separate editor project. If the tree has no defining path, stop.
Do not rebuild the modules work inside this spec.

[`../vscode/`](../vscode/) already launches `racket -l aloe/lsp`
with client options that contain only `documentSelector`. It is a
consumer, not a predecessor you extend.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. A public Racket function, given a source, a document path, and a
   cursor, returns the defining name's location or no location.
   Unit tests are the first consumer. Each test is a snippet plus a
   cursor. Fixtures live under `tests/editor/definition/`.
2. The location is the class name in `define-class`, a short span.
   It is not the whole form. `(define-class (Option T) ...)` lands
   on `Option`.
3. The cursors in §4.1 and §4.2 jump. The cursors in §4.3 do not.
   A miss is the same kind of empty answer hover uses for a miss,
   not a diagnostic and not a crashed server.
4. LSP `textDocument/definition` calls that function once.
   Initialize advertises `definitionProvider` beside the capabilities
   already advertised. The result is one LSP `Location`, or null.
   The range is the name, in UTF-16, using the existing position
   conversion. The URI is never a temporary sibling path.
5. Hover's selected expression, range, and contents are unchanged,
   including the `from:` line.
6. `editors/vscode/` is unchanged. `createClientOptions` still
   returns only `documentSelector`. If that client would ignore
   `definitionProvider`, stop and report it. Do not specify an
   extension change in anticipation.
7. No TypeScript or JavaScript copy of Aloe name resolution. No
   Aloe message for the query.

## 4. Locked decisions (record these; do not reopen them)

### 4.1 Name uses that jump

The cursor is on a name that resolves to a class which has a
defining path.

- A variable whose binding is that class. `AloemacsBuffer` in
  `(AloemacsBuffer new* ...)` is the original case. The binding is
  the class, not a `define` or `let` that holds the class object.
- The target name of `define-methods`, when the checker resolves it
  to such a class. `(define-methods AloemacsWindowTree ...)` and a
  target defined in another file both jump. `List`, `String`, and
  `Int` have no defining file, so they do not.
- The class's own name in `define-class`. Both headers work:
  `Name` and `(Name T ...)`. The answer is that same name span.
  `T` is not a class.

### 4.2 Type names that jump

A type is a sexpr. Each symbol in it that the checker resolves to a
class with a defining path is its own target. The cursor sits on
that symbol.

- A field type.
- A constructor payload field type.
- A method parameter type or return type, in `define-class` and in
  `define-methods`.
- A class name in a protocol signature's parameter type or return
  type.

`(Option AloemacsBuffer)` is two targets. `(AloemacsSession H)`
jumps for `AloemacsSession` only. `(List String)` jumps for neither
name, because those classes have no defining file.

### 4.3 What does not jump

These return no location. They are not errors.

- An expression whose type is an instance. F12 on `buf` does not
  open `AloemacsBuffer`. This includes a field read and a send.
- An alias. After `(define Buffer AloemacsBuffer)`, F12 on
  `Buffer` does not open the class. F12 on the `AloemacsBuffer`
  value in that definition does.
- A protocol. This includes the protocol slot of
  `(define-class Sym Math ...)` and a type position that resolves
  to a protocol. Do not open `define-protocol`.
- A type parameter, including a method-local `(type A ...)`
  parameter and `T` in `(List T)`.
- A selector. This includes method selectors, constructor
  selectors such as `Some` and `new`, and the markers `new*` and
  `with`.
- The name bound by `define`, `let`, or `fn`.
- A class with no defining path. Kernel classes, a class defined
  at the prompt, and an unkeyed port are in this group.
- `fn` annotations. The parser accepts `(fn (name ...) body)` only.
  Do not add typed `fn` so that a jump exists.
- `let` and `check`. Neither has a type slot.
- A comment, a string, whitespace, a parenthesis, or `->`.

A file that fails checking, an incomplete or malformed buffer, an
unopened document, an unsupported URI, an invalid position, and an
unreadable load are the same misses as hover. Copy those rules.
Do not publish diagnostics from this project.

### 4.4 Where the jump lands

The span covers the class's name and nothing around it. It does not
cover the `define-class` form. `AloemacsSession` is most of
`examples/aloemacs/file.aloe`; a range over that form would select
the whole class.

Record the span when the class is checked, from the syntax object
of the name. Do not find the definition by searching for the text
`define-class`.

One class has one definition. The LSP result is a single
`Location`, not a list and not a location link.

### 4.5 Query, hover, and document identity

The definition answer is a different result from
`expression-query-result`. Hover's `location` is the selected
expression. Do not add a definition field to that struct, and do
not make hover call the definition query.

The public function takes a source path, a document path, and a
`srcloc` position, in the same coordinate `query-expression-at`
uses. Follow that function's `#:document-path` rule and the LSP
spec's temporary-sibling rule. A class defined by the queried
buffer reports the document URI, including when the buffer is
dirty. A class brought in by `load` reports that loaded file. The
client never sees the sibling path.

A type name is not an expression node today. Hover on declaration
syntax stays on the enclosing declaration. Definition may answer
on a token hover does not select. Do not change which expression
hover selects.

`aloe/lsp.rkt` calls the public function. It does not import the
parser, walk declarations, or read `class-info` itself. One
definition request makes one query call.

The query does not evaluate the program and does not add an Aloe
message, a driver export, or a runtime binding.

### 4.6 LSP and the VS Code client

Advertise `definitionProvider` as a static boolean on the existing
initialize result. Handle `textDocument/definition`. Leave hover
and completion in place.

Every existing test that asserts the initialize capability map
gains `definitionProvider` and keeps `hoverProvider` and
`completionProvider`. Read those tests from the tree. Do not freeze
their count in the spec.

Reuse the LSP adapter's UTF-16 conversion. The range is the name's
span in the file the location names. For the queried document, convert
with the synchronized text. For a loaded file, convert with the
bytes that were checked. A name is an identifier and may be ASCII;
the converter still has to be the existing one.

The extension in `editors/vscode/` does not change.
`editors/vscode/test/000-hover-client.test.js` already requires
client options to be only `documentSelector`. That test stays green
without an edit.

### 4.7 Spans

Editor-source-locations 000 stores no location on
`field-declaration`, `parameter-declaration`,
`constructor-declaration`, or `method-declaration`. This project
needs the span of the class name and of each class-name symbol in
a type. That freeze is amended for those name tokens only.

The spec chooses the smallest representation that lets the checker,
after resolving the name, return that span. Record the choice.
Constraints:

- One parser. `read-program` remains syntax-aware. `parse-datum`
  still yields `#f` locations, and two `parse-datum` trees of the
  same datum still compare `equal?`.
- No second syntax tree retained beside the program, no wrapper
  node, and no new special form.
- Declaration structure does not gain a new Aloe meaning. A field
  is still a name and a type sexpr.
- The whole-form `loc` on `define-class-expr` stays the form's
  span. The name span is separate.

If those constraints cannot be met together, stop and report the
conflict. Do not drop type-name jumps to save the representation.

### 4.8 Tests and the hand check

Automated proof is `TMPDIR=/tmp raco test -j 4 -y` on the new tests
and on the suites the spec names. Include `-j 4` and `-y`.

The fixture suite covers §4.1, §4.2, and §4.3, including a class
used from another file, a `define-methods` target, a compound type,
a generic header, a kernel name, a protocol name, an instance, and
an alias. One hover golden on a definition cursor stays byte-for-byte
the same.

The human check, after the LSP slice, is in VS Code. Open
`examples/aloemacs/main.aloe`, go to definition on `AloemacsBuffer`
in `(AloemacsBuffer new* ...)`, and land on the name in
`examples/aloemacs/file.aloe` with the name selected. Then go to
definition on a field type that names a class. That check is not a
`raco test`.

On the LSP slice, `npm test` in `editors/vscode/` still passes, and
`git diff` shows no change under `editors/vscode/`.

## 5. Authority

- `SPEC.md` — language law. This spec does not amend it.
- [`../expression-query/spec.md`](../expression-query/spec.md) —
  selection, `query-expression-at`, `#:document-path`, and hover's
  result. This project does not change those rules.
- [`../lsp/spec.md`](../lsp/spec.md) — framing, lifecycle, UTF-16,
  document sync, the temporary sibling, and hover failure. Its
  deferred-work list still names definition. This spec amends that
  deferral for class names only. Do not rewrite the LSP spec's
  historical non-goals.
- [`../source-locations/checkpoints/000-spans.md`](../source-locations/checkpoints/000-spans.md)
  — expression spans and the `parse-datum` rule. §4.7 is the only
  amendment.
- [`../README.md`](../README.md) — project 8. The map already lists
  this charter.
- [`../../workflow.md`](../../workflow.md) — checkpoint size and the
  test command.
- LSP 3.17, the `textDocument/definition` request only.

When a locked decision here and an older editor non-goal disagree,
this charter wins for class-name definition and nowhere else.

## 6. Non-goals

- Method selectors, constructor selectors, `new*`, and `with`
- Protocols as jump targets
- `define`, `let`, and `fn` parameter names
- Go-to-type-definition on an instance
- References, rename, signature help, formatting, code actions,
  semantic tokens, diagnostics
- Aloemacs calling the query, a file sidebar, or highlighting in
  Aloemacs
- An Aloe message, driver export, or runtime binding for the query
- A workspace index, a dirty overlay for a nested load, or
  incremental sync
- Typed `fn`, or any other grammar change whose purpose is a new
  jump site
- A VS Code extension change, a second editor, or a client-side
  parser
- `CHECKPOINTS.md` and `docs/checkpoints/`
- Gel, evaluation, and host capabilities

## 7. Handoff

- Series identity: `definition`. Spoken name: **editor-definition
  000**.
- Folder: `docs/editor/definition/`. Spec: `spec.md` beside this
  file. Checkpoints: `checkpoints/000-slug.md` and upward, three
  digits, never renumbered.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Code and tests go there. Tests go under
  `tests/editor/definition/`.
- The checkpoint manager writes one checkpoint, then stops. The
  implementer receives that checkpoint and the accepted spec.
- Layer order is §1. The manager may split a layer that does not
  fit one conversation. The manager may not add a feature or
  reorder LSP ahead of the query.
- After the human accepts `spec.md`, it is the design authority.
  This charter is only the spec writer's assignment.
