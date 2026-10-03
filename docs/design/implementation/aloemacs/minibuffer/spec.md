# aloemacs minibuffer specification

**Status: Accepted.** This file is the complete design
input for the **aloemacs-minibuffer** checkpoint manager and
implementers. They do not need the charter or this conversation.
This file is their design authority.
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law;
[`docs/workflow.md`](../../../../workflow.md) governs the roles and
review boundaries.

The session can start an editable, single-line prompt on the echo row.
The prompt owns its label, string, and cursor independently of the
current buffer. Return stores its string and ends the prompt; Escape
ends it without replacing the last submission. A checked no-TTY caller
can read that submission. No command uses it yet.

## 1. Series, predecessors, and authority

The series identity is **aloemacs-minibuffer**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Product code stays
in `examples/aloemacs/`; tests stay in `tests/aloemacs/`. This folder
holds the specification and later checkpoints, never the program.

There are exactly two checkpoints, in this order:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-minibuffer 000** | `checkpoints/000-prompt-value.md` | Prompt value, session fields, constructor migration, and the active echo row with its cursor, including clipping. Tests construct an active prompt directly. No start send, typing, submit, or cancel. |
| **aloemacs-minibuffer 001** | `checkpoints/001-type-submit-cancel.md` | Start, cursor editing, submit, cancel, and readable submission, with unchanged buffer state and idle behavior. |

Numbers are three digits, start at 000, and are never renumbered.
Slugs are lowercase words separated by hyphens. After the human accepts
this spec, the manager writes **000 only**, then stops. After human
review of its implementation, a later manager turn may write 001.
An implementer writes tests first, implements only the approved
checkpoint, runs verification, and stops when green. Do not combine
these layers or issue both checkpoint documents in one conversation.
The cursor clamp belongs entirely to 000; ignoring other keys adds no
forwarding machinery to 001. This design requires no 002. If either
slice cannot fit one implementer conversation, return the size problem
for review instead of widening the series.

The implemented Text through Buffer layers are predecessors. In
particular, Echo reserves the last row and fits the text above it;
Safe cells replaces displayed controls after clipping; Search owns its
keys and row; Keymap supplies idle dispatch and the one pending prefix;
Buffer supplies the current editor/path pair and the nonempty zipper.
aloemacs-runner-check 000 is **not** a prerequisite. Do not wait for it
or edit that checkpoint.

Authority for the preserved seams is:

- [`../README.md`](../README.md) and
  [`../explorations.md`](../explorations.md): layer order, Band 2 item 7,
  and the boundary before item 8's commands.
- [`../echo/spec.md`](../echo/spec.md): token vocabulary, text height,
  suffix composition, and the final cursor while the prompt is inactive.
- [`../safe-cells/spec.md`](../safe-cells/spec.md): one space per control
  after clipping; stored characters remain intact.
- [`../search/spec.md`](../search/spec.md): query, search keys, exit,
  point movement, and preservation of the stored echo token.
- [`../keymap/spec.md`](../keymap/spec.md): quit absorption, search
  precedence, pending-map consumption, idle commands, and save effects.
- [`../buffer/spec.md`](../buffer/spec.md): buffer ownership, current
  access, addition, switch, kill-buffer, visit, save, and fitting.

The implementation starting points are
[`file.aloe`](../../../../../examples/aloemacs/file.aloe) and
[`main.aloe`](../../../../../examples/aloemacs/main.aloe).
This spec extends session reconstruction with two fields and inserts
active-prompt dispatch after search. It supersedes Echo's final
text-cursor rule only while an active prompt is drawn. All predecessor
buffer, search, keymap, and inactive-frame results remain in force.
`SPEC.md` wins on syntax, types, sends, and immutability. The charter
assigned this design; it is not an additional input later conversations
need to interpret.

## 2. Product, host, and file boundary

This remains one window showing the current buffer. The prompt is a
separate immutable value, outside the buffer zipper. It is not an
`AloemacsBuffer`, `AloemacsEditor`, session, window, or search query.
No editor field or constructor changes. Prompt edits push no
`UndoFrame`, change no mark, and use no kill-ring entry. There is no
prompt undo.

The implementation is checked Aloe 0.1. Racket tests use the existing
checked driver, `rackunit`, and counted Fs doubles, without a TTY.
Keep the two existing loads in `file.aloe`. Declare the non-generic
`AloemacsPrompt` there after those loads and before the existing class
declarations; retain the existing declarations' relative order. The
new name does not clash with `safe-cell-controls`, `UndoFrame`, or any
loaded class. No new module, capability, dependency, or build step is
needed.

000 may edit `examples/aloemacs/file.aloe`,
`examples/aloemacs/main.aloe`, and the affected tests under
`tests/aloemacs/`. 001 may edit `examples/aloemacs/file.aloe` and its
focused tests under `tests/aloemacs/`. Their exact scopes are in §3.5
and §4.6. Leave `examples/aloemacs/editor.aloe`,
`host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, host
capabilities, libraries, the language implementation, `SPEC.md`,
`CHECKPOINTS.md`, and predecessor documents untouched.

The runner retains zero or one path argument, the `aloemacs-editor`
binding, fit-then-frame order, one frame String and one `term write`
per iteration, and `(aloemacs-editor quit)`. There is no key or argv
that starts the prompt. Its first consumer is a no-TTY checked send.

Explicit non-goals are find-file, save-as, selection by buffer name,
completion, prompt history, initial path/name text, `C-x C-f`,
`C-x C-w`, `C-x b`, `M-x`, another prefix, a prompt-start binding,
windows, splits, a mode line, buffer menu, dirty bit, confirmation
before killing, region painting, clipboard, and rewriting search
around the prompt. Do not add an `AloemacsCommand` constructor or an
`execute-command` arm. No Text method, List index, kernel message,
Term method, global checkpoint, `Vector`, mutation, inheritance,
macro, class method, delegation, Mirror, or new special form belongs
here. Evaluation remains send; function objects execute only through
`call`. Do not start Boids or the later command series.

## 3. Layer 000 — prompt value, state, and frame

### 3.1 Prompt representation and display sends

Declare `AloemacsPrompt` with exactly these ordered fields:

```aloe
(label String)
(text String)
(column Int)
```

The constructor is `(AloemacsPrompt new label text column)`. Generated
selectors read those three fields. `column` is a zero-based insertion
position in `text`, including the position immediately after its last
character. Valid values satisfy `0 <= column <= (text len)` and contain
no LF in `text`. A direct constructor's callers supply these invariants;
the generated constructor is not a new runtime validator. Session
transitions in 001 preserve them. Use String character units, matching
`len`, `take`, and `drop`, and the editor's one-character-per-cell rule.
There is no one-line Text, Position, viewport, history, or cached length
inside the prompt.

`label` may be empty or contain controls. It is display data and is
never part of the editable string or the submission. Add these methods
in 000:

| Send | Result | Contract |
|---|---|---|
| `(prompt row)` | `String` | Exactly `(label append text)`, before clipping or safe cells. |
| `(prompt screen-column columns)` | `Int` | For positive `columns`, the one-based cursor rule in §3.4. |

The join inserts **no separator**. A caller wanting `"Ask: "` supplies
that whole label, including the space. An empty label makes the text
start in screen column 1. No colon, space, path, or default label is
invented. Safe cells changes the painted row only.

### 3.2 Complete session shape and lawful startup

Append `prompt` and `last-submission` after `pending`. The complete
ordered fields become:

```aloe
(buffers AloemacsBuffers)
(fs (Fs H))
(echo String)
(searching Bool)
(query String)
(origin Position)
(wrapped Bool)
(failing Bool)
(kill-ring (List String))
(pending (Option (AloemacsKeymap AloemacsBinding)))
(prompt (Option AloemacsPrompt))
(last-submission (Option String))
```

`None` in `prompt` means inactive; `Some(prompt)` holds the whole active
value. There is no extra active flag or stack. `last-submission` begins
as `None`. Its generated read send, `(session last-submission)`, returns
`(Option String)`: `None` before the first submit, `Some("")` after an
empty submit, and `Some(text)` after any other submit. Reads do not
consume or clear it. This accessor exists in 000, although submitting
belongs to 001.

The constructor is
`(AloemacsSession new buffers fs echo searching query origin wrapped failing kill-ring pending prompt last-submission)`.
Existing field order remains a prefix. All ordinary reconstructions
thread both new fields. Startup in `main.aloe` is inactive with no
submission. Its lawful constructor is shown once here, after loading
`file.aloe` and with the existing injected `fs-host`:

```aloe
(define aloemacs-editor
  (AloemacsSession new
    (AloemacsBuffers new
      (List empty)
      (AloemacsBuffer new
        (AloemacsEditor new
          (Text from-string "")
          (Position new 0 0) #f 0 0 (List empty)
          (if #t (Option None) (Option Some (Position new 0 0)))
          0)
        (if #t (Option None) (Option Some (Path new "/typed-none"))))
      (List empty))
    (Fs new fs-host)
    "" #f "" (Position new 0 0) #f #f (List empty)
    (if #t (Option None) (Option Some aloemacs-global-keymap))
    (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
    (if #t (Option None) (Option Some ""))))
```

The unselected `Some` branches supply the concrete types of mark, path,
pending, prompt, and submission under `SPEC.md` §9. Every untyped
constructor fixture uses these `if` forms whenever an Option is absent.
A method whose expected field type supplies `T` may write
`(Option None)` directly. Do not change the checker or add a helper
whose argument is a concrete Option just to set either new field;
absent Options have the existing runtime dispatch limitation. Active
and submitted fixtures can use `Some` directly.

### 3.3 Reconstruction and direct operations

These rules are part of 000's field migration and remain in 001:

| Operation | New-field rule | Existing behavior |
|---|---|---|
| `with-editor`, direct editor wrappers, `with-kill-state`, `with-search`, `with-echo`, `with-prefix`, `clear-prefix`, `unchanged` | Preserve prompt and last submission exactly. | Keep each operation's existing buffer, echo, search, ring, and pending result. |
| Direct `save`, including its successful returned session | Preserve both. | Write only current text to current path; retain the existing Option outcome and effects. |
| Direct `add-buffer` (both arities), `switch-buffer`, `kill-buffer` | Preserve both, including an active line and its cursor. | Keep the existing selection, search/echo/pending resets, and buffer preservation or removal. They read no prompt text. |
| `ensure-visible` | Preserve both. | Fit only current with the existing text-height rule; fitting may change that editor's origins and remembered rows. |
| `frame` | Read only; preserve both. | Frame current from its fitted, stored origins, with §3.4's row choice. |
| Successful `visited` / `visit` | Set prompt to `None`; preserve last submission. | Replace only current with the existing fresh visited buffer and reset echo, search, ring, and pending as before. |
| Refused `visit` | Return `None`; the receiver, including active prompt and submission, is unchanged. | Keep existing eligibility/read rules and host failures. |

Successful visit drops the in-progress label, string, and cursor; it does
not submit that string. This applies both to an existing regular file
and a missing path that succeeds as an empty bound buffer. No neighboring
buffer changes. Idle keys, search, saves, selections, and either visit
outcome never erase a stored submission.

Direct methods keep their existing meanings, rather than being routed
through prompt key handling. In particular, direct buffer motion can
move the buffer while a prompt is active; a direct switch can change the
current buffer while preserving the active prompt. The preservation of
the buffer in §4 applies to **prompt transitions**. No existing direct
send interprets the line as a filename or buffer name.

### 3.4 Row, clipping, and finished cursor

For positive `columns` and `rows`, retain:

```text
text-rows = if rows >= 2 then rows - 1 else rows
body      = current-editor.frame(columns, text-rows)
```

The caller fits the session before framing, as today. `frame` itself
does not fit or change either cursor. For `rows >= 2`, choose the row:

| State | Row before clipping | Finished cursor |
|---|---|---|
| Prompt is `Some(prompt)` | `prompt.row` | Echo row and the prompt's screen column. |
| Prompt is `None`, search active | Existing `search:` / `wrapped:` / `failing:` row. | Existing text cursor. |
| Prompt is `None`, search inactive | Existing path or `untitled`, optionally prefixed `saved: ` / `failed: `. | Existing text cursor. |

In every case, `clipped = (row take columns)` and
`shown = (current-editor safe-cells clipped)`, in that order. There is
no ellipsis, horizontal prompt scroll, wrapping, padding prefix, or
trimming of the stored label/text. The editor frame clears unused cells
as before. Controls in the label or text paint as one space, keeping
character counts and cursor columns aligned.

For an active prompt, the insertion slot is after the full label and
the first `column` characters of its text:

```text
logical-column = (label len) + column + 1
screen-column  = min(columns, logical-column)
cursor-row     = rows
```

The logical insertion position is in the editable text, after the label.
When that slot is clipped, its screen position saturates at the final
visible cell. This also applies when the label itself fills or exceeds
the width; the cursor then sits on the last displayed label cell.
Right clipping cannot show an offscreen insertion slot. The clamp is
the specified display of that slot, and does not move the stored cursor
or shorten the string. Valid prompt columns and positive terminal width
guarantee `1 <= screen-column <= columns` without a lower clamp.

| Label | Text | Stored column | Width | Shown row | Screen column |
|---|---|---|---|---|---|
| `"Ask: "` | `"abcd"` | 2 | 12 | `"Ask: abcd"` | 8 |
| `"Ask: "` | `"abcd"` | 2 | 7 | `"Ask: ab"` | 7 |
| `"Ask: "` | `"ab"` | 2 | 12 | `"Ask: ab"` | 8 (blank cell after text) |
| `"long-label"` | `"x"` | 0 | 4 | `"long"` | 4 |
| `""` | `""` | 0 | 1 | `""` | 1 |

Append exactly the existing single echo suffix to `body`:

```text
ESC[?25l ESC[rows;1H shown ESC[cursor-row;cursor-columnH ESC[?25h
```

The spacing above separates pieces; it adds no literal spaces. Active
prompt coordinates are those just defined. Inactive coordinates remain
`point.line - editor.scroll-row + 1` and
`point.column - editor.scroll-col + 1`. The complete current-editor frame
is still a prefix of the single session String. There is no extra CRLF,
clear, suffix, or terminal write.

At `rows = 1`, pass one row to fit/frame and append no echo suffix,
even with an active prompt. The finished cursor stays in the sole text
row. All prompt transitions and stored fields still work. A later frame
with two or more rows shows the current line/cursor. `rows = 0` and
nonpositive columns remain outside the frame contract.

Rendering an active prompt never writes the echo token. It stays `""`,
`"saved"`, or `"failed"` through redraw, prompt editing, submit, and
cancel. When the prompt ends, the next frame uses the inactive row and
restores the text cursor. There is no new echo vocabulary.

Ordinary start/key use cannot activate a prompt alongside search or a
pending prefix (§4.2). Raw fixtures or existing direct helper sends may
combine those states. Their new fields are still preserved by §3.3;
`frame` follows the row table above, and `handle-key` follows §4.3's
independent precedence. Do not add a new guard to existing search or
prefix helpers to police such construction.

### 3.5 File migration and proof for 000

Add `tests/aloemacs/minibuffer-value.rkt` before product edits. Product
changes are confined to `file.aloe` for the new value, fields,
reconstruction, visit, and frame, and `main.aloe` for startup.
There are no prompt editing methods or session start/submit/cancel sends
in 000. Active frame tests construct `Some(AloemacsPrompt)` directly;
they do not send keys to that intermediate active state.

Migrate **every valid untyped session constructor**, including expected
session reconstructions in tests, by appending the two lawful defaults.
Search again instead of treating this current inventory as exhaustive:

- `tests/aloemacs/buffer-value.rkt`, `buffer-session.rkt`,
  `echo-session.rkt`, `file-session.rkt`, `kill-session.rkt`,
  `motion-editor.rkt`, `runner.rkt`, `safe-cells.rkt`,
  `search-session.rkt`, `undo-session.rkt`, `viewport-editor.rkt`,
  `visited-unchanged.rkt`, `keymap-session.rkt`, `keymap-prefix.rkt`.
- Main/source-shape expectations in `runner.rkt` and `file-runner.rkt`,
  and exact session-field inventories in `buffer-value.rkt`.
- All product reconstruction sites named in §3.3, not just startup.

Keep intentional old-arity negatives as negatives. Update other negative
fixtures so they still test the original field/type mistake. Prompt and
submission reads now have their declared types; do not retain an
unknown-selector negative for either. Editor-only fixtures stay on the
unchanged `AloemacsEditor`. Preserve substantive buffer, key, search,
quit, mark, ring, history, viewport, file-effect, and exact-frame checks.

000's no-TTY tests must prove:

1. Checked prompt fields, constructor order/arity/types, generated reads,
   `row`, and `screen-column`; bad arguments and arities are type errors.
   Loading `file.aloe` twice in fresh checked drivers needs no Fs or Term
   injection and performs no host effect. Session tests inject Fs later.
2. The complete ordered session shape, typed read results, startup
   `prompt = None` and `last-submission = None`, and immutable old values.
   A constructed `Some("")` submission is distinct from `None`.
3. Nontrivial active prompt and stored submission survive every §3.3
   preserving reconstruction, including direct save, both add arities,
   switch, kill-buffer, fit, and frame. Those methods retain their
   existing buffer results. Successful existing/missing-path visits
   deactivate the prompt and preserve the submission; every refusal
   retains the complete source. Count Fs effects and keep neighbor order.
4. Exact full ANSI frames at wide and narrow widths, empty label/text,
   cursor at beginning/middle/end, label-only clipping, and width 1.
   Assert both the last-row address and the final clamped cursor address.
   Text rows and their cursor sequences remain the editor frame prefix.
   Frame twice to prove purity; resize to prove the stored column stays.
5. Control characters in label and text paint as one space after clipping,
   with no control from that data reaching the painted row. Test ESC
   followed by printable `[31m`, tab, CR, another low control, and DEL,
   including a control beyond the clip. Stored strings are unchanged.
6. Text still fits in `rows - 1`, including a point requiring scrolling;
   inactive path/status/search frames remain exact and finish on text.
   At one row the result equals the existing editor frame and the active
   state survives, including when framed later at a taller size.

## 4. Layer 001 — start, edit, submit, and cancel

### 4.1 Prompt editing algebra

Add these methods to `AloemacsPrompt`. All return `AloemacsPrompt`,
preserve `label`, and leave the old receiver immutable. Let `s` be its
text and `c` its column:

| Send | Result text | Result column |
|---|---|---|
| `(prompt insert character)` with `character : String`, length 1, not LF | `(s take c) + character + (s drop c)` | `c + 1` |
| `insert` with any other string, including `"\n"` | Unchanged. | `c` |
| `(prompt backward-delete)` when `c > 0` | `(s take (c - 1)) + (s drop c)` | `c - 1` |
| `backward-delete` when `c = 0` | Unchanged. | 0 |
| `(prompt move-left)` | Unchanged. | `max(0, c - 1)` |
| `(prompt move-right)` | Unchanged. | `min((s len), c + 1)` |
| `(prompt line-start)` | Unchanged. | 0 |
| `(prompt line-end)` | Unchanged. | `(s len)` |

The `+` in the text formulas means String `append`; column arithmetic
uses Int sends. All but `insert` take no arguments. Use existing String
and Int sends. No Text operation
or safe-cells filter participates in editing. In particular, a
length-one tab, CR, ESC, NUL, or DEL is stored exactly, while LF is
ignored. The same one-character-per-cell display rule applies later.
This series makes no Unicode width change.

### 4.2 Start and session helper sends

Add `(session start-prompt label) -> (AloemacsSession H)` with
`label : String`. Return the **unchanged whole session** if current has
quit, search is active, pending is `Some(map)`, or prompt is already
`Some(prompt)`. Do not end search, consume a prefix, replace an active
label, or clear a submission in order to start. There is no prompt stack.

Otherwise store `Some(AloemacsPrompt new label "" 0)`. Preserve every
other field. Empty label is accepted exactly like any other String;
it is not a missing command. Start resolves, inspects, reads, and writes
no path and performs no buffer operation.

Use these ordinary session helpers, returning the receiver's concrete
`(AloemacsSession H)`:

| Send | Contract |
|---|---|
| `with-active-prompt(prompt : AloemacsPrompt)` | Store `Some(prompt)`; preserve every other field. No Option argument. |
| `submit-prompt()` | If active, set prompt to `None` and last submission to `Some(prompt.text)`, preserving every other field. If inactive, return unchanged. |
| `cancel-prompt()` | Set an active prompt to `None`, preserving every other field, including last submission. If inactive, return unchanged. |
| `prompt-key(key : String)` | If active, apply §4.4. If inactive, return unchanged. |

`handle-key` owns the quit/search routing guard, as it does for existing
key helpers. These helpers do not dispatch idle commands or fit the
buffer. Cleared Options are constructed directly in the rebuilt session,
with the method's expected field type. No setter takes `(Option String)`
or `(Option AloemacsPrompt)`.

### 4.3 Key routing

`AloemacsSession.handle-key` uses exactly this order:

1. Current editor already quit: return the session unchanged.
2. Active search: send the existing `search-key key`.
3. Prompt is `Some(prompt)`: send `prompt-key key`.
4. Otherwise: send the existing `idle-key key`, which selects pending
   before the global map and retains its consumed-miss rule.

Do not consult a keymap in the active-prompt arm. Do not send prompt
input to editor `handle-key`, `execute-command`, `find`, or `idle-key`.
Search keeps its existing query, input filter, row, point transitions,
and forwarding behavior. This series does not retarget that state machine.
While the prompt is inactive, Ctrl-F searches, Ctrl-S saves, `C-x C-s`
saves, and a pending miss consumes its key exactly as today.

### 4.4 Active key table

| Key | Transition |
|---|---|
| Any length-one String except `"\n"`, including space and controls | Insert through prompt `insert` at its current column. |
| The length-one String `"\n"` | Return the unchanged session. Prompt stays active. |
| `"backspace"` | Prompt `backward-delete`. |
| `"left"`, `"right"` | Prompt `move-left`, `move-right`. |
| `"line-start"`, `"line-end"` | Prompt `line-start`, `line-end`. |
| `"return"` | `submit-prompt`. Store editable text only; an empty text is a submission. |
| `"escape"` | `cancel-prompt`. Do not quit or replace the submission. |
| Every other key | Return the unchanged session, keeping the prompt active. |

Length one means `(key len) = 1`, not printable or safe-cell equality.
`"return"` is a named key distinct from the one-character LF string.
Neither adds a newline. Empty keys, unknown names, multi-character
strings, `"find"`, `"save"`, `"ctrl-x"`, `"undo"`, `"mark"`,
`"kill"`, `"kill-line"`, `"yank"`, up/down, page motions, and
buffer motions are ignored. Ignoring neither cancels nor forwards them;
in particular, it cannot save, enter search, arm a prefix, or quit.
There is no prompt Delete, kill, yank, or undo command.

Boundary backspace/motions retain the active line. After submit or
cancel, prompt is `None`; its label, text, and cursor are discarded.
The next frame uses the inactive row and text cursor. The next key uses
normal search/pending/idle routing. An idle direct `"\n"` still takes
the existing length-one self-insert path.

### 4.5 Preservation and submission lifetime

Start, prompt insert/delete/motion, submit, cancel, and ignored active
keys preserve the complete buffer collection and focus, every editor
field (Text including its focus, point, quit, history, mark, both
origins, remembered text rows), paths and derived names, Fs, echo,
search fields, ring, and pending. They add no history frame and perform
zero filesystem calls. Only prompt and, on submit, last submission
change. They do not call fit, visit, save, switch, add, or kill-buffer.

Cancel before any submit leaves `None`. Cancel after a submission leaves
that exact `Some(string)`. Starting again retains the previous submission
until a new Return replaces it, including Return on an empty line.
The stored string excludes the label, is not clipped or sanitized, and
keeps inserted controls. Framing and repeated reads do not consume it.
Idle keys, search, direct save, selections, and successful/refused visits
preserve it by §3.3. Nothing in this series acts on its contents.

### 4.6 File scope and proof for 001

Product edits are confined to `examples/aloemacs/file.aloe`: the
prompt methods, five session methods in §4.2, and `handle-key`'s new
arm. Keep 000's session fields, frame, startup, and migrated fixtures.
Add `tests/aloemacs/minibuffer-session.rkt` before product edits;
extend `minibuffer-value.rkt` for the new editing-method types/algebra.
Other existing tests need no behavior or constructor changes in 001.

No-TTY checked tests must prove:

1. Exact method signatures and return types, including the receiver's
   concrete Fs host parameter; bad labels, edit arguments, receivers,
   and arities are type errors. Start with empty label and a label with
   controls. Already quit, active search, armed prefix, and active prompt
   each refuse start with full-session equality and zero Fs calls.
2. Insertion at beginning, middle, and end; backspace at zero/middle/end;
   left/right at both edges; line-start/end, including an empty line.
   Compare strings and columns independently of the production handler.
   Test controls and LF; no valid transition introduces LF.
3. A session sequence starts `"Ask: "`, types `"ac"`, moves left,
   inserts `"b"`, and reads active text `"abc"` at column 2. At width
   12 with three rows its next frame shows `"Ask: abc"` and ends at
   `ESC[3;8H`. Return stores `Some("abc")`, deactivates, and restores
   the prior echo row and text cursor. Compare complete frame strings.
4. Empty Return stores `Some("")`; repeated submits replace the value.
   Escape before and after a submission preserves that value, never
   quits, and restores the old echo token, including `saved` and `failed`.
   LF leaves the active full session unchanged; idle LF still inserts.
   An edit/Return/cancel sequence at one row works without any echo suffix.
5. Snapshot nontrivial buffers, point, exact Text/focus, history, mark,
   origins, remembered rows, path/name, ring, echo, search, and pending
   **before each prompt transition**, then compare every preserved
   field. Use two buffers so no edit or submission can touch a neighbor.
   Keep old prompt/session values immutable. Count Fs calls through
   start, ignored save/find/prefix keys, submit, and cancel: all zero.
6. Every named ignored-key example in §4.4, plus unknown/empty/multiple
   character keys, leaves the whole active session unchanged. Already
   quit still absorbs all keys before prompt work. A fixture with both
   search and prompt proves search remains ahead of prompt dispatch.
   A fixture with active prompt and pending proves prompt keys preserve
   that pending value instead of consulting or clearing its map.
7. Start/edit/submit, then ordinary input, search, plain save and
   `C-x C-s`, consumed prefix cancellation, direct buffer selection,
   and both visit outcomes retain the last submission and their existing
   results. Direct save/switch/kill/fit/frame during an active prompt
   preserve its line, and successful/refused visits follow §3.3.
   Successful visit does not store the unfinished line.

## 5. Verification and acceptance

Each implementer writes focused tests first, observes the missing behavior
fail, implements that slice, runs its verification, and stops. From the
project root, always use `TMPDIR=/tmp` and `-y`, including when a
predecessor document omits them.

For **aloemacs-minibuffer 000**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/minibuffer-value.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **aloemacs-minibuffer 001**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/minibuffer-value.rkt tests/aloemacs/minibuffer-session.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

The aloemacs suite is the required regression bar. A checkpoint may name
wider tests only for a concrete dependency. No timing gate, benchmark,
or physical TTY hand check is required. Do not commit `compiled/`.
The optional existing launch is
`racket host/racket/aloemacs-run.rkt [path]`, with no prompt-start key.
After a `.rkt` edit, first run the named tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe`; the launchers load
existing bytecode without rebuilding it. `.aloe` edits need no rebuild.
A tour that opens a path from a prompt belongs to the later series.

The completed series is accepted when all of these are true:

1. Inactive sessions retain today's complete idle key, search, quit,
   visit, save, switch, kill-buffer, prefix, file-effect, and frame
   results. The inactive frame still ends with the cursor on text.
2. A no-TTY caller starts a separate prompt, inserts/deletes at its
   cursor, moves within it, and sees current buffer text above its
   clipped, safe echo row. The finished active cursor follows §3.4.
   One-row sessions keep their only text row and still accept transitions.
3. Prompt transitions preserve every buffer/editor field and the session
   ring/search/echo/pending state; Return and Escape neither insert a
   newline nor quit. LF is ignored while active. Ignored named keys
   cannot run buffer commands or filesystem effects.
4. `last-submission` distinguishes no submission from empty submission,
   returns exact editable text without the label, and survives cancel,
   redraw, ordinary commands, and either visit outcome. Successful visit
   deactivates and drops only the unfinished prompt line; refusal keeps
   it active and leaves the receiver unchanged.
5. Quit, search, prompt, and pending/global key routing have the specified
   precedence. Start refuses every ineligible state. Existing search
   and keymaps retain their meanings when the prompt is inactive.
6. Both focused layers and `TMPDIR=/tmp raco test -y tests/aloemacs`
   pass without a TTY, with no runner, editor, language, command, binding,
   or later-feature change.

The checkpoint manager writes 000 only, then stops. Human review of
its implementation precedes issuing 001.
