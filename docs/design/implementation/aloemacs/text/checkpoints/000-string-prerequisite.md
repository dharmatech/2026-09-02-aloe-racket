# aloemacs-text 000 — String `drop` and `split-lines`

**Status.** Ready to implement.

## Goal

Add the one kernel operation needed by the text algebra, `String.drop`, and
use it to add the Aloe-defined `String.split-lines` method. Prove the exact
clamping, typing, character-count, LF-splitting, empty-piece, reflection, and
default-driver behavior required by the aloemacs text specification.

Stop when this prerequisite is green. Do not add `Position`, `Span`, `Text`,
`EditResult`, or `lib/text.aloe`; those belong to later aloemacs-text
checkpoints.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-text, 000)`, spoken **aloemacs-text 000**. This is a
  local project checkpoint, not global checkpoint 116. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is language law,
  especially send evaluation, exact primitive types, immutable values,
  `define-methods`, `let`, `fn`/`call`, `List`, and reflection. Evaluation is
  send, not apply: the head of a list is the receiver and its second element
  is the literal selector.
- [`../spec.md`](../spec.md), especially sections 1, 2, 7.7, 8, and 9, is the
  local design authority. This checkpoint implements only its String
  prerequisite.
- Existing global checkpoints 114 and 115 supply the four current String
  kernel rows, `define-methods String`, the bootstrapped `lib/string.aloe`, and
  the Aloe-defined `starts-with?` method. Preserve those behaviors.
- Existing `List` kernel sends and `lib/list.aloe` are predecessors. No new
  List behavior is needed.

## Starting point

The current String kernel has these instance rows, in order:

```text
=      : (String) -> Bool
append : (String) -> String
len    : ()       -> Int
take   : (Int)    -> String
```

`aloe/signature-catalog.rkt` is the shared declaration of those rows.
`aloe/eval.rkt` owns primitive runtime dispatch and `aloe/type.rkt` owns
primitive send typing. Reflection and editor queries consume the shared
catalog; do not add a second signature table.

`lib/string.aloe` is already read, checked, and evaluated after the List
library by public default environments and by `make-driver`. It currently
defines `starts-with?`. This checkpoint extends that same file. It does not
change bootstrap policy or make raw runtime/type environments non-raw.

## Exact file scope

### May edit

- `aloe/signature-catalog.rkt`
- `aloe/eval.rkt`
- `aloe/type.rkt`
- `lib/string.aloe`
- `tests/aloemacs/000-string-prerequisite.rkt` (new)
- `tests/checkpoint-114.rkt`, only to add the new kernel behavior and repair
  String kernel/reflection expectations
- `tests/checkpoint-115.rkt`, only to replace its obsolete exact one-method
  String-library and five-row expectations while preserving all
  `starts-with?` and bootstrap coverage
- `tests/editor/signatures-of-type/000-shared-catalog.rkt`, only to insert the
  new String kernel row in the expected catalog
- `tests/editor/completion/001-contextual-receiver.rkt`, only to insert the new
  String kernel row in its expected fixture
- `tests/editor/completion/002-public-query.rkt`, only to insert the required
  new String rows in its expected fixtures
- `tests/editor/expression-query/001-contextual-observation.rkt`, only to
  insert the new String kernel row in its expected fixtures
- `tests/editor/expression-query/003-public-query.rkt`, only to insert the
  required new String rows in its expected fixtures

The seven existing test-file edits are compatibility maintenance for an
observable shared catalog and default String library. Do not weaken unrelated
assertions or rewrite those suites.

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, or any global checkpoint document
- `aloe/env.rkt`, `aloe/library.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`, the
  parser, or host-boundary code
- `lib/list.aloe`, `lib/option.aloe`, or any other existing library
- `lib/text.aloe` (it does not exist in this slice)
- `examples/`, `gel/`, `host/`, `bin/`, `docs/editor/`, or editor production
  modules
- the aloemacs README, charter, or specification
- any test outside the exact list above

If another production file appears necessary, stop and send the checkpoint
back for correction rather than widening the slice.

## Required kernel message: `String.drop`

Add exactly this kernel instance signature after `take`:

```text
drop : (Int) -> String
```

The public send is `(s drop n)`, where the receiver is a `String` and `n` is
exactly an `Int`. Its result is the suffix after a clamped prefix:

```aloe
("abc" drop -1)  ; "abc"
("abc" drop 0)   ; "abc"
("abc" drop 1)   ; "bc"
("abc" drop 3)   ; ""
("abc" drop 9)   ; ""
("" drop 2)      ; ""
```

Formally:

- `n <= 0` returns all of `s`;
- `n >= (s len)` returns `""`;
- otherwise it returns `s` without its first `n` characters.

Use the same Racket character-count unit as existing `len` and `take`, not
UTF-8 bytes. Object identity is not promised. For every String `s` and Int
`n`, this value identity must hold:

```aloe
((s take n) append (s drop n)) = s
```

The evaluator enforces exactly one argument and rejects a bypassed raw send
whose argument is not an exact integer. The checker enforces exactly one
argument of type `Int` and returns `String`. There is no implicit Int/Float
conversion.

Keep one dispatch path and one signature source:

- add the row to the shared String instance catalog;
- add runtime behavior beside `len` and `take` in `send-to-string`;
- add checker behavior beside `len` and `take` in `infer-string-send`.

Do not add `drop` as an Aloe method, host receiver, class-object send, generic
slice operation, `Char` operation, or String mutation. Do not add any other
kernel selector.

## Required Aloe method: `String.split-lines`

Extend the existing `define-methods String` declaration in
`lib/string.aloe`. Preserve `starts-with?` with its existing signature and
behavior, and add:

```text
split-lines : () -> (List String)
```

`split-lines` is ordinary Aloe code. It must not be recognized by the
evaluator, checker, signature catalog, host boundary, or any Racket special
case. It derives its result using existing String and List sends plus the new
`drop` message.

The result is always a nonempty list. Split only on the single LF character
`"\n"`, discard the LF separators, and preserve all empty pieces, including
the final one:

| Receiver | Result |
|---|---|
| `""` | `(List of "")` |
| `"ab"` | `(List of "ab")` |
| `"ab\ncd"` | `(List of "ab" "cd")` |
| `"ab\n"` | `(List of "ab" "")` |
| `"\n"` | `(List of "" "")` |

Consecutive LFs therefore preserve interior empty lines; for example,
`"a\n\nb\n"` becomes `(List of "a" "" "b" "")`. Carriage return is
ordinary content: `"a\r\nb"` becomes `(List of "a\r" "b")`.

A direct recursive method can take one-character Strings, recurse on
`(self drop 1)`, and rebuild the first piece with List `first`, `rest`, and
`cons`. The specification also permits one Aloe helper selector for the
recursion. If a helper is used, it remains ordinary reflected Aloe behavior;
do not hide it with a Racket exception or invent private-method machinery.
Tests must establish the required selector and results without treating an
unnecessary helper name as design law.

Do not add generic `insert` or `delete` String messages, string indexing,
substring, a newline primitive, `Char`, mutation, or a parallel Racket line
splitter.

## Reflection and query compatibility

The kernel String rows are now, in order:

```text
=       : (String) -> Bool
append  : (String) -> String
len     : ()       -> Int
take    : (Int)    -> String
drop    : (Int)    -> String
```

Default checked environments then expose the Aloe library rows in source
declaration order, including existing `starts-with?` and required
`split-lines`. If an allowed helper is used, it is an ordinary library row at
its declaration position.

`Mirror.messages`, `Mirror.signatures`, exact-row `Mirror.invoke`, static
signature queries, expression queries, and completion must all observe the
new real rows through their existing shared machinery. Do not special-case
aloemacs in any reflection or editor module.

Repair the scoped historical fixtures by inserting `drop` after `take`, and
by inserting `split-lines` at its actual library declaration position where
the fixture uses a public default environment. Preserve fixture distinctions:
raw kernel environments do not acquire the Aloe library, while public default
environments do. Do not merely change counts; continue asserting selectors,
parameter types, return types, and exact-row invocation where those suites
already do so.

The focused reflection proof must show that the `drop` row has one `Int`
parameter, returns `String`, and exact-row invocation on `"abc"` with `1`
returns `"bc"`. It must also show `split-lines` is a library row rather than a
kernel row.

## Tests

Add `tests/aloemacs/000-string-prerequisite.rkt`. Use the ordinary checked
Aloe driver (`make-driver` / `driver-eval!`); do not implement a Racket text
API or test an independent Racket splitting function.

Together with the tightly scoped checkpoint-114/115 maintenance, cover all of
the following:

1. `drop` returns every boundary value listed above and has checked type
   `String`.
2. `drop` and `take` count characters, not encoded bytes; for example,
   `("é🙂水" drop 2)` is `"水"`.
3. The take/drop identity holds below, at, within, and above the bounds,
   including a non-ASCII String.
4. The checker rejects zero or two `drop` arguments and rejects `Float`,
   `Bool`, and `String` arguments. A raw runtime environment bypassing the
   checker rejects the same arity/type errors with the normal String error
   shape.
5. Reflection exposes the fifth kernel row exactly as described above and
   invokes it exactly. The class object `String` still gains no constructor or
   class send.
6. `split-lines` has checked type `(List String)` and returns every exact row
   from the table above.
7. `split-lines` preserves consecutive, leading, and final empty pieces; the
   `"a\n\nb\n"` and `"\n"` fixtures establish this.
8. No returned element contains LF. A carriage return remains in its piece.
9. `starts-with?` retains its checkpoint-115 behavior, and `split-lines` is
   available without an explicit load in `make-driver`.
10. Raw environments retain the existing bootstrap distinction; adding this
    method does not move library policy into the kernel.
11. Existing List behavior remains available.

Racket may inspect the Aloe List result returned by the checked driver, but
all production splitting behavior must be exercised through Aloe sends.

## Verification and hand check

Run the focused and directly affected suites first:

```sh
raco test tests/aloemacs/000-string-prerequisite.rkt
raco test tests/checkpoint-114.rkt tests/checkpoint-115.rkt
raco test tests/editor/signatures-of-type/000-shared-catalog.rkt
raco test tests/editor/completion/001-contextual-receiver.rkt
raco test tests/editor/completion/002-public-query.rkt
raco test tests/editor/expression-query/001-contextual-observation.rkt
raco test tests/editor/expression-query/003-public-query.rkt
```

Then run the recursive suite; `tests/*.rkt` is not an acceptable substitute
because it skips nested aloemacs and editor tests:

```sh
raco test tests
```

Run one checked expression by hand from the repository root:

```racket
(require "aloe/driver.rkt")
(define state (make-driver))
(list (driver-eval! state '("é🙂水" drop 2))
      (driver-eval! state '("a\n\nb\n" split-lines)))
```

The value is a two-element Racket list whose first element is `"水"` and
whose second element is the Aloe list `("a" "" "b" "")`.

## Acceptance

This checkpoint is complete when:

- `drop` is the only new kernel operation and obeys its exact arity, type,
  clamping, character-count, and take/drop identity contracts;
- `split-lines` is Aloe-defined, returns a nonempty `(List String)`, splits
  only LF, and preserves all empty pieces;
- existing String and List behavior remains intact;
- shared reflection and editor-query consumers observe the new rows without
  production special cases;
- the focused tests and full recursive suite are green; and
- the hand check has the stated result.

Stop for human review. Do not begin aloemacs-text 001.

## Explicit non-goals

- `Position`, `Span`, `Text`, `EditResult`, replacement, insertion, deletion,
  newline editing, validity, or flat offsets
- `lib/text.aloe` or any test of the later text algebra
- Term, a TTY, editor state, point, marks, files, buffers, rendering, Unicode
  display width, grapheme handling, or a running editor
- any host crossing, host String receiver, public Racket text API, or Racket
  line-splitting implementation
- `Char`, string indexing, substring, generic slicing, generic String
  insertion/deletion, mutation, or any kernel message other than `drop`
- changes to Aloe language law, the global checkpoint sequence, or bootstrap
  policy
