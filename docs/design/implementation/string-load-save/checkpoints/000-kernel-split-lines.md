# string-load-save 000 — Linear kernel `String.split-lines`

**Status.** Implemented, reviewed, and accepted. The focused test and the
full recursive suite pass (2,277 tests); interval 1 measured 0.000847 s on
review, below the 0.110 s bar. Human acceptance authorized checkpoint 001.

## Goal and stop

Move the existing public `(s split-lines)` send from recursive Aloe code to a
linear String kernel operation. Preserve every LF-delimited piece, including
empty pieces, and make a cold `Text` value's `indexed-value` cheap on the
10,000-line fixture. Update the shared signatures and their existing consumers
without changing editor behavior.

Stop when this checkpoint's tests and interval 1 timing bar are green. Do not
add `joined-with` or change indexed `Text.to-string`; those belong to
string-load-save 001.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); this checkpoint narrows the spec to one slice and
does not revise it. Sections 1–4, 6, and 7 of that spec govern this slice,
especially §4's exact split contract and §6's first timing interval.
`SPEC.md` remains Aloe language law: evaluation is a send, the second list
element is a literal selector, and there is no implicit Int/Float coercion.

- Identity is `(string-load-save, 000)`, spoken **string-load-save 000**. It is
  local to this project. Do not take global checkpoint 116 or edit
  `CHECKPOINTS.md` or `docs/checkpoints/`.
- Project root for code, tests, and commands:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Global checkpoints 114 and 115, aloemacs-text 000, and the implemented
  aloemacs Text, File, and Index layers are predecessors. Their functional
  behavior remains law. No earlier string-load-save checkpoint exists.
- The current kernel String rows are `=`, `append`, `len`, `take`, `drop`.
  `lib/string.aloe` currently defines `starts-with?` followed by the
  recursive `split-lines`; raw environments lack these Aloe methods, while
  default checked environments install them. `Text.indexed-value` already
  sends `split-lines`. Visit already uses `indexed-value`.

## Exact file scope

### May create or edit

- `aloe/eval.rkt` — only the String runtime send and construction of its
  ordinary typed Aloe List result.
- `aloe/type.rkt` — only String send typing, arity, and argument checks.
- `aloe/signature-catalog.rkt` — one ordered String kernel row.
- `lib/string.aloe` — remove only the superseded `split-lines` method; keep
  `starts-with?` unchanged.
- `SPEC.md` §7.5 — document the actual kernel, including predecessor `drop`.
- `tests/string-load-save/000-split-lines.rkt` and
  `tests/string-load-save/timing.rkt` — new focused tests and no-TTY timing.
- `tests/checkpoint-114.rkt`, `tests/checkpoint-115.rkt`, and
  `tests/aloemacs/000-string-prerequisite.rkt` — repair obsolete exact-source,
  kernel-versus-Aloe, raw-bootstrap, row-order, and row-count assertions only.
- `tests/editor/signatures-of-type/000-shared-catalog.rkt`,
  `tests/editor/completion/001-contextual-receiver.rkt`,
  `tests/editor/completion/002-public-query.rkt`,
  `tests/editor/expression-query/001-contextual-observation.rkt`, and
  `tests/editor/expression-query/003-public-query.rkt` — insert or move the
  String rows in their existing fixtures only.

Preserve unrelated assertions in every historical test. The existing
`tests/editor/signatures-of-type/001-kernel-query.rkt` reads the catalog and
should pass without an edit. Do not change any other test file.

### Must leave untouched

- `lib/text.aloe`, `lib/list.aloe`, other libraries, `examples/aloemacs/`,
  Gel, Term, Fs host, and editor production modules.
- `CHECKPOINTS.md`, global checkpoint documents, the accepted spec, this
  series' charter, and parser or class-method machinery.
- Any String representation, List spine, or existing `append`, `take`, and
  `drop` behavior.

If another production file is necessary, return this checkpoint for review
instead of widening its scope.

## Required `split-lines` behavior

`(s split-lines)` is a zero-argument **String instance kernel** message. It
returns a nonempty `(List String)` in source order. Split at every LF only;
retain every empty piece, including the final piece after a trailing LF.
CR, BOM, and Unicode characters remain ordinary content. Positions use the
same Racket character units as String `len`, `take`, and `drop`.

| Receiver | Result |
|---|---|
| `""` | `(List of "")` |
| `"ab"` | `(List of "ab")` |
| `"ab\ncd"` | `(List of "ab" "cd")` |
| `"ab\n"` | `(List of "ab" "")` |
| `"\n"` | `(List of "" "")` |
| `"a\r\nb"` | `(List of "a\r" "b")` |

Leading and repeated LFs also create empty pieces: `"\na\n\n"` yields
`(List of "" "a" "" "")`. No result piece contains LF.

Scan the receiver once. Take one substring per piece, then construct an
ordinary Aloe List with element type `String`; use the existing List class
and value representation. Work and retained result size must be O(`N + P`)
for `N` source characters and `P` pieces. Do not perform Aloe `drop`, `take`,
`append`, `cons`, or recursive sends per character or per line. Do not add a
new String representation or public method.

The checker and raw runtime reject extra arguments. `(3 split-lines)` is a
checked type error; a non-String receiver has no such message. Raw runtime
and checker environments know the new kernel send without bootstrapping
`lib/string.aloe`. They still do not know `starts-with?` until that library
is installed.

The ordered String kernel instance catalog becomes exactly:

```text
=            : (String) -> Bool
append       : (String) -> String
len          : ()       -> Int
take         : (Int)    -> String
drop         : (Int)    -> String
split-lines  : ()       -> (List String)
```

Default reflection appends only `starts-with? : (String) -> Bool` from
`lib/string.aloe`. The String class object has no constructor, `split-lines`,
or join row. `Mirror.messages`, `Mirror.signatures`, exact-row
`Mirror.invoke`, and editor signature queries must agree with ordinary
dispatch. Use the shared catalog; do not add a second signature table or
editor-specific behavior.

Update `SPEC.md` §7.5 to list `drop` and `split-lines`, explain their
contracts, and state that `starts-with?` remains Aloe-defined. Its kernel
count and precedence prose must match the six actual rows.

## Tests first and compatibility maintenance

Write `tests/string-load-save/000-split-lines.rkt` first and observe it fail
because the kernel row or raw send is missing. Use `aloe/driver.rkt` for
checked evaluation, plus raw evaluator and checker environments where their
bootstrap distinction matters. Exercise Aloe sends, not a separate Racket
splitting API.

The new focused test must prove:

1. Every table result above, plus leading and repeated LF, multiple trailing
   LF, Unicode, and exact checked result type `(List String)`.
2. The returned value is an ordinary nonempty Aloe List of String pieces in
   source order. `tests/aloemacs/000-string-prerequisite.rkt` keeps its old
   split goldens.
3. Zero arguments succeed; one or more extra arguments fail in checked Aloe
   and raw evaluation. `(3 split-lines)` is rejected by the checker.
4. The raw runtime and checker accept `split-lines` without the String
   library, while raw `starts-with?` remains unavailable. Default checked
   environments expose both selectors.
5. The six kernel signatures have exactly the order, parameters, and returns
   above; default `Mirror.messages` and `Mirror.signatures` append
   `starts-with?` once. `Mirror.invoke` using the actual `split-lines` row
   returns the same typed pieces. The String class object has no new row.

Narrowly update existing fixtures whose older assertions now misstate the
machine. In particular, `tests/checkpoint-115.rkt` currently expects the
exact two-method source and bans `split-lines` in kernel modules; replace
those assumptions with the one unchanged `starts-with?` Aloe body and the
new kernel location. Its reflection, row counts, and raw/bootstrap proofs
must continue to assert real behavior. Shift the affected String row order
in checkpoint 114, the aloemacs prerequisite, and the named editor fixtures;
keep their non-String assertions intact. Do not change editor implementation.

## Timing and verification

Create `tests/string-load-save/timing.rkt` with a `module+ main` no-TTY hand
check. In this checkpoint it measures **interval 1 only**; string-load-save
001 extends the same file with intervals 2 and 3. Build the source as 9,999
repetitions of `"x\n"` followed by `"x"`: exactly 10,000 one-character
lines and 19,999 characters. Initialize the checked driver and load
`lib/text.aloe` outside the timed interval. Time `(Text from-string source)`
followed by `indexed-value`. Outside the timed interval, assert an indexed
value at focus 0 whose `to-string` equals the exact source. Report elapsed
seconds.
Interval 1 must be below **0.110 s** on this machine. If it misses, return
the result to the design discussion instead of expanding this checkpoint.
Keep the threshold out of ordinary `raco test tests` execution.

From the project root, run in this order:

```sh
raco test tests/string-load-save/000-split-lines.rkt
raco test tests/checkpoint-114.rkt tests/checkpoint-115.rkt tests/aloemacs/000-string-prerequisite.rkt
raco test tests/aloemacs
raco test tests/editor/signatures-of-type
raco test tests/editor
raco test tests
racket tests/string-load-save/timing.rkt
git diff --check
```

If Racket tries to write under the read-only `/var/tmp`, prefix the affected
test or timing command with `TMPDIR=/tmp`. Do not replace `raco test tests` with a
top-level glob; nested test directories matter. Run one checked expression
by hand, such as `("a\n\nb\n" split-lines)`, and confirm the four pieces
`"a"`, `""`, `"b"`, `""`.

## Acceptance and explicit non-goals

This checkpoint is complete when the new send has the exact values, type,
arity, and O(`N + P`) implementation above; kernel and reflected catalogs
agree in order; the old String, List, Text, visit, and editor behaviors stay
green; the focused and full suites pass; and timing interval 1 meets its
bar. Stop for human review. Do not begin string-load-save 001.

No `joined-with`, indexed `to-string` change, `Text.lines` rewrite, List
change, class-side String send, StringBuilder, Vector, mutation, editor
control-flow change, safe control-character display, echo, windows, or Boids
work belongs here.
