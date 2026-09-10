# Checkpoint 114 — String `len` / `take` / `define-methods`

**Branch.** Continue on `experiment/gel-directory-surface` after reviewed
checkpoint 113.

**Depends on.** The existing primitive `String` messages (`=` and `append`),
`define-methods List`, and the reflection rules in `SPEC.md`.

**Status.** Ready to implement.

## Goal

Give primitive `String` two irreducible kernel operations, `len` and `take`,
and make `String` a legal `define-methods` target parallel to `List`. Kernel
string facts stay in Racket; later derived string behavior can be written in
Aloe.

This is one language checkpoint. The implementer receives only this document.

## Required String messages

Keep `=` and `append` unchanged. Add these kernel sends:

| Send | Parameter | Result | Meaning |
| --- | --- | --- | --- |
| `(s len)` | none | `Int` | number of characters in `s` |
| `(s take n)` | `Int` | `String` | prefix of `s`, clamped to its bounds |

The exact boundary behavior is:

```aloe
("" len)                  ; 0
("abc" len)               ; 3
("abc" take 0)            ; ""
("abc" take 2)            ; "ab"
("abc" take 3)            ; "abc"
("abc" take 5)            ; "abc"
("abc" take -1)           ; ""
("" take 2)               ; ""
```

For `take`, `n <= 0` returns `""`; `n >= (s len)` returns all of `s` (object
identity is not promised); otherwise it returns the first `n` characters.
Count string characters, not encoded bytes. The argument is exactly `Int`:
there is no implicit `Float` conversion.

Both the evaluator and checker must enforce the normal arities. `len` takes no
arguments and `take` takes exactly one. A non-`Int` `take` argument is rejected
statically and by the raw runtime path when checking is bypassed.

## `define-methods String`

This must be legal and use the existing method declaration syntax:

```aloe
(define-methods String
  (methods
    (empty? () Bool
      ((self len) = 0))))
```

The declaration above is test-only. Do not add `empty?` to the kernel or create
`lib/string.aloe` in this checkpoint. Prove that it typechecks and that:

```aloe
("" empty?)       ; #t
("x" empty?)      ; #f
```

The installed body runs as an ordinary Aloe method with `self : String`, may
send kernel string messages, and uses the same lexical/top-level environment
behavior as methods installed on `List`. Existing overload selection and
method-local type-parameter rules apply; `String` itself has no class type
parameter and does not put `T` in scope.

Normal string dispatch checks the four kernel selectors first, then the Aloe
methods installed for `String`, matching the `List` shape. Do not add a second
method lookup mechanism or turn host operations into Aloe stubs. Keep method
tables local to their runtime/checker environments so a definition in one
fresh environment does not leak into another.

Only `String` is lifted. Do not make `Int`, `Float`, `Bool`, or `Symbol` legal
`define-methods` targets. Do not generalize this into a common primitive-class
framework.

## Checker, runtime, and reflection integration

Follow the small existing `List` parallel in the runtime and type environments:
record installed String methods, check their bodies with `self : String`, and
fall back to them only after kernel String dispatch. Do not change parsing or
introduce syntax.

The checker knows these exact kernel signatures:

```text
=      : (String) -> Bool
append : (String) -> String
len    : ()       -> Int
take   : (Int)    -> String
```

String `take` has a concrete `Int` argument, so this checkpoint must not widen
the List-only expected-type propagation or add another inference special case.

Keep existing reflection coherent with dispatch. A String mirror exposes the
four kernel rows first and then installed Aloe method rows. `messages` remains
unique by selector, `signatures` reports the parameter and return types above,
and `Mirror.invoke` invokes the selected owned row exactly. For an installed
String row, exact-row invocation must run that method body directly rather
than resolving its selector again. Account for the four kernel rows wherever
String signature row indexes are interpreted.

Do not add constructors or class sends for `String`. Making it an extension
target does not make strings user-constructed through `(String new ...)`.

## Exact file scope

Implementation may edit only:

- `aloe/env.rkt`
- `aloe/eval.rkt`
- `aloe/type.rkt`
- `SPEC.md`
- `docs/decisions.md`
- `tests/checkpoint-114.rkt` (new)
- `CHECKPOINTS.md` (append checkpoint 114 only)

Do not edit `aloe/main.rkt`, parsing, existing libraries, Gel, host
capabilities, runners, examples, prior checkpoints, or prior tests. Do not add
hidden files.

In `SPEC.md`, list all four primitive String messages and say that further
String methods may be installed with `define-methods String`, as it already
does for List methods. Keep the change local to the String and
`define-methods` descriptions.

Add one short dated entry to `docs/decisions.md`: `len` and `take` are the
irreducible String kernel facts, while derived String behavior belongs in Aloe
through `define-methods String`; this lifts String only, not every primitive.

Append only this entry to `CHECKPOINTS.md`:

```text
## 114. [String `len` / `take` / `define-methods`](docs/checkpoints/0114-string-len-take.md)

- Primitive `String` adds kernel `len` and clamped-prefix `take`; further
  String behavior may be installed as Aloe methods with `define-methods
  String`. Other primitives remain closed.
```

## Tests and acceptance

Add `tests/checkpoint-114.rkt`. Cover at least:

1. Every successful `len` and `take` expression listed above, including its
   checked result type.
2. Character counting/prefixing on a non-ASCII string, without adding `Char`.
3. Wrong arities for `len` and `take`, plus rejection of `Float`, `Bool`, and
   `String` arguments to `take`; no numeric coercion.
4. Existing `=` and `append` behavior and types remain unchanged.
5. The test-only `empty?` definition typechecks and evaluates for empty and
   nonempty strings, and a fresh environment without that definition still
   reports an unknown message.
6. `define-methods Int`, `Float`, `Bool`, and `Symbol` remain rejected.
7. String reflection includes exact kernel signatures and the installed
   method once; direct sends and exact `Mirror.invoke` work for the new kernel
   rows and the installed Aloe row.
8. The full existing suite remains green, including List extension and
   reflection tests. Source assertions enforce the exact file scope and the
   absence of a string library or unrelated primitive extension.

Run:

```sh
raco test tests/checkpoint-114.rkt
raco test tests/*.rkt
racket -e '(require "aloe/main.rkt") (displayln (eval-source "(\"abc\" take 2)"))'
git diff --check
```

The hand check must print `ab`. Stop for review when all commands are green;
do not commit and do not begin checkpoint 115.

## Explicit non-goals

- No `starts-with?`, `ends-with?`, `contains?`, `empty?`, `drop`, `slice`,
  `at`, or `Char` kernel message.
- No `take` on `List`; it remains derivable from `first` and `rest`.
- No `lib/string.aloe`, string-library bootstrap, hidden-file predicate, or
  checkpoint 115 work.
- No Gel, disk, filesystem host, runner, key, menu, or presentation change.
- No inheritance, mutation, macro, special form, implicit numeric coercion,
  general primitive extension facility, or new checker inference rule.
