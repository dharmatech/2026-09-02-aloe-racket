# aloemacs undo specification

**Status: Accepted.** This is the complete design input for the
aloemacs-undo checkpoint manager and implementer. It is not Aloe language law.

Undo restores the state just before the latest successful edit. Each further
undo restores the state before the preceding edit. The editor keeps immutable
snapshots of focused `Text`, point, and viewport origin; unchanged zipper lines
and list tails remain shared. There is no inverse-span calculation, source
resplit, or nested editor in a history frame.

## 1. Checkpoint series and authority

The local series identity is **aloemacs-undo**. The first checkpoint is spoken
**aloemacs-undo 000** and filed under
`docs/design/implementation/aloemacs/undo/checkpoints/000-slug.md`.
Numbers are three digits, start at 000, and are never renumbered; slugs are
lowercase hyphenated words. The checkpoint manager writes only the next
checkpoint, then stops. The implementer builds and tests only that checkpoint,
then stops for human review. Code and tests go in the project root,
`/home/dharmatech/journal/2026-09-02-aloe-racket`, not in this design folder.

This feature is one closed slice: **000, persistent editor history and one
interactive undo key**. Its unit tests precede the implementation in the same
change; the checkpoint is complete only when the editor, session, and key
mapping tests are green together. The manager may split 000 if it cannot fit
one implementer conversation, but must keep the pure editor behavior before
the host key binding, keep each split independently testable, and add no
features.

`SPEC.md` governs Aloe syntax, sends, types, `List`, and immutability. The
accepted `../text/spec.md` and `../index/spec.md` govern exact `Text`
replacement and zipper focus; `../loop/spec.md` governs editing and keys;
`../file/spec.md` governs session, visit, save, and Ctrl-S; and
`../viewport/spec.md` governs origin and fit-before-frame. This spec changes
only the editor state shape, edit history, undo transition, and one key
normalization described below. Earlier behavior remains in force otherwise.
`../README.md` governs the aloemacs application boundary. The current
`examples/aloemacs/` source and `host/racket/term.rkt` are starting points,
not authority over the changed behavior.

## 2. Product and file boundary

The running program remains one buffer, one point, one session, and one Term
capability. `AloemacsEditor` owns history. `AloemacsSession` retains exactly
its `editor`, `fs`, and `path` fields; it stores no second history. The runner
continues to pass one `read-key` string to session `handle-key`, fit before
frame, and write one complete frame. Undo never sends `Fs.write` and does not
alter the bound path. A later save writes the then-current exact
`(text to-string)`, including after undo. Untitled save stays a no-op.

The only permitted product files are `examples/aloemacs/editor.aloe`,
`examples/aloemacs/file.aloe` for visit construction,
`examples/aloemacs/main.aloe` for initial construction, and
`host/racket/term.rkt` for the Ctrl-Z normalization. New tests belong under
`tests/aloemacs/`. Existing tests there may be adjusted only for the editor
constructor's added history argument and direct consequences of the new
undo behavior. Constructor sites currently occur in `editor-keys.rkt`,
`file-runner.rkt`, `file-session.rkt`, `frame.rkt`,
`index-001-editor-movement.rkt`, `index-002-frame.rkt`,
`index-002-timing.rkt`, `runner.rkt`, and `viewport-editor.rkt`.
Keep their substantive prior assertions. No change is needed in the Racket
runner, `lib/text.aloe`, any other library, the Term interface, Fs host, Gel,
`aloe/eval.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or global checkpoints.

Use checked Aloe 0.1 for the product and the existing Racket driver and host
doubles for tests. From the project root, run `raco test tests/aloemacs` for
the focused suite and `raco test tests` for full regression. The application
still runs with `racket host/racket/aloemacs-run.rkt` or that command followed
by one path. No build step or dependency is added.

## 3. State and history

Declare `UndoFrame` after loading `Text` and before `AloemacsEditor`:

```aloe
(define-class UndoFrame
  (fields
    (text Text)
    (point Position)
    (scroll-row Int)
    (scroll-col Int))
  (methods))
```

Append one field to the existing editor, in this order:

```aloe
(define-class AloemacsEditor
  (fields
    (text Text)
    (point Position)
    (quit Bool)
    (scroll-row Int)
    (scroll-col Int)
    (history (List UndoFrame)))
  (methods ...))
```

The constructor is
`(AloemacsEditor new text point quit scroll-row scroll-col history)`.
`(List empty)` supplies the initial history in its contextual field type.
There is no wrapper around a whole editor and no `quit`, `fs`, or `path` in a
frame. The list is newest first, unbounded in this layer. A frame holds the
pre-edit `Text` value **as it was on the receiver**, including its focus, plus
that receiver's point and origin. It does not call `Text.lines`,
`Text.to-string`, or `Text.from-string`. `UndoFrame` and history are ordinary
immutable Aloe values; no `set!`, host array, or `Vector` is involved.

The initial editor in `main.aloe` has empty history. Every successful visit,
whether an existing regular file or a missing new-file path, constructs an
editor with empty history, point `(0, 0)`, quit `#f`, and origin `(0, 0)`.
Rejected visits return `None` and leave the original session and its history
untouched. A visit never imports history from the source session. Save,
movement, `ensure-visible`, request-quit, and no-op rebuilds preserve the
same history list.

## 4. Transitions

`insert`, `newline`, and `backward-delete` keep their current signatures and
`Text` edit contracts. Each successful `Some(EditResult)` conses **one**
`UndoFrame` of the receiver's pre-edit fields before constructing the result
editor. The result takes `text` and `position` directly from `EditResult`,
keeps `quit` and the current origin, and stores the extended history. This
rule also covers a successful direct `(editor insert "")`; `Some`, rather
than a comparison of resulting strings, is the success criterion. The
Backspace join at column 0 is one edit and one frame, even though it removes
an LF. An edit returning `Option None`, Backspace at `(0, 0)`, and any other
unsuccessful edit preserve history and all current fields. No frame is
created by `move-left`, `move-right`, `move-up`, `move-down`,
`ensure-visible`, `request-quit`, save, visit failure, an unknown key, or
ordinary frame rendering. A post-quit `handle-key` remains absorbing before
dispatch, so it pushes nothing.

Add the pure editor send `(editor undo) -> AloemacsEditor`. With an empty
history, it returns an editor structurally equal to the receiver. With a
nonempty history, it returns an editor whose `text`, `point`, `scroll-row`,
and `scroll-col` come from the first frame, whose `history` is the old list's
`rest`, and whose `quit` is the receiver's current value. It never pushes a
frame. No popped frame is retained for redo. Direct `undo` on a quit editor
follows this same pure rule; `handle-key` on a quit editor still ignores every
key, including `"undo"`.

Add exact `"undo"` to editor `handle-key` **before** the length-one printable
fallback. File session's existing `handle-key` checks quit, handles
`"save"`, and otherwise delegates to editor `handle-key`; that delegation
handles `"undo"` without a second history or filesystem branch. Direct
session `insert`, `newline`, and `backward-delete` keep delegating, so they
also create history through the editor. No new session command is required.

Undo restores the captured origin, not just text and point. It may put point
outside that origin's window if movement or resize happened after the edit;
the runner's next `ensure-visible` fits the restored point with current
dimensions before drawing. Undo itself has no terminal-size input and does
not call `ensure-visible` or `frame`. For an edit made after arrow movement,
its frame records the point at the edit, not a point from an earlier edit.
Arrows, fit, and save alone add no frames. If those are the only actions on a
fresh editor, undo is an equal no-op. After an edit, intervening movement
does not create a separate undo step: undo restores that edit's captured
pre-edit point and origin.

## 5. Physical key

The Aloe command string is `"undo"`. Add exactly one guarded clause to
`tkeymsg->aloe-key` in `host/racket/term.rkt`, before the existing printable
character clauses:

```racket
(make-tkeymsg #\z '(ctrl) #f)  ; => "undo"
(make-tkeymsg #\z '(ctrl) #\z) ; => "undo"
```

The `key` must be `#\z`, modifiers exactly `'(ctrl)`, and `char` either `#f`
or `#\z`. The installed `tui-term` VT decoder recognizes byte 26 as Ctrl-Z;
its TTY raw mode delivered a live pseudo-terminal probe as key `#\z`, mods
`'(ctrl)`, char `#\z`. The second form is therefore required, matching the
Ctrl-S precedent where `char` defaults to the key. Printable `z` remains
`"z"` and inserts. Other modifier shapes and all existing Return,
Backspace, arrows, Escape, Ctrl-S, and unknown-key mappings retain their
prior behavior. This is one normalization clause, not a prefix map or new
Term host method.

## 6. Tests and verification

Add focused no-TTY unit tests first, then implement until they pass:

- `tests/aloemacs/undo-editor.rkt`: checked class fields, constructor and
  `undo`/`handle-key` types; insert then undo; newline then undo; Backspace
  then undo within a line and joining at column 0; two edits then two undos
  and a no-op at the history bottom; fresh undo no-op; an attempted failed
  edit and Backspace at `(0, 0)` adding no frame; arrows and
  `ensure-visible` adding no frame; pre-edit point and both origin fields
  restored exactly; old editor and `Text` values still equal themselves.
  Test the post-quit `"undo"` and edit keys as no-ops.
- `tests/aloemacs/undo-session.rkt`: existing and missing-file visits start
  empty history even when the source session has edits; a rejected visit
  preserves its source; direct and handled session edits undo through
  delegation; save does not add history, Ctrl-S behavior stays intact, undo
  does not write, and a later save writes the restored exact text. Use an Fs
  double and no physical file.
- `tests/aloemacs/undo-key-mapping.rkt`: construct both Ctrl-Z `tkeymsg`
  forms above, plain printable `z`, neighboring modified `z` forms, and a
  representative Ctrl-S and Backspace regression. The exact plain Ctrl-Z
  forms map to `"undo"`; printable `z` maps to `"z"`.

Use the checked driver for Aloe sends and field inspection. Assert history
length or frames directly where needed to distinguish a no-op from an extra
push; compare full `Text.to-string`, `Position`, both origin fields, and
history state across transitions. In a two-edit sequence, a post-edit arrow
is not a third step. The terminal test calls `tkeymsg->aloe-key` directly and
needs no TTY. Run `raco test tests/aloemacs` and `raco test tests` after the
change. A live Ctrl-Z TTY check is optional; no acceptance test depends on
one.

## 7. Acceptance and stop

The series is done when insert, newline, and both forms of backward delete
each produce exactly one reversible edit frame on success; repeated undo
pops newest first and stops at empty; movement, fit, save, quit, failed edits,
unknown keys, and post-quit keys push none; visit and initial construction
start empty history; viewport origin follows the policy in section 4; the
pre-undo values remain unchanged; Ctrl-Z reaches `"undo"` without taking
printable `z`; and all focused and full tests pass without a TTY. File
strings and save behavior remain exact. The implementer stops when green.

This layer does not add redo, an undo tree, undo-in-region, edit grouping,
`C-x u`, prefix maps, a minibuffer, search, kill ring, dirty flags, backup
files, status messages, windows, scroll margin, paint cache, inverse-span
rebasing, mutation, a compiler, or `Vector`. It does not change public
`Text.replace` semantics or start Boids.
