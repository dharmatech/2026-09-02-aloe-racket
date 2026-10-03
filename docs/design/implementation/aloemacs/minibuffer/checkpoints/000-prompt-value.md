# aloemacs-minibuffer 000 — Prompt value, session migration, and frame

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Add an immutable `AloemacsPrompt` value outside the buffer zipper. Append
the active prompt and last submission to the session, migrate startup
and every valid session constructor/rebuild, and draw a directly
constructed active prompt on the existing echo row with its clamped
cursor. Preserve all inactive behavior and existing buffer operations.

Stop at the value, state migration, and frame. Tests construct active
prompts directly. Do not add prompt editing, start, submit, cancel, or
active-prompt key dispatch; those belong to aloemacs-minibuffer 001,
which is not issued.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-minibuffer 000**, filed as
  `checkpoints/000-prompt-value.md`. This is a local editor checkpoint,
  not a global Aloe number. There is no earlier minibuffer checkpoint.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), root `AGENTS.md`,
  `SPEC.md`, and `CHECKPOINTS.md` before product edits. `SPEC.md` remains
  Aloe language law. Evaluation is send with a literal selector, and
  function objects execute only through `call`.
- The accepted [`../spec.md`](../spec.md) §§1–2 govern authority,
  predecessors, file boundaries, and non-goals. §§3.1–3.5 govern this
  complete slice. §5's **000** verification and the value, reconstruction,
  inactive-behavior, and frame acceptance conditions govern completion.
  §4's transitions and routing are later work.
- Text through Buffer are implemented predecessors.
  [aloemacs-buffer 001](../../buffer/checkpoints/001-switch-and-kill-buffer.md)
  is implemented, reviewed, and accepted, as recorded in
  [the Buffer README](../../buffer/README.md). Echo, Safe cells, Search,
  and Keymap retain the seams named by the minibuffer spec §1.
  aloemacs-runner-check 000 is not a prerequisite; do not wait for it
  or edit that checkpoint.

Start with `examples/aloemacs/file.aloe`, which loads editor and Fs and
stores ten session fields ending in `pending`. It already owns the
buffer operations, session reconstructions, save/visit policy, fit, and
echo-frame composition. `main.aloe` constructs the cold untitled session.
Read the existing runner as a seam; it is outside the edit scope.

The minibuffer spec supersedes the predecessor final-text-cursor rule
only while an active prompt is drawn. Keep their buffer, filesystem,
search, keymap, inactive-row, and one-row contracts. Do not amend their
documents.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: declare the prompt value, append the
  two session fields, thread them through reconstructions, clear only
  the prompt on successful visit, and extend active frame rendering.
- `examples/aloemacs/main.aloe`: append the two lawful inactive defaults
  to the existing startup constructor.
- Create `tests/aloemacs/minibuffer-value.rkt` before product edits.
- Existing files under `tests/aloemacs/`, only for session-constructor
  migration, independent expected-session reconstructions, stored-field
  and loaded-class inventories, exact startup/source expectations, and
  newly valid prompt/submission reads. The current constructor inventory
  is `buffer-value.rkt`, `buffer-session.rkt`, `echo-session.rkt`,
  `file-session.rkt`, `kill-session.rkt`, `motion-editor.rkt`,
  `runner.rkt`, `safe-cells.rkt`, `search-session.rkt`,
  `undo-session.rkt`, `viewport-editor.rkt`, `visited-unchanged.rkt`,
  `keymap-session.rkt`, and `keymap-prefix.rkt`. Also inspect
  `runner.rkt` and `file-runner.rkt` for startup/source expectations.

Search again instead of treating that inventory as exhaustive. Other
existing aloemacs tests may change only for the same migration purposes.
Retain substantive behavior and exact inactive-frame assertions.

### Must leave untouched

- `examples/aloemacs/editor.aloe` and all other product modules.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, all other host
  files, capabilities, and Fs/Term interfaces.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, global checkpoints,
  predecessor documents, and this series' design documents/checkpoints.
- Command constructors/names, `execute-command` arms, keymaps and their
  bindings/defaults, search-key rules, and `handle-key` routing.
- All tests outside `tests/aloemacs/`. Do not create
  `tests/aloemacs/minibuffer-session.rkt` or a demo in this checkpoint.

No new module, load, dependency, capability, build step, or API beyond
the additions below. If another file or design change proves necessary,
stop and send this checkpoint back to the manager instead of widening
the slice.

## Slice requirements

### 1. Prompt representation and display sends

Retain the two existing loads in `file.aloe`. Declare the non-generic
`AloemacsPrompt` immediately after them and before the existing class
declarations; retain those declarations' relative order.

The prompt has exactly these ordered fields:

```aloe
(label String)
(text String)
(column Int)
```

Construction is `(AloemacsPrompt new label text column)`. Generated
selectors read the three fields. `column` is a zero-based insertion
position in `text`, including its end. Direct callers supply
`0 <= column <= (text len)` and text containing no LF. Do not add a
runtime validator to the generated constructor. Count String characters
as the existing one-character-per-cell display does.

Add only these prompt methods in 000:

| Send | Result | Contract |
|---|---|---|
| `(prompt row)` | `String` | Exactly `(label append text)`, before clipping or safe cells. |
| `(prompt screen-column columns)` | `Int` | For positive `columns`, `min(columns, (label len) + column + 1)`. The argument is `Int`. |

The join inserts no separator. A caller supplies the whole label,
including any colon or trailing space. Label may be empty or contain
controls; it is display data. No one-line Text, Position, viewport,
history, cached length, or editor field belongs to the prompt. Old
prompt values remain immutable.

### 2. Session fields and lawful construction

Append `prompt` and `last-submission` after `pending`. The complete
ordered session fields become:

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

Construction becomes:

```aloe
(AloemacsSession new
  buffers fs echo searching query origin wrapped failing kill-ring
  pending prompt last-submission)
```

`prompt = None` means inactive; `Some(prompt)` holds the whole active
value. No active flag or stack is added. The generated read
`(session prompt)` has type `(Option AloemacsPrompt)`;
`(session last-submission)` has type `(Option String)`. Reads are pure
and do not consume the submission. A directly constructed `Some("")`
is distinct from `None`; submitting is not implemented here.

Keep every existing startup payload, including the cold
`(Text from-string "")`, the singleton untitled buffer, the
`aloemacs-editor` binding, and explicit Fs injection. Append typed absent
prompt and submission values. The lawful startup is spec §3.2's exact
constructor; its final arguments are:

```aloe
(if #t (Option None) (Option Some aloemacs-global-keymap))
(if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
(if #t (Option None) (Option Some ""))
```

At every untyped constructor fixture, use those inferable `if` forms
when the corresponding Option is absent. Preserve the existing lawful
mark and path forms too. Active/submitted fixtures may use `Some`
directly. A method's expected constructor field type may supply the
type of a direct `(Option None)`.

Do not add an Option-taking setter/helper to set either new field, and
do not change the checker or evaluator to work around absent-Option
runtime dispatch. Put any cleared Option directly in the rebuilt
constructor. There are no session prompt helper methods in 000.

### 3. Reconstruction and direct-operation migration

Search all `AloemacsSession new` sites. In current `file.aloe`, the
reconstruction sites are both `add-buffer` overloads, `switch-buffer`,
`kill-buffer`, `with-editor`, `with-kill-state`, `with-search`,
`with-echo`, `with-prefix`, `clear-prefix`, and `visited`. Migrate all of
them, plus any further sites found; retain their existing results.

| Operation | New-field rule | Existing behavior to preserve |
|---|---|---|
| `with-editor`, direct editor wrappers, `with-kill-state`, `with-search`, `with-echo`, `with-prefix`, `clear-prefix`, `unchanged` | Preserve prompt and last submission exactly. | Keep each operation's existing buffer, echo, search, ring, and pending result. |
| Direct `save`, including a successful returned session | Preserve both. | Write only current text to current path; retain existing Option outcomes and effects. |
| Direct `add-buffer` (both arities), `switch-buffer`, `kill-buffer` | Preserve both, including active text and column. | Keep the existing selection, search/echo/pending resets, buffer defaults, neighbor order, and preservation/removal results. |
| `ensure-visible` | Preserve both. | Fit only current with the existing text-height rule; fitting may change that editor's origins and remembered rows. |
| `frame` | Read only; preserve both. | Frame current using fitted, stored origins and the row/cursor rules below. |
| Successful `visited` / `visit` | Store prompt `None`; preserve last submission. | Replace only current with the existing fresh visited buffer and existing echo/search/ring/pending resets. |
| Refused `visit` | Return `None`; preserve the entire source session. | Keep existing eligibility, read, and raised host-failure behavior. |

Successful regular-file and missing-path visits discard the unfinished
prompt without submitting it. They retain all neighbors and their order.
Direct save and buffer sends retain their own meanings: they do not
interpret prompt text or pass through prompt dispatch. A direct switch
may change the current buffer while retaining the active prompt.

Preserve both fields through the existing direct edit/motion/undo/quit,
search, mark, kill, yank, and save-key helpers via their unchanged
reconstruction paths. Raw fixtures and existing direct helpers may
combine an active prompt with search or a pending prefix. Do not add
new guards to those helpers; frame selection follows the next section.

Migrate every valid test constructor, including independent expected
reconstructions. Initial fixtures append the two lawful defaults;
reconstructed expectations thread the source fields where preservation
is required. Keep intentional old-arity negatives as negatives. Update
other negative fixtures to full new arity so they still test their
original wrong field/type. Replace any unknown-selector negative for
either new read with its valid type check.

Update exact session-field inventories, including the helpers in
`buffer-value.rkt`, `keymap-session.rkt`, and `keymap-prefix.rkt`.
Update `buffer-value.rkt`'s class order to include `AloemacsPrompt`
after the loads, `runner.rkt`'s exact main datums and loaded-class
expectations, and affected main/source expectations in `file-runner.rkt`.
Do not change editor-only fixtures, behavior assertions, or their frame
goldens.

### 4. Row, clipping, and final cursor

For positive dimensions, retain:

```text
text-rows = if rows >= 2 then rows - 1 else rows
body      = current-editor.frame(columns, text-rows)
```

The caller fits before framing. `frame` itself remains pure and does
not fit or move either stored cursor. `ensure-visible` still fits only
the current editor to this text rectangle.

At `rows >= 2`, select the row and final cursor in this order:

| State | Row before clipping | Final cursor |
|---|---|---|
| Prompt `Some(prompt)` | `(prompt row)` | Row `rows`, column `(prompt screen-column columns)`. |
| Prompt `None`, search active | Existing `search:`, `wrapped:`, or `failing:` row. | Existing text cursor. |
| Prompt `None`, search inactive | Existing path/`untitled` row, optionally prefixed `saved: ` or `failed: `. | Existing text cursor. |

Active prompt display wins even in a raw fixture with active search or
pending. Key routing does not change in this checkpoint; do not send
keys to those intermediate active fixtures.

In every row arm, clip before sanitizing:

```text
clipped = row take columns
shown   = current-editor.safe-cells(clipped)
```

Use the current editor's existing safe-cells method. Each control with
code 0–31 or DEL becomes exactly one space after clipping. Keep stored
label/text intact, including printable `[31m` following an ESC. There
is no ellipsis, horizontal prompt scrolling, wrapping, padding prefix,
or stored-string trimming.

The active insertion slot counts the full label plus the first
`column` text characters and adds one for the screen's one-based column.
Clamp it at `columns`, even when the label alone fills the width. Do
not shorten the prompt or change its stored column when clipped.

| Label | Text | Stored column | Width | Shown row | Final column |
|---|---|---|---|---|---|
| `"Ask: "` | `"abcd"` | 2 | 12 | `"Ask: abcd"` | 8 |
| `"Ask: "` | `"abcd"` | 2 | 7 | `"Ask: ab"` | 7 |
| `"Ask: "` | `"ab"` | 2 | 12 | `"Ask: ab"` | 8 (blank after text) |
| `"long-label"` | `"x"` | 0 | 4 | `"long"` | 4 |
| `""` | `""` | 0 | 1 | `""` | 1 |

The complete current-editor frame remains the prefix of the single
session String. Append exactly the existing one echo suffix:

```text
ESC[?25l ESC[rows;1H shown ESC[cursor-row;cursor-columnH ESC[?25h
```

Spaces in that notation separate pieces and add no literal spaces.
For an active prompt, cursor coordinates are the last-row/clamped
coordinates above. Inactive coordinates remain
`point.line - editor.scroll-row + 1` and
`point.column - editor.scroll-col + 1`. No extra CRLF, clear, suffix,
frame String, or terminal write is added. Rendering never writes the
stored echo token or either new field.

At `rows = 1`, fit/frame the sole text row and append no echo suffix,
even with an active prompt. The final cursor stays in the text row;
prompt and submission survive for a later taller frame. Zero rows and
nonpositive columns remain outside the frame contract.

### 5. Focused proof, written first

Create `tests/aloemacs/minibuffer-value.rkt` and write its focused proof
before product edits. Run its focused command and observe the missing
value/state/frame behavior fail, then implement this slice. Use the
existing checked driver, `rackunit`, and counted Fs doubles. No physical
TTY, Term injection, production filesystem, or new dependency is needed.

The focused tests must prove:

1. Exact prompt field order/types, constructor arity/types, generated
   reads, and the two display-method signatures and results. Bad
   arguments, receivers, and arities are checked type errors. Independently
   load `file.aloe` in two fresh checked drivers without Fs/Term injection,
   output, or host effects; inject Fs later for session tests.
2. The complete twelve-field session shape, checked prompt/submission
   read types, startup `None`/`None`, and old-value immutability.
   Construct `Some("")` as well as a nonempty submission to prove the
   distinction from `None`; repeated reads do not consume them.
3. A nontrivial active prompt and stored submission survive every
   preserving operation in section 3, including the direct wrappers,
   search/prefix rebuilds, direct save, both add arities, switch,
   kill-buffer, fit, and frame. Compare exact new fields independently
   of production rebuilds. Use nontrivial buffer/editor state, including
   Text focus, point, history, mark, both origins, remembered rows,
   path/name, neighbors, ring, echo, search, and pending; retain each
   operation's specified existing changes and surviving buffer order.
4. Successful direct `visited` and regular-file/missing-path `visit`
   clear only the prompt among the new fields, preserve the stored
   submission, and retain the existing fresh-buffer/reset results.
   Every refused visit preserves the entire source, including both
   new fields. Count Fs effects using the existing eligibility/read/
   write contracts and retain neighbor order; successful visit does
   not store the unfinished line.
5. Exact full ANSI frames at wide/narrow widths, empty label/text,
   insertion at beginning/middle/end, label-only clipping, and width 1.
   Assert both the last-row address and final clamped cursor address.
   Verify the exact editor-frame prefix, including its own cursor
   sequences. Expected row text and cursor numbers must not be computed
   by the production prompt methods. Frame twice to prove purity and
   resize to prove stored label/text/column and submission survive.
6. Controls in label and text paint as one space after clipping. Include
   ESC followed by printable `[31m`, tab, CR, another low control, DEL,
   and a control beyond the clip. No control from that data reaches
   the painted row; the frame's ANSI control sequences stay intact.
   Stored label/text are unchanged.
7. Text still fits within `rows - 1`, including a point that requires
   scrolling. Inactive path, status, and search frames remain exact and
   finish on text. A raw search-plus-prompt fixture draws the prompt
   without changing search state. At one row the complete result equals
   the existing editor frame, preserves active state/submission, and
   displays that same prompt on a later taller frame.

Keep the migrated suite's substantive buffer, key, quit, search, mark,
ring, history, viewport, filesystem, and exact-frame checks. Do not
weaken them to obtain a pass. No active-fixture key test may require
001's input handling.

## Explicit non-goals

No prompt `insert`, deletion or motion methods; no `start-prompt`,
`with-active-prompt`, `submit-prompt`, `cancel-prompt`, or `prompt-key`.
No active-prompt `handle-key` arm, start binding, argv, new command
constructor, or `execute-command` arm. No prompt edits, buffer edits
from prompt input, prompt undo, history, completion, or initial text.

No find-file, save-as, named buffer selection, `C-x C-f`, `C-x C-w`,
`C-x b`, `M-x`, another prefix, windows, splits, mode line, buffer menu,
dirty bit, kill confirmation, region painting, clipboard, or search
rewrite. No Text/List extension, index, Vector, kernel/Term message,
global checkpoint, class method, delegation, Mirror, mutation,
inheritance, macro, implicit Int/Float coercion, or special form.
Do not start Boids or the later command series.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/minibuffer-value.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test run. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or physical TTY
hand check is required. The optional existing launch remains
`racket host/racket/aloemacs-run.rkt [path]`, with no prompt-start key.
After a `.rkt` edit, run the tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching;
launchers load existing bytecode without rebuilding it. `.aloe` edits
alone need no rebuild.

Review the source as well as the tests: the prompt is a separate
three-field value; session stores exactly the two appended Options;
all valid constructors and independent expectations migrated lawfully;
every reconstruction follows section 3; active frame uses the specified
clipping, safe cells, and cursor clamp; inactive frame and one-row
fallback retain their contracts. Confirm no input handling or change
to editor, runner, command maps, host, libraries, or language slipped in.

Complete when both test commands pass, `git diff --check` is clean,
the structural review passes, the scope is respected, and the focused
proof covers the requirements above. Report changed files, the observed
initial focused failure, final verification results, and the structural
review. Stop when green for human review. Do not implement or issue
aloemacs-minibuffer 001.
