# aloemacs-undo 000 — Persistent history and undo key

**Status.** Ready to implement.

## Goal

Give the immutable editor one newest-first history of pre-edit snapshots, a
pure `undo` send, and one Ctrl-Z normalization to the `"undo"` key string.
One successful insert, newline, or backward delete makes one undo step;
movement, fitting, saving, quitting, and failed edits make none. Test the
editor, session, and host key mapping together, then stop. This is the only
planned checkpoint in the **aloemacs-undo** series.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-undo 000**, the first local checkpoint in the
  **aloemacs-undo** series. There is no preceding undo checkpoint. Text,
  Loop, File, Index, and Viewport are implemented predecessors.
- The governing undo spec sections are §1–7. `SPEC.md` governs Aloe syntax,
  sends, types, `List`, and immutability. The accepted Text, Index, Loop,
  File, and Viewport specs named in undo §1 remain authority for their
  respective behavior. The aloemacs parent map governs the application
  boundary. This checkpoint changes only the fields, transitions, and key
  mapping specified by undo §2–5.
- The project root for product code and tests is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. The current
  `AloemacsEditor` has `text`, `point`, `quit`, `scroll-row`, and
  `scroll-col`; `AloemacsSession` has only `editor`, `fs`, and `path`.
  `main.aloe` and successful visits construct five-argument editors.
  `host/racket/term.rkt` already maps Ctrl-S before its printable clauses.
  These sources are starting points, not authority over the accepted change.
- Use checked Aloe for product sends and the existing Racket driver and host
  doubles for tests. Aloe list forms are sends: the head is the receiver and
  the second element is a literal selector. Function objects run through
  `call`. Do not add special forms, mutation, inheritance, or implicit
  `Int`/`Float` conversion.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` for `UndoFrame`, editor history, undo, and
  editor key dispatch
- `examples/aloemacs/file.aloe` only to give successful visits empty history
- `examples/aloemacs/main.aloe` only to give the initial editor empty history
- `host/racket/term.rkt` only for the Ctrl-Z normalization clause
- `tests/aloemacs/undo-editor.rkt` (new)
- `tests/aloemacs/undo-session.rkt` (new)
- `tests/aloemacs/undo-key-mapping.rkt` (new)
- The existing `tests/aloemacs/editor-keys.rkt`, `file-runner.rkt`,
  `file-session.rkt`, `frame.rkt`, `index-001-editor-movement.rkt`,
  `index-002-frame.rkt`, `index-002-timing.rkt`, `runner.rkt`, and
  `viewport-editor.rkt` **only** to add the required history argument at
  editor constructor sites and adjust direct expectations of the changed
  constructor or undo behavior. Retain their substantive prior assertions,
  including negative arity/type checks, frames, timing, visits, saves, and
  runner effects.

### Must leave untouched

- `host/racket/aloemacs-run.rkt`, the Term interface, Fs host, and every
  other host module
- `lib/text.aloe`, every other library, Gel, `aloe/eval.rkt`, and other
  language implementation files
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, accepted design specs,
  earlier local checkpoints, and project maps
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## State and construction

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

Append exactly `(history (List UndoFrame))` after `scroll-col` in
`AloemacsEditor`. Its constructor becomes
`(AloemacsEditor new text point quit scroll-row scroll-col history)`.
Use `(List empty)` for an initial history in the contextual field type. The
list is unbounded and newest first. A frame contains the receiver's **focused
`Text` value as it stands before the edit**, point, and both origin fields.
Keep the zipper structure; do not turn it into source lines or a string, and
do not store a whole editor, `quit`, `fs`, or `path` in a frame. History and
frames are ordinary immutable Aloe values.

The initial editor in `main.aloe` has empty history. Every successful visit
to an existing regular file or a missing new-file path constructs an editor
with empty history, point `(0, 0)`, quit `#f`, and origin `(0, 0)`. A visit
never imports the source session's history. Rejected visits return `None`
and leave the source session, including history, unchanged.
`AloemacsSession` keeps exactly its existing three fields and no second
history.

## Editor transitions and session behavior

Preserve the existing signatures and `Text` edit contracts of `insert`,
`newline`, and `backward-delete`. For **each** successful
`Some(EditResult)`, cons exactly one pre-edit `UndoFrame` onto the receiver's
history and build the result editor from the result's `text` and `position`,
the receiver's `quit` and current origin, and that extended history. The
success criterion is `Some`, so even direct `(editor insert "")` pushes when
`Text.insert` succeeds. A Backspace join at column 0 is one frame. An edit
returning `None`, and Backspace at `(0, 0)`, preserve all fields and history.

`move-left`, `move-right`, `move-up`, `move-down`, `ensure-visible`,
`request-quit`, unknown keys, and frame rendering create no frame and
preserve the existing history list through any rebuild. Save also preserves
it. `handle-key` on an already quit editor stays absorbing before dispatch,
including for `"undo"` and edit keys. Quit itself does not create a frame.

Add `(editor undo) -> AloemacsEditor`. Empty history yields an editor
structurally equal to the receiver. Otherwise restore `text`, `point`,
`scroll-row`, and `scroll-col` from the first frame, set history to the old
list's `rest`, and retain the receiver's current `quit`. Undo pushes no
frame and retains none for redo. Direct `undo` on a quit editor follows this
same pure rule; quit only blocks `handle-key`. Do not fit or frame inside
`undo`. The runner's existing fit-before-frame step handles a restored
point outside the captured viewport after a later movement or resize.

Add exact `"undo"` to editor `handle-key` before the length-one printable
fallback. File session's existing `handle-key` checks quit, handles
`"save"`, then delegates other keys to the editor; that delegation handles
`"undo"`. Direct session `insert`, `newline`, and `backward-delete` keep
their existing delegation and gain history through the editor. No session
command or field is added. Undo never calls `Fs.write` or changes the bound
path. A later save writes the exact then-current `(text to-string)`, even
after undo; untitled save remains a no-op.

The frame records the point and **both** origin values at the edit, even if
arrows or fitting changed them since a previous edit. Intervening movement,
fit, or save is not an undo step. Undo after an edit restores that edit's
pre-edit point and origin, not a later moved or fitted state. If only
movement, fit, and save have happened on a fresh editor, undo is an equal
no-op. All pre-undo editor and `Text` values remain unchanged.

## Physical key normalization

Add exactly one guarded Ctrl-Z clause to `tkeymsg->aloe-key` in
`host/racket/term.rkt`, before the printable character clauses. It returns
`"undo"` only when `key` is `#\z`, `mods` is exactly `'(ctrl)`, and
`char` is either `#f` or `#\z`. Both of these must work:

```racket
(make-tkeymsg #\z '(ctrl) #f)  ; => "undo"
(make-tkeymsg #\z '(ctrl) #\z) ; => "undo"
```

The second shape is the observed live decoder form. Printable `z` remains
`"z"` and inserts. Neighboring modifier shapes and existing Return,
Backspace, arrows, Escape, Ctrl-S, and unknown-key mappings retain their
behavior. Do not add a prefix map, Term method, or runner key branch.

## Tests first and verification

Write the three focused no-TTY test files **before** implementation. Use
the checked Aloe driver for sends and field inspection, and Racket host
doubles rather than a physical file or terminal. Assert history length or
individual frames wherever needed to distinguish an equal no-op from an
extra push. Compare complete `Text.to-string`, `Position`, both origin
fields, and history across transitions.

1. `tests/aloemacs/undo-editor.rkt`: check `UndoFrame` and editor field
   types, the six-argument constructor, and `undo`/`handle-key` result
   types. Cover insert then undo, newline then undo, Backspace within a line
   then undo, and Backspace joining at column 0 then undo. Cover two edits,
   an arrow after the second edit, two undos in newest-first order, and a
   no-op at the history bottom. Check fresh undo; successful direct empty
   insertion; a failed edit and Backspace at `(0, 0)` making no frame;
   arrows, `ensure-visible`, unknown keys, `request-quit`, and frame
   rendering making no frame. Show that a frame captures the pre-edit
   focused `Text`, point, `scroll-row`, and `scroll-col`, and undo restores
   them exactly despite later movement or fit. Show old editor and `Text`
   values still equal themselves. Test direct `undo` on a quit editor and
   post-quit `handle-key "undo"` and edit keys as no-ops.
2. `tests/aloemacs/undo-session.rkt`: with an Fs double, visit an existing
   file and a missing path from a session that already has edits, and check
   each new history is empty. Check a rejected visit preserves its source.
   Cover both direct and handled session edits and delegated `"undo"`.
   Prove save and `"save"` do not add history, undo does not write, and a
   later save writes the restored exact text to the same bound path. Retain
   Ctrl-S behavior through session dispatch and an untitled save no-op.
3. `tests/aloemacs/undo-key-mapping.rkt`: call `tkeymsg->aloe-key` directly
   with both exact Ctrl-Z shapes, plain printable `z`, neighboring modified
   `z` forms, and representative Ctrl-S and Backspace messages. Only the
   two specified Ctrl-Z shapes become `"undo"`; printable `z` becomes
   `"z"`. No test needs a TTY.

Update existing test constructor expressions and their direct type/arity
expectations for the new history argument, including the nine test files
listed in **May edit**. Keep their other assertions. In particular, a
formerly valid five-argument editor constructor is now invalid, and a
six-argument construction with `(List empty)` is valid in its field context.

From the project root, run:

```sh
raco test tests/aloemacs
raco test tests
git diff --check
```

The application launch remains `racket host/racket/aloemacs-run.rkt`, with
an optional path argument. A live Ctrl-Z TTY probe is optional and is not
an acceptance condition.

## Acceptance and stop

- Each successful insert, newline, and either form of backward delete
  contributes exactly one reversible pre-edit frame; failed edits contribute
  none. Repeated undo restores newest first and stops at empty.
- Movement, fit, save, quit, unknown keys, ordinary rendering, and post-quit
  keys never push. Visit and initial construction start empty history.
- Undo restores the saved focused `Text`, point, and both origin fields,
  retains current quit, and leaves all earlier values unchanged. Session
  delegation and exact save strings still work without an undo write.
- Exactly the two specified Ctrl-Z message shapes normalize to `"undo"`;
  printable `z` and established key mappings keep working.
- The focused and full test commands pass, and `git diff --check` is clean.
  Report the files changed and the verification results, then stop for human
  review. There is no aloemacs-undo 001 in this plan.

Do not add redo, an undo tree, edit grouping, inverse-span rebasing,
source resplitting, a nested editor history frame, `C-x u`, prefix maps,
minibuffer, dirty flags, backup files, status messages, windows, scroll
margin, paint cache, `Vector`, mutation, a compiler, or Boids. Do not
change public `Text.replace` semantics or any language law.
