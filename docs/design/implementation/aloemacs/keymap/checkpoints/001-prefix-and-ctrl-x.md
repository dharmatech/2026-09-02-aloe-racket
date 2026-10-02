# aloemacs-keymap 001 — Pending prefix and Ctrl-X save

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Add one pending-map field to the session and one nested global binding.
Plain Ctrl-X arms a map whose only command binding is Ctrl-S. `C-x C-s`
executes the existing save command after clearing pending state. Every
other second key cancels the prefix and is consumed. A redraw between
the two keys preserves the armed map.

Stop at this prefix: no further binding, prompt, command, buffer, or
checkpoint belongs to this assignment. Command execution remains
`(session execute-command command key)`; do not restore command `run`.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity is **aloemacs-keymap 001**, filed as
  `checkpoints/001-prefix-and-ctrl-x.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), root `AGENTS.md`,
  `SPEC.md`, and `CHECKPOINTS.md` before product edits. `SPEC.md` remains
  language law; this checkpoint changes no language rule.
- [`../spec.md`](../spec.md) §§1–2 govern authority and product boundaries;
  §§3.1–3.6 govern retained command values, lookup, execution, helpers,
  bindings, and search/quit precedence; §§4.1–4.5 govern this slice;
  §5's **001** verification and completed-series acceptance govern
  completion. §3.7's 000-only constructor/table assertions are updated
  only as required by §4.
- Predecessor [aloemacs-keymap 000](000-session-keymap.md) is implemented,
  reviewed against its checkpoint, and accepted by the user. Its reported
  verification was 14 focused tests and 220 full aloemacs tests passing,
  with `git diff --check` clean. There is no checker prerequisite.
- Text through Motion remain the application predecessors. The
  safe-cell-controls cleanup is not a prerequisite; do not wait for it.

Start with the implemented declarations, immutable global map, and session
`execute-command` in `examples/aloemacs/file.aloe`. Lookup currently uses
the existing List fold and already preserves first-match semantics; retain
its contract. The session has ten fields, no pending state, and no prefix
binding. `main.aloe` constructs that session. `term.rkt` already normalizes
plain Ctrl-S before both printable branches. Its Ctrl-X normalization is
the only new host behavior.

`tests/aloemacs/keymap-session.rkt` is the 000 acceptance suite to extend.
`kill-key-mapping.rkt` shows converter tests; `echo-runner.rkt` and
`runner.rkt` show scripted Term/Fs doubles and exact frame assertions.
Read the existing runner as a seam; do not edit it.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: the Prefix binding constructor, its key
  extraction, static nested map, appended global binding, pending field,
  preservation/reset through session construction, prefix helpers, and
  pending-aware idle dispatch specified below.
- `examples/aloemacs/main.aloe`: append the typed empty pending argument
  to the initial session construction. Preserve every other payload.
- `host/racket/term.rkt`: add the plain Ctrl-X converter clause and,
  optionally, its small predicate parallel to plain Ctrl-S.
- `tests/aloemacs/keymap-session.rkt`: extend the accepted 000 assertions
  for the new state and binding, retaining their substantive results.
- Create `tests/aloemacs/keymap-prefix.rkt`,
  `tests/aloemacs/keymap-key-mapping.rkt`, and
  `tests/aloemacs/keymap-runner.rkt` before product edits.
- Existing files under `tests/aloemacs/`: only pending construction/type
  checks and the specified consequences of this slice. The current valid
  constructor inventory includes `echo-session.rkt`, `file-session.rkt`,
  `kill-session.rkt`, `motion-editor.rkt`, `runner.rkt`, `safe-cells.rkt`,
  `search-session.rkt`, `undo-session.rkt`, `viewport-editor.rkt`, and
  `visited-unchanged.rkt`. Search all occurrences again; preserve prior
  assertions and the purpose of negative tests.

### Must leave untouched

- `examples/aloemacs/editor.aloe` and all other product modules.
- `host/racket/aloemacs-run.rkt`, runner entry procedures, ordering, and
  Term writes; Fs and Term interfaces and capabilities.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, and predecessor specs or
  checkpoints, including 000 and safe-cell-controls.
- `AloemacsCommand` constructors, names, and its sole `name` method;
  session `execute-command` signature and command transitions;
  `AloemacsBinding.Command` payload and keymap fields/lookup contracts.
- Editor fields and constructor, Text, frame composition, safe-cells,
  existing search-key rules, undo/kill/motion behavior, and load order.

Do not add a module, load cycle, dependency, capability, or public API
outside the additions named here. If another file or design change proves
necessary, stop and return the checkpoint to the manager instead of
widening the slice.

## Slice requirements

### 1. Prefix binding and static maps

Add exactly this constructor after `Command` in `AloemacsBinding`:

```aloe
(Prefix
  (fields
    (key String)
    (map (AloemacsKeymap AloemacsBinding))))
```

Extend `binding.key`'s exhaustive constructor `case` to return the Prefix
key. Lookup still returns `(Option AloemacsBinding)` for application maps,
compares whole key strings in list order, and returns the first matching
binding. It neither executes a command, descends into the nested map, nor
uses the default. Old binding/list/map values stay immutable.

Keep all definitions in `file.aloe` and retain the declaration order from
000: command, keymap, binding, search/session, then constants and maps.
Define `aloemacs-ctrl-x-keymap` after the command constants and before
`aloemacs-global-keymap`. Its bindings are exactly:

```aloe
(List of
  (AloemacsBinding Command "save" aloemacs-save-command))
```

Its default is None. At this untyped generic construction site spell the
default with the inferable command type:

```aloe
(if #t
    (Option None)
    (Option Some aloemacs-self-insert-command))
```

Append exactly one binding after the existing 20 global bindings:

```aloe
(AloemacsBinding Prefix "ctrl-x" aloemacs-ctrl-x-keymap)
```

The 20 existing bindings retain their values and order. The global default
remains `Some aloemacs-self-insert-command`. Both save bindings use the
existing `aloemacs-save-command` value. There are now 21 global bindings,
one nested binding, and the same 21 command constructors. The maps remain
static top-level data; add no global-map session field or extra binding.

### 2. Pending state, helpers, and constructor threading

Append one field after `kill-ring`. The complete ordered session fields
are now:

```aloe
(editor AloemacsEditor)
(fs (Fs H))
(path (Option Path))
(echo String)
(searching Bool)
(query String)
(origin Position)
(wrapped Bool)
(failing Bool)
(kill-ring (List String))
(pending (Option (AloemacsKeymap AloemacsBinding)))
```

Construction is:

```aloe
(AloemacsSession new
  editor fs path echo searching query origin wrapped failing kill-ring pending)
```

Add these instance methods inside `(AloemacsSession H)`:

```aloe
(with-prefix (map (AloemacsKeymap AloemacsBinding)) (AloemacsSession H)
  ...)

(clear-prefix () (AloemacsSession H)
  ...)
```

`with-prefix` stores `Some(map)`, sets echo to `""`, and preserves every
other field. `clear-prefix` stores None and preserves every other field,
including echo. Write the cleared Option directly in its rebuilt
constructor; add no setter taking Option. `H` remains the receiver's class
parameter. Check both helpers and the pending field with the unchanged
checker, including incorrect types and arities.

Append the final argument at every construction site. In the current
product implementation the inventory is:

| Site | Pending argument |
|---|---|
| `file.aloe`: `with-editor` | Receiver's pending |
| `file.aloe`: `with-kill-state` | Receiver's pending |
| `file.aloe`: `with-search` | Receiver's pending |
| `file.aloe`: `with-echo` | Receiver's pending |
| `file.aloe`: `visited` | None |
| `main.aloe`: initial `aloemacs-editor` | None |
| `file.aloe`: new `with-prefix` | `(Option Some map)` |
| `file.aloe`: new `clear-prefix` | None |

`save-key` already uses `with-echo` in both branches. Its None branch must
therefore preserve the receiver's pending; its Some branch must preserve
the returned session's pending. It needs no separate constructor. Direct
`save` still returns Option through `unchanged`, preserving pending on
success. It writes exact `(text to-string)` once for each eligible bound
save; a returned failure produces `"failed"` through `save-key`, and a
raised host failure still raises.

Fresh sessions and every successful existing-file or missing-file visit
hold pending None. A rejected visit retains its unchanged source,
including pending. Ordinary editor wrappers, search helpers, kill helpers,
`with-echo`, fitting, framing, and direct save preserve pending. Command
transitions themselves add no prefix routing; consumption is in idle key
handling. Rendering and fitting must retain the armed map across the
runner's next iteration, including a resize.

At untyped sites, including `main.aloe` and direct test fixtures, use this
inferable empty pending argument:

```aloe
(if #t
    (Option None)
    (Option Some aloemacs-global-keymap))
```

The unselected branch supplies the concrete map type. A method's expected
constructor field type may instead supply a bare None's type. Preserve
the existing lawful empty path/mark spellings. Do not change the checker
or construct Options with Mirror.

Search every `AloemacsSession new` occurrence again. Thread pending through
valid fixtures and independent expected-value builders, including the
whole-session comparison field inventory in `keymap-session.rkt` and
`runner.rkt`'s exact initial main datums. Intentional old-arity negatives
may remain errors; other negatives must still exercise their original
field/type error. Source-shape guards in `file-runner.rkt` and `runner.rkt`
are not constructor sites and need no argument added to their strings.

### 3. Dispatch, save, and consumed cancellation

Keep session `handle-key` precedence:

1. Already quit: return the unchanged session before lookup or effects.
2. Active search: send `search-key key`.
3. Otherwise: send `idle-key key`.

Inside idle dispatch select the global map when pending is None and the
stored map when pending is Some. Send `lookup key` exactly once to the
selected map. Apply this transition table:

| Pending before key | Lookup result | Transition |
|---|---|---|
| None | Some Command | `(self execute-command command key)`; pending stays None |
| None | Some Prefix | `(self with-prefix map)`; echo becomes empty |
| None | None | Existing global length-one default/miss rule; pending stays None |
| Some(map) | Some Command | `((self clear-prefix) execute-command command key)` |
| Some(map) | Some Prefix | `(self with-prefix next-map)` replaces pending; echo becomes empty |
| Some(map) | None | Clear pending and echo, preserve all other fields, consume key |

For global misses, execute Some(default) only when `(key len) = 1`;
otherwise clear echo without any other change. A missing global default
also yields that cleared no-op. Lookup precedes the length check, so a
bound one-character key takes its command. Plain `"x"`, `"s"`, `"q"`, and
space still insert globally. Keep the existing direct length-one insert
behavior without an idle safe-cells filter.

Pending misses are never retried globally and never consult either map's
default. A pending Command clears the prefix **before** execution, so
`"ctrl-x"` then `"save"` ends with pending None and the same `"saved"` or
`"failed"` result, text written, session payloads, and history as plain
Ctrl-S. A pending Prefix replaces the selected map as required by the
data shape. A test-only nested binding may prove that transition; install
no production prefix chain.

Installing or cancelling a prefix changes only pending and echo. It does
not write, edit, move point, set/clear mark, touch the ring, push/pop
history, or alter search fields. Preserve text, quit, both viewport
origins, remembered text-rows, fs, path, and all source values. These rules
also hold at no-op command boundaries.

Every second key other than `"save"` cancels the production Ctrl-X prefix.
Required cancellation examples are `"x"`, `"s"`, `"left"`, `"escape"`,
`"find"`, `"undo"`, `"return"`, `"mark"`, an unknown name, the empty
string, and another `"ctrl-x"`. That key is consumed: no insert, global
command, quit, search entry, or re-arming. The next key dispatches globally.
In particular, Ctrl-X followed by two Escapes cancels on the first Escape
and quits on the second.

Keep the existing search state machine. Search Escape/Return exit without
quit/insertion; Backspace edits the query; find advances search; accepted
safe length-one strings append to the query. Other keys reset search and
fall through to idle dispatch as before. Ctrl-X from ordinary active
search therefore resets searching/query/origin/wrapped/failing before
arming the map. The following save uses the pending path. Search motion
adds no undo frame. No new search-key string arm is needed.

Keep the exhaustive command-value case inside session `execute-command`.
Commands have only their naming method. Do not dispatch by command-name
strings, send computed selectors, or call editor `handle-key` on the
session idle path. Lookup and pending Option/binding cases remain the
dispatch authority.

### 4. Echo and frame preservation

Installing a prefix clears a prior saved/failed token; cancellation keeps
echo empty. Save replaces it with the existing saved/failed outcome. Find
retains the stored token. Echo vocabulary remains the path/untitled row,
`saved:` or `failed:` plus the path, and existing search rows. Add no
`C-x-` prompt or cancellation label.

Frame and safe-cells do not inspect pending. Preserve the exact frame
bytes, clipping, text-row allocation, safe-cell rendering, and final
text-cursor placement. A one-row session still handles prefix/save/cancel
without an echo suffix. Keep the runner's fit-before-frame order, one
frame string and one Term write per iteration, key-read counts, and
stop-on-quit behavior. The frame between the two prefix keys is required
evidence that redraw preserves pending.

### 5. Plain Ctrl-X normalization

In `host/racket/term.rkt`, add one plain Ctrl-X clause to
`tkeymsg->aloe-key` before both printable-character branches. Match the
plain Ctrl-S predicate shape:

| tkeymsg key | mods | char | Aloe key |
|---|---|---|---|
| `#\x` | exactly `'(ctrl)` | `#f` | `"ctrl-x"` |
| `#\x` | exactly `'(ctrl)` | `#\x` | `"ctrl-x"` |

A small `plain-ctrl-x-key?` predicate parallel to `plain-ctrl-s-key?` may
name the guard. `(make-tkeymsg #\x)` still yields `"x"`. Ctrl-Shift-X and
Alt-X, each with absent or matching decoded char, still yield `"x"`.
A mismatched printable decoded character retains character-first behavior
and is not accepted as Ctrl-X. Keep Return, Backspace, arrows, all motion
keys, Escape, Ctrl-S, Ctrl-F, Ctrl-Z, and kill chords unchanged. Term gains
no prefix state or interface message.

### 6. Focused tests, written first

Extend/create the four focused files before product edits. Update their
fixtures for the specified pending arity, run the focused command below,
and observe missing prefix behavior fail before implementing it. Use the
checked driver, rackunit, and existing Fs/scripted Term double patterns.
No acceptance condition depends on a physical TTY.

`tests/aloemacs/keymap-session.rkt` must retain 000's substantive command,
lookup, field-result, type, and precedence assertions. Update its
000-only expectations: the exact global table now ends with Prefix,
`"ctrl-x"` lookup now finds it, pending is a valid typed field, and an
idle Ctrl-X now arms a map instead of being an unknown named miss. Add:

- Prefix payload/key/type checks; exact global/nested binding lists and
  defaults; the shared save command value; pending type and both helpers'
  checked signatures/negative argument and arity cases. Commands still
  reject `run`; session execution retains each concrete injected host.
- Initial pending None, including the checked main session; pure lookup
  returning Prefix data without arming a session or running a command.
- Pending preservation through ordinary rebuilds, direct wrappers, search
  and kill helpers, direct save, `ensure-visible`, and framing. Exercise
  a fit and frame while armed before the next key.
- Successful existing/missing-file visits resetting pending and rejected
  visits preserving the source. Preserve independent expected-value
  construction and compare pending along with all existing fields.

`tests/aloemacs/keymap-prefix.rkt` must prove:

- Arming changes only pending/echo and writes zero times. Ctrl-X then save
  clears pending, writes exact text on success, and equals plain save in
  all session/editor fields, history, and echo frame. Cover bound success,
  untitled failure, and ineligible bound-path failure. Count writes:
  successful save writes once; failed saves retain their existing effect
  rules. Raised host failures remain raised.
- Every cancellation example in requirement 3 is consumed exactly once.
  Use nontrivial mark, ring, history, viewport/origin, remembered rows,
  path, and echo fixtures. Compare all preserved fields and source values;
  ensure zero writes; prove the following key acts globally. No cancellation
  inserts, moves, enters search, quits, undoes, or re-arms. Include the
  cancel-then-quit pair of Escapes.
- Active search still owns its keys; Ctrl-X resets ordinary active search
  before arming, then save works. Already quit sessions absorb Ctrl-X and
  save without effects. A test-only nested Prefix may prove replacement
  of an already pending map without adding a production chain.
- A test-only pending map with a Some default still consumes a missing
  length-one key, ignoring both the selected and global defaults.
- Prefix/save/cancel on a one-row session, plus exact echo/frame behavior
  at ordinary sizes and no extra history from arm, fit, frame, or cancel.

`tests/aloemacs/keymap-key-mapping.rkt` must call the converter directly
without a TTY and cover both plain Ctrl-X shapes, printable x,
Ctrl-Shift-X/Alt-X with both char variants, mismatched char, and
representative existing control/motion/special keys.

`tests/aloemacs/keymap-runner.rkt` must drive plain x, `"ctrl-x"`, `"save"`,
cancellation, and quit through the unchanged runner using scripted Term
and Fs doubles. Verify exact saved text and write counts. Frames after
prefix/cancel show only the path; the frame after successful save shows
`saved:`; the following ordinary key clears it. Verify one write per
frame, fit-before-frame, key-read counts, and no frame/key read after quit.
Exercise redraw between prefix keys and changing size so pending survives
the runner iteration. Preserve clipping, safe-cell rendering, text-row
allocation, and final cursor bytes; include a one-row run.

## Non-goals

Add no other production binding or prefix, including `C-x C-f`, `C-x b`,
or `C-x u`. No M-x, command-name input, minibuffer, find-file, save-as,
extra buffers, windows, splits, mode line, configuration, mutable maps,
rebindings, prefix prompts, or cancellation echo. Do not change search
keys, region painting, clipboard, mark rebasing, or edit grouping.

No Text method, kernel message, Term/Fs interface row, language amendment,
global checkpoint, or checker fix. No command execution method, generic
commands, method-local host parameter, or executable payload. Do not
execute commands through `call` or Mirror. No class-side method,
delegation, inheritance, mutation, macro, implicit Int/Float coercion,
or new special form. Evaluation remains send; the
second element is a literal selector. All new application names use
`Aloemacs` or `aloemacs-`; preserve existing names including
`safe-cell-controls`, `UndoFrame`, and `AloemacsSearchScan`. Do not rename
safe-cell-controls or start Boids.

## Verification and completion

From the project root, run in this order after implementing the slice:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt tests/aloemacs/keymap-prefix.rkt tests/aloemacs/keymap-key-mapping.rkt tests/aloemacs/keymap-runner.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y`. Do not commit `compiled/`. No wider suite,
timing gate, benchmark, or physical TTY is required for this slice.

Review the structure as well as results: one lookup of the selected map,
no pending fallback/default, clear-prefix before command execution, all
constructor sites threaded, no editor `handle-key` send in idle dispatch,
and commands with only `name`. Confirm only the three named product files
changed and the runner/frame/language boundaries stayed intact.

An optional interactive check is
`racket host/racket/aloemacs-run.rkt [path]`. After a `.rkt` edit, first run
the tests above or `raco make host/racket/aloemacs-run.rkt bin/aloe` before
launching; launchers load bytecode and do not rebuild it. `.aloe` edits
alone need no rebuild. The no-TTY suite is the acceptance evidence.

Complete when both test commands pass, `git diff --check` is clean, the
structural review passes, the required save/cancellation/preservation
results hold, and the file scope is respected. Report changed files, the
observed initial focused failure, final verification, and structural
review. Stop when green for human review. This is the last checkpoint in
the accepted two-checkpoint series; do not issue or implement 002.
