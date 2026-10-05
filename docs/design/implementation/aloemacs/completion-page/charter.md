# Charter — aloemacs completion page

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **paging the name list
on the find-file and save-as prompts**. The series identity is
**aloemacs-completion-page**. Tab still completes one path
component. When that Tab paints a list, a page key moves a
window over the same matches, so a name that the first window
left behind `...(+N)` can be shown. Return still submits the
typed text. The list stays a display, with no highlighted row.
Then **stop**. Do not write checkpoints. Do not implement.

This effort refuses a selected row, Up or Down moving through
the names, cycling a match into the text, a list that updates
on each typed character, fuzzy or partial matching, completion
for select-buffer or `M-x`, a directory browser, and any change
to what Return opens. Those stay later, so this spec stays
small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-completion-page 000** under
   `docs/design/implementation/aloemacs/completion-page/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the checkpoints in §4.8. A highlighted name, a
directory buffer, or a second meaning for Tab are defects in
this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../completion/`](../completion/) | Accepted spec. aloemacs-completion 000 and 001 are in the working tree: find-file and save-as prefill, Tab completes the last component, and an ambiguous Tab that cannot extend the text paints at most eight prepared lines above the prompt. Nine or more matches prepare seven names and `...(+N)`. The prompt stays on the last row. The root shrinks by the painted list rows |
| [`../prompt-commands/`](../prompt-commands/) | Return on find-file and save-as runs the waiting command on the typed string. Escape runs nothing |
| [`../minibuffer/`](../minibuffer/) | The prompt is a label, a text, and a column on the echo row. Insert, backspace, and the horizontal motions edit that line |
| [`lib/list.aloe`](../../../../../lib/list.aloe) | `fold`, `map`, and `reverse` exist. The host `List` messages are `len`, `empty?`, `first`, `rest`, `cons`, and `of` / `empty`. There is no index |

This series does not wait on a status edit in the completion
README, and it does not edit that spec, that charter, or those
checkpoints. It does not edit the idle-echo checkpoint.

**Checker constraint.** `(AloemacsSession H)` is a legacy generic
`(fields ...)` class. Method bodies of that form are checked
again on every send, so a recursive send on that receiver does
not finish checking. `AloemacsCompletionScan` is fieldless and
nongeneric; the completion spec already puts the character scan
and the prefix fold there. A walk that skips names uses that
same kind of receiver. This series does not change `aloe/` and
does not take checker-recursion as a predecessor.

**Why this layer:** Tab on `/` with an empty leaf already lists
a directory. Past eight prepared rows the last row is a count,
and another Tab builds that same first window again. The names
behind the count have nowhere to appear.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Every filtered name can be shown.** On an Fs double whose
   filtered matches fill more than two windows, repeating the
   forward key reaches a window that displays the last match.
   The typed text and the cursor column stay the same. The
   page key performs no filesystem operation.
2. **The first window is still Tab.** A Tab that cannot extend
   the text shows the start of the filtered matches. Another
   Tab does not advance the window. It asks the directory
   again, as completion does now, and shows the first window
   of whatever that query returns.
3. **Return and Escape keep today's effects.** The typed text,
   not a displayed name, is what Return submits. Find-file and
   save-as keep the outcomes the prompt-commands spec requires.
   Select-buffer, a bare prompt, search, a pending prefix, and
   idle dispatch ignore the page key.
4. **The current buffer stays current.** Paging does not change
   its text, point, quit flag, undo, mark, scroll, path, or
   name, and does not read or write a file. It does not scroll
   the buffer and does not run the idle page commands.
5. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

A hands-on tour can wait until the checkpoints are green.
This bar is the no-TTY test.

## 4. Locked decisions (record these; do not reopen)

### 4.1 Which prompts page

Find-file and save-as share the page key. It acts only while
that prompt is showing a list from the last Tab. Select-buffer
does not page. A prompt with no waiting command does not. A
note (` [No match]`, ` [Sole completion]`), a unique
completion, and a common-prefix edit do not page.

When every filtered name is already in the prepared window,
the page key returns the session unchanged and sends nothing
to Fs. When the prompt is absent, or the key arrives during
quit, search, or a pending prefix, the existing `handle-key`
order stands and the key does not page.

`handle-key` keeps today's order: quit, then search, then an
active prompt, then a pending prefix, then the idle map.

### 4.2 What a page is

A page is a window over the display lines of the last Tab.
Those lines are the filtered matches completion already
computes: case-sensitive prefix of the leaf, names that start
with `.` only when the leaf starts with `.`, directory names
painted with a trailing `/`, order left as `entries` returns
it. This series does not sort again and does not change the
filter.

The prompt retains every display line from that Tab, and the
start of the current window. `completion-lines` stays the
prepared window that paint already reads. The retained lines
and the start are further prompt state. The spec names those
fields. They do not become session fields. The session keeps
its fourteen fields in the existing order.

The windows do not overlap and do not skip. The next window
starts at the first retained line that was not a name row in
the previous window. The last window is the tail. A window
that hides any retained line prepares those name rows and
exactly one summary row. A window that hides nothing prepares
only name rows. A window never prepares zero name rows while
any match exists, and it never prepares two summary rows.

The page key does not change the prompt text or column, does
not insert, and does not send `current`, `path`, `parent`,
`name`, `inspect`, `entries`, `read`, or `write`. Tab remains
the only completion read.

### 4.3 What Tab still does

Tab keeps the completion spec's result. A Tab that paints a
list sets the window start to the first retained line and
prepares the first window. A Tab that extends the text, or
that sets a note, clears the retained lines and the start,
as an edit clears the list today.

Insert and backspace clear the note, the prepared window,
the retained lines, and the start, then edit as they do
today. Left, right, line-start, and line-end keep all of
that display state. Return and Escape clear it by ending the
prompt, then follow the prompt-commands rules.

### 4.4 The page key is not Tab, Up, or Down

Tab does not page. Up and Down stay ignored while the prompt
is active. The list gains no selection marker and no
highlighted row. The page key does not cycle a match into
the text.

The page key is not a keymap command. Idle, search, and a
pending prefix do not page. Printable characters still
insert. The spec chooses the key in §5. It is either a named
key `tkeymsg->aloe-key` already produces, or one new plain
mapping specified the way completion specified `"tab"`. A
new mapping does not add a Term method. Modified forms of
that key stay on the existing unsupported path.

### 4.5 Where the rows go

The prompt stays on the terminal's last row whenever
`rows >= 2`. List rows sit immediately above it, below the
window tree, full width, with no cursor. Paint still reads
the prepared window and still clips with `take` of
`columns`, then `safe-cells`. A control paints as one space.
No ellipsis is added to a name.

The root height is still `rows - 1 - list-rows` while a list
is painted, and `list-rows` is still the prepared window
capped by `rows - 2`. A short terminal paints the first
prepared lines of the current window and does not recompute
the summary. At `rows = 1` there is still no list row.

When the list is absent, the root height, the mode line, and
the idle echo payload stay as they are. The frame remains
one string and one `term write`. Fit still runs before frame
in the runner. This series does not edit
`host/racket/aloemacs-run.rkt`.

### 4.6 The summary row

The summary is a display row, not a match and not part of
the typed text. It begins with the characters `...(+`, so it
cannot be read as a name `entries` returned. It carries the
count of retained display lines that are not name rows in
this window. The spec gives the exact spelling, including
what else the row may say, in §5.

The first window of a Tab that uses seven name rows and then
a summary keeps today's count: N is the number of matches
past those seven. Nine matches still prepare seven names and
`...(+2)` on that first window.

### 4.7 Reachability

Repeating the forward key reaches every retained display
line. The spec says whether the key stops on the last window
or wraps to the first. Either way, the last match has a
window, the typed text is unchanged, and a further press has
a specified result a test can assert.

A backward key is optional. If the spec adds one, it moves
to the previous window by the same step, and it does not
query the filesystem.

### 4.8 Checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-completion-page 000** | The prompt retains one Tab's display lines. The forward key rewrites the prepared window under §4.2–§4.7. The text and column stay. The page key makes no Fs call. Select-buffer, a bare prompt, idle, search, and a pending prefix do not page. Return and Escape keep today's effects. With the window length completion already paints, existing frames follow the new prepared lines |

000 is testable once a no-TTY session can read the prepared
window after the page key. If §5 keeps that window at the
eight prepared rows completion already paints, 000 is the
whole series.

A second checkpoint exists only when §5 makes the window
length depend on the terminal. That checkpoint paints the
taller window and proves the root height. It adds no second
feature. The manager writes 000 only, then stops. Do not
collapse a taller window into 000 if that slice no longer
fits one implementer conversation.

### 4.9 Where the skip walks

The session still owns Tab's Fs queries and the prompt
result. The walk that drops retained lines until the window
start calls itself. That recursive send does not live on
`(AloemacsSession H)` or on any other legacy generic
`(fields ...)` class.

The spec chooses one receiver the checker already finishes:

- methods on `AloemacsCompletionScan`
- one new fieldless nongeneric class
- methods on `AloemacsPrompt`, which is checked once

The walk uses the existing `List` messages. It adds no host
method, no `String` method, and no `List` index. Another
`(fields ...)` generic is not an allowed receiver.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **The key.** Which named key moves forward, and whether a
   second named key moves back. `"page-down"` and `"page-up"`
   already arrive from Term and are ignored while a prompt is
   active. The spec may choose them or another key under §4.4.
   State the result of the forward key on the last window, and
   of the backward key on the first window.
2. **Wrap.** On the last window, the forward key either leaves
   that window in place or returns to the first retained line.
   Say which, and give the same rule for a backward key if §5.1
   has one.
3. **Window length.** Either keep seven name rows, plus a
   summary row when lines remain hidden, or let the name rows
   grow to the rows the terminal can spare above the prompt.
   A spare row that is not part of the window stays with the
   file. The root still keeps at least one row. If the length
   depends on the terminal, use the size the session already
   stores from fit. Do not read Term from the key handler, and
   do not edit the runner. State the first window and a later
   window for a height that can show eight list rows, and for
   a height that clips them. A fixture with more matches than
   two full windows must still reach the last match by
   repeating the forward key.
4. **Summary spelling.** Keep the `...(+` prefix and the
   hidden-line count from §4.6. Say the exact row, including
   whether the count is every line outside this window or only
   the lines after it, and whether the row also shows the
   window's place. Give the row for the first window, a middle
   window, and the last window of an 18-line list.

## 6. Authority

- [`../README.md`](../README.md) — layer order. This layer is
  completion page
- [`../completion/spec.md`](../completion/spec.md) — prefill,
  Tab, the filter, the prepared window, and paint. §4 of this
  charter supersedes only the eight-line storage cap, the
  sentence that Tab does not page, and the non-goal that
  forbids paging. Tab's prefix result and the first window's
  seven-name count stay
- [`../prompt-commands/spec.md`](../prompt-commands/spec.md)
  — Return and Escape. Their outcomes stay
- [`../minibuffer/spec.md`](../minibuffer/spec.md) — the
  prompt value and the keys that edit it
- [`../windows/spec.md`](../windows/spec.md) — the tree and
  the echo row. List rows stay between them while a list is
  painted
- [`../mode-line/spec.md`](../mode-line/spec.md) — leaf last
  rows inside the root this series still shortens
- [`../keymap/spec.md`](../keymap/spec.md) — quit, search,
  pending, and idle dispatch
- [`lib/fs.aloe`](../../../../../lib/fs.aloe) and
  [`host/racket/fs.rkt`](../../../../../host/racket/fs.rkt)
  — `entries`. The page key does not call it
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — existing named keys. A new mapping is allowed only under
  §4.4
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — prompt, session, and frame
- [`SPEC.md`](../../../../../SPEC.md) §6 — `List`. This series
  does not amend `SPEC.md`

`SPEC.md` remains language law. Do not edit the completion,
echo, windows, mode-line, minibuffer, prompt-commands, or
idle-echo documents. Where one of those specs describes
Return, Tab's prefix result, or the root height with no list,
that spec wins. Where this charter describes the page window,
this charter wins. After the human accepts `spec.md`, that
file is the design authority for the checkpoint manager and
the implementers.

## 7. Non-goals

- A highlighted row, a selection marker, or Up and Down
  moving through the names
- Cycling a match into the typed text
- A list that updates as characters are typed
- Fuzzy, substring, or partial matching
- Changing the prefix filter, the dotfile rule, prefill, or
  the spelling before the last slash
- Completion for select-buffer, `M-x`, or command names
- `~`, wildcards, prompt history, or `mkdir`
- A directory browser, or opening a directory with Return
- Tab as indent, or Tab as the page key
- Following a symlink to decide `/` or to list inside it
- A new echo token, a dirty bit, or prompt undo
- A new host method, a `String` method, a `Text` method, a
  `List` index, or a `SPEC.md` row
- A runner change, or a Term method
- A new session field, or a change to the session's fourteen
  fields
- Editing the completion spec, its checkpoints, or the
  idle-echo checkpoint
- Mirror, mutation, delegation, or a `CHECKPOINTS.md` entry
- A checker change, an edit under `aloe/`, or a recursive
  method on a legacy generic `(fields ...)` class

## 8. Handoff

- Series identity: `aloemacs-completion-page`.
- Checkpoint 000 is spoken **aloemacs-completion-page 000**
  and filed as `checkpoints/000-page-the-list.md`. Numbers
  are three digits, start at 000, and are never renumbered.
  The slug is lowercase words separated by hyphens. The
  checkpoint manager writes one checkpoint, then stops.
- Intended order: §4.8. 000 first. A later number exists only
  when §5.3 makes the window length depend on the terminal.
  The spec names that slug. If the window stays seven name
  rows plus a summary, there is no 001.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`, plus `host/racket/term.rkt`
  only for a new plain key mapping §4.4 allows. Tests stay in
  `tests/aloemacs/`. The design folder receives `spec.md` and
  later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
