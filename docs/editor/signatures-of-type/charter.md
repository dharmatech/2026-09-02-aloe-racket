# Charter — Signatures of a type

**Status.** Handoff from the editor-support brainstorm into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/editor/README.md`](../README.md).

**Your job.** Turn this charter into a specification for the static
catalog of messages a type understands. Then **stop**. Do not write
checkpoints. Do not implement. Do not design source locations,
expression-query CLI, LSP, or VS Code. Do not add macros.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority in §5.
2. Resolve the open questions in §4.
3. Write `spec.md` in this folder. That spec is what a later
   checkpoint-manager conversation will slice into
   **editor-signatures-of-type 000**, `001`, … under
   `docs/editor/signatures-of-type/checkpoints/` (not
   `docs/checkpoints/0118`, not `docs/editor/source-locations/`).
4. Stop. The human reviews it. The spec conversation does not write
   those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A language server, a
documentation generator, or a second method table in a new datatype
unrelated to `Mirror` is a defect.

## 2. Why this experiment exists

Gel already answers "what can I send this **value**?" with
`(mirror signatures)`: ordered rows of selector, params, and
return, including fields and kernel tables.

The editor needs the same answer for a **type**, before anything
runs. `type-of` only types a complete expression. Send inference
looks up a method only after the selector is already written. There
is no checker query: given `Point` or `Int` or `(List String)`,
list the rows.

If that query is the static twin of `Mirror`, library methods,
overloads, constructors, and host receivers appear without teaching
VS Code about `Point`. If the editor grows its own catalog, every
language change is two implementations.

This project does **not** need source locations. It does not look at
a buffer. A later expression-query project will compose spans with
this catalog.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. There is a Racket-callable query from a checker type to an
   ordered list of signature rows (selector, parameter types, return
   type).
2. For a value `v` whose checker type is `T`, those rows match
   `(Mirror of v)` / `(mirror signatures)` unless the spec records a
   named, tested exception.
3. Adding a method with `define-methods` (for example on `List` or
   `String`) changes the query the same way it changes `Mirror`.
   The query does not hardcode `fold`.
4. Instance types, class objects, kernel numbers, `Bool`, `String`,
   `Symbol`, `List`, functions (`call`), `Mirror`, `Signature`, and
   injected host receivers are in scope or explicitly deferred **by
   name** in the spec.
5. No VS Code, no LSP, no cursor, no JSON-RPC.

## 4. Open questions (resolve these)

1. **Return representation.** Racket structs (today's
   `signature-spec` in `aloe/eval.rkt`) versus kernel `Signature`
   values versus both? Who owns the row type?
2. **Row identity with Mirror.** Fields, constructors, methods,
   overloads, order. `class-signature-specs` today only exposes
   `new`; constructor sets are richer. Does the static query follow
   Mirror (including that gap), or does this project also fix
   Mirror / class rows so constructors other than `new` appear in
   both?
3. **Class versus instance.** `(Point new 1 2)` vs `Point`. Two
   catalogs. Spell them.
4. **Where the function lives.** `aloe/type.rkt`, `aloe/eval.rkt`
   next to `value-signature-specs`, or a new module that both can
   call so the tables do not drift?
5. **Generics.** `(Point T)` vs `(Point Int)`: rows with `T`
   unsubstituted vs substituted. What does Mirror do today, and
   does the query match that?
6. **Protocols.** Does a `Math` type list protocol signatures, or
   only concrete class methods?

Do not leave these as "later." Pick, or defer a named type family
with a one-line reason.

## 5. Authority

- `SPEC.md` — send, classes, constructors, overloading, host
  boundary, `Mirror` / `Signature`
- `docs/philosophy.md` — one catalog, not editor-private knowledge
- `aloe/eval.rkt` — `value-signature-specs`, `instance-signature-specs`,
  `class-signature-specs`, kernel tables
- `aloe/type.rkt` — `class-info-methods`, send inference
- `gel/menu.aloe` — `GelRows.of` as a consumer of Mirror rows, not
  as a design to copy into Racket
- `docs/editor/README.md`

`SPEC.md` is language law. This spec is not language law until
ratified. Do not invent special forms.

## 6. Non-goals

- Source locations, `read-syntax`, error message format
- `messages-at` / type-at-cursor / CLI
- LSP, VS Code
- Incomplete programs
- Changing dispatch, overloading, or `define-class`
- Gel UI
- Documenting every class in the tree as a hardcoded list
