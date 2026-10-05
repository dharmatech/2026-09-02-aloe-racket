# Charter — aloemacs completion

**Status.** The accepted spec is back in a **design conversation**
for one revision. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Revise [`spec.md`](spec.md) in place.
Checkpoints stay in `checkpoints/`.
[`checkpoints/000-complete-on-tab.md`](checkpoints/000-complete-on-tab.md)
is not ready to implement.
[`checker-recursion`](../../checker-recursion/) is not this series
and is not a predecessor. Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Revise the accepted specification for **prefix
completion on the find-file and save-as prompts**. The series
identity stays **aloemacs-completion**. Tab still finishes a
unique path component, adds `/` to a unique directory, and, when
it cannot add a character, shows the matching names above the
prompt. The revision moves the recursive character scan and
prefix fold off `(AloemacsSession H)`. Then **stop**. Do not
write checkpoints. Do not implement. Do not edit the checker.

This effort refuses a live list, fuzzy or partial matching,
moving through the names, buffer-name completion, `M-x`, `~`,
wildcards, history, `mkdir`, a directory browser, and Tab as
indent. Those stay later, so this spec stays small enough to
slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), the authority
   in §6, and the accepted [`spec.md`](spec.md).
2. Record the locked decisions in §4, including §4.9. Do not
   reopen §4.1–§4.8. Keep the accepted prompt fields, reads,
   notes, prepared lines, and prefilled starters.
3. There is no open question left. §4.9 closes placement.
4. Revise `spec.md` in place. In §2 and §3.3, replace the
   sentences that put the scans and folds on the generic
   session and that forbid every new class. Keep the two
   checkpoints in §4.8. A later checkpoint-manager
   conversation rewrites **aloemacs-completion 000** after
   the human accepts the revision.
5. Stop. The human reviews the spec. Do not write or refresh
   the checkpoint files in this conversation.

Keep the spec to the two checkpoints in §4.8. A live list, a
selected row, a directory buffer, or a change to what Return
opens are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../prompt-commands/`](../prompt-commands/) | `C-x C-f`, `C-x C-w`, and `C-x b` start the prompt. Return runs the waiting command on the typed string. Escape runs nothing. A missing file opens empty and bound. A directory, symlink, or other node fails |
| [`../minibuffer/`](../minibuffer/) | The prompt is a label, a text, and a column on the echo row. Insert, backspace, and the horizontal motions edit that line. Named keys other than Return and Escape are ignored while it is active |
| [`../windows/`](../windows/) | The frame is a window tree plus one full-width echo row. Fit and frame use the root rectangle `(0, 0, columns, rows - 1)` when `rows >= 2` |
| [`../mode-line/`](../mode-line/) | A leaf at least two rows tall paints its buffer name on its last row. A shorter leaf does not. The prompt cursor stays on the terminal's last row |
| [`lib/fs.aloe`](../../../../../lib/fs.aloe) | `current`, `path`, `parent`, `name`, `inspect`, and `entries` exist. `entries` lists children of a directory. `names` on a non-directory is a host error |
| [`lib/string.aloe`](../../../../../lib/string.aloe) | `starts-with?` is a library method. `take` is clamped to the string |

Layers 1–18 are implemented. Final human review of windows and
of the mode line may still be open. This series does not wait
for that review and does not edit those specs.

aloemacs-idle-echo 000 is **not** a predecessor. It may land
before or after this series. This series does not edit that
checkpoint and does not change the idle echo payload. An active
prompt still owns the last row either way.

**Checker constraint.** `(AloemacsSession H)` is a legacy generic
`(fields ...)` class. Method bodies of that form are checked
again on every send, so a recursive send on that receiver does
not finish checking. Nongeneric classes, including
`AloemacsPrompt`, are checked once at definition. `SPEC.md`'s
recursive golden is `(Tree T)` with explicit constructors, also
checked once. This series does not change `aloe/` and does not
take [`checker-recursion`](../../checker-recursion/) as a
predecessor.

**Why this layer:** find-file and save-as already read a path,
and the prompt starts empty. Tab cannot yet complete one
component or show the names in a directory.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Return and Escape keep today's effects.** Find-file still
   reuses a buffer, opens a regular file, accepts a missing
   path as an empty bound buffer, and fails on a directory,
   symlink, or other node. Save-as still writes the current
   text or fails as it does now. Select-buffer still matches
   the exact name. An empty submission still fails with no
   filesystem write. The typed text, not a highlighted name,
   is what Return submits.
2. **The file prompts open ready to complete.** Find-file
   starts in the selected buffer's directory, with a trailing
   `/`. A pathless buffer starts in `(fs current)`, also with
   a trailing `/`. Save-as starts at the selected buffer's
   full path when it has one, and in that same directory when
   it does not. The cursor is at the end. The text is
   editable. Opening the prompt does not list a directory.
3. **Tab completes the last component.** A no-TTY test, on an
   Fs double, can finish a unique file, add `/` to a unique
   directory, insert a shared prefix, and leave the text alone
   when nothing matches. Names that start with `.` appear only
   when the component being typed starts with `.`. The
   spelling before the last slash stays as typed.
4. **An ambiguous Tab shows the names.** When Tab cannot add a
   character and more than one name matches, the frame shows
   those base names above the prompt, directories ending in
   `/`, and the prompt stays on the last row. The window
   rectangle shrinks by the rows used. Typing or backspace
   clears the names. The next Tab looks again.
5. **The current buffer stays current until Return.** Prefill,
   Tab, and painting the names do not change its text, point,
   undo, mark, scroll, path, or name, and do not read or write
   a file. Select-buffer and a bare prompt ignore Tab. Idle
   Tab does not indent. Search, quit, and a pending prefix
   keep their existing precedence.
6. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

A hands-on tour can wait until both checkpoints are green.
This bar is the no-TTY test.

## 4. Locked decisions (record these; do not reopen 4.1–4.9)

### 4.1 Which prompts complete

Find-file and save-as share one path completer. Select-buffer
does not. A prompt with no waiting command does not. Tab on
those prompts changes nothing and calls no filesystem
operation.

`C-x C-f` stays this prompt. It does not open a directory
buffer. Return on a directory still fails, as find-file fails
today. The list is not a selection. There is no highlighted
row, and Up and Down stay ignored while the prompt is active.

Completion reads the filesystem only on Tab, and only for
those two prompts. It may send `current`, `path`, `parent`,
`name`, `inspect`, and `entries`. It does not send `read` or
`write`. It does not send `names` or `entries` unless
`inspect` has returned `Some Directory`. A host error from a
real unreadable directory still propagates. Tests use a
readable double and do not need a new error channel.

### 4.2 What the prompt contains at the start

The editable text is data, not part of the label.

| Start | Initial text |
|---|---|
| Find-file, selected buffer has a path | That path's parent directory, ending in `/` |
| Find-file, pathless buffer | `(fs current)` text, ending in `/` |
| Save-as, selected buffer has a path | That path's text, exactly |
| Save-as, pathless buffer | The same directory text as pathless find-file |
| Select-buffer, or `start-prompt` | `""`, as today |

The cursor starts at the end of that text. A refused start
still returns the receiver unchanged and does not prefill.

Directory text comes from `Fs.parent` when the buffer has a
path. If the parent is `None`, use the path text itself. If
the directory text already ends in `/`, leave it. Otherwise
append one `/`. Root therefore stays `/`, and `/home/me`
becomes `/home/me/`. Save-as does not add a slash to a file
path.

`(fs path …)` still resolves on Return, as it does now.
Prefill uses the stored absolute text or `current`. This
series does not expand `~`.

Existing find-file and save-as proofs that assume an empty
prompt must account for this text. Their submitted outcomes
stay the ones the prompt-commands spec already requires. The
spec says how a proof types over the prefill or deletes it.
This series may edit those fixtures, and frame expectations,
only for the prefill, Tab, and the list rows.

### 4.3 What Tab does to the text

Tab completes the whole editable string and then puts the
cursor at the end when the text changes. The cursor column
does not choose the component. When the text does not change,
the cursor stays.

Split the text at the last `/`:

| Text | Directory string | Leaf |
|---|---|---|
| Contains `/` | The prefix through that slash | The suffix after it, possibly empty |
| No `/` | `""` | The whole text |

An empty directory string lists `(fs current)`. Any other
directory string is resolved with `(fs path directory-string)`
and then inspected. The characters of the directory string are
written back unchanged. Tab does not rewrite them to the
absolute spelling.

On `Some Directory`, send `entries` once. Keep an entry only
when its name passes both filters:

- `(name starts-with? leaf)`, case-sensitive
- if the name starts with `.`, the leaf starts with `.` too

`(fs name entry-path)` is the name. Order is the order
`entries` returns after that filter. Do not sort again.
`.` and `..` are already absent from `names`.

The common prefix is the longest string that is a prefix of
every remaining raw name. It is computed from those names,
not from the display spellings below. Use `take`, `drop`,
`len`, `=`, and `starts-with?`. Add no `String` method.

| Remaining names | Text | Shown besides the text |
|---|---|---|
| None | Unchanged | The note ` [No match]` |
| One, and the replacement differs from the text | Directory string, plus that name, plus `/` when the entry is `Directory` | Nothing |
| One, and the replacement equals the text | Unchanged | The note ` [Sole completion]` |
| Two or more, common prefix longer than the leaf | Directory string plus that prefix. No added slash | Nothing |
| Two or more, common prefix no longer than the leaf | Unchanged | The list in §4.4 |

A unique directory typed without its slash becomes `name/`.
The next Tab then has an empty leaf and lists inside it. A
file, a symlink, and an `Other` entry contribute their name
only. A symlink is not inspected as a directory, so Tab does
not list through it and does not give it a slash.

The notes are display. They are not part of the editable
text and not part of the submission. Each note begins with
one space, as written above. A later Tab recomputes from the
current text. It does not page and it does not cycle.

Insert and backspace clear the note and the list, then edit
as they do today. Left, right, line-start, and line-end do
not clear them. Return and Escape clear them by ending the
prompt, and then follow the prompt-commands rules.

### 4.4 The names above the prompt

The list exists only in the last row of the §4.3 table.
Display each remaining entry as its raw name. A `Directory`
entry adds a trailing `/` on screen. That slash is not part
of the common-prefix calculation.

Show one name per row, full width, with no selection marker.
Clip with `String.take` of `columns`, then `safe-cells`, the
same way the echo row is clipped. No ellipsis. A control in
a name paints as one space. The stored completion text keeps
the original characters.

At most eight list rows are prepared:

| Prepared names | Rows |
|---|---|
| 8 or fewer | Every display name |
| More than 8 | The first 7 display names, then one row `...(+N)`, where `N` is the count not shown |

Nine names therefore show seven names and `...(+2)`.

000 stores this prepared list and makes it readable without
painting it. 001 paints it. A note and a list are never both
present.

### 4.5 Keys, echo, and the buffer

`handle-key` keeps today's order: quit, then search, then an
active prompt, then a pending prefix, then the idle map.

| When `"tab"` arrives | Result |
|---|---|
| Session already quit | Unchanged session |
| Search active | The existing rule for any other key: end search, then idle dispatch |
| Prompt active, find-file or save-as | §4.3 |
| Prompt active, anything else | Unchanged prompt. No filesystem call |
| Prefix pending | Today's miss: cancel the prefix and consume the key |
| Idle | Today's miss for a named key: echo `""`, no insert, no indent |

`"tab"` has length greater than 1, so the idle default does
not insert it. No keymap binding is added for it.

The stored echo token stays `""`, `"saved"`, or `"failed"`.
Showing a note, a list, or a prefilled prompt does not write
the token. The echo vocabulary does not grow. The note is
painted on the prompt row, after the editable text:
label, text, note, then `take`, then `safe-cells`. The
cursor still addresses the editable text. The existing prompt
clamp keeps that column on the echo row.

Prefill, Tab, clearing, and painting do not change the
current buffer's text, point, quit flag, undo, mark, scroll,
path, or name. They do not push an `UndoFrame`. They do not
switch, add, or kill a buffer. They do not arm or clear a
pending prefix except where the table above already does.

### 4.6 Where the rows go

The prompt stays on the terminal's last row whenever
`rows >= 2`. The cursor stays on that row during a prompt.
List rows sit immediately above it, below the window tree.
They are full width. They have no cursor.

Let `wanted` be the number of prepared list rows, or 0 when
the list is absent. The painted count is

```text
list-rows = min(wanted, max(0, rows - 2))
```

when `rows >= 2`, and 0 when `rows < 2`. The root rectangle
height becomes `rows - 1 - list-rows` while a list is
painted. Single-frame, multi-frame, and the too-small-tree
fallback all use that height. Mode-line rules then apply to
the leaves of that shorter rectangle, unchanged: a leaf at
least two rows tall still keeps its last row for the name.

Paint only the first `list-rows` prepared lines. Do not
recompute `...(+N)` when the terminal cuts the list short.
When `list-rows` is 0, Tab still updates the text and the
note. The note shares the echo row. At `rows = 1` there is
still no echo row, and no list row.

When the list is absent, the root height, the mode line, and
the idle echo payload stay exactly as they are. This series
does not give the text area the echo row.

The frame remains one string and one `term write`. Fit still
runs before frame in the runner. Fit's text height follows
the shorter root while the list is showing, through the
existing `text-rows` rule. This series does not edit
`host/racket/aloemacs-run.rkt`.

### 4.7 The Tab key

In `host/racket/term.rkt`, map a plain Tab before the
printable branches of `tkeymsg->aloe-key`:

| tkeymsg key | mods | char | Aloe key |
|---|---|---|---|
| `#\tab` | exactly `'()` | `#f` or `#\tab` | `"tab"` |

Shift-Tab stays on the existing unsupported path. Do not add
a Term method. The byte Tab already arrives as `#\tab`; do
not add a second Ctrl-I mapping.

Outside this mapping, Term is unchanged.

### 4.8 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-completion 000** | Prefill. The `"tab"` key. The §4.3 result, including the note and the prepared list, readable with no extra frame rows. Select-buffer and a bare prompt ignore Tab. Idle Tab does not indent. Return and Escape keep today's effects. The window rectangle is still `rows - 1` |
| **aloemacs-completion 001** | The prepared list is painted under §4.6. The prompt stays on the last row. A short terminal shows only the lines that fit. With no list, frames match 000 |

000 is testable once Tab changes the prompt and a test can
read the prepared lines. 001 is testable once 000 is green.
The manager writes 000 only, then stops. Do not collapse
them: the completion result has to be specified before the
extra rows are worth a checkpoint.

If Term-plus-prefill and the Tab result cannot share one
implementer conversation, the spec may split those two
pieces and keep the paint checkpoint last. The split adds
no feature. The manager still writes one checkpoint at a
time.

### 4.9 Where the recursive scans live

`complete-prompt`, the Fs queries, the prompt result, the note,
and the prepared lines stay on the session. The character scan
and the common-prefix fold call themselves. Those recursive
sends do not live on `(AloemacsSession H)` or on any other
legacy generic `(fields ...)` class.

The spec chooses one receiver the checker already finishes:

- a new nongeneric class, the small value the session asks
- methods on an existing nongeneric class, such as
  `AloemacsPrompt`
- a new generic class with explicit constructors, the
  `(Tree T)` form

The session still performs `current`, `path`, `parent`, `name`,
`inspect`, and `entries`. The recursive receiver uses the
existing `String` and `List` messages from §4.3. It adds no
host method and no `String` method. Another `(fields ...)`
generic is not an allowed receiver.

The accepted spec already named the prompt fields, the reads,
and the prefilled starters. Keep those names. `start-prompt`
still starts an empty line. A bare `(Option None)` at an
untyped constructor still uses the lawful `if` form.

## 5. Open questions

None. §4.9 closes placement. Do not reopen §4.

## 6. Authority

- [`../README.md`](../README.md) — layer order. This layer
  is completion
- [`../prompt-commands/spec.md`](../prompt-commands/spec.md)
  — find-file, save-as, select-buffer, and Return. Its
  refusal of prefill and of completion is superseded only
  by §4.1 and §4.2. Return's outcomes stay
- [`../minibuffer/spec.md`](../minibuffer/spec.md) — the
  prompt value, the echo row, ignored keys, and the cursor
  clamp. §4.3 adds `"tab"` for the two file prompts
- [`../windows/spec.md`](../windows/spec.md) — the tree and
  the single echo row below it. §4.6 inserts list rows
  between them only while a list is painted
- [`../mode-line/spec.md`](../mode-line/spec.md) — leaf last
  rows and the root height. §4.6 changes that height only
  while a list is painted
- [`../echo/spec.md`](../echo/spec.md) — the reserved last
  row and the three echo tokens
- [`../safe-cells/spec.md`](../safe-cells/spec.md) —
  controls paint as one space after clipping
- [`../keymap/spec.md`](../keymap/spec.md) — quit, search,
  pending, and the idle miss used for `"tab"`
- [`lib/fs.aloe`](../../../../../lib/fs.aloe) and
  [`host/racket/fs.rkt`](../../../../../host/racket/fs.rkt)
  — `entries` and the `names` error on a non-directory
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — §4.7 is the only new key
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — session, prompt, and frame
- [`SPEC.md`](../../../../../SPEC.md) §9 — the lawful
  `Option` form

Behavior catalogs, not law: e's ordinary prompt completion
in `/home/dharmatech/src/e/manual/PROMPTS.md`, e's Finder in
`/home/dharmatech/src/e/manual/FINDER.md`, and Legmacs in
`/home/dharmatech/src/legmacs/legmacs/completion.lg` and
`minibuffer.lg`. This charter already chose among them.

`SPEC.md` remains language law. This series does not amend
it. Do not edit the echo, windows, mode-line, minibuffer,
prompt-commands, or idle-echo documents. Where one of those
specs describes Return, the idle echo payload, or the root
height with no list, that spec wins. Where this charter
describes prefill, Tab, and list rows, this charter wins.
After the human accepts `spec.md`, that file is the design
authority for the checkpoint manager and the implementers.

## 7. Non-goals

- A list that updates on each typed character
- Fuzzy, substring, or partial matching
- Up, Down, or a highlighted row
- Completion for select-buffer, `M-x`, or command names
- `~`, wildcards, prompt history, or `mkdir`
- A directory browser, or opening a directory with Return
- Tab as indent, in or out of a prompt
- Following a symlink to decide `/` or to list inside it
- Paging the list, or cycling matches into the text
- A new echo token, a dirty bit, or prompt undo
- A new host method, a `String` method, a `Text` method, a
  `List` index, or a `SPEC.md` row
- A runner change, or a Term method
- Editing the idle-echo checkpoint, or changing the idle
  payload
- Mirror, mutation, delegation, or a `CHECKPOINTS.md` entry
- A checker change, an edit under `aloe/`, or recursive
  methods on a legacy generic `(fields ...)` class
- Taking [`checker-recursion`](../../checker-recursion/) as
  a predecessor or an assignment

## 8. Handoff

- Series identity: `aloemacs-completion`.
- Checkpoint 000 is spoken **aloemacs-completion 000** and
  filed as `checkpoints/000-complete-on-tab.md`. Checkpoint
  001 is spoken **aloemacs-completion 001** and filed as
  `checkpoints/001-show-matches.md`. Numbers are three
  digits, start at 000, and are never renumbered. The slug
  is lowercase words separated by hyphens. The checkpoint
  manager writes one checkpoint, then stops.
- Intended order: §4.8. 000 first. Paint stays last if the
  spec splits 000.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`, plus the Tab mapping
  in `host/racket/term.rkt`. Tests stay in
  `tests/aloemacs/`. The design folder receives `spec.md`
  and later checkpoints, not the program.
- After the human accepts the revised `spec.md`, that file
  is the design authority for the checkpoint manager and
  the implementer. The manager rewrites checkpoint 000
  against §4.9, then stops. This charter is the assignment
  for the spec writer only.
  [`checker-recursion`](../../checker-recursion/) is not the
  next conversation.

If you have been told to read this file, this is the whole assignment.
