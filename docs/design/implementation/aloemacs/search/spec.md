# aloemacs search specification

**Status: Accepted.** This is the complete design input for the
aloemacs-search checkpoint manager and implementers. The
charter and design conversation are not required in those conversations.
`SPEC.md` governs Aloe; checkpoint 000 amends its String section. The rest of
this file specifies the editor application.

## 1. Series, authority, and stop points

The identity is **aloemacs-search**. The first checkpoint is spoken
**aloemacs-search 000** and filed as
`docs/design/implementation/aloemacs/search/checkpoints/000-string-find.md`.
The second is **aloemacs-search 001**. Numbers are three digits, start at
000, and are never renumbered. The manager writes only the next checkpoint,
then stops. An implementer completes only that checkpoint, adds its tests,
runs verification, then stops for human review. A manager may split a layer
that proves too large, preserving this order and adding no feature. This
series takes no `CHECKPOINTS.md` number unless a human later promotes it.

| Order | Independently testable result |
|---|---|
| 000 | One String kernel `find` send, its checked and reflected signature, and the timing bar. No editor or Term change. |
| 001 | Plain Ctrl-F, incremental query and echo row, point movement, wrap, failure, and restoration. Uses `find`; adds no kernel send. |

Predecessors are the implemented aloemacs File, Echo, Safe cells, Index,
Viewport, and Undo layers, the accepted `string-load-save` series, and the
Term `"save"`, `"undo"`, and `"escape"` keys. The parent
[`README.md`](../README.md) maps these projects.
[`../file/spec.md`](../file/spec.md) governs visit/save and the session;
[`../echo/spec.md`](../echo/spec.md) governs its row and cursor composition;
[`../safe-cells/spec.md`](../safe-cells/spec.md) governs clipped display;
[`../../string-load-save/spec.md`](../../string-load-save/spec.md) governs
`split-lines` and `joined-with`. The current `examples/aloemacs/` sources
are the implementation starting point. `SPEC.md` wins on language behavior.

## 2. Product boundary and host

In the terminal editor, plain Ctrl-F enters a forward search. The user types
and edits a literal query on the existing echo row. Each edit seeks from the
point where this search began; another Ctrl-F seeks the next occurrence.
Matches move the editor point without changing text or undo history. Escape
and Return accept the current point and restore the prior idle echo token.
Ctrl-S continues to save.

The interpreter, checker, and Term adapter are Racket. The session and editor
are Aloe. Work is rooted at
`/home/dharmatech/journal/2026-09-02-aloe-racket`; code and tests do not go
in this design folder. Functional tests use the checked driver and no
physical TTY. On this machine, run Racket tests with `TMPDIR=/tmp`:

```text
TMPDIR=/tmp raco test tests/aloemacs/search-find.rkt
TMPDIR=/tmp racket tests/aloemacs/search-timing.rkt
TMPDIR=/tmp raco test tests/aloemacs/search-session.rkt tests/aloemacs/search-key-mapping.rkt
TMPDIR=/tmp raco test tests/aloemacs
TMPDIR=/tmp raco test tests
```

The timing script uses `module+ main` and is excluded from ordinary
`raco test tests` timing gates. The existing interactive runner remains
`racket host/racket/aloemacs-run.rkt [path]`; no runner protocol changes.

Non-goals are reverse search, case folding, regular expressions, replace,
match highlighting, a minibuffer or query cursor, remembered queries, keymap
data, prefix commands, new motion commands, and any Text, safe-cells,
`split-lines`, `joined-with`, or Ctrl-S redesign. There is no mutation,
inheritance, macro, new special form, or implicit Int/Float conversion.

## 3. Layer 000: String `find`

Add exactly this instance message after `joined-with` in `SPEC.md` §7.5 and
the ordered String kernel catalog:

```aloe
(haystack find pattern start) ; (Option Int)
```

`haystack` and `pattern` are `String`; `start` is `Int`. The result is the
least character index `i >= start` whose pattern-length substring equals
`pattern`. The comparison is case-sensitive and literal. Negative `start`
acts as zero. A nonempty pattern with no match, including a start past the
last possible start index, returns `(Option None)`. An empty pattern returns
`(Option Some i)`, with `i` clamped to `0..(haystack len)` inclusive. Thus
`("abc" find "" 99)` is `Some(3)` and `("abc" find "" -2)` is `Some(0)`.
Indexes use the same Racket character units as String `len`, `take`, and
`drop`, not UTF-8 bytes. `"abcabc" find "bc" 2` is `Some(4)`;
`"abcabc" find "bc" 5` is `None`.

The checker, evaluator, and signature catalog change together in
`aloe/type.rkt`, `aloe/eval.rkt`, and `aloe/signature-catalog.rkt`. The
signature is `(String Int) -> (Option Int)` on a String instance. A bad
arity, non-String receiver or pattern, or non-Int start is a type error in
checked code and rejected by raw runtime guards. There is no Int/Float
coercion. The class object gains no `find` row. Reflection lists `find`
immediately after `joined-with` and before Aloe-library `starts-with?`.
The library method stays in `lib/string.aloe`.

Implement one forward scan over character indexes, comparing in place
without allocating a candidate substring. It must not call `drop` once per
candidate or allocate a copied suffix per character. A pattern may be
compared at successive candidate indexes; there is no requirement for a
new pattern-matching data structure.

`tests/aloemacs/search-find.rkt` proves checked result type, exact `Some`
and `None` values, first-match selection, overlapping candidates, nonzero
and negative starts, past-end starts, empty haystack and pattern, Unicode
character indexes, case sensitivity, errors, and exact catalog/Mirror row
order and invocation. Existing exact String-row fixtures in
`tests/aloemacs/000-string-prerequisite.rkt`,
`tests/string-load-save/000-split-lines.rkt`,
`tests/string-load-save/001-indexed-to-string.rkt`,
`tests/checkpoint-114.rkt`, `tests/checkpoint-115.rkt`, and
`tests/editor/signatures-of-type/000-shared-catalog.rkt`, plus
`tests/editor/completion/001-contextual-receiver.rkt`,
`tests/editor/completion/002-public-query.rkt`,
`tests/editor/expression-query/001-contextual-observation.rkt`, and
`tests/editor/expression-query/003-public-query.rkt` gain the one row
where they enumerate kernel selectors, signatures, completion items, or
positional reflection rows. Preserve unrelated assertions, including
ordering, source positions, freshness, overload multiplicity, and method
visibility. Catalog consumers such as
`tests/editor/signatures-of-type/001-kernel-query.rkt` should continue to
pass without weakened checks.

`tests/aloemacs/search-timing.rkt` constructs one haystack of at least
20,000 characters outside every measured interval. It times a pattern of
length at least two whose only match begins at the end, and an absent
pattern of the same length. For each case the same script times a slow
reference that, at every candidate index, sends `drop` and then
`starts-with?` on the resulting tail. Use repeat measurements and report
the measured seconds for each fast and slow interval, plus `slow/fast`.
The hit and the miss must each have `slow/fast >= 50` on this machine.
The implementation's no-copied-tail property is independently reviewed;
beating a needlessly costly reference alone is insufficient. Actual seconds
are recorded from the implemented checkpoint's run, since no `find` timing
exists before checkpoint 000. The numeric acceptance bar is **50×** for
both intervals.

No `examples/aloemacs/`, `host/racket/term.rkt`, `CHECKPOINTS.md`, or
other language API changes belong in 000.

## 4. Layer 001: session search

### 4.1 State and reconstruction

`AloemacsSession` owns search. Extend its fields in
`examples/aloemacs/file.aloe` after the existing `editor`, `fs`, `path`,
and `echo` with the following ordered fields:

| Field | Type | Idle default and role |
|---|---|---|
| `searching` | `Bool` | `#f`; whether keys are interpreted as search input. |
| `query` | `String` | `""`; current query, discarded on exit. |
| `origin` | `Position` | `(Position new 0 0)`; captured from editor point on entry. Idle value is unused. |
| `wrapped` | `Bool` | `#f`; current match came from the wrap pass. |
| `failing` | `Bool` | `#f`; most recent search attempt failed. |

The existing `echo` remains the stored idle token (`""`, `"saved"`, or
`"failed"`). Search never overwrites it merely to display a search row.
Every `AloemacsSession new` site, including `visited`, save outcomes,
`with-editor`, and the empty session in `main.aloe`, supplies these fields.
Ordinary rebuilds, including `ensure-visible`, preserve them exactly unless
the method deliberately changes search. New visits start idle with the
defaults above. The `AloemacsEditor` constructor and fields do not change.

The search move focuses the existing Text at the match line and sends the
existing `(editor with-text-and-point focused-text position)`. The rebuilt
editor retains its text content, quit flag, scroll origins, and exact undo
history. Search moves never call `from-edit` or push an undo frame. The
existing fit step makes the new point visible before framing.

### 4.2 Keys and transitions

In `host/racket/term.rkt`, a `tkeymsg` whose key is `#\f`, modifiers are
exactly `'(ctrl)`, and decoded character is `#f` or `#\f` maps to
`"find"` before printable fallbacks. This is the same plain-Ctrl rule as
Ctrl-S. Ctrl-Shift-F, Alt-F, and printable `f` retain their current paths.
Ctrl-S still maps to `"save"`, Ctrl-Z to `"undo"`, and Escape to
`"escape"`. This adds no Term method or keymap data structure.

`AloemacsSession.handle-key` remains absorbing when the nested editor has
quit. Otherwise use this transition table:

| State and key | Transition |
|---|---|
| Idle, `"find"` | Enter search; capture current point in `origin`, set empty `query`, clear `wrapped` and `failing`, retain `echo` and point. |
| Active, a length-one printable character including space | Append to `query`; search from `origin` inclusive. No buffer edit. |
| Active, `"backspace"` | Remove one final query character, if any; search afresh from `origin`. Empty query returns point to `origin` and shows the plain search prefix. |
| Active, `"find"` with empty query | Stay put. |
| Active, `"find"` with nonempty query and an unwrapped current match | Seek after the current match's start index on that same line. |
| Active, `"find"` after a wrapped match | Do not scan; retain point and set `failing`. |
| Active, `"find"` after a query miss | Do not scan; retain point and the `failing` row. |
| Active, `"escape"` or `"return"` | Exit search, retain point, restore stored `echo`; do not quit or insert newline. |
| Active, any other key | Exit search, then dispatch that key through today's idle session rule. Save saves; an arrow moves; undo undoes. |
| Idle, any other key | Today's session rule, including Ctrl-S save, non-save echo clearing, and Escape quit. |

Exiting search sets `searching = #f`, `query = ""`, `origin = (0,0)`,
`wrapped = #f`, and `failing = #f`. The `echo` token stays as it was for
Escape/Return. For a forwarded other key, the existing rule may replace it:
`"save"` becomes `"saved"` or `"failed"`; any other forwarded key clears
it to `""`. Direct `save` and direct editor commands retain their existing
semantics. `AloemacsEditor.handle-key` receives no `"find"` from normal
session dispatch; the session consumes it.

A query edit discards the prior match/failure status and searches from the
captured origin, not the last match. On a hit, point moves to the match and
`wrapped` reports whether that attempt wrapped. On a miss, point returns to
the origin, `wrapped` is false, and `failing` is true. A query edit can
recover from any failure. Backspacing an already empty query remains
empty at the origin. No query contains LF because only printable
length-one key strings enter it.

### 4.3 Ordered scan

For a query edit, the attempt's start point is `origin`; for Ctrl-F after an
unwrapped hit, it is `(current.line, current.column + 1)`. The attempt first
considers that start line at its start column, then later lines at column 0.
If none matches, it considers lines from line 0 to just before the start
line, then match starts strictly before the attempt's start column on the
start line. The second part is the one wrap pass. The first hit in that
order wins. The origin character is eligible for a query edit. Ctrl-F
after a match starts at `current.column + 1`, so an
overlapping match is eligible. A wrapped hit sets `wrapped = #t`; a later
Ctrl-F fails without returning to the first match. Search never matches
across a line break.

Each candidate line is searched with `String.find` at most once per attempt.
The start line needs both a suffix candidate and a deferred prefix
candidate. To honor the one-call limit, it may be searched as one temporary
String consisting of its suffix, an LF sentinel, and the prefix through
`start-column + query-length - 1` characters (clamped to the line length).
Because the query has no LF, a hit cannot cross the sentinel; a start-line
prefix hit is held until later and earlier lines have been considered.
A hit before the sentinel maps to `start-column + hit-index`; a hit after it
maps to `hit-index - suffix-length - 1`. The prefix includes matches that
start before the column but extend past it.
Equivalent single-call logic is allowed. Do not repeatedly `drop` and retry
on a line. A line's first `find` result is sufficient for its candidate
because `find` returns the least eligible index.

### 4.4 Echo row

For `rows >= 2`, `AloemacsSession.frame` chooses the row before clipping:

| Active state | Row before clipping |
|---|---|
| Query empty or unwrapped hit | `"search: " append query` |
| Wrapped hit | `"wrapped: " append query` |
| Failed attempt | `"failing: " append query` |

`failing` takes priority over `wrapped`. Inactive sessions use the
existing path / `saved: ` / `failed: ` row. The save token `"failed"`
is distinct from the search prefix `"failing: "`. The selected row is
clipped with `take columns`, then passed to the editor's `safe-cells` send
and inserted through the existing ANSI suffix. Search never changes the
buffer text, row allocation, or final text cursor. At `rows = 1`, no echo
row is drawn; search and point transitions still work.

### 4.5 Tests and file scope

`tests/aloemacs/search-key-mapping.rkt` proves both Ctrl-F message shapes,
unchanged Ctrl-S, and exclusion of printable/modified F. In a checked
driver with a filesystem double, `tests/aloemacs/search-session.rkt`
proves constructor defaults and preservation; query typing including
space; forward hit and overlapping next hit; wrap, including a match that
starts before the start column but extends past it; post-wrap failure,
ordinary miss, and recovery by edit; backspace and empty query; Escape and
Return acceptance; prior `"saved"` restoration without quit; an arrow,
Ctrl-S, and Ctrl-Z forwarded from search; idle Ctrl-S still saving; and
unchanged text and undo history throughout search motion. Compare exact
search row, clipping, safe-cells, and text cursor behavior without a TTY,
including a one-row frame. Keep the existing session and runner tests green.

Code for 001 is limited to `examples/aloemacs/file.aloe`,
`examples/aloemacs/main.aloe`, and `host/racket/term.rkt`. Existing
`tests/aloemacs/` constructor fixtures and frame goldens may change where
the new session fields require it. Search must use existing editor sends;
do not alter `examples/aloemacs/editor.aloe`, `lib/text.aloe`, the Term
interface, the runner, or kernel files in 001.

## 5. Verification and acceptance

Checkpoint 000 runs its focused checked tests, existing exact String-row
tests, the full `TMPDIR=/tmp raco test tests` suite, and the no-TTY timing
script. The completion report includes the two measured fast/slow second
pairs and ratios. Checkpoint 001 runs its two focused files,
`TMPDIR=/tmp raco test tests/aloemacs`, and
`TMPDIR=/tmp raco test tests`. Each implementer writes failing focused
tests first, implements that checkpoint, then runs its named verification.
No physical TTY hand check is required; an optional interactive run may
confirm the appearance of the row.

Acceptance requires all of the following: Ctrl-F searches while Ctrl-S
saves; incremental edits leave buffer text unchanged and seek from the
origin; repeated Ctrl-F advances, wraps at most once, then fails; failure
has its own row; Escape/Return retain point and restore the previous echo
without quitting or newline; `find` obeys the total `(Option Int)` contract
and both measured cases beat the drop-based reference by at least 50×; and
the named checked, no-TTY tests and existing suites pass.
