# Charter — aloemacs kill

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for **mark,
region kill, kill-line, and yank** on the one buffer. Then
**stop**. Do not write checkpoints. Do not implement.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §6.
2. Record the locked decisions in §4. Name the fields and the
   Text selector the behavior needs.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-kill 000** under
   `docs/design/implementation/aloemacs/kill/checkpoints/`.
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice** into the checkpoints in
§4.8. A painted region, a host clipboard, yank-pop, and a keymap
data structure are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../text/`](../text/) | `Span`, `delete`, `insert`, `valid-span?`, `valid-position?`. `EditResult` is the new text and the new point |
| [`../undo/`](../undo/) | A successful insert, newline, or backward-delete conses one `UndoFrame`. Ctrl-Z restores that frame |
| [`../file/`](../file/) | Session `handle-key`. Visit builds an editor. Save writes `(text to-string)` |
| [`../search/`](../search/) | An active search treats any key other than the search keys as: end the search, then handle that key idle |
| [`../echo/`](../echo/) | The last row shows the path, or `saved:` / `failed:` plus the path, or the search row |
| Term | Plain Ctrl-S is `"save"`, plain Ctrl-F is `"find"`, plain Ctrl-Z is `"undo"` |

**Why this layer:** the editor can visit, edit, save, undo, and
search, and it cannot lift a span out of the buffer and put it
back. `delete` removes a span and returns the remaining `Text`
and the new point. It does not return the characters it removed.
This slice adds that read, then the mark and the ring that use it.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **A valid span can be read as a `String`.** One new `Text`
   selector, `excerpt`, returns `(Option String)`. `None` when
   `valid-span?` is false. `Some` of the characters `delete`
   would remove when the span is valid, including `Some ""` for
   an empty span. `delete` that span, then insert the excerpt at
   the point `delete` returns: `(text to-string)` is the text
   from before the delete.
2. **Mark, kill, kill-line, and yank behave as §4.3.** The ring
   is a `List String` on the session, newest first. A no-op
   changes neither the text nor the ring and pushes no undo
   frame. A successful kill, kill-line, or yank pushes one undo
   frame, the same way insert does.
3. **Undo restores text and point, and leaves the ring alone.**
   `UndoFrame` does not gain a mark or a ring. After undo of a
   kill, yank inserts the same string again.
4. **The four chords become the four Aloe strings** in §4.4.
   Ctrl-S still saves. A plain letter still inserts. Escape
   outside a search still quits.
5. **The echo vocabulary does not grow.** The row is still the
   path, `saved:` / `failed:`, or the search row. These four
   keys leave the echo token `""`.
6. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

## 4. Locked decisions (record these; do not reopen 4.1–4.9)

### 4.1 The editor owns the mark

Append one field to `AloemacsEditor`, after `history`:

```aloe
(mark (Option Position))
```

The constructor gains that argument at the end. Every
`AloemacsEditor new` in `examples/aloemacs/` and `tests/aloemacs/`
passes it. `main.aloe` and any other untyped construction site
use the lawful empty value, the same spelling as the empty path
already in `main.aloe` and as SPEC.md §9:

```aloe
(if #t
    (Option None)
    (Option Some (Position new 0 0)))
```

A bare `(Option None)` at an untyped `new` is a defect in the
spec. Do not change the type checker. `AloemacsEditor new` may
take a bare `(Option None)` when the mark field already expects
`(Option Position)`. That is how a method clears the mark: it
rebuilds the editor and puts None in the field.

`with-mark` takes `(Option Position)`. Bare `(Option None)` does
not typecheck as that argument (`T` is unknown). The `if` form
typechecks, and the value it returns is still a None whose `T`
is unknown. Runtime dispatch then reports
`unknown message: with-mark`. `with-mark` is for
`(Option Some position)`. Clearing is a zero-argument method
on the editor. Do not change `eval.rkt` to stamp `T` onto None.

A fresh editor and a successful visit start with no mark. Visit
does not keep the previous editor's mark.

`UndoFrame` stays `(text point scroll-row scroll-col)`. `undo`
restores those four from the frame and keeps the receiver's
current `mark`. `from-edit`, `with-text-and-point`,
`ensure-visible`, `request-quit`, and `unchanged` keep the
receiver's mark unless the command in §4.3 replaces it.
`frame` and `safe-cells` do not read the mark.

### 4.2 The session owns the ring

Append one field to `AloemacsSession`, after `failing`:

```aloe
(kill-ring (List String))
```

Newest string at the front. `(List empty)` is the initial value,
the same way empty history is `(List empty)`. A fresh session
and a successful visit start with an empty ring. Visit does not
keep the previous ring. Save, search, and `with-editor` keep the
ring unless yank or kill replaces it.

The session stores no second undo history. Kill and yank push
the editor's existing history by deleting or inserting through
the editor.

Every `AloemacsSession new` threads the new field. The spec
finds those sites. It does not treat a list copied from an older
spec as complete.

### 4.3 The four commands

The session consumes the keys. The editor's `handle-key` does
not gain these arms. A direct `(editor handle-key "kill")` is
unchanged, because the string is longer than one character.

| Key | Behavior |
|---|---|
| `"mark"` | Store `(Option Some point)`. Text, point, history, and the ring stay. The mark replaces any previous mark |
| `"kill"` | Kill the span between mark and point, as below |
| `"kill-line"` | Kill from point through the rest of the line, as below. The mark is not an input |
| `"yank"` | Insert the front of the ring at point, as below |

**Ordering a region.** The span's start is the earlier of mark
and point, and its end is the later, using `Position.before?`.
The commands do not care which one was set first.

**`"kill"`.** No mark, an empty span, or `excerpt` of `None` or
`Some ""`: the editor and the ring stay, and no undo frame is
pushed. Otherwise `excerpt` yields the string, `delete` removes
that span, that string is consed onto the front of the ring, and
the mark becomes `(Option None)`. Point is the point `delete`
returns, which is the start of the span. A `delete` of `None`
after a non-empty `excerpt` leaves the ring and the mark
unchanged and pushes no frame.

**`"kill-line"`.** Let the point's column be `c` and the current
line's length be `n`.

- `c < n`: the span runs from the point to `(line, n)`. The
  newline stays. The killed string is the suffix of the line.
- `c = n` and a following line exists: the span runs from the
  point to column 0 of the next line. The killed string is
  `"\n"`.
- `c = n` and no following line exists: no-op. The last line of
  the buffer is this case.
- `c > n`: no-op.

A no-op leaves the mark alone. After a successful kill-line, if
the stored mark is no longer `valid-position?` in the new text,
the mark becomes `(Option None)`. A mark that is still valid
stays the same object. This series does not slide a mark forward
or backward to track an insertion or a deletion.

**`"yank"`.** An empty ring is a no-op. Otherwise the session
inserts the front string at point through the editor's existing
insert. The string stays on the ring. Point is the point insert
returns. The mark follows the kill-line rule: unchanged when
still valid, `(Option None)` when not. Yank does not move the
mark to either end of the inserted text.

**Quit.** `(session handle-key …)` is already unchanged when
`quit` is true. These keys do not run in that state.

A command that no-ops still clears the echo token, per §4.5.
Clearing the token pushes no undo frame.

### 4.4 Keys

Term maps plain chords to Aloe strings by the same rule as
`plain-ctrl-s-key?` and `plain-ctrl-z-key?`: the key character,
mods exactly `'(ctrl)`, and char either `#f` or that same
character. The clause precedes the printable-character branches.

| Chord | Aloe string |
|---|---|
| Ctrl-W | `"kill"` |
| Ctrl-Y | `"yank"` |
| Ctrl-K | `"kill-line"` |
| Ctrl-Space | `"mark"` |

Ctrl-Shift and Alt of those letters stay on the printable path,
as Ctrl-Shift-S stays `"s"`. A plain `w`, `y`, `k`, or space
still inserts.

Ctrl-Space is the open shape in §5. The Aloe string is not open.
`"mark"` is longer than one character, so the editor cannot
insert it if the session ever fails to consume it.

### 4.5 What the echo row shows

These keys set the session's echo token to `""` before the row
is built. The row then shows the path, or `untitled`, including
when the command was a no-op.

They do not add a token. There is no `Mark set` row. The region
is not painted. `frame` does not read the mark or the ring.

While a search is active, these keys are the existing "anything
else" case: end the search, then handle the key idle. Do not add
a search-key arm for them. Ending the search keeps the stored
echo token, and the idle command then sets that token to `""`,
the same way an arrow during search accepts the match and clears
the row back to the path.

`rows < 2` still has no echo row. The commands still run.

### 4.6 `Text.excerpt`

Add one method on `Text`. `delete` and `EditResult` stay as they
are. No kernel message. No `SPEC.md` row. No `line-at`. No
public offset.

```text
(text excerpt span) -> (Option String)
```

- `None` exactly when `(text valid-span? span)` is false.
- `Some ""` when the span is valid and empty.
- Otherwise `Some` of the characters that `delete` of that span
  removes. A span that crosses a line includes the LF between
  those lines. CR stays inside the line, as the rest of `Text`
  already stores it.
- The walk uses the zipper: `indexed-value` at most once, then
  `focus-at` and `current-line`, then `take` and `drop` on the
  end lines. It does not send `lines` or `to-string`.
- The pieces it joins are line fragments, not characters. It
  joins them with `append`. It does not call `joined-with`.
  `joined-with` remains the three-field zipper join. A linear
  join of an arbitrary list is the parked class-side
  `(String join …)`, and this series does not add it.
- Appending once per line of the span is accepted. A timing bar
  is not part of this series.

The round trip in §3 is the proof. A fixture that crosses one
LF, a single-line middle, an empty span, and an invalid span
are the minimum.

### 4.7 Undo

A successful `"kill"`, `"kill-line"`, or `"yank"` pushes one
frame, the pre-edit text, point, and origin, via the existing
`from-edit` path. `"mark"` does not. A no-op does not. A search
motion still does not.

The frame has no mark. Undo of a kill restores the text and the
point and leaves the killed string on the ring. The mark after
undo is the mark the killing command left behind, which for
`"kill"` is `(Option None)`. Undo does not put the old mark back.

Yank after that undo inserts the front string into the restored
text. The ring still has that string afterward.

### 4.8 Checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-kill 000** | `excerpt`: the contract in §4.6 and the round trip. No editor field, no session field, no Term change |
| **aloemacs-kill 001** | The mark, the ring, the four commands, undo, the echo token, search fall-through, and the Term chords |

000 is a library slice and is testable with no editor. 001 is
the editor. The manager writes 000 only, then stops. Do not
collapse them into one checkpoint.

001's behavior tests send the Aloe strings (`"mark"`, `"kill"`,
`"yank"`, `"kill-line"`) through the session. The Term predicates
are a separate section of the spec. If 001 will not fit one
implementer conversation, the manager peels that Term section off
as **aloemacs-kill 002**. The manager does not peel constructor
threading off by itself, and does not put Term work into 000.

### 4.9 The spec names

- The session and editor methods that perform §4.3, and which
  existing rebuilds gain a `mark` or `kill-ring` argument.
- The test files under `tests/aloemacs/`. Existing suites change
  only to pass the new constructor arguments, and to keep their
  current assertions. Frame bytes for an editor with no mark stay
  the bytes those tests already expect.
- The Term predicates, including the Ctrl-Space shape from §5.
- That `examples/aloemacs/main.aloe` constructs both new fields.

## 5. Open questions

Resolve this in the spec. Do not reopen §4.

**What `tui-term` delivers for Ctrl-Space** in the raw reader
behind `call-with-tty-term-receiver`. Letter chords are the
plain-Ctrl rule in §4.4. Ctrl-Space may arrive as a space, as
NUL, or as another `tkeymsg`. Record the live shape, map that
shape to `"mark"`, and accept the `#f` char variant when the key
and the mods match, as Ctrl-S accepts both `#f` and `#\s`.
Neighboring modified spaces that are not that plain chord stay
off `"mark"`.

## 6. Authority

- [`../README.md`](../README.md) — one buffer; this layer is Kill
- [`../text/spec.md`](../text/spec.md) — spans, `delete`,
  `insert`. `line-at` and offset stay off the public surface
- [`../undo/spec.md`](../undo/spec.md) — `UndoFrame` and which
  commands push
- [`../search/spec.md`](../search/spec.md) — search keys, and the
  idle fall-through
- [`../echo/spec.md`](../echo/spec.md) — echo tokens and the last
  row
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — `from-edit`, `undo`, `handle-key`
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — session fields, `idle-key`, `search-key`
- [`examples/aloemacs/main.aloe`](../../../../../examples/aloemacs/main.aloe)
  — the lawful `(Option None)` spelling
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — `plain-ctrl-s-key?`, `plain-ctrl-z-key?`
- [`SPEC.md`](../../../../../SPEC.md) §9 — bare `(Option None)` is
  rejected; the `if` form is the golden
- [`../../string-load-save/spec.md`](../../string-load-save/spec.md)
  — `joined-with` stays the zipper join

`SPEC.md` remains language law. This series does not amend it.
The kill spec is editor design plus one `Text` method.

## 7. Non-goals

- Painting the region, a face, or an echo token for the mark
- Copying a span onto the ring without deleting it
- Yank-pop, or merging consecutive kills into one ring entry
- Removing the yanked string from the ring
- Sliding the mark so it sticks to the same character across an edit
- The motion pack: beginning and end of line, page, beginning
  and end of the buffer
- Commands as objects, a keymap, prefix keys, `C-x`
- The host clipboard, mouse, or a Term method beyond the key strings
- A kernel message, `SPEC.md` row, class-side `(String join …)`,
  or a change to `delete` / `EditResult`
- A `CHECKPOINTS.md` entry
- Rewriting the undo, search, echo, or safe-cells specs. They
  stay the authority they are. This spec extends the editor.

## 8. Handoff

- Series identity: `aloemacs-kill`.
- Checkpoint 000 is spoken **aloemacs-kill 000**. Checkpoint
  001 is spoken **aloemacs-kill 001**. A peeled Term slice is
  spoken **aloemacs-kill 002**. Numbers are three digits, start
  at 000, and are never renumbered. The checkpoint manager
  writes one checkpoint, then stops.
- Intended order: §4.8. 000 first.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code for 000 stays in `lib/text.aloe`. Code for 001 stays in
  `examples/aloemacs/` and, unless peeled into 002,
  `host/racket/term.rkt`. Tests stay in `tests/aloemacs/`.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.
