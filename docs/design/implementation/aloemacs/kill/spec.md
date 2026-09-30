# aloemacs kill specification

**Status. Accepted.** This is the complete design input to the
checkpoint manager and implementers. It extends the one
buffer editor with a mark, region kill, kill-line, and yank, preceded by a
`Text` read operation. It is editor design, not Aloe language law.

## 1. Series and authority

The series identity is **aloemacs-kill**. Checkpoints are spoken
**aloemacs-kill 000**, **aloemacs-kill 001**, and, only if the manager must
split the Term work, **aloemacs-kill 002**. Numbers have three digits, begin
at 000, and are never renumbered. The manager writes one checkpoint and
stops; each implementer completes only that checkpoint and stops. Code and
tests live under the project root
`/home/dharmatech/journal/2026-09-02-aloe-racket`, not this design folder.

| Order | Layer | Independent proof |
|---|---|---|
| 000 | `Text.excerpt` in `lib/text.aloe` | A valid span reads exactly what deletion removes; invalid and empty spans keep their distinct `Option` results. No editor, session, or Term change. |
| 001 | Mark, ring, commands, and normally Term chords | Session behavior, undo, echo, search fall-through, and key mapping without a TTY. |
| 002, only if needed | Term chords peeled from 001 | Four physical chords map to the four command strings. Constructor threading remains in 001. |

The manager may peel only the Term section into 002 if 001 exceeds one
implementer conversation. It must keep 000 and 001 distinct, and must not
put any Term change into 000. A layer is a meaningful, independently tested
slice that fits one implementer conversation. A later layer cannot be a
prerequisite for testing an earlier one.

`SPEC.md` governs Aloe syntax, type checking, and sends. The accepted
`text/spec.md`, `undo/spec.md`, `search/spec.md`, and `echo/spec.md` in sibling
folders govern the existing Text, history, search, and row behavior.
`examples/aloemacs/editor.aloe`, `file.aloe`, and `main.aloe` are the current
state and construction seams; `host/racket/term.rkt` is the key conversion
seam. The accepted `string-load-save/spec.md` one directory above aloemacs
keeps `joined-with` as the three-field zipper join. This spec extends those
seams where it says so; it does not amend `SPEC.md`, `UndoFrame`, `delete`,
`EditResult`, or a prior design document. Where existing code and an accepted
predecessor disagree, the accepted predecessor governs. Where Aloe language
typing is in question, `SPEC.md` governs.

## 2. Product boundary and host

The editor still has one immutable `Text` buffer and one point. A mark is an
optional stored `Position`; a session ring is an immutable `List String`,
newest first. Kill removes text and saves the removed string; yank inserts
the newest string without consuming it. Edits use the existing editor undo
history. No region is painted, and the frame and safe-cell rendering do not
read the mark or the ring.

The host is the current checked Aloe program in `examples/aloemacs/`, with
the pure text library in `lib/text.aloe` and Racket Term conversion in
`host/racket/term.rkt`. The runner and Term capability are unchanged. Tests
use the checked Aloe driver and Racket `rackunit` without a TTY. From the
project root, the required suite is:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs
```

Write focused tests first, observe failure for the missing behavior, then
implement and run the suite. `-y` rebuilds changed Racket bytecode; do not
commit `compiled/`. If an implementer launches the editor after a `.rkt`
edit, run the test command or `raco make host/racket/aloemacs-run.rkt bin/aloe`
first. An `.aloe`-only edit needs no rebuild before launch.

The series excludes copy without deletion, yank-pop, merged kills, mark
rebasing, the motion pack, prefix keys, keymaps as data, host clipboard,
mouse, new Term methods, public offsets, `Text.line-at`, kernel messages,
class-side `String join`, and global checkpoints. Save, visit, search,
echo, and rendering retain their existing contracts except for the field
threading and command transitions specified here.

## 3. Layer 000 — read a Text span

Add exactly one public `Text` selector in `lib/text.aloe`:

```aloe
(text excerpt span) ; (Option String), span : Span
```

Return `(Option None)` exactly when `(text valid-span? span)` is false.
Return `(Option Some "")` for a valid empty span. Otherwise return `Some`
of the exact characters `(text delete span)` removes. A cross-line span
contains the intervening LF, including a span from the end of one line to
column 0 of the next. CR remains ordinary content inside its line.

The implementation indexes the source at most once, then works through the
zipper with `focus-at` and `current-line`. It takes and drops fragments at
the endpoints and traverses intervening focused lines. It joins line
fragments and LF with `append`; appending once per line is acceptable.
It does not send `lines`, `to-string`, or `joined-with`, and exposes no
offset or new String method. The `Text` constructors, `delete`, and
`EditResult` are unchanged.

An implementable one-method shape is: validate on an indexed value; focus
at the start; for a one-line span, take the requested width after dropping
the start column. For a multiline span, append the start-line suffix and
LF, fold the complete interior lines with one LF after each, then append
the end-line prefix. `next-lines` may supply the interior lines; its
receiver is already indexed. The end-line prefix comes from a focus at
the end line. This uses no general list join or additional public selector.

Add `tests/aloemacs/kill-excerpt.rkt`. It must assert the checked
`(Option String)` result, single-line middle, cross-line LF, valid empty,
and invalid reversed/out-of-range spans. A CR-containing fixture verifies
exact bytes. For each representative valid span, read `excerpt`, delete
the same span, then insert the excerpt at the `EditResult.position` of
deletion; the final `(text to-string)` must equal the original string.
Test both cold and indexed Text and a span whose endpoints straddle the
current focus. This checkpoint changes only `lib/text.aloe` and that
focused test file. It runs the focused test and
`TMPDIR=/tmp raco test -y tests/aloemacs`, then stops.

## 4. Layer 001 — state and reconstruction

Append `(mark (Option Position))` after `history` in `AloemacsEditor`.
Its constructor is now
`(AloemacsEditor new text point quit scroll-row scroll-col history mark)`.
A fresh editor and a successful visit have no mark. The empty mark at an
untyped construction site, including `main.aloe`, must have this inferable
form; a bare `(Option None)` there does not typecheck under `SPEC.md` §9:

```aloe
(if #t
    (Option None)
    (Option Some (Position new 0 0)))
```

A bare `(Option None)` typechecks as the mark argument of
`AloemacsEditor new` inside a method, because the field type supplies
`T` to the checker and the constructor stores the value. It does not
typecheck as the argument of `with-mark`. The `if` form typechecks as
that argument and fails at runtime with `unknown message: with-mark`:
None's runtime `T` is unknown, and the parameter type is
`(Option Position)`. Do not pass None to `with-mark`. Do not change
the type checker or `eval.rkt` in this series. `ensure-visible`,
`with-text-and-point`, `from-edit`, `request-quit`, and all other
editor rebuilds carry the
receiver's mark unchanged unless a command below replaces it. `unchanged`
returns it unchanged. `undo` takes text, point, and both scroll origins
from the popped frame while retaining the receiver's current mark.
`UndoFrame` remains exactly `(text point scroll-row scroll-col)`.
`frame` and `safe-cells` never read the mark.

Append `(kill-ring (List String))` after `failing` in `AloemacsSession`.
The constructor gains it as its final argument. `(List empty)` supplies a
fresh ring; a successful visit discards the former session's ring and
starts another empty one. The ring is newest first. `with-editor`,
`with-search`, `end-search`, save outcome rebuilds, ordinary idle fallback,
and every other session reconstruction retain the current ring unless a
successful kill conses onto it. Search and save do not create a second
history. `main.aloe` constructs both new fields.

Name and use these methods so command flow and state preservation are
visible to the checkpoint manager:

| Owner and selector | Contract |
|---|---|
| `AloemacsEditor.with-mark(mark)` | Rebuild editor with this `(Option Position)` when the value is `Some`. Preserve all other fields. Do not pass None. |
| `AloemacsEditor.clear-mark()` | Zero arguments. Rebuild the editor with `(Option None)` in the mark field. |
| `AloemacsEditor.keep-valid-mark()` | After a successful edit, keep the exact stored mark if `(new-text valid-position? mark)`; otherwise send `clear-mark`. |
| `AloemacsSession.with-kill-state(editor, kill-ring)` | Rebuild session with these values, preserve fs, path, search state, and set echo token to `""`. |
| `AloemacsSession.set-mark()` | Store `Some` of the current point through `editor.with-mark`, with no edit or ring change. |
| `AloemacsSession.kill-span(span, clear-mark)` | Perform the checked excerpt/delete transition in §5; the Bool selects clearing the mark on region kill or validating it on kill-line. |
| `AloemacsSession.kill()`, `kill-line()`, `yank()` | Implement the respective commands in §5. |

The named helpers are ordinary Aloe methods, not keymap objects or special
forms. All `AloemacsSession new` and `AloemacsEditor new` sites in product
source and valid test fixtures gain their final arguments. Type-negative
constructor tests may retain an intentional arity error; other negative
cases gain the field so they still test their original error. This is
constructor threading, not a rewrite of existing assertions or frame
goldens.

## 5. Layer 001 — command transitions

The session consumes `"mark"`, `"kill"`, `"kill-line"`, and `"yank"` in
`idle-key`, before its fallback to `editor.handle-key`. Do not add these
arms to the editor's `handle-key`; a direct editor send with `"kill"`
still returns an unchanged editor because the string is longer than one
character. The outer `session.handle-key` remains absorbing when the
editor has quit. Each of these keys sets the stored echo token to `""`
through `with-kill-state`, including a no-op, so the idle row shows the
path or `untitled`. At `rows < 2`, the command still runs without an echo
row. None creates a mark status message.

| Key | Transition |
|---|---|
| `"mark"` | Replace any prior mark with `Some` of the current point. Preserve text, point, history, and ring. |
| `"kill"` | With no mark, do nothing except clear echo. Otherwise order mark and point with `Position.before?` into half-open `Span(earlier, later)` and send `kill-span(span, #t)`. Direction does not matter. |
| `"kill-line"` | Build the span described below without consulting the mark, then send `kill-span(span, #f)`; no span is a no-op. |
| `"yank"` | Empty ring is a no-op. Otherwise insert its front string at point through `AloemacsEditor.insert`; keep the ring and validate the mark in the new text. |

`kill-span` first sends `(text excerpt span)`. `None` or `Some ""` is a
no-op: text, point, history, mark, and ring stay. For a nonempty excerpt,
send `(text delete span)`. If deletion returns `None`, the same no-op rule
applies. On `Some EditResult`, send the existing
`(editor from-edit result)` exactly once, cons the excerpt onto the ring,
and set point to `EditResult.position`, the start of the span. With
`clear-mark = #t`, send `clear-mark` on the edited editor; otherwise
send `keep-valid-mark`. No-op paths must not call
`from-edit`. The successful region kill consumes its mark.

For `kill-line`, let point have line `r` and column `c`, and let the focused
line have length `n`:

| Condition | Span or result |
|---|---|
| `c < n` | From point to `(Position new r n)`. The newline stays; the suffix is killed. |
| `c = n`, following line exists | From point to `(Position new (r + 1) 0)`. The killed string is exactly `"\n"`. |
| `c = n`, no following line | No-op, including on the final empty line after a trailing LF. |
| `c > n` or no focused line | No-op. |

The mark is not consulted to choose that span. After a successful
kill-line, keep the same stored mark object if it remains a valid position
in the new text; otherwise clear it. A no-op leaves the mark as it was.
No edit in this series slides a mark to track content.

For yank, an empty ring leaves the editor and ring unchanged. With a ring
entry and valid point, the existing editor `insert` creates the edit and
one undo frame; then `keep-valid-mark` checks the resulting text. If the
point is invalid and insertion would fail, leave the editor and ring
unchanged. The yanked string remains at the ring's front. Normal ring
entries are nonempty because only a nonempty successful kill adds one.
Yank does not move the mark to either end of the inserted text.

Every successful kill, kill-line, or yank pushes exactly one `UndoFrame`
containing the pre-edit text, point, and scroll origins via `from-edit`
or the existing editor `insert` path. `mark`, no-op commands, search
motion, and echo clearing push none. Undo restores the frame's text,
point, and origins, preserves the current mark, and leaves the session
ring alone. Thus undo of a region kill leaves its mark empty and its
killed string at the ring front; yank after that undo inserts the same
string into the restored text.

While search is active, these four strings are the existing “anything
else” case in `search-key`: end search, then dispatch through `idle-key`.
Do not add search-key arms. Ending search initially keeps the stored echo
token; the idle command then clears it. Escape while search is active
still ends search without quitting, and idle Escape still requests quit.

## 6. Layer 001 — physical keys

`host/racket/term.rkt` maps the plain chords before either printable
character branch, using predicates parallel to `plain-ctrl-s-key?`:

| Chord | Key and modifiers | Aloe string |
|---|---|---|
| Ctrl-W | `#\w`, exactly `'(ctrl)` | `"kill"` |
| Ctrl-Y | `#\y`, exactly `'(ctrl)` | `"yank"` |
| Ctrl-K | `#\k`, exactly `'(ctrl)` | `"kill-line"` |
| Ctrl-Space | raw NUL decoding described below, or an explicit `#\space` with exactly `'(ctrl)` | `"mark"` |

For each letter and for an explicit space key, the decoded `tkeymsg-char`
is `#f` or the same character as its key. The installed `tui-term` raw
TTY reader was exercised with NUL input under `with-term (make-tty-term)`:
it produced key ``#\` ``, modifiers `'(ctrl)`, character ``#\` ``.
The VT decoder maps raw NUL to this backtick key. The Ctrl-Space predicate
therefore also accepts exactly that key with exactly `'(ctrl)` and
character either ``#\` `` or `#f`. This terminal encoding cannot
distinguish another physical chord that emits the same NUL byte.
Modified spaces with Shift or Alt, and mismatched decoded characters,
remain on the existing printable or unsupported-key path. Plain `w`,
`y`, `k`, and space still insert. Ctrl-Shift or Alt forms of those letters
retain the printable path as Ctrl-Shift-S does. Ctrl-S, Ctrl-F, Ctrl-Z,
Backspace, Return, and Escape keep their current mappings.

If the manager peels this section into 002, checkpoint 001 uses the four
Aloe strings directly in its behavior tests and leaves `term.rkt` alone.
Checkpoint 002 changes only the converter and its focused tests; it adds
no session or editor behavior.

## 7. Tests and file boundaries

Layer 001 product files are `examples/aloemacs/editor.aloe`,
`examples/aloemacs/file.aloe`, and `examples/aloemacs/main.aloe`;
`host/racket/term.rkt` belongs here unless §6 is peeled to 002. Do not
change the runner, Fs implementation, `SPEC.md`, kernel, earlier specs,
`UndoFrame`, or `lib/text.aloe` in 001. Tests are under `tests/aloemacs/`.

Add `tests/aloemacs/kill-session.rkt` first. Through
`session.handle-key`, prove mark replacement; forward and backward
multiline region ordering; no mark and empty-span no-ops; a single-line
suffix kill; the LF-only kill-line; end of final line and invalid-column
no-ops; ring newest-first and unchanged on no-op; undo of kill restoring
text, point, and origins while preserving the ring; yank after undo;
successful yank retaining the front entry; mark preserved or cleared by
post-edit validity; no frame for mark or no-op; exactly one frame per
successful edit; quit absorption; echo clearing including no-ops;
search fall-through; and rows below two. Compare existing exact frame
bytes for an editor without a mark to ensure rendering is unchanged.

Add `tests/aloemacs/kill-key-mapping.rkt` for the four conversions,
`#f` and matching-character variants, NUL-derived backtick, plain keys,
neighboring modifiers, and unchanged Ctrl-S, Ctrl-F, Ctrl-Z, and Escape.
Exercise the raw VT decoding shape with a no-TTY input port or an
equivalent focused reader fixture; automated tests need no physical TTY.
If Term is peeled into 002, that file and the Term test belong to 002.

Update existing constructor fixtures only to supply the final mark and
ring arguments while retaining their assertions. Known files with
construction sites are `echo-session.rkt`, `editor-keys.rkt`,
`file-session.rkt`, `frame.rkt`, `index-001-editor-movement.rkt`,
`index-002-frame.rkt`, `index-002-timing.rkt`, `int-min.rkt`,
`next-lines.rkt`, `runner.rkt`, `safe-cell-scan.rkt`, `safe-cells.rkt`,
`search-session.rkt`, `text-line-length.rkt`, `undo-editor.rkt`,
`undo-session.rkt`, `viewport-editor.rkt`, `viewport-top.rkt`, and
`visited-unchanged.rkt`. `file-runner.rkt` and `runner.rkt` also contain
source-shape assertions; change them only if the new constructor shape
requires it. Recheck all product and test `AloemacsEditor new` and
`AloemacsSession new` occurrences rather than treating this list as
exhaustive. Do not weaken existing movement, undo, visit, save, search,
echo, or frame assertions.

Run the new focused tests and then
`TMPDIR=/tmp raco test -y tests/aloemacs` from the project root. The
manager's checkpoint may name a wider suite if a concrete dependency
requires it. Use `git diff --check` on changes. No physical TTY hand check
is required; the raw-reader finding above is already recorded.

## 8. Acceptance

The completed series reads any valid span as precisely the String that
deletion removes, with `None` only for invalid spans and `Some ""` for a
valid empty one. Mark, region kill, kill-line, and yank follow §§4–5,
including one undo frame per successful edit, no frame for no-ops, a ring
unchanged by undo, and a mark that is cleared or retained exactly as
specified. The four chords yield the four Aloe command strings while
the previous key behavior remains. The echo row uses only its existing
path, save outcome, and search vocabulary; no region is painted. The
focused no-TTY tests and `TMPDIR=/tmp raco test -y tests/aloemacs` pass.
The manager writes 000 first after this spec is accepted, then stops.
