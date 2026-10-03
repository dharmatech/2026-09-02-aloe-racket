# aloemacs-buffer 001 — Add, switch, and kill buffers

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Extend the existing buffer zipper with movement, insertion, and removal.
Add session sends that supply a buffer from already held text, cycle
forward, and discard current while always leaving a current buffer.
Add the SwitchBuffer and KillBuffer command values, executed by the
existing session command dispatcher in the same single window.

Stop at these checked sends and commands. No production binding, Term
chord, prompt, runner argument, find-file, or window feature belongs to
this checkpoint. This is the last checkpoint in the accepted series.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-buffer 001**, filed as
  `checkpoints/001-switch-and-kill-buffer.md`. This is a local editor
  checkpoint, not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), root `AGENTS.md`,
  `SPEC.md`, and `CHECKPOINTS.md` before product edits. `SPEC.md` remains
  Aloe language law.
- The accepted [`../spec.md`](../spec.md) §§1–2 govern series authority,
  product boundaries, and non-goals. §§3.1–3.6 govern retained ownership,
  constructor shapes, accessors, reconstruction, visit/save, and frames.
  §§4.1–4.5 govern this slice. §5's **001** commands and completed-series
  acceptance govern completion. Extend §3.7's 000-only method inventory
  where §4 adds methods; retain its substantive singleton results.
- Predecessor [aloemacs-buffer 000](000-buffer-value.md) is implemented,
  reviewed against its written checkpoint with no findings, and accepted
  by the user. Reported verification was 10 focused tests and 261 full
  aloemacs tests passing, with `git diff --check` clean. The manager
  reviewed the diff/tests and checked whitespace without rerunning the
  suites.
- Text through Keymap remain implemented predecessors. Neither
  aloemacs-runner-check 000 nor aloemacs-safe-cell-controls 000 is a
  prerequisite; do not wait for or edit those checkpoint documents.

Start with the implemented buffer classes and computed session accessors
in `examples/aloemacs/file.aloe`. `AloemacsBuffers` currently has only
`with-current-buffer`; the session has ten fields, headed by the
collection. The editor/path pair lives only on each buffer. All seven session
reconstructions already preserve or replace current through the
collection. The command class currently has 21 constructors and only
`name`; execution is the constructor case in session `execute-command`.

Use the existing checked-driver/Fs-double patterns in `buffer-value.rkt`
and `keymap-session.rkt`. Read `lib/text.aloe` for its zipper pattern
and the existing runner for the fit/frame seam; neither is editable here.
The current startup and all constructor shapes are already correct.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: the four collection methods, both
  `add-buffer` overloads, session switch/kill, the two appended command
  constructors/names, and their session execution arms.
- Create `tests/aloemacs/buffer-collection.rkt` and
  `tests/aloemacs/buffer-session.rkt` before product edits.
- `tests/aloemacs/buffer-value.rkt`: extend method/signature inventories
  for these interfaces while retaining 000's ownership, construction,
  naming, startup, singleton, reconstruction, file, and frame assertions.
- `tests/aloemacs/keymap-session.rkt`: extend the command/method inventory
  and checked execution assertions; preserve the exact production maps,
  existing command expectations, and prefix/search/quit assertions.

### Must leave untouched

- `examples/aloemacs/main.aloe`, `editor.aloe`, and all other product
  modules. No constructor shape changes or fixture migration is needed.
- All other test files, including `keymap-prefix.rkt` and runner tests.
  Add the new integration proofs in `buffer-session.rkt`.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, all host
  capabilities and Fs/Term interfaces, runner arguments and sequencing.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, predecessor documents,
  and this series' design documents/checkpoints.
- Buffer/collection/session fields, editor and UndoFrame shapes,
  computed accessors, existing reconstruction and file contracts,
  keymap/binding definitions, lookup rules, and search-key behavior.

Keep the two existing loads and relative declaration order. Add no
module, dependency, capability, or language workaround. If another file
or design change proves necessary, stop and send the checkpoint back
to the manager instead of widening the slice. If the slice cannot be
finished in one implementer context, return the size problem for review.

## Slice requirements

### 1. Closed zipper operations

Add these methods to `AloemacsBuffers`:

| Send | Result | Behavior |
|---|---|---|
| `(buffers focus-next)` | `AloemacsBuffers` | Select next in logical order; wrap last to first. |
| `(buffers focus-previous)` | `AloemacsBuffers` | Select previous; wrap first to last. |
| `(buffers insert-after buffer)` | `AloemacsBuffers` | `buffer : AloemacsBuffer`; insert immediately after current and select it. |
| `(buffers remove-current)` | `AloemacsBuffers` | Discard current; prefer following, otherwise preceding, otherwise a fresh untitled buffer. |

`current-buffer` remains the generated field selector. Movement returns
a collection, not an Option or a buffer alone. Let `B` be the reversed
before list, `C` current, and `A` the forward after list. Use these exact
transitions; `B cons C` and `A cons C` mean ordinary List sends:

| Operation/edge | New before | New current | New after |
|---|---|---|---|
| Next, `A` nonempty | `B cons C` | `A first` | `A rest` |
| Next, `A` empty | Empty | First of `reverse(B cons C)` | Rest of that reversal |
| Previous, `B` nonempty | `B rest` | `B first` | `A cons C` |
| Previous, `B` empty | Rest of `reverse(A cons C)` | First of that reversal | Empty |
| Insert D after current | `B cons C` | D | A |
| Remove, `A` nonempty | B | `A first` | `A rest` |
| Remove, `A` empty, `B` nonempty | `B rest` | `B first` | Empty |
| Remove, both empty | Empty | Fresh untitled buffer | Empty |

Guard every `first`/`rest` with a proven nonempty list. Movement on a
singleton preserves the complete buffer and collection. Adjacent
movement, insertion, and removal use list head operations; a wrap uses
one reversal. Do not add an index, cached count, materialized second
collection, or Text operation. Preserve all old values.

For `[A, B, C]`, next cycles `A → B → C → A`, and previous cycles in
reverse. Removing B selects C and leaves `[A, C]`; removing C selects B
and leaves `[A, B]`; removing A selects B and leaves `[B, C]`. Equal-valued
buffers and duplicate paths/names do not change position-based behavior.

The singleton fallback has indexed Text from `""`, point `(0,0)`, quit
`#f`, scroll origins `(0,0)`, empty history, no mark, `text-rows = 0`,
path `None`, and name `"untitled"`. It reads/writes no file. Surviving
buffers preserve their exact editor/path values: no added undo frame,
mark clearing, fitting, or quit-flag rewrite.

### 2. Addition from text, with an optional path by arity

Add these two ordinary session overloads, both returning
`(AloemacsSession H)` with the receiver's existing concrete host type:

```aloe
(session add-buffer contents)
(session add-buffer contents path)
```

`contents` is String. The second overload's path is Path, and is stored
as `Some(path)` exactly as supplied. The first constructs the absent
path directly in the new buffer's constructor. Do not declare an
`(Option Path)` argument: absent Options can retain an unknown runtime
type argument even when checked through `if`, and cannot match that
concrete method parameter. Add no input wrapper or language change.
An already held optional path is consumed at the caller:

```aloe
(known-path case
  (None () (session add-buffer "second"))
  (Some (path) (session add-buffer "second" path)))
```

String or Option in the path position is a type error. Preserve lawful
empty Option construction from spec §3.4; at untyped test construction
sites use inferable Some branches. Add no Option-taking setter.

Build indexed Text from the supplied contents and a fresh editor with
the same defaults as the fallback above. Insert through `insert-after`
and select immediately. Adding D while B is current in `[A, B, C]`
yields `[A, B, D, C]` with D current. The old current is its immediate
predecessor; all other buffers retain their order and payloads.

Neither overload resolves, inspects, reads, writes, rejects, or
deduplicates a path. Relative spelling is unchanged; only visit
guarantees a resolved stored path. Duplicate names/paths are accepted.
Addition pushes no undo frame and creates no command constructor,
prompt, runner argument, or find-file behavior.

### 3. Session selection and exact resets

Add zero-argument methods returning `(AloemacsSession H)`:

| Send | Collection action |
|---|---|
| `(session switch-buffer)` | Send `focus-next`. |
| `(session kill-buffer)` | Send `remove-current`. |

Switch always cycles forward; it reads no name or key string. Previous
movement remains collection algebra only, with no session command.

All three selection operations — add, switch, kill — first end active
search, accepting the current search-result point. Never restore its
origin or run that search against another buffer. Apply the collection
transition and rebuild exactly this state:

| Field | Result |
|---|---|
| `buffers` | Operation's collection result. |
| `fs`, `kill-ring` | Receiver's exact values. |
| `echo`, `query` | `""`. |
| `searching`, `wrapped`, `failing` | `#f`. |
| `origin` | `(Position new 0 0)`. |
| `pending` | `None`. |

Apply these resets even on singleton switch and when inactive search
fixtures hold nondefault values. Clear pending/origin at every selection
boundary. The departing editor retains its accepted point, exact Text
focus, history, mark, scroll, and remembered row count unless it is
discarded. Killing discards its history; killing the singleton replaces
its editor/path with the fresh fallback while preserving Fs and ring.
It does not save or request quit.

Direct selection methods and direct command execution perform the same
transitions. Do not add a general quit guard to `execute-command`.
`handle-key` keeps its absorbing guard on current's quit flag before
search/map lookup or effects. A surviving editor's quit flag is never
rewritten, and session quit reports the selected editor's exact flag.
Singleton kill creates an editor with quit `#f`.

Selection does not fit. Frame immediately after selection reads the
destination's stored scroll. The runner's next `ensure-visible` fits
only current before framing. A round trip without editing/fitting
preserves both editors completely; fitting later may change only the
selected editor's origins/text-rows under the existing minimal rule.

### 4. Command values and retained keymaps

Append these zero-field constructors after the existing command
constructors, in this order, and extend the exhaustive `name` case:

| Constructor | Exact name | Session `execute-command` action |
|---|---|---|
| `SwitchBuffer` | `"switch-buffer"` | Send `switch-buffer`. |
| `KillBuffer` | `"kill-buffer"` | Send `kill-buffer`. |

There are now 23 constructors. `Kill` still means region kill with name
`"kill"`. Commands still have only their naming method. Extend the
existing constructor case inside session `execute-command`, retaining
the receiver's concrete Fs type. The new arms ignore the supplied key,
including a length-one string; only SelfInsert uses that argument.
Use the selection methods' exact resets. No dispatch by name, command
execution method, or editor `handle-key` arm is added.

The commands can be performed directly without any production binding:

```aloe
(session execute-command (AloemacsCommand SwitchBuffer) "")
(session execute-command (AloemacsCommand KillBuffer) "")
```

Retain exactly 20 global command bindings, then the one ctrl-x prefix,
and the `Some SelfInsert` default. The C-x map keeps only its save
binding and a None default. Both save bindings retain the same existing
save command. A pending miss cancels and consumes without retrying
globally. Plain x inserts. Idle strings `"switch-buffer"` and
`"kill-buffer"` remain map misses; install no synthetic production
binding or Term chord for them.

Search keeps precedence over lookup: printable query input, Backspace,
Find, Escape, Return, and forwarding of other keys retain their rules.
Direct switch/kill commands during search perform the selection reset.
A test-only binding in an existing map follows ordinary search
exit/idle dispatch and prefix consumption. Add no `search-key` arm.
Entering search after selection captures the newly current point.

### 5. Focused collection tests, written first

Create `buffer-collection.rkt` with checked sends proving:

- Exact signatures and checked results for all four methods, including
  wrong receivers, arguments, and arities.
- Logical order and exact current for next/previous, both wrap edges,
  singleton movement, insertion at first/middle/last focus, every removal
  neighbor choice, singleton fallback, and repeated removal that never
  leaves an empty collection.
- Two and three-buffer cases, with complete buffer/editor values and
  both list orders compared, not names alone. Include duplicate names,
  duplicate paths, and equal-valued buffers so positional selection and
  removal cannot accidentally deduplicate or discard another position.
- Surviving payloads and old collections remain unchanged; no history
  frame, mark change, fit, quit rewrite, or filesystem operation occurs.

Use distinctive Text focus, point, history, mark, origins, remembered
rows, and paths to make accidental rebuilding visible. The fresh
singleton replacement must match every default in requirement 1.

### 6. Focused session and integration tests, written first

Create `buffer-session.rkt` using the checked driver, rackunit, and Fs
doubles that count effects. Compare complete values and independent
expectations. No physical TTY or production files are needed. Prove:

- Both addition arities, new method/command types and exact names, and
  wrong receivers/types/arities. Execute the optional-path caller case
  for both None and Some. Addition stores text/path exactly, has fresh
  defaults, selects immediately after old current, and causes zero Fs
  calls, including for relative, duplicate, or ineligible supplied paths.
- Switch, kill, and direct command execution give the specified focus
  and resets. Singleton switch preserves the complete buffer while
  resetting session fields. Singleton/repeated kill gives fresh
  untitled contents/path/history/mark/scroll, retains ring/Fs, and
  neither saves nor quits. Include inactive nondefault search fields
  and exact quit-flag behavior without a new direct-command guard.
- Round-trip switching preserves point, exact Text/focus, history,
  mark, origins, remembered rows, and path/name. Edits and undo affect
  only current; selection adds no frame. Removing another buffer does
  not change surviving histories or source values.
- Region kill in one buffer, switch, yank in another, and undo there.
  The session's one ring stays newest first and is not consumed by
  yank/undo. Killing the source buffer leaves its entry usable. Marks
  remain per editor with the existing kill/yank validity rules.
- Save on two distinct bound paths writes only current's exact text
  to its path. Switch changes the next target, preserving every other
  buffer. Cover untitled failure, an ineligible path, and shared-path
  buffers: current overwrites the file without changing the other
  in-memory buffer. Exercise direct save, Ctrl-S, and `C-x C-s`, with
  their distinct echo/pending contracts and existing host-failure rules.
- Existing/missing-path successful visit replaces only current and
  retains neighbors/order. Its fresh defaults and session resets,
  including an empty ring and pending None, still follow spec §3.5.
  Refused visit preserves the whole source, all buffers, and pending.
- Selection during search with a nonzero origin accepts the departing
  point and clears every search field before another editor can use
  that origin. Use a shorter destination where the old origin would
  be invalid. Cover add, singleton switch, switch/kill, and Find after
  selection capturing the new point. No search/selection adds history.
- Saved/failed echo clears on selection. The complete ANSI frame shows
  the new path/untitled label, preserves clipping/safe cells/padding
  and final text cursor, and handles one-row frames. Frame before fit
  uses stored origin; a later fit changes only current under the
  existing minimal viewport rule.
- Pending clears on direct add/switch/kill, including singleton
  switch. Test-only pending bindings to the new commands prove existing
  lookup/consume/execute behavior. Search precedence and prefix
  cancellation stay intact. Already quit sessions absorb keys before
  lookup or effects. Production maps/defaults remain exact, and the new
  command-name strings remain idle misses.

Extend `buffer-value.rkt`'s exact collection method/signature inventory
for the four additions while retaining its field/constructor shapes
and existing proofs. Extend `keymap-session.rkt`'s command inventory
for SwitchBuffer/KillBuffer independently of its unchanged production
binding table, and prove checked execution with each concrete Fs host.
Keep all old command, prefix, search, save, and frame assertions.
Do not replace independent expected values with the new dispatcher or
weaken existing results to obtain a pass.

## Non-goals

No minibuffer, find-file, save-as, named selection, `C-x C-f`, `C-x b`,
M-x, new prefix/binding/chord, previous-buffer session command, windows,
splits, mode line, buffer menu, dirty bit, kill confirmation, save-on-kill,
two-file interactive tour, region painting, clipboard, search-key change,
new editor field, mark rebasing, or new edit grouping.

No Text/List extension, index/cached count, Vector, mutation, inheritance,
macro, class method, delegation, Mirror, kernel message, language
amendment, implicit Int/Float coercion, or new special form. Evaluation
is send with a literal selector; function objects execute only through
`call`. Do not start Boids or a global checkpoint.

## Verification and completion

Write the focused tests first, run the focused command below, and observe
the missing movement/addition/command behavior fail before product
edits. After implementation, run these commands from the project root
in this order:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/buffer-value.rkt tests/aloemacs/buffer-collection.rkt tests/aloemacs/buffer-session.rkt tests/aloemacs/keymap-session.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test run. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or hand check is
required. The optional existing launch is
`racket host/racket/aloemacs-run.rkt [path]`, still with zero or one path;
opening two files interactively belongs to find-file. After a `.rkt`
edit, first run tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`,
because launchers load existing bytecode without rebuilding it. `.aloe`
edits alone need no rebuild.

Review structure as well as results: buffers remain the sole owners of
editor/path pairs; the session stores only its collection and specified
session state. Current reads/rebuilds follow focus and preserve neighbors.
New command arms live inside session `execute-command`; commands still
have only `name`. Verify positional zipper operations, guarded list head
access, one reversal at wrapping edges, and exact unchanged production
maps. Confirm main, runner, editor, host, libraries, and language stayed
untouched. Behavioral equality alone cannot prove these boundaries.

Complete when the two test commands pass, `git diff --check` is clean,
the structural review passes, and the accepted spec §5's completed-series
conditions hold within the file scope. Report changed files, the
observed initial focused failure, final verification, and structural
review. Stop when green for human review. Do not implement later editor
features or issue 002; this two-checkpoint series ends at 001.
