# string-load-save 001 — Linear indexed `Text.to-string`

**Status.** Implemented, reviewed, and accepted. The focused test and full
recursive suite pass (2,282 tests); review measured indexed `to-string` at
0.000343 s for focus 0 and 0.000342 s for focus 9,999, both below 0.029 s.
Human acceptance closes the two-checkpoint series.

## Goal and stop

Add the String instance kernel send `joined-with` to flatten the three fields
of an indexed `Text` in one linear copy. Make indexed `(text to-string)` send
that primitive once, preserving exact source text at every valid focus. Keep
the cold `from-string` branch as its direct stored-source return.

Stop when the direct send, Text round trips, full suite, and both indexed save
timing intervals are green. Do not change editor visit/save control flow or
begin adjacent editor work.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); this checkpoint narrows the spec to one slice and
does not revise it. Sections 1–3, 5–7 of that spec govern this slice,
especially §5's `joined-with` contract and §6's intervals 2 and 3. `SPEC.md`
remains Aloe language law: the head of a list is the receiver, the second
element is a literal selector, and function objects run only through `call`.

- Identity is `(string-load-save, 001)`, spoken **string-load-save 001**. It is
  local to this project. Do not edit `CHECKPOINTS.md` or add a global
  checkpoint document.
- Project root for implementation, tests, and commands:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- string-load-save 000 is implemented, reviewed, and accepted. Its linear
  kernel `split-lines`, typed List result, test goldens, and interval 1 bar
  are predecessors. Preserve them.
- The current String kernel rows are `=`, `append`, `len`, `take`, `drop`,
  `split-lines`; default reflection then appends the Aloe `starts-with?` row.
  `lib/text.aloe` currently rebuilds `lines` and folds growing-prefix String
  `append` calls in indexed `to-string`; its cold case already returns the
  stored source directly. `examples/aloemacs/file.aloe` already saves through
  `to-string` and requires no flow change.

## Exact file scope

### May create or edit

- `aloe/eval.rkt` — only the String `joined-with` runtime send, validation of
  its Aloe List and String arguments, and direct flattening of their existing
  vectors.
- `aloe/type.rkt` — only String `joined-with` send typing, arity, and argument
  checks.
- `aloe/signature-catalog.rkt` — one ordered String kernel row.
- `lib/text.aloe` — only the indexed branch of `Text.to-string`.
- `SPEC.md` §7.5 — document this new kernel send.
- `tests/string-load-save/001-indexed-to-string.rkt` — new focused tests.
- `tests/string-load-save/timing.rkt` — extend the existing no-TTY script
  with intervals 2 and 3; retain interval 1.
- `tests/string-load-save/000-split-lines.rkt`, `tests/checkpoint-114.rkt`,
  `tests/checkpoint-115.rkt`, and
  `tests/aloemacs/000-string-prerequisite.rkt` — only the ordered String row,
  count, and exact-row fixture changes caused by the new kernel row. Preserve
  their split, `starts-with?`, and earlier String behavior assertions.
- `tests/editor/signatures-of-type/000-shared-catalog.rkt`,
  `tests/editor/completion/001-contextual-receiver.rkt`,
  `tests/editor/completion/002-public-query.rkt`,
  `tests/editor/expression-query/001-contextual-observation.rkt`, and
  `tests/editor/expression-query/003-public-query.rkt` — only the same String
  row fixture maintenance. Preserve unrelated rows and assertions.

If the full suite reveals another exact String row fixture, adjust only that
fixture to add the real row; report the extra file in the implementation
summary. `tests/editor/signatures-of-type/001-kernel-query.rkt` consumes the
shared catalog directly and should pass without an edit.

### Must leave untouched

- `lib/string.aloe`, `lib/list.aloe`, every other library, and other methods
  in `lib/text.aloe`, including `lines`, `indexed-value`, focus, and replace.
- `examples/aloemacs/`, Gel, Term, Fs host, editor production modules,
  parser/class-method machinery, and `CHECKPOINTS.md`.
- The accepted spec, this series' charter, and the implementation of
  `split-lines`, `append`, `take`, `drop`, or the List representation.
- Behavioral goldens in existing aloemacs Text, File, and editor tests.

If another production file appears necessary, return the checkpoint for
review instead of widening its scope.

## Required String instance send

The exact Aloe spelling is:

```aloe
(separator joined-with above current below)
```

`separator` and `current` are `String`; `above` and `below` are
`(List String)` in that argument order. The result is `String`. This is a
String **instance** kernel message, not `(String join ...)`, a generic List
join, a new class method, or a new Aloe form. The selector `join` remains
unused. The checker requires exactly three arguments of those types and
rejects a non-String receiver. Raw runtime dispatch checks arity, checks
that both list arguments are Aloe Lists containing only Strings, and checks
that `current` is a String. Empty Aloe Lists whose element type remains
unresolved are valid on either side. `Mirror.invoke` validates the owned
signature and runs this exact row.

The result joins the document-order sequence
`reverse(above), current, below` with exactly the receiver String between
adjacent pieces. `above` holds its nearest predecessor first, so traverse
its existing vector from last element to first; traverse `below` from first
to last. `current` is always one piece, even when empty. An empty side adds
no piece and no separator. Both sides empty yield `current`. An empty
separator concatenates. Empty String pieces retain their surrounding
separators; a final empty `below` piece produces a trailing separator. The
primitive does not treat LF, CR, BOM, or Unicode specially.

Illustrative direct sends, with `|` as separator:

| `above` | `current` | `below` | Result |
|---|---|---|---|
| `(List empty)` | `"c"` | `(List empty)` | `"c"` |
| `(List of "b" "a")` | `"c"` | `(List empty)` | `"a|b|c"` |
| `(List empty)` | `"c"` | `(List of "d" "e")` | `"c|d|e"` |
| `(List of "b" "a")` | `"c"` | `(List of "d" "e")` | `"a|b|c|d|e"` |
| `(List of "a")` | `""` | `(List of "b")` | `"a||b"` |
| `(List empty)` | `"c"` | `(List of "d" "")` | `"c|d|"` |

The host counts the characters in the pieces and separators, allocates one
result String of the exact length, and copies in document order. With `N`
characters across pieces, `P` pieces including `current`, and separator
length `S`, work is O(`N + P*S`) and output length is
`N + (P - 1)*S`. Traverse the existing Aloe List vectors directly. Do not
build a List of all lines, use Aloe List sends, or copy a growing prefix.
No mutable builder or state is exposed to Aloe; inputs remain unchanged.

Append this row after `split-lines` in the shared String instance catalog:

```text
=            : (String) -> Bool
append       : (String) -> String
len          : ()       -> Int
take         : (Int)    -> String
drop         : (Int)    -> String
split-lines  : ()       -> (List String)
joined-with  : ((List String), String, (List String)) -> String
```

Default reflection appends `starts-with? : (String) -> Bool` after these
seven kernel rows. `Mirror.messages`, `Mirror.signatures`, exact-row
`Mirror.invoke`, and editor signature queries preserve that order. The
String class object still has no `join` or `joined-with` row. Add the send,
zipper order, and empty-side rules to `SPEC.md` §7.5 without changing other
language sections.

## Text use and tests first

Change only the indexed clause of `Text.to-string` to send exactly:

```aloe
("\n" joined-with above current below)
```

The cold `from-string` clause returns `stored-source` directly. The indexed
clause does not send `lines`, `reverse`, `fold`, `cons`, or `rest`, or use a
growing-prefix `append` loop. It adds no Text field, helper, or public
message. `Text.lines` keeps its current reconstruction behavior.

Write `tests/string-load-save/001-indexed-to-string.rkt` first and observe it
fail for the missing kernel send. Through the checked driver, prove the
direct-send table, an empty separator, non-LF separators, empty pieces on
both sides, a final empty element, and exact checked result type `String`.
Test zero, two, and four explicit arguments, a non-String separator or
`current`, and Int or other non-String elements in either List. Repeat the
invalid argument and arity checks in a raw runtime environment. Confirm raw
empty unresolved Aloe Lists succeed. Test the seven kernel signatures and
eight default reflection rows in order, including parameter and return
types, `Mirror.invoke` of the actual `joined-with` row, and the absence of a
class-object join row.

For `Text`, exercise a cold `from-string` value and indexed values at focus
0, a middle line, and the last line. For **every valid focus** of fixtures
with empty source, internal/repeated/final LF, multiple trailing LFs, CRLF,
BOM, and Unicode, `(text to-string)` equals the exact source. Check the
result type `String` and verify the cold clause returns its stored source
directly while the indexed clause is exactly the send above. A parsed-method
or source-shape assertion may establish the two clause boundaries; result
equality alone does not prove the indexed path avoids `lines`.

Retain existing round-trip and replacement goldens in
`tests/aloemacs/index-000-text-focus.rkt` and the File visit/save goldens in
`tests/aloemacs/file-session.rkt`. Those suites are regressions to run, not
files to edit. Do not modify `examples/aloemacs/`.

## Timing, verification, and acceptance

Extend `tests/string-load-save/timing.rkt` under its existing `module+ main`
to report all three intervals separately. Preserve the 10,000-line,
19,999-character source and interval 1 measurement. Initialize the driver
and load `lib/text.aloe` before any interval. Reuse the focus-0 indexed Text
created for interval 1, and build an indexed Text focused at line 9,999 with
`focus-at` **outside interval 3**. Time only `to-string` for each indexed
value:

| Interval | Required elapsed time on this machine |
|---|---:|
| 2 — focus 0 indexed `to-string` | below 0.029 s |
| 3 — focus 9,999 indexed `to-string` | below 0.029 s |

After each timed call, assert the exact original source result and the
expected focus. Check that both receivers are indexed, so neither interval
passes via the cold shortcut. Report seconds; keep thresholds in `module+
main`, outside ordinary `raco test tests`. If either threshold fails, return
the result to the design discussion instead of adding a new collection or
editor feature.

From the project root, run:

```sh
raco test tests/string-load-save/001-indexed-to-string.rkt
raco test tests/string-load-save/000-split-lines.rkt tests/aloemacs/000-string-prerequisite.rkt
raco test tests/aloemacs/index-000-text-focus.rkt tests/aloemacs/file-session.rkt
raco test tests/checkpoint-114.rkt tests/checkpoint-115.rkt
raco test tests/editor/signatures-of-type
raco test tests/editor
raco test tests
racket tests/string-load-save/timing.rkt
git diff --check
```

If Racket tries to write under the read-only `/var/tmp`, prefix the affected
test or timing command with `TMPDIR=/tmp`. Run one checked direct send by
hand, such as `("\n" joined-with (List of "b" "a") "c"
(List of "d" ""))`, and confirm `"a\nb\nc\nd\n"`.

This checkpoint is complete when `joined-with` obeys its typing, runtime,
order, empty-piece, and linear-copy contracts; cold and indexed Text round
trips retain exact strings at every focus; reflection and editor queries
show the new shared row; all focused and full suites pass; and intervals 2
and 3 both meet the bar. Stop for human review. Do not start another
checkpoint, editor feature, List change, or Boids work.
