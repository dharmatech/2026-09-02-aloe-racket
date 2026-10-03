# aloemacs-minibuffer 001 — Type, submit, and cancel

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Let a checked no-TTY caller start an editable prompt, insert and delete
at its cursor, move within its string, submit with Return, and cancel
with Escape. Route active input to that prompt while preserving the
buffer collection and every existing editor field. A submission is the
exact editable string, readable through the existing last-submission
selector, and survives cancellation and ordinary buffer operations.

Stop after the prompt transitions and routing pass their tests. No
command consumes a submission, and no production key or runner argument
starts the prompt. This is the final checkpoint of the two-checkpoint
minibuffer series; do not start a later command series or issue 002.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-minibuffer 001**, filed as
  `checkpoints/001-type-submit-cancel.md`. This is a local editor
  checkpoint, not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), root `AGENTS.md`,
  `SPEC.md`, and `CHECKPOINTS.md` before product edits. `SPEC.md` remains
  Aloe language law. Evaluation is send with a literal selector;
  function objects execute only through `call`.
- The accepted [`../spec.md`](../spec.md) §§1–2 govern authority,
  predecessors, file boundaries, and non-goals. §§3.1–3.4 govern the
  retained value invariants, constructor typing, reconstruction, and
  display seam. §§4.1–4.6 specify this slice completely. §5's **001**
  commands and completed-series acceptance conditions govern completion.
- [aloemacs-minibuffer 000](000-prompt-value.md) is implemented,
  reviewed with no findings, and accepted by the user, as recorded in
  [the Minibuffer README](../README.md). Its prompt value, twelve-field
  session, constructor migration, visit rules, and frame are the
  starting point. Text through Buffer remain implemented predecessors.
  aloemacs-runner-check 000 is not a prerequisite; do not wait for it
  or edit that checkpoint.

`examples/aloemacs/file.aloe` already defines the three-field
`AloemacsPrompt` with `row` and `screen-column`, stores prompt and last
submission on the session, preserves them through ordinary rebuilds,
and clears only the unfinished prompt on successful visit. Its
`handle-key` currently checks quit, then search, then idle dispatch.
`tests/aloemacs/minibuffer-value.rkt` proves 000. Keep those contracts.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, only for the six prompt editing methods,
  five session methods below, and the new active-prompt arm of
  `AloemacsSession.handle-key`.
- Create `tests/aloemacs/minibuffer-session.rkt` before product edits,
  for checked session transitions, routing, preservation, submission
  lifetime, and exact frames.
- Extend `tests/aloemacs/minibuffer-value.rkt` for prompt editing-method
  signatures, checked argument/arity failures, algebra, and immutability.
  Extend its exact prompt-method inventory to include those methods;
  preserve its existing 000 proof.

### Must leave untouched

- `examples/aloemacs/main.aloe`, `examples/aloemacs/editor.aloe`, and all
  other product modules.
- All existing test files other than `minibuffer-value.rkt`. There is
  no further session-constructor migration in 001.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, all other host
  files, capabilities, and Fs/Term interfaces.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, global checkpoints,
  predecessor documents, and this series' design documents/checkpoints.
- Prompt/session field shapes, startup defaults, existing reconstruction
  and visit rules, `frame`, `ensure-visible`, editor/UndoFrame shapes,
  command constructors/names, `execute-command` arms, keymaps and their
  bindings/defaults, `search-key`, and `idle-key`.

No new module, load, dependency, capability, build step, or API beyond
the additions below. If another file or design change proves necessary,
stop and send this checkpoint back to the manager instead of widening
the slice.

## Slice requirements

### 1. Prompt editing algebra

Keep the ordered prompt fields `label : String`, `text : String`, and
`column : Int`. Valid callers supply text containing no LF and
`0 <= column <= (text len)`. The generated constructor remains an
ordinary constructor, with no new runtime validator.

Add these methods. All return `AloemacsPrompt`, preserve the exact
label, and leave the old receiver immutable. Let `s` be the stored text
and `c` its zero-based insertion column:

| Send | Result text | Result column |
|---|---|---|
| `(prompt insert character)`, `character : String`, length 1 and not LF | `(s take c) + character + (s drop c)` | `c + 1` |
| `insert` with any other String, including empty, multiple characters, or `"\n"` | Unchanged. | `c` |
| `(prompt backward-delete)` when `c > 0` | `(s take (c - 1)) + (s drop c)` | `c - 1` |
| `backward-delete` when `c = 0` | Unchanged. | 0 |
| `(prompt move-left)` | Unchanged. | `max(0, c - 1)` |
| `(prompt move-right)` | Unchanged. | `min((s len), c + 1)` |
| `(prompt line-start)` | Unchanged. | 0 |
| `(prompt line-end)` | Unchanged. | `(s len)` |

The text `+` is String `append`; arithmetic is Int sends. All methods
except `insert` take no arguments. Use existing String `len`, `take`,
`drop`, and `append`, and existing Int sends. There is no Text operation
or safe-cells filter in editing. Length-one tab, CR, ESC, NUL, DEL,
space, and other non-LF characters are stored exactly. LF is ignored;
valid transitions preserve the text/column invariants. Character counts
and the one-character-per-cell display policy remain unchanged.

### 2. Session start and helper sends

Add exactly these ordinary methods, each returning the receiver's
concrete `(AloemacsSession H)`:

| Send | Contract |
|---|---|
| `(session start-prompt label)`, `label : String` | Refuse by returning the unchanged whole session if current has quit, search is active, pending is `Some(map)`, or prompt is already `Some(prompt)`. Otherwise store `Some(AloemacsPrompt new label "" 0)` and preserve every other field. |
| `(session with-active-prompt prompt)`, `prompt : AloemacsPrompt` | Store `Some(prompt)` and preserve every other field. The argument is the prompt value, never an Option. |
| `(session submit-prompt)` | If active, store prompt `None` and last submission `Some(prompt.text)`, preserving every other field. If inactive, return unchanged. |
| `(session cancel-prompt)` | If active, store prompt `None` and preserve every other field, including last submission. If inactive, return unchanged. |
| `(session prompt-key key)`, `key : String` | If active, apply the active-key table below. If inactive, return unchanged without idle dispatch. |

Start accepts an empty label and a label with controls exactly as given.
It neither replaces an active label nor clears a submission to become
eligible. It does not end search, consume a prefix, resolve a path,
operate on a buffer, or create a prompt stack.

`handle-key` owns the quit/search routing guard, as for the existing
key helpers. Do not move that guard into `prompt-key`, submit, or
cancel, or add an eligibility guard to `with-active-prompt`. Direct
helpers retain their specified local transitions, including in raw
combined-state fixtures. They do not fit the buffer or dispatch commands.

Thread all twelve session fields through the new reconstructions. Put
cleared `(Option None)` values directly in the rebuilt session, where
the method's expected field type supplies their type. No setter takes
`(Option AloemacsPrompt)` or `(Option String)`, and no checker/evaluator
workaround for absent-Option dispatch is allowed. New untyped test
constructors retain 000's inferable absent-Option `if` forms.

### 3. Routing and active-key ownership

`AloemacsSession.handle-key` must use exactly this precedence:

1. Current editor already quit: return the whole session unchanged.
2. Search active: send the existing `search-key key`.
3. Prompt `Some(prompt)`: send `prompt-key key`.
4. Otherwise: send the existing `idle-key key`.

The active-prompt arm consults no keymap and sends no input to editor
`handle-key`, `execute-command`, `find`, or `idle-key`. Search retains
its existing input filter, query, point transitions, row, exit, and
forward-to-idle behavior, including in a raw search-plus-prompt fixture.
Do not rewrite search around the prompt or add guards to its helpers.
Inactive idle dispatch still selects pending before the global map and
consumes a pending miss without global retry.

When active, use this complete key table:

| Key | Transition |
|---|---|
| Any length-one String except `"\n"`, including space and controls | Insert through prompt `insert` at its current column. |
| The one-character LF String `"\n"` | Return the whole session unchanged, keeping the prompt active. |
| `"backspace"` | Prompt `backward-delete`. |
| `"left"`, `"right"` | Prompt `move-left`, `move-right`. |
| `"line-start"`, `"line-end"` | Prompt `line-start`, `line-end`. |
| `"return"` | `submit-prompt`; store text only, including an empty string. |
| `"escape"` | `cancel-prompt`; retain last submission and do not quit. |
| Every other key | Return the whole session unchanged, keeping the prompt active. |

Length one means `(key len) = 1`, not printable or safe-cell equality.
The named key `"return"` differs from the LF string; neither adds a
newline. Empty, unknown, and multiple-character keys are ignored, as
are `"find"`, `"save"`, `"ctrl-x"`, `"undo"`, `"mark"`,
`"kill"`, `"kill-line"`, `"yank"`, `"up"`, `"down"`,
`"page-up"`, `"page-down"`, `"buffer-start"`, and `"buffer-end"`.
Ignoring does not cancel or forward the key, save, search, arm a prefix,
or quit. There is no prompt Delete, kill, yank, or undo command.

Boundary deletion/motions retain the active line. After submit or
cancel, prompt is `None`; label, text, and column are discarded. The
next frame uses 000's inactive row and text cursor, and the next key
uses normal search/pending/idle routing. An idle direct LF key still
takes the existing length-one self-insert path.

### 4. Preservation, submission lifetime, and frame seam

Before and after every prompt transition, preserve the entire buffer
collection and focus, every editor payload (exact Text including focus,
point, quit, history, mark, both origins, and remembered text rows),
paths and derived names, Fs, echo, all search fields, ring, and pending.
Only prompt and, on active submit, last submission change. Do not call
fit, visit, save, add-buffer, switch-buffer, or kill-buffer from a prompt
transition. No prompt operation adds an UndoFrame or performs an Fs call.

Cancel before a submission retains `None`. Cancel after a submission
retains its exact `Some(string)`. Restart retains the previous
submission until Return replaces it, including Return on empty text.
The stored string excludes the label, is not clipped or sanitized, and
retains inserted controls. Repeated reads and redraws do not consume it.
No method in this series interprets or acts on that string.

Keep 000's rendering unchanged: active prompt row is label plus text,
clipped then passed through safe cells, with the cursor on the echo row
at `min(columns, (label len) + column + 1)`. The existing complete
editor frame stays the prefix of one session String. At one row there
is no echo suffix, but transitions still work and the prompt survives
for a taller frame. No transition writes the stored echo token.

For the required sequence, start `"Ask: "`, insert `"a"`, insert
`"c"`, move left, then insert `"b"`. Active text is `"abc"` at
column 2. At width 12 and three rows, the frame shows `"Ask: abc"`
and ends with cursor address `ESC[3;8H` followed by the existing cursor
show sequence. Return stores `Some("abc")`, clears prompt, and restores
the previous echo row and text cursor without changing the buffer.
Compare complete frames, not only the row or final cursor address.

The retained spec §3.3 direct-operation rules still apply. Ordinary
input/search, direct save, selection, and both visit outcomes preserve
last submission. Direct save/add/switch/kill/fit/frame preserve an
active prompt. Successful regular-file or missing-path visit clears
the unfinished prompt without submitting it; refused visit retains
the complete source. These are existing behaviors, not new dispatch
routes or changes to their methods.

### 5. Focused proof, written first

Create `minibuffer-session.rkt` and extend `minibuffer-value.rkt` before
product edits. Run the focused command and observe missing editing/
session/routing behavior fail, then implement this slice. Use checked
Aloe drivers, `rackunit`, counted Fs doubles, and no physical TTY or
production filesystem. Keep 000's assertions intact, extending its
prompt-method inventory rather than removing the structural check.

The focused tests must prove:

1. Exact signatures, arities, and checked result types for all six
   prompt editing methods and five session methods. Session returns
   retain the concrete Fs host parameter. Bad labels, edit arguments,
   receivers, and arities are type errors. Start with empty and control
   labels. Each start refusal (quit, search, pending, already active)
   compares the entire unchanged session and counts zero Fs calls.
   Inactive submit, cancel, and prompt-key also return the whole session
   unchanged; inactive prompt-key does not run idle commands.
2. Insertion at beginning/middle/end; backspace at zero/middle/end;
   left/right at both boundaries; line-start/end, including empty text.
   Assert literal expected strings and columns independently of the
   production handler. Invalid-length insertion and LF retain the
   value. Controls are stored exactly, valid transitions introduce no
   LF, and old prompt values remain immutable.
3. The `"Ask: "` / `"ac"` / left / `"b"` sequence above, its exact
   active frame and `ESC[3;8H` cursor, then Return's `Some("abc")`,
   deactivation, and exact restored inactive frame and text cursor.
   Prove stored submissions exclude labels and retain unclipped,
   unsanitized text, including controls.
4. Empty Return yields `Some("")`, distinct from `None`; subsequent
   Return replaces the old submission. Restart and Escape before/after
   submissions retain it. Escape never quits and restores the previous
   echo row, including saved and failed tokens. Repeated reads and
   frames do not consume the value. Active LF preserves the entire
   session; idle LF still inserts. An edit/Return/cancel sequence at
   one row works with no echo suffix, including a later taller frame.
5. Snapshot all preserved state before each prompt transition, then
   compare every field named in section 4. Use at least two distinct
   buffers with nontrivial current Text/focus, point, history, mark,
   origins, remembered rows, path/name, ring, and echo, so neither
   editing nor submission can touch a neighbor. Check old prompt and
   session values remain immutable. Count Fs calls through start,
   editing/motions, ignored save/find/prefix keys, submit, and cancel:
   all zero. Expected changes must not be built by the production
   prompt/session transition being tested.
6. Every named ignored key above, plus empty/unknown/multiple-character
   keys, preserves the full active session. Already quit absorbs keys
   before prompt work. A raw search-plus-prompt fixture proves search
   remains first and preserves the prompt through its existing helper
   paths. A raw prompt-plus-pending fixture proves prompt keys preserve
   the pending value without consulting or consuming its map. Exercise
   all active key-table rows and compare text and column independently.
7. Start/edit/submit, then ordinary input, search, plain save,
   `C-x C-s`, consumed prefix cancellation, direct buffer selection,
   and successful/refused visit: last submission survives and the
   existing command/file results remain intact. During an active
   prompt, direct save/switch/kill/fit/frame preserve its line. Regular
   and missing-path successful visits discard only the unfinished line
   among prompt state, preserve last submission, and keep existing
   buffer resets/neighbor order; refusals retain the whole source.
   Successful visit does not store the unfinished text.

Existing regression tests need no constructor or behavior changes.
Do not weaken their key, buffer, search, quit, prefix, mark, ring,
history, viewport, filesystem, or exact-frame assertions to pass.

## Explicit non-goals

No command consumer, find-file, save-as, selection by buffer name,
completion, prompt history/undo, initial path/name text, prompt-start
key or argv, `C-x C-f`, `C-x C-w`, `C-x b`, `M-x`, another prefix,
new command constructor, or `execute-command` arm. No prompt Delete,
kill, yank, undo, vertical/page/buffer motion, or forwarding of ignored
prompt keys. No search rewrite or retargeting onto the prompt.

No new editor field, windows, splits, mode line, buffer menu, dirty bit,
kill confirmation, region painting, clipboard, Text/List extension,
index, Vector, kernel/Term message, global checkpoint, class method,
delegation, Mirror, mutation, inheritance, macro, implicit Int/Float
coercion, special form, dependency, or demo. Do not start Boids or
the later command series.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/minibuffer-value.rkt tests/aloemacs/minibuffer-session.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test run. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or physical TTY
hand check is required. The optional existing launch remains
`racket host/racket/aloemacs-run.rkt [path]`, with no prompt-start key.
After a `.rkt` edit, run tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching;
launchers load existing bytecode without rebuilding it. `.aloe` edits
alone need no rebuild.

Review source as well as tests: only the named methods and routing arm
were added; start enforces all four refusal cases; active input never
dispatches buffer commands or Fs effects; no transition alters buffers,
echo, search, ring, or pending; submit/cancel have the specified lifetime;
quit/search/prompt/idle precedence is explicit. Confirm fields,
constructor typing, frame, visit/rebuild rules, startup, editor, runner,
commands, maps, host, libraries, and language remain intact.

Complete when both test commands pass, `git diff --check` is clean,
the structural review passes, the scope is respected, and the focused
proof covers the requirements above and spec §5's completed-series bar.
Report changed files, the observed initial focused failure, final
verification results, and the structural review. Stop when green for
human review. Do not implement later commands or issue 002; 001 ends
this series.
