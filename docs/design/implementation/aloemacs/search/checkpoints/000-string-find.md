# aloemacs-search 000 — String find

**Status.** Ready to implement.

## Goal

Add the checked String instance send `(haystack find pattern start)` returning
`(Option Int)`, expose its exact reflected signature, and measure it against a
drop-based search. Stop when this kernel slice and its tests pass. Search keys,
session state, the echo row, and editor point movement belong to a later
checkpoint.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-search 000**, the first local checkpoint of the
  **aloemacs-search** series. There is no earlier search checkpoint. The
  aloemacs File, Echo, Safe cells, Index, Viewport, and Undo layers, the
  string-load-save series, and the Term save/undo/escape keys are in place.
- The accepted spec's §§1–3 and §5 govern this slice. [`SPEC.md`](../../../../../../SPEC.md)
  governs Aloe syntax, checking, constructors, and message sends; this
  checkpoint amends its §7.5 String API as the accepted spec directs.
  Evaluation is send: the head is the receiver and the second element is a
  literal selector.
- The project root for code, tests, and commands is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. The String kernel
  branches are in `aloe/eval.rkt` and `aloe/type.rkt`. The ordered String
  instance signatures are in `aloe/signature-catalog.rkt`; the Aloe-defined
  `starts-with?` remains in `lib/string.aloe`.
- `(Option T)` is the existing Aloe class in `lib/option.aloe`, loaded by the
  editor through `lib/text.aloe`. Focused standalone checked and raw tests
  should load that class before asking for a `find` result. `find` returns an
  ordinary `Option` instance, not a new host representation.

## Exact file scope

### May edit or create

- `SPEC.md` — add the `find` row immediately after `joined-with` in §7.5.
- `aloe/eval.rkt` — implement String `find` with runtime arity and argument
  guards and an in-place character comparison.
- `aloe/type.rkt` — infer and check `(Option Int)` for the String send.
- `aloe/signature-catalog.rkt` — add the String instance signature after
  `joined-with`.
- `tests/aloemacs/search-find.rkt` (new) — checked, raw, and reflection tests.
- `tests/aloemacs/search-timing.rkt` (new) — no-TTY timing script with its
  measured work in `module+ main`.
- Only to add the new row or adjust exact String row counts/positions while
  preserving unrelated assertions:
  `tests/aloemacs/000-string-prerequisite.rkt`,
  `tests/string-load-save/000-split-lines.rkt`,
  `tests/string-load-save/001-indexed-to-string.rkt`,
  `tests/checkpoint-114.rkt`, `tests/checkpoint-115.rkt`,
  `tests/editor/signatures-of-type/000-shared-catalog.rkt`,
  `tests/editor/completion/001-contextual-receiver.rkt`,
  `tests/editor/completion/002-public-query.rkt`,
  `tests/editor/expression-query/001-contextual-observation.rkt`, and
  `tests/editor/expression-query/003-public-query.rkt`.

### Must leave untouched

- `examples/aloemacs/`, `host/racket/term.rkt`, the runner, `lib/string.aloe`,
  `lib/option.aloe`, `lib/text.aloe`, and the other language libraries.
- `CHECKPOINTS.md`, global checkpoints, the Term interface, other language
  APIs, and all other product and design files.
- The behavior and assertions unrelated to String row enumeration in the
  existing test fixtures. In particular, do not weaken their Mirror or
  `starts-with?` checks.

If another file is necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Required behavior

The new String instance message is:

```aloe
(haystack find pattern start) ; (Option Int)
```

`haystack` and `pattern` are `String`; `start` is `Int`. Find the least
Racket-character index at or after `max(start, 0)` where the entire literal,
case-sensitive pattern matches. A nonempty pattern with no eligible match
returns `(Option None)`. An empty pattern returns `(Option Some i)` where `i`
is `start` clamped to `0..(haystack len)` inclusive. In particular,
`("abc" find "" 99)` is `Some(3)`, `("abc" find "" -2)` is `Some(0)`,
`("abcabc" find "bc" 2)` is `Some(4)`, and
`("abcabc" find "bc" 5)` is `None`. Indexes use String `len`/`take`/`drop`
character units, including for Unicode input.

The checker requires exactly two arguments, a String pattern, and an Int
start, with no Int/Float coercion, and returns `(Option Int)`. Checked sends
to a non-String receiver fail type checking. Raw evaluation rejects bad
arity and argument types; a raw send to a non-String receiver is an unknown
message. Construct `Some` or `None` using the existing loaded `Option` class.

The implementation scans candidate character indexes forward. Compare the
pattern against the haystack at each candidate without allocating a candidate
substring or copying a suffix. Do not send `drop` per candidate. A successive
comparison may revisit characters; no new matching data structure is needed.

The ordered String instance catalog gains exactly one
`(String Int) -> (Option Int)` signature after `joined-with`. A String
instance's Mirror selector and signature lists show `find` there, before the
Aloe-library `starts-with?` row. `(Mirror of String)` has no `find` row, and
the String class object has no `find` message. `Mirror.invoke` with the new
signature returns the same ordinary `Option` result. No other catalog row
changes.

## Focused tests

Write failing tests before product edits. Use the checked driver, raw
evaluator/checker where needed, and no physical TTY. In
`tests/aloemacs/search-find.rkt`, prove:

1. Checked result type is `(Option Int)` and exact `Some`/`None` values are
   produced. Cover first match, overlapping candidates, nonzero and negative
   starts, starts beyond the last possible match, empty haystack, empty
   pattern, case sensitivity, and Unicode character indexes. Load
   `lib/option.aloe` in isolated environments as needed.
2. Checked sends reject bad arity, non-String receiver or pattern, and
   non-Int start. Raw sends reject the same invalid shapes through arity,
   argument, or unknown-message errors.
3. The exact String kernel catalog has the new row in position eight, and
   instance Mirror messages/signatures show it immediately before
   `starts-with?`. Verify the row's selector, two parameter types, return
   type, and `Mirror.invoke` result. Verify the String class object has no
   `find` row or send.

Update the ten named exact-row fixtures only where their String selector,
signature, length, completion-item, or positional expectations require the
insertion. Preserve ordering, source positions, freshness, overload
multiplicity, and method visibility assertions. Run the
existing `tests/editor/signatures-of-type/001-kernel-query.rkt` consumer
unchanged as part of the full suite.

## Standalone no-TTY timing

`tests/aloemacs/search-timing.rkt` constructs one haystack of at least 20,000
characters outside every measured interval. Use a pattern at least two
characters long whose only match starts at the final eligible index, plus
an absent pattern of the same length. For both hit and miss, time the new
`find` send and a slow reference on that same haystack. The slow reference
must, at every candidate index, send `drop` and then `starts-with?` on the
tail. Construct inputs and load `Option` and String methods before timing.

Repeat the measurements. Print the measured seconds for each fast and slow
interval and `slow/fast` for the hit and for the miss. Both ratios must be at
least **50×** on this machine. Timed work belongs in `module+ main`, so the
full `raco test tests` run does not impose a timing gate. Inspect the product
source independently to confirm it does not copy a tail or candidate
substring at each index; the ratio alone does not prove this property.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test tests/aloemacs/search-find.rkt
TMPDIR=/tmp raco test tests/aloemacs/000-string-prerequisite.rkt tests/string-load-save/000-split-lines.rkt tests/string-load-save/001-indexed-to-string.rkt tests/checkpoint-114.rkt tests/checkpoint-115.rkt tests/editor/signatures-of-type/000-shared-catalog.rkt
TMPDIR=/tmp raco test tests/editor/completion/001-contextual-receiver.rkt tests/editor/completion/002-public-query.rkt tests/editor/expression-query/001-contextual-observation.rkt tests/editor/expression-query/003-public-query.rkt
TMPDIR=/tmp raco test tests
TMPDIR=/tmp racket tests/aloemacs/search-timing.rkt
git diff --check
```

The checkpoint is complete when the focused tests, exact-row regressions,
and full repository suite pass; both timing ratios meet 50×; and source
inspection confirms the no-copied-tail scan. Report changed files, test
results, and both measured fast/slow seconds and ratios. Then stop for human
review. Do not issue or implement aloemacs-search 001.

## Explicit non-goals

- Ctrl-F mapping, session search state, point movement, wrap/failure display,
  or any editor or Term change.
- Reverse search, case folding, regular expressions, replacement, match
  highlighting, or a query cursor.
- New constructors, Option representations, special forms, mutation,
  inheritance, implicit numeric coercion, or a global checkpoint number.
