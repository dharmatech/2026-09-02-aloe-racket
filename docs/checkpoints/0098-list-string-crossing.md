# Checkpoint 98 — `(List String)` host crossing

**Branch.** `experiment/host-boundary`

**Depends on.** Checkpoint 97 (constructors + sealed host boundary on
one branch)

**Status.** Complete (reviewed 2026-09-08 on `experiment/host-boundary`)

## Goal

Admit homogeneous `(List String)` as a host crossing type so a host
method can return immediate directory names. Do not encode a listing as
a delimiter-separated `String`. Do not add a filesystem capability.

This is the first compound crossing type. Keep the descriptor-driven
architecture from checkpoints 83–88. Term stays unchanged.

## Depends on

- `experiment/host-boundary` after checkpoint 97.
- Working design: `docs/host-boundary-extensions.md` (not law).
- Consumer pressure: `docs/filesystem-vocabulary.md` §5 and §7 item 2
  (host `names` returns `(List String)`). Do not implement that
  vocabulary here.
- Not authority: `codex/unified-nominal-adts`, Proposal A.

## Authority / starting point

Law until this lands: `SPEC.md` §14 (crossing is only `Int`, `Bool`,
`String`) and `aloe/host.rkt` as merged in 97.

After this checkpoint, SPEC §14 includes homogeneous `(List String)`
and nothing else.

Design against the merged files, not from memory:

- `aloe/host.rkt` — `crossing-types`, `crossing-type?`,
  `normalize-crossing-value`, `host-receiver-invoke-method`
- `aloe/type.rkt` — `host-crossing-type->type`, `infer-host-send`
- `aloe/eval.rkt` — `list-value` / `make-list-value`,
  `host-method->signature-spec`, `type-datum->aloe-value`
- `tests/checkpoint-83.rkt` — currently rejects `'(List String)`

## Exact file scope

**May edit:**

- `aloe/host.rkt`
- `aloe/eval.rkt` (only marshalling around host invoke / list
  construction; no second send rule)
- `aloe/type.rkt` (host crossing mapping and nothing else)
- `SPEC.md` §14 crossing sentence only (plus the opening line if it
  still says the vocabulary is three scalars)
- `docs/decisions.md` (short dated addendum, not a rewrite)
- `docs/handoff.md` (crossing vocabulary sentence in the typed-host
  section)
- `CHECKPOINTS.md` (append 98)
- `docs/host-boundary-extensions.md` (status only, if needed)
- `tests/checkpoint-83.rkt` (living declaration tests; see below)
- `tests/checkpoint-98.rkt` (new)
- reflection tests in `tests/checkpoint-87.rkt` **only** if a current
  assertion assumes every host type datum is a lone Symbol and that
  assertion would become false for a new `names` row. Do not rewrite
  Term's reflected shape.

**Do not edit:**

- `docs/checkpoints/0083-validated-host-declarations.md` through
  `0088-seal-typed-host-boundary.md` (historical)
- `docs/checkpoints/0097-integrate-typed-host-boundary.md`
- `docs/filesystem-vocabulary.md`
- `docs/class-constructors.md`
- `aloe/parse.rkt`
- `examples/`, `lib/`, `gel/`, MPL
- no `host/racket/fs.rkt`, no `lib/fs.aloe`, no `lib/option.aloe`
- no generic `Holder` / `Fs` wrapper work (checkpoint 99)

## Required behavior

### Crossing grammar

Permitted host method type datums are exactly:

```text
Int
Bool
String
(List String)
```

Represent `(List String)` as the Racket datum `'(List String)`, not as
a new symbol. `make-host-method` must accept that datum in parameter
position and in return position.

Still rejected at declaration time, in both positions:

- `'List`
- `'(List Int)`
- `'(List Entry)`
- `'(List (List String))`
- `'Float`, `'Path`, `'Term`, `'T`, `'(-> String String)`, `42`

Update `tests/checkpoint-83.rkt` so `'(List String)` is no longer in
`unsupported-types`. Keep `'List` and the other rejects. Add a positive
declaration that a method with return type `'(List String)` (and one
with a `'(List String)` parameter) constructs successfully. Do not
rewrite the historical checkpoint 83 document.

`crossing-type?` cannot stay a `memq` on a flat symbol list.

### Runtime marshalling

Host implementations for a `(List String)` slot see a **proper Racket
list of strings**. Aloe programs see an ordinary homogeneous
`(List String)` (`list-value`).

Both directions, on the existing guarded invoke path (ordinary
`host-receiver-send` and reflected `host-receiver-invoke-method`):

1. Argument declared `(List String)`: require an Aloe `list-value`
   whose elements are all strings (empty is allowed). Freeze each
   string. Pass a proper Racket list to the implementation. Reject
   non-lists, improper lists, vectors, delimiter-encoded strings, and
   non-string elements with the existing host crossing error shape
   (`host crossing error for … expected …`).
2. Result declared `(List String)`: require a proper Racket list of
   strings (empty is allowed). Freeze each string. Return an Aloe
   `(List String)` that answers `len` / `first` / `rest` like any other
   list. Prefer recording `String` as the element type even when empty,
   so runtime and checker agree. Reject the same bad shapes as above.

Do not add a second send or evaluation rule. If building the Aloe list
needs the `List` class object, obtain it from the evaluator (the
binding already in a driver environment). Do not create a second list
representation inside `aloe/host.rkt`.

Scalar crossing is unchanged. Term `read-key` / `write-line` are
unchanged.

### Checker

`host-crossing-type->type` maps `'(List String)` to the same
`(List String)` the rest of the checker uses (`list-type` of `STRING`).
`case` on a list datum will not work; match with `equal?`.

A host send declared to return `(List String)` typechecks as
`(List String)`. Passing a `(List String)` into a host parameter
typechecks. Passing `(List Int)` or a `String` there is a type error.

### Reflection

`host-method->signature-spec` already forwards declared type datums.
`'(List String)` must reify through the existing compound type-data
path (`type-datum->aloe-value` already handles list datums): a `List`
of two `Symbol` values named `List` and `String`. Do not add a new
type-data form. Term's two rows stay `String`.

### SPEC, decisions, handoff

`SPEC.md` §14: replace “The complete crossing vocabulary is `Int`,
`Bool`, and `String`” with a sentence that adds homogeneous
`(List String)` and explicitly excludes nested lists and `(List T)` for
any other `T`. Leave the rest of §14 (injection, no ambient
capability, no second send rule) unchanged. Do not put `Term` or host
interface names into §5.1.

`docs/decisions.md`: add a short dated entry (2026-09-08) that
`(List String)` was admitted under filesystem listing pressure, not as
a general list FFI. Do not reopen opaque handles or `Result`.

`docs/handoff.md`: the typed-host section's crossing sentence must
match SPEC. Do not claim `Path` / `Entry` / `Fs` exist.

`CHECKPOINTS.md` compact entry:

```text
## 98. [(List String) host crossing](docs/checkpoints/0098-list-string-crossing.md)

- Homogeneous `(List String)` is a host crossing type. Host `names` can
  return a list of strings. Nested lists and other `(List T)` forms are
  not crossing types. No filesystem capability.
```

## Tests and hand check

Add `tests/checkpoint-98.rkt`. Do not repeat 83–88 or 90–97.

Cover:

1. `make-host-method` accepts `'names` with parameter-types `'(String)`
   and return-type `'(List String)`. It still rejects `'List`,
   `'(List Int)`, `'(List Entry)`, and `'(List (List String))` as
   return types.
2. Inject a test host (not Term, not a real filesystem) with:

   | Selector | Parameters | Return |
   | --- | --- | --- |
   | `names` | `String` | `(List String)` |
   | `count` | `(List String)` | `Int` |

   Controlled state is enough: `names` of `"empty"` returns `'()`;
   `names` of `"dir"` returns `'("a" "b")` (or equivalent).
3. `(host names "empty")` typechecks as `(List String)`, has `len` 0.
4. `(host names "dir")` typechecks as `(List String)`, `len` is 2,
   `first` / `rest` yield the strings in order. Aloe must not have to
   split a delimiter-encoded `String`.
5. `(host count (host names "dir"))` returns `2`.
6. A host implementation that returns `"a,b"`, `'(1 2)`, or an
   improper list for `names` is a host crossing error. A non-string
   element is a crossing error.
7. Checker rejects `(host names 1)` and rejects passing `(List of 1 2)`
   to `count`.
8. `Mirror` of that host: `names` return type reifies as compound
   type-data `List` then `String`, not as a delimiter `String`. Exact-row
   invoke of `names` still returns a `(List String)`.
9. Inject Term on a **different** driver (or after the test host on a
   fresh driver) and confirm `(term write-line "sealed")` still returns
   `"sealed"`. Default drivers still have no `term`.

Existing 83–88, 90–95, and 97 must stay green after the checkpoint-83
test update.

### Hand check

Same Term check as checkpoint 88/97:

```racket
(require "aloe/driver.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define state (make-driver))
(driver-inject-host!
 state 'term (make-term-receiver output (lambda () "unused")))

(list (driver-eval! state '(term write-line "sealed"))
      (get-output-string output))
```

Expected: `'("sealed" "sealed\r\n")`

Plus one list send on the test host, by hand:

```racket
(driver-eval! state '(host names "dir"))
```

must be a list whose `len` is 2, not the string `"a,b"`.

## Acceptance

- `raco test` green, including updated 83 and new 98.
- Hand checks above hold.
- `git diff --check` clean.
- Crossing is `Int` / `Bool` / `String` / `(List String)` only.
- No filesystem library, no generic wrapper slice, no source-written
  host type names.
- Stop. Do not start checkpoint 99.

## Explicit non-goals

- `Path`, `Entry`, `Fs`, `lib/fs.aloe`, real directories, Gel UI.
- Generic field retention of a host-receiver type (checkpoint 99).
- Source-written host interface names.
- `lib/option.aloe`.
- `(List Entry)`, `(List Int)`, nested lists, opaque handles, `Result`,
  bytes, mutable directory handles.
- Redesigning descriptor injection or adding a second send rule.
- Merging this branch to `main`.
