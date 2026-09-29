# string-load-save specification

**Status: Accepted.** This is the complete design input for the
later checkpoint manager and implementers. The charter and design conversation
are not required in those conversations. Aloe syntax, evaluation, types, and
immutability remain governed by [`SPEC.md`](../../../../SPEC.md). This series
updates its String section as the kernel messages land. The aloemacs Text and
Index specifications continue to govern values and round-trips; this spec
changes the cost and implementation location of `split-lines` and the cost of
indexed `to-string`.

## 1. Checkpoint series and authority

The identity is `string-load-save`. Its first checkpoint is spoken
**string-load-save 000** and filed under
`docs/design/implementation/string-load-save/checkpoints/000-slug.md`.
Numbers start at 000, use three digits, and are never renumbered. The manager
writes one checkpoint and stops. Each implementer completes only that
checkpoint, adds its tests, runs verification, and stops for human review.
No number is taken from `CHECKPOINTS.md` or `docs/checkpoints/` unless a human
later promotes the work.

Implement these layers in order:

1. **000 — Linear `String.split-lines`.** Move this exact public send from
   Aloe recursion to the String kernel. Make visit's `indexed-value` cheap.
2. **001 — Linear indexed `Text.to-string`.** Add the String kernel
   `joined-with` send over the three zipper fields and use it in indexed
   `to-string`. Make save cheap at focus 0 and at the last line.

Each layer is one meaningful, independently testable checkpoint. A manager
may split a layer if it cannot fit one implementer conversation, but must
keep this order and add no features. The predecessors are global checkpoints
114 and 115, aloemacs-text 000, and the implemented aloemacs Text, File, and
Index layers. The project root for code and tests is
`/home/dharmatech/journal/2026-09-02-aloe-racket`, not this design folder.

## 2. Product boundary

The public sends remain `(s split-lines)` and `(text to-string)`. Visit
already sends `indexed-value` to a cold `Text`; save already sends `to-string`
to its current `Text`. Neither flow needs a new call site or control path.
The exact source content represented as an Aloe String, the LF-only line
policy, immutable Text values, and all existing editor behavior remain the
same. Only LF (`"\n"`) separates pieces. CR, BOM, and Unicode characters
are ordinary content and are never normalized. String positions use the same
character units as `len`, `take`, and `drop`, not encoded UTF-8 bytes.

The cold `Text.from-string` branch of `to-string` returns its stored source
directly, in O(1) time in the source length. The indexed branch reads the
existing `above`, `current`, and `below` fields without changing their
representation or the public `Text.lines` send. `Text.lines` may retain its
existing reconstruction cost; it is not on the indexed save path.

There are no class methods, mutable Aloe builders, Vector, new String
representation, generic List concatenation, List spine changes, parser
forms, or changes to `append`, `take`, or `drop`. Do not retune Index motion,
`next-lines`, Gel/frame string folds, visit/save policy, or the editor. Echo,
minibuffer, safe control-character display, windows, and Boids are outside
this series. No `examples/aloemacs/` edit is expected: `visited` already
indexes and `save` already uses `to-string`.

## 3. Host, layout, and commands

The interpreter and checker are Racket; library and Text methods are Aloe.
Use the existing checked driver (`aloe/driver.rkt`) for functional tests.
The implementation is confined to these seams:

| Path | Permitted change |
|---|---|
| `aloe/eval.rkt` | Runtime String kernel sends and typed Aloe List result |
| `aloe/type.rkt` | Static signatures, arity, and argument checking for those sends |
| `aloe/signature-catalog.rkt` | Ordered kernel String rows for reflection and editor queries |
| `lib/string.aloe` | Remove only the superseded Aloe `split-lines`; retain `starts-with?` |
| `lib/text.aloe` | Change only indexed `to-string` to the new send |
| `SPEC.md` §7.5 | Document the actual String kernel, including predecessor `drop` |
| `tests/string-load-save/` | Focused functional tests and the no-TTY timing script |

Surgical updates to existing String reflection, catalog, and editor signature
fixtures are allowed when their expected rows or old implementation-location
assertions become obsolete. Preserve unrelated assertions and behavior. Do
not edit `lib/list.aloe`, Gel, Term, Fs host, `examples/aloemacs/`,
`CHECKPOINTS.md`, or parser/class-method machinery.

From the project root, focused tests use `raco test` on their named files.
The existing integration suites use `raco test tests/aloemacs`,
`raco test tests/editor`, and `raco test tests`. The timing script runs with
`racket tests/string-load-save/timing.rkt`; if this machine needs its known
temporary-directory setting, run it as
`TMPDIR=/tmp racket tests/string-load-save/timing.rkt`. Timing is a no-TTY
hand check in `module+ main`, not a CI timeout.

## 4. Layer 000 — kernel `split-lines`

### Contract and implementation seam

`(s split-lines)` has zero arguments and returns a nonempty `(List String)`.
It splits the String receiver at every LF and retains every empty piece,
including the final piece after a trailing LF:

| `s` | Result |
|---|---|
| `""` | `(List of "")` |
| `"ab"` | `(List of "ab")` |
| `"ab\ncd"` | `(List of "ab" "cd")` |
| `"ab\n"` | `(List of "ab" "")` |
| `"\n"` | `(List of "" "")` |
| `"a\r\nb"` | `(List of "a\r" "b")` |

Choose kernel `split-lines`, rather than a suffix view: it keeps the current
String representation and API and makes the irreducible scan linear. The
runtime scans the receiver once, takes one substring for each piece, and
constructs an ordinary Aloe `List` with element type `String` in source
order. It does not call Aloe `drop`, `take`, `append`, `cons`, or a recursive
String method per character or per line. With `N` source characters and `P`
pieces, its work and retained result size are O(`N + P`). The checker and raw
runtime reject extra arguments; non-String receivers have no `split-lines`
send. This is a String instance kernel message, not a String class send.

The String kernel catalog order after 000 is exactly:

```text
=            : (String) -> Bool
append       : (String) -> String
len          : ()       -> Int
take         : (Int)    -> String
drop         : (Int)    -> String
split-lines  : ()       -> (List String)
```

`starts-with? : (String) -> Bool` remains the sole Aloe method in
`lib/string.aloe`, follows the six kernel rows in default reflection, and
retains its current body and behavior. Raw runtime/checker environments now
know `split-lines` without bootstrapping the String library; they still do
not know `starts-with?` until that library is installed. The `String` class
object still has no construction or join rows. `Mirror.messages`,
`Mirror.signatures`, and exact-row `Mirror.invoke` must agree with dispatch.

### Tests and files

Write `tests/string-load-save/000-split-lines.rkt` first. It checks the
table, leading and repeated LFs, Unicode, exact `(List String)` checked
type, arity errors in checked and raw evaluation, `(3 split-lines)` as a
type error, and kernel reflection plus exact-row invocation. Keep the
existing `tests/aloemacs/000-string-prerequisite.rkt` split goldens green.
Then add the kernel implementation, remove only the Aloe `split-lines` body,
and update `SPEC.md` §7.5 to list `drop` and `split-lines` with their existing
and new contracts.

Historical tests with known obsolete assumptions include
`tests/checkpoint-114.rkt`, `tests/checkpoint-115.rkt`,
`tests/aloemacs/000-string-prerequisite.rkt`, and
`tests/editor/signatures-of-type/000-shared-catalog.rkt`. Their exact-source,
raw-bootstrap, kernel-vs-Aloe, row-position, and row-count assertions must be
updated narrowly. Ordered String fixtures in
`tests/editor/completion/002-public-query.rkt` and
`tests/editor/expression-query/003-public-query.rkt` also put `split-lines`
before `starts-with?`. The kernel String row fixtures in
`tests/editor/completion/001-contextual-receiver.rkt` and
`tests/editor/expression-query/001-contextual-observation.rkt` gain the new
row. `tests/editor/signatures-of-type/001-kernel-query.rkt` consumes the
catalog directly and should keep passing without a fixture edit. No editor
implementation changes.

This checkpoint is complete when focused tests, predecessor String tests,
aloemacs tests, editor signature tests, and the full suite pass, and timing
interval 1 in §6 meets its bar. Stop before adding `joined-with`.

## 5. Layer 001 — kernel zipper flatten and indexed `to-string`

### New String instance send

The selector is `joined-with`, leaving `join` free for a possible future
String class method. Its Aloe spelling is:

```aloe
(separator joined-with above current below)
```

The `String` receiver is the separator. The three explicit arguments have
types `(List String)`, `String`, and `(List String)`, in that order; the
result is `String`. There is no generic `(List String)` join or class-side
`(String join ...)`. The checker requires exactly three arguments of those
types. Raw runtime dispatch checks arity, both arguments are Aloe Lists of
String elements (including empty Lists whose element type is unresolved),
and `current` is a String. A non-String separator is a non-String receiver
and therefore a type error in checked Aloe. `Mirror.invoke` validates the
same signature and invokes the owned kernel row.

The result is the document-order sequence of pieces, separated by exactly
the receiver String:

```text
reverse(above), current, below
```

`above` stores its nearest predecessor first, so the kernel traverses its
existing List vector from the last element to the first. It then copies
`current`, then traverses `below` from the first element to the last. Empty
`above` or `below` contributes no pieces and no separator. `current` is
always one piece, even when it is `""`. Both lists empty yield `current`.
An empty separator concatenates the pieces in the same order. Empty String
elements are real pieces and preserve their adjacent separators; a final
empty `below` element produces a trailing separator. No LF or CR receives
special treatment inside this primitive: `to-string` passes `"\n"` as the
separator.

The host determines the exact result length from the existing pieces and
separator count, then makes one result String and copies the pieces in that
order. It traverses the two List vectors directly, without Aloe List sends
or rebuilding `lines`. With `N` total characters in the pieces, `P` pieces,
and separator length `S`, work is O(`N + P*S`) and output size is
`N + (P - 1)*S`. No mutable builder or state is exposed to Aloe. Input
Strings, Lists, and Text remain immutable.

The kernel catalog order after 001 is exactly:

```text
=            : (String) -> Bool
append       : (String) -> String
len          : ()       -> Int
take         : (Int)    -> String
drop         : (Int)    -> String
split-lines  : ()       -> (List String)
joined-with  : ((List String), String, (List String)) -> String
```

Default reflection then appends the Aloe `starts-with?` row. `Mirror` rows
and editor signature queries show that order; `String` the class object
still has no `join` or `joined-with` row. Add `joined-with` to `SPEC.md`
§7.5 in this checkpoint, including the zipper order and empty-list rules.

### Text use and tests

Only the indexed branch of `Text.to-string` changes. In the existing `case`
binders, it sends exactly:

```aloe
("\n" joined-with above current below)
```

The cold branch still returns `stored-source` directly. The indexed branch
must not send `lines`, `reverse`, `fold`, `cons`, or `rest`; it does not copy
the source through a growing-prefix `append` loop. It adds no Text fields or
public messages. `Text.lines`, `indexed-value`, focus, and replacement
remain as they are.

Write `tests/string-load-save/001-indexed-to-string.rkt` first. Exercise
`joined-with` directly with both lists empty, only `above`, only `below`,
many pieces on both sides, empty separator, empty `current`, and empty
pieces including a final empty element. Assert exact checked result type,
wrong arity, non-String separator/current, non-String List elements, raw
runtime rejection, signature order, and exact-row `Mirror.invoke`. Exercise
cold and indexed Text values at focus 0, middle, and last line; for every
valid focus, `to-string` equals the original source for empty, internal
empty, repeated/final LF, CRLF, BOM, and Unicode fixtures. Assert the cold
branch does not send the new primitive and indexed `to-string` does not
rebuild `lines`.

Surgically shift row counts and positions in the historical String catalog,
reflection, and editor signature fixtures named in layer 000, plus any
other exact String row fixtures the full suite reveals. Retain their
unrelated assertions. The existing aloemacs File visit/save and Index
round-trip tests must pass without changing `examples/aloemacs/`.

This checkpoint is complete when focused tests and the full suite pass,
intervals 2 and 3 in §6 both meet their bars, and no `List` or editor flow
has changed. Stop before adjacent editor work.

## 6. Verification and timing

Automated checked and raw tests prove the contracts above. Reflection tests
prove ordered signatures and exact-row invocation. Existing
`tests/aloemacs/000-string-prerequisite.rkt`,
`tests/aloemacs/index-000-text-focus.rkt`, File visit/save tests, and editor
signature tests retain the earlier results. Each layer starts with its new
focused test, observes it fail for the missing kernel behavior, implements
the layer, then runs its named tests and the full `raco test tests` suite.
Use `git diff --check` after changes. Do not weaken unrelated assertions.

The no-TTY `tests/string-load-save/timing.rkt` has `module+ main`, so the
ordinary `raco test tests` run does not impose wall-clock thresholds. Its
fixture is 9,999 repetitions of `"x\n"` followed by `"x"`: exactly 10,000
one-character lines and 19,999 source characters. Initialize the driver
and load `lib/text.aloe` outside all intervals. Time and report separately:

| Interval | Timed operation | Required time on this machine |
|---|---|---:|
| 1 | `(Text from-string source)` then `indexed-value` | below 0.110 s |
| 2 | `to-string` of that focus-0 indexed value | below 0.029 s |
| 3 | `to-string` of an indexed value focused at line 9,999 | below 0.029 s |

Build the last-line value with `focus-at` outside interval 3. Check that
each result has the expected focus and exact source String, so no empty or
cold shortcut passes. Report elapsed seconds; these are review-time hand
bars, not CI timeouts. Each threshold is more than 50 times below its
predecessor floor (about 5.6 s split and 1.5 s focus-0 indexed join).
Interval 1 belongs to 000; intervals 2 and 3 belong to 001. If a threshold
fails, return the result to the design discussion rather than expanding the
checkpoint into a new collection or editor feature.

## 7. Acceptance and stop

The series is accepted when `split-lines` returns exactly the old LF pieces
as a typed, linear kernel send; cold `to-string` returns its stored source;
indexed `to-string` directly flattens the zipper through one typed kernel
send in linear output work at every focus; visit and save still round-trip
exact strings; all focused and predecessor suites pass; and all three 10k
timing intervals meet §6. `SPEC.md` §7.5 and the shared String catalog must
describe the resulting machine and reflection order.

The checkpoint manager writes only the next missing number after human
acceptance of this draft. Each implementer tests and stops at its assigned
number. This spec does not authorize echo, safe-cell display, a List
representation change, or global checkpoint 116.
