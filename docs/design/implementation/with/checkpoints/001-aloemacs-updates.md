# with 001 — Aloemacs field updates

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Use selector-position `with` for every reconstruction of an existing
`(fields ...)` instance in Aloemacs. Keep each method's name, its
parameters, and its behavior. The line count should fall where a
method currently repeats fields it does not change. A method that
changes every field still uses `with`, so two same-typed fields
cannot be swapped unnoticed.

Stop when the named sites are converted, the programs still pass the
tests below, and no behavior has changed.

Do not convert a construction of a new value into `with`. Do not
edit `main.aloe`. Do not issue 002. Do not change the language.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. `SPEC.md` §4.12
is the law for `with`. This checkpoint chooses where Aloemacs uses it.

- Identity is **with 001**. File:
  `docs/design/implementation/with/checkpoints/001-aloemacs-updates.md`.
  Number this locally. Do not add a global checkpoint or a
  `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Predecessor: **with 000** is implemented in the working tree and
  discussion-reviewed. Its form is available. Do not revert it, and
  do not edit the kernel, `SPEC.md`, or `docs/decisions.md`.
- Read [`docs/workflow.md`](../../../../workflow.md) and `SPEC.md`
  §4.12 before editing. The Aloemacs sources are
  `examples/aloemacs/editor.aloe` and `examples/aloemacs/file.aloe`.

`with` evaluates the receiver once, then each written value once, in
written order, against that original receiver. Pair names bind
nothing. A parameter may share a field's name: the pair name is the
field, and the value expression sees the parameter.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe`
- `examples/aloemacs/file.aloe`

### Must leave untouched

- `examples/aloemacs/main.aloe` and every other `.aloe` program.
- The kernel, `SPEC.md`, `docs/decisions.md`, `tests/with/`, and
  every other test. Test fixtures that build a session with
  positional `new` are constructions. Leave them.
- `tests/parenthetical-construction/session.rkt`. It loads `main.aloe`
  and compares the startup value. This slice does not change that
  startup.
- This folder's README, both checkpoint files, `CHECKPOINTS.md`,
  Gel, and unrelated working-tree changes.

If a test fails because it snapshots the source of a converted
method, stop and send this checkpoint back. If another file is
necessary, stop and send it back. If the slice cannot fit one
implementer conversation, stop and say which classes are done rather
than leaving a class half converted.

## The rule

Replace `Class new` with `(receiver with (field expr) ...)` when the
`new` copies one or more stored fields from an existing instance of
that class. The receiver is that instance: usually `self`, and
otherwise the local the fields are read from (`view`, `session`,
`buffer`, `windows`, `focused`).

Write a pair for every field the `new` does not simply copy. Copy
the value expression into the pair. Do not rewrite it, reorder it,
or drop an `(if #t (Option None) (Option Some ...))` witness. Omit
the fields that were `(receiver field)`.

A method whose selector is `with-mark`, `with-editor`, or any other
`with-` name stays a method. The special form is only the `with`
token in the selector position. Calls of those methods stay calls.

When the same pure buffer update is currently computed twice, name
it once with `let` and use that name in both fields. Do this in
`AloemacsSession.with-editor`, `with-kill-state`, and `with-search`.
Do not introduce a `let` anywhere else.

Keep the comments in `split-window` and `enter-view`. They record
ordering that the conversion must not change.

## Shapes to copy

A parameter that shares the field name:

```scheme
(with-origin (scroll-row Int) (scroll-col Int) AloemacsEditor
  (self with
    (scroll-row scroll-row)
    (scroll-col scroll-col)))
```

A replacement that must see the original fields. The history frame
stores the editor from before the edit:

```scheme
(from-edit (result EditResult) AloemacsEditor
  (self with
    (text (result text))
    (point (result position))
    (history
      ((self history) cons
        (UndoFrame new
          (self text)
          (self point)
          (self scroll-row)
          (self scroll-col))))))
```

`UndoFrame new` stays. It builds a new frame.

A prompt field computed from the parameter, not from the field of
the same name:

```scheme
(with-completion (text String) (note String) (lines (List String))
                 AloemacsPrompt
  (self with
    (text text)
    (column (if (text = (self text)) (self column) (text len)))
    (completion-note note)
    (completion-lines lines)
    (completion-matches (List empty))
    (completion-start 0)))
```

A stored path is an `Option`. The method still accepts a `Path`:

```scheme
(with-path (path Path) AloemacsBuffer
  (self with (path (Option Some path))))
```

One buffer value, used by the buffer list and the windows:

```scheme
(with-editor (editor AloemacsEditor) (AloemacsSession H)
  (let ((buffer ((self current-buffer) with-editor editor)))
    (self with
      (buffers ((self buffers) with-current-buffer buffer))
      (windows ((self windows) with-buffer buffer)))))
```

## Sites

Convert every `Class new` in these methods. Also convert the
`AloemacsView new` expressions inside the tree methods, using the
existing `view` as the receiver. Also convert the `AloemacsWindows new`
inside `enter-view`, using `(self windows)` as the receiver.

`AloemacsEditor`: `with-origin`, `ensure-visible`, `with-mark`,
`clear-mark`, `with-text-and-point`, `from-edit`, `undo`,
`request-quit`.

`AloemacsPrompt`: `with-completion`, `with-completion-page`,
`clear-completion`, `insert`, `backward-delete`, `move-left`,
`move-right`, `line-start`, `line-end`.

`AloemacsBuffer`: `with-editor`, `with-path`.

`AloemacsBuffers`: `with-current-buffer`, `focus-next`,
`focus-previous`, `insert-after`, and each `AloemacsBuffers new` in
`remove-current`.

`AloemacsView`, from the surrounding `view`: the leaf of
`AloemacsWindowTree.with-toggled-lock`, both views built in
`with-split`, the leaf of `with-view-buffer`, and the leaf of
`retarget-buffer`.

`AloemacsWindowRect`: `top`, `bottom`, `left`, `right`.

`AloemacsWindows`: `with-split`, `with-toggled-lock`, `with-buffer`,
`without-buffer`, `with-size`.

`AloemacsSession`: `with-current-path`, `with-active-prompt`,
`with-waiting-command`, `clear-waiting-command`, `submit-prompt`,
`cancel-prompt`, `kill-buffer`, `selected-buffers`, `with-editor`,
`with-kill-state`, `with-search`, `with-echo`, `split-window`,
`enter-view`, `toggle-window-lock`, `with-prefix`, `clear-prefix`,
`visited`, `ensure-visible`.

## Leave as `new` or `new*`

These build a value. They do not copy fields out of an existing
instance of that class.

- All of `examples/aloemacs/main.aloe`.
- `start-prompt` and `start-command-prompt`: the fresh
  `AloemacsPrompt new`.
- The `(if #t (Option None) (Option Some (AloemacsPrompt new ...)))`
  witness in `submit-prompt`, and every other `(if #t ...)` type
  witness. The session or buffer around the witness still converts.
- Fresh editors and buffers in both `add-buffer` methods, in
  `visited`, and in the empty branch of `remove-current`. The
  `AloemacsSession new` or `AloemacsBuffers new` around them converts.
- `UndoFrame new` inside `from-edit`.
- `AloemacsWindowTree` constructor calls: `Leaf`, `Below`, and
  `Right`. Only the `AloemacsView` payload converts.
- `AloemacsWindowRect new` in `AloemacsWindows.text-rect` and
  `AloemacsSession.root-rect`.
- `Position`, `Span`, `Text`, `Option`, `AloemacsModeLine`,
  `AloemacsCompletionScan`, `AloemacsSearchScan`, `AloemacsKeymap`,
  and `Fs` constructions.

After the edit, `editor.aloe` and `file.aloe` contain no
`AloemacsEditor new`, `AloemacsPrompt new` used as an update,
`AloemacsBuffer new` used as an update, `AloemacsBuffers new`,
`AloemacsView new`, `AloemacsWindows new`, or `AloemacsSession new`.
A remaining `AloemacsEditor new` or `AloemacsBuffer new` is one of
the fresh constructions named above. A remaining `AloemacsPrompt new`
is a fresh prompt or a type witness. A remaining
`AloemacsWindowRect new` is `text-rect` or `root-rect`.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction/session.rkt
git diff --check
```

The checkpoint is complete when those tests pass, the whitespace
check is clean, the sites above are converted, the leave-list is
unchanged, and method names and signatures are unchanged. Report the
results and stop.

Do not commit. Do not start another checkpoint.
