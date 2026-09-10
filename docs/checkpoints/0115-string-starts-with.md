# Checkpoint 115 — String `starts-with?` library

**Branch.** Continue on `experiment/gel-directory-surface` after reviewed,
green checkpoint 114.

**Depends on.** Checkpoint 114 (`String.len`, `String.take`, and
`define-methods String`) and the existing `lib/list.aloe` bootstrap pattern.

**Status.** Ready to implement.

## Goal

Add one derived String method, `starts-with?`, as Aloe library code and load
that library in every default checked environment. This checkpoint adds no
kernel message and makes no evaluator or checker change.

The implementer receives only this document.

## Exact library

Create `lib/string.aloe` with exactly this definition:

```aloe
(define-methods String
  (methods
    (starts-with? (prefix String) Bool
      ((self take (prefix len)) = prefix))))
```

This is the entire String library for checkpoint 115. The method derives its
answer only from checkpoint 114's `len`, `take`, and existing `=` messages.
It is not a Racket builtin and must not appear in `aloe/eval.rkt`.

Required values are:

```aloe
("hello" starts-with? ".")     ; #f
(".bashrc" starts-with? ".")   ; #t
("." starts-with? ".")         ; #t
("" starts-with? ".")          ; #f
("abc" starts-with? "ab")      ; #t
("ab" starts-with? "abc")      ; #f
("abc" starts-with? "")        ; #t
("" starts-with? "")           ; #t
```

The parameter type is `String` and the result type is `Bool`. Existing String
kernel behavior, including clamped `take`, determines the short-receiver and
empty-prefix cases; do not add special cases in Racket or new Aloe helpers.

## Default bootstrap

Extend `aloe/library.rkt` with a cached reader for `lib/string.aloe`, parallel
to `lib/list.aloe`. Typecheck and evaluate the String library after the List
library everywhere the public APIs build their default environments:

- `aloe/main.rkt`: `make-type-environment`, `make-top-level-env`, and the
  fallback that associates a checker environment with a supplied runtime
  environment;
- `aloe/driver.rkt`: `make-driver`, which also covers `bin/aloe`.

A program using those defaults can send `starts-with?` without an explicit
`load`. Keep runtime and checker installation paired and environment-local,
just as for List. Raw environment constructors remain raw; do not move library
policy into `aloe/env.rkt` or `aloe/type.rkt`.

This bootstrap adds one reflected Aloe method row after String's four kernel
rows. Existing `Mirror.messages`, `Mirror.signatures`, and exact-row
`Mirror.invoke` behavior from checkpoint 114 must work without a reflection
special case.

## Exact file scope

Implementation may edit only:

- `lib/string.aloe` (new)
- `aloe/library.rkt`
- `aloe/main.rkt`
- `aloe/driver.rkt`
- `tests/checkpoint-115.rkt` (new)
- `tests/checkpoint-114.rkt` (only its now-superseded no-library and default
  four-row assumptions)
- `tests/checkpoint-109.rkt` (only the generic String menu expectation, adding
  the reflected `starts-with?` row after `take`)
- `SPEC.md`
- `CHECKPOINTS.md` (append checkpoint 115 only)

Do not edit `aloe/eval.rkt`, `aloe/env.rkt`, `aloe/type.rkt`, parsing, any
other library or test, Gel or disk source, host capabilities, runners,
examples, prior checkpoint documents, or `docs/decisions.md`.

Checkpoint 114 deliberately asserted that no String library was present.
Replace only those obsolete assertions and shift its default reflected-row
expectations to account for the bootstrapped `starts-with?`; preserve its
kernel, environment-local extension, shadowed-row, and other-primitive tests.
The raw runtime environment used there still has no bootstrapped libraries.

The checkpoint-109 change is fixture maintenance only. Its String menu gains:

```text
5  starts-with?  1
```

Do not change Gel implementation or behavior beyond the row that ordinary
String reflection now supplies.

## Documentation

Update only the String library description in `SPEC.md`: `starts-with?` is an
Aloe method defined in `lib/string.aloe` and installed in default environments,
parallel to List's Aloe-defined `fold`, `reverse`, and `map`. Keep `=`,
`append`, `len`, and `take` as the complete kernel String message set.

Append only this entry to `CHECKPOINTS.md`:

```text
## 115. [String `starts-with?` library](docs/checkpoints/0115-string-starts-with.md)

- `lib/string.aloe` derives `starts-with?` from String `len`, `take`, and `=`;
  default checked environments bootstrap it alongside the List library. No
  new kernel message.
```

## Tests and acceptance

Add `tests/checkpoint-115.rkt`. Cover at least:

1. All eight value goldens above and `Bool` as their checked type.
2. A non-String prefix is rejected by the checker and by raw method dispatch
   when checking is bypassed.
3. `eval-source`, `make-top-level-env`, and `make-driver` provide the method
   without an explicit `load`; a raw runtime/checker environment does not.
4. The loaded String library has only `starts-with?`, and the method's source
   body is the exact Aloe composition above.
5. Default String reflection lists `=`, `append`, `len`, `take`, then
   `starts-with?`; its signature is `(String) -> Bool`, and exact
   `Mirror.invoke` returns the expected Boolean.
6. `starts-with?` is absent from `aloe/eval.rkt`, `aloe/env.rkt`, and
   `aloe/type.rkt`; those files are unchanged from checkpoint 114.
7. List library behavior, checkpoint 114's String kernel behavior, the updated
   generic String menu bytes, and the full existing suite remain green.

Run:

```sh
raco test tests/checkpoint-115.rkt
raco test tests/*.rkt
racket -e '(require "aloe/main.rkt") (displayln (eval-source "(\".bashrc\" starts-with? \".\")"))'
git diff --check
```

The hand check must print `#t`. Stop for review when all commands are green;
do not commit and do not begin checkpoint 116.

## Explicit non-goals

- No `ends-with?`, `contains?`, `drop`, or any other String library method.
- No new String kernel message, primitive extension, inference rule, syntax,
  inheritance, mutation, macro, or numeric coercion.
- No Gel or disk implementation, hidden-name filtering, filesystem change,
  runner change, or checkpoint 116 work.
- No comments-as-essays in `lib/string.aloe`; keep the library to the one
  method above.
