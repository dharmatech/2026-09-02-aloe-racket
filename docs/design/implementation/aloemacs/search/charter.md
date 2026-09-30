# Charter — aloemacs search

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for
**incremental search**: Ctrl-F reads a query on the echo row and
moves point to a match. Then **stop**. Do not write checkpoints.
Do not implement.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Name the session fields
   the behavior needs.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-search 000** under
   `docs/design/implementation/aloemacs/search/checkpoints/`.
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice** into the two checkpoints
in §4.7. A minibuffer, a reverse search, and a keymap data
structure are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../echo/`](../echo/) | The last row shows the path, or `saved:` / `failed:` plus the path |
| [`../safe-cells/`](../safe-cells/) | That row and each text line pass through `safe-cells` after clipping |
| [`../file/`](../file/) | Session `handle-key`. Ctrl-S is `"save"`. Any other forwarded key clears the echo token to `""` |
| [`../../string-load-save/`](../../string-load-save/) | `split-lines` and `joined-with` are accepted. Do not reopen them |
| Term | Plain Ctrl-S becomes `"save"`, plain Ctrl-Z becomes `"undo"`, Escape becomes `"escape"` and quits |

**Why this layer:** the editor can visit and show a file, and it
cannot find a word in it. The echo row can show the query, so
this slice does not need a minibuffer.

String can take, drop, append, compare, split lines, and join a
zipper. `starts-with?` in `lib/string.aloe` is `(self take n) = prefix`.
A find written as “drop one character and try again” copies the
tail on every step. The scan named below is the linear primitive
that avoids that.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Ctrl-F searches; Ctrl-S saves.** Plain Ctrl-F becomes the
   Aloe key `"find"`, by the same plain-Ctrl rule as `"save"`.
   Ctrl-S is unchanged.
2. **The query is incremental and lives on the echo row.**
   Printable characters, including space, append to the query.
   Backspace drops the last character. The buffer text does not
   change. Each query edit searches forward from the point where
   this search started.
3. **Ctrl-F again finds the next match** after the current one.
   The attempt may wrap once. After a match that was reached by
   wrapping, another Ctrl-F fails.
4. **Failure is a distinct echo row.** Leaving the search
   restores the echo token from when the search started
   (`""`, `"saved"`, or `"failed"`). Escape and Return leave the
   point where the search put it, restore that token, and do
   not quit or insert a newline.
5. **`find` is one forward scan.** `(haystack find pattern start)`
   returns `(Option Int)`. On a haystack of at least 20,000
   characters, a hit only at the end and a miss are each at
   least **50×** below a drop-based search of that same
   haystack. The slow loop is timed in the same script and is
   not product code.
6. **Tests first**, no TTY. Kernel tests cover the `find`
   contract and the checker. Session tests cover a move to a
   match, a wrap, a failure, backspace, Escape restoring a
   prior `saved` echo without quitting, and Ctrl-S still saving
   when no search is active. On this machine, Racket tests need
   `TMPDIR=/tmp`.

## 4. Locked decisions (record these; do not reopen 4.1–4.7)

### 4.1 The session owns the search

`AloemacsSession` already owns the echo token and intercepts
`"save"`. Search is the same kind of mode. The session keeps the
query, the origin point, and whether the current match was
wrapped. The editor keeps the text and the point.

The spec names the new fields and their defaults (not searching,
empty query). Every `AloemacsSession new`, including
`with-editor`, preserves those fields unless the method is
changing the search. The editor constructor does not grow for
this series.

Moving point uses the existing editor rebuild that keeps undo
history as it is. A search move does not push a history frame.
Arrows already behave that way.

### 4.2 Keys

While a search is active:

| Key | Behavior |
|---|---|
| length-1 printable, including space | Append, then search from the origin |
| `"backspace"` | Drop the last query character, then search from the origin. An empty query shows the search prefix and leaves point at the origin |
| `"find"` | Next match after the current one, when the query is non-empty. An empty query stays put |
| `"escape"`, `"return"` | End the search. Point stays. Echo token returns. No quit and no newline |
| anything else | End the search, then handle that key as today. Ctrl-S therefore saves. An arrow accepts the match and moves. Ctrl-Z accepts and undoes |

Starting from an idle session, `"find"` enters search at the
current point and shows the search prefix. It does not move.

`"escape"` outside a search still quits. The editor's own
`handle-key` never inserts the word `find`; `"find"` is longer
than one character and the session consumes it.

### 4.3 What the echo row shows

The row is one of these strings, then clipped and passed through
`safe-cells` as the path row is today:

| State | Row |
|---|---|
| searching | `search: ` and the query |
| wrapped | `wrapped: ` and the query |
| failing | `failing: ` and the query |

`failing:` is not the save token `"failed"`. While the search is
active the stored save token is kept and not displayed. When
`rows < 2` the session still has no echo row; point behavior is
unchanged.

### 4.4 Where a match is

The search is case-sensitive and literal. There is no pattern
language. The query contains only characters the user typed, so
it does not contain a newline. Each line is given to `find` at
most once per attempt.

A query edit searches forward from the origin, including a match
that starts on the origin character. Point is placed on the
first character of the match. The following Ctrl-F starts after
that match, on the same line.

An attempt scans the origin line from its start column, then
later lines from column 0. If that finds nothing, it scans from
the first line up to the origin, and on the origin line accepts
only an index before the attempt's start column. A match in
that second scan is the wrap. If the current match already came
from a wrap, Ctrl-F does not scan again: the row becomes
`failing:` and point stays. A miss on the first query leaves
point at the origin.

### 4.5 The String message

Add one kernel message. `starts-with?` stays the library method
it is.

```text
(haystack find pattern start) -> (Option Int)
```

`haystack` and `pattern` are `String`. `start` is `Int`. A
non-String receiver or argument, or a bad arity, is a type
error. No Int/Float coercion.

- The result is the smallest index `i >= start` such that the
  `pattern`-length substring at `i` equals `pattern`.
- `start < 0` is treated as 0. A non-empty pattern with no such
  `i` is `(Option None)`, including when `start` is past the
  last character.
- An empty pattern is `(Option Some i)` with `i` clamped into
  `0` through `haystack`'s length, inclusive. The editor does
  not call `find` for an empty query; the message is still total.
- One forward scan. It does not allocate the matched text. It
  does not `drop` the tail once per character.
- `SPEC.md` §7.5 gains this row. In the String catalog it
  follows `joined-with`. Library rows stay library rows.
- Checker, evaluator, and signature catalog learn the row
  together: `aloe/type.rkt`, `aloe/eval.rkt`,
  `aloe/signature-catalog.rkt`.

Selector lists that snapshot String's kernel rows may be updated
where they name those rows. Do not weaken an unrelated
assertion. This series does not take a `CHECKPOINTS.md` number
unless a later human promotes it.

### 4.6 Timing

A script in the spirit of
[`tests/aloemacs/index-002-timing.rkt`](../../../../../tests/aloemacs/index-002-timing.rkt)
(`module+ main`, not part of `raco test tests`) times two
intervals on one haystack of at least 20,000 characters, with
construction outside the timer:

1. `find` of a pattern whose only match starts at the end.
2. `find` of a missing pattern of the same length.

The same script times a drop-based search of that haystack: at
each index, `drop` then `starts-with?`. Each `find` interval
must be at least 50× below that slow timing. The spec records
the measured seconds and the numeric bar. A `find` that still
copies the remainder per character has failed, even if it beats
a clumsier loop.

### 4.7 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-search 000** | The `find` contract, the catalog row, and the timing bar. No editor and no Term change |
| **aloemacs-search 001** | Ctrl-F, the echo row, point motion, wrap, failure, and restore. It calls `find`. It adds no second kernel message |

000 is language law and is testable alone. 001 is the editor.
The manager writes 000 only, then stops. Do not collapse them
into one checkpoint: the kernel slice and the session slice are
each a conversation.

### 4.8 The spec names

- The session fields and the defaults on the existing
  constructors, including the empty session in `main.aloe`.
- The editor send used to place point without a new undo frame.
  `with-text-and-point` already keeps history.
- Which existing selector-list tests gain the `find` row.

## 5. Authority

- [`../README.md`](../README.md) — one cell per character; search
  is this layer
- [`../echo/spec.md`](../echo/spec.md) — echo tokens and the last
  row
- [`../safe-cells/spec.md`](../safe-cells/spec.md) — clip, then
  `safe-cells`
- [`../file/spec.md`](../file/spec.md) — session `handle-key` and
  save
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — fields `editor`, `fs`, `path`, `echo`; non-save keys clear
  the token
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — `handle-key`, `with-text-and-point`
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — `plain-ctrl-s-key?`
- [`SPEC.md`](../../../../../SPEC.md) §7.5 — String kernel messages
- [`../../string-load-save/spec.md`](../../string-load-save/spec.md)
  — `joined-with` stays the previous kernel row

`SPEC.md` remains language law. Checkpoint 000 amends §7.5 as
§4.5 requires. The rest of this spec is editor design.

## 6. Non-goals

- Reverse search, case folding, regular expressions, replace
- Highlighting the match, or a face on the match
- A minibuffer, or a query with its own cursor
- Remembering the last query across searches
- A search that pushes an undo frame
- Motion commands beyond what the keys already do (no page, no
  beginning-of-line binding)
- Kill, yank, prefix maps, commands as objects
- Tab stops, a Tab key, a programming mode
- Changing `safe-cells`, `split-lines`, `joined-with`, or the
  Ctrl-S binding
- A `CHECKPOINTS.md` entry, unless the human promotes 000 later

## 7. Handoff

- Series identity: `aloemacs-search`.
- Checkpoint 000 is spoken **aloemacs-search 000**. Checkpoint
  001 is spoken **aloemacs-search 001**. Numbers are three
  digits, start at 000, and are never renumbered. The
  checkpoint manager writes one checkpoint, then stops.
- Intended order: §4.7. 000 first.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Kernel code for 000 stays in `aloe/` and `SPEC.md`. Editor
  code for 001 stays in `examples/aloemacs/` and
  `host/racket/term.rkt`. Tests stay in `tests/aloemacs/`.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.
