# aloemacs-buffer 000 — Buffer value and singleton session

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Move the editor and optional path into an immutable `AloemacsBuffer`.
Store a nonempty `AloemacsBuffers` zipper on the session, initially with
one buffer and empty neighbor lists. Migrate every valid session
constructor and rebuild while preserving today's single-buffer behavior.
Existing session `editor` and `path` sends become computed methods.

Stop at the buffer value and singleton migration. Do not add buffers,
move focus, remove buffers, or add command constructors or bindings.
Those operations belong to aloemacs-buffer 001, which is not issued.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-buffer 000**, filed as
  `checkpoints/000-buffer-value.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), root `AGENTS.md`,
  `SPEC.md`, and `CHECKPOINTS.md` before product edits. `SPEC.md` remains
  Aloe language law.
- The accepted [`../spec.md`](../spec.md) §§1–2 govern authority,
  predecessors, file boundaries, and non-goals. §§3.1–3.7 specify this
  slice completely. §5's **000** commands and singleton/ownership
  acceptance conditions govern completion. §4 is later work.
- There is no earlier checkpoint in this series. Text through Keymap
  are implemented predecessors. In particular,
  [aloemacs-keymap 001](../../keymap/checkpoints/001-prefix-and-ctrl-x.md)
  is implemented, reviewed, and accepted, as recorded in
  [the Keymap README](../../keymap/README.md).
- Neither aloemacs-runner-check 000 nor aloemacs-safe-cell-controls 000
  is a prerequisite. Do not wait for or edit their checkpoint documents.

Start with `examples/aloemacs/file.aloe`: it loads editor and Fs, defines
command/keymap/binding/search classes, and stores the editor and path as
sibling session fields. Its seven session reconstruction sites are
`with-editor`, `with-kill-state`, `with-search`, `with-echo`, `with-prefix`,
`clear-prefix`, and `visited`. `main.aloe` constructs the initial session.
Read the existing runner as a seam; it is outside the edit scope.

The spec supersedes predecessor descriptions of stored session
editor/path fields and whole-session replacement on successful visit.
Preserve their filesystem, command, echo, search, and reset contracts.
Do not amend predecessor documents.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: declare the two buffer classes, replace
  the session fields, add the computed accessors, and thread the current
  buffer/collection through existing reads and reconstructions.
- `examples/aloemacs/main.aloe`: wrap the existing startup editor/path in
  a singleton collection, preserving every other startup payload.
- Create `tests/aloemacs/buffer-value.rkt` before product edits.
- Existing files under `tests/aloemacs/`, only for session construction,
  stored-field/API inventories, exact source expectations, and the
  singleton consequences of this migration. The current inventory is:
  `echo-session.rkt`, `file-session.rkt`, `kill-session.rkt`,
  `motion-editor.rkt`, `runner.rkt`, `safe-cells.rkt`,
  `search-session.rkt`, `undo-session.rkt`, `viewport-editor.rkt`,
  `visited-unchanged.rkt`, `keymap-session.rkt`, `keymap-prefix.rkt`,
  and `file-runner.rkt`.

Search again rather than treating that inventory as exhaustive. Other
existing aloemacs test files may be changed only for the same migration
purposes. Keep substantive assertions and their original intent.

### Must leave untouched

- `examples/aloemacs/editor.aloe` and all other product modules.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, all host
  capabilities and Fs/Term interfaces, runner arguments and sequencing.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, predecessor documents,
  and this series' design documents/checkpoints.
- The command constructors/names, keymaps, binding payloads, lookup and
  dispatch contracts, search-key rules, and editor/UndoFrame shapes.
- All test files outside `tests/aloemacs/`. Do not create
  `buffer-collection.rkt` or `buffer-session.rkt` in this checkpoint.

Add no module, load, dependency, capability, or API beyond the additions
below. If another file or design change proves necessary, stop and send
the checkpoint back to the manager instead of widening the slice.

## Slice requirements

### 1. Buffer and collection values

Keep the two existing loads in `file.aloe`. Declare `AloemacsBuffer`,
then `AloemacsBuffers`, after those loads and before `AloemacsSession`.
Both are non-generic. Retain the relative order of the existing command,
keymap, binding, search-scan, session, and map declarations.

`AloemacsBuffer` has exactly these ordered fields:

```aloe
(editor AloemacsEditor)
(path (Option Path))
```

Construction is `(AloemacsBuffer new editor path)`. Generated `editor`
and `path` selectors read those fields. Add only:

| Send | Result | Behavior |
|---|---|---|
| `(buffer name)` | `String` | `Some(path)` yields exactly `(path text)`; `None` yields `"untitled"`. |
| `(buffer with-editor editor)` | `AloemacsBuffer` | Replace only the editor; preserve the exact optional path. |

Derive the name on demand. Store no name, editor-field copies, or
identity. Preserve relative path spelling supplied directly; do not
resolve, sanitize, shorten, or uniquify it. Echo still derives its own
label from the path. There is no name lookup.

`AloemacsBuffers` has exactly these ordered fields:

```aloe
(before (List AloemacsBuffer))
(current-buffer AloemacsBuffer)
(after (List AloemacsBuffer))
```

Construction is `(AloemacsBuffers new before current-buffer after)`.
Before is reversed logical order, nearest predecessor first. After is
forward logical order, nearest successor first. The mandatory current
buffer makes an empty collection unrepresentable. Add only
`(buffers with-current-buffer buffer) -> AloemacsBuffers`, replacing
the middle value while preserving both lists. `current-buffer` is the
generated field selector. Do not validate paths, names, or editor point
validity in either raw constructor.

Startup, visits, and all valid session fixtures in 000 have empty
neighbor lists. Implement no `focus-next`, `focus-previous`,
`insert-after`, or `remove-current`, and no multi-buffer session behavior.
Old buffers, editors, collections, and lists remain immutable.

### 2. Session ownership and computed access

Replace the stored session editor/path pair with the collection.
The complete ordered fields are:

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
```

Construction becomes:

```aloe
(AloemacsSession new
  buffers fs echo searching query origin wrapped failing kill-ring pending)
```

Add these zero-argument methods:

| Send | Result | Source |
|---|---|---|
| `(session current-buffer)` | `AloemacsBuffer` | Current field of `(session buffers)`. |
| `(session editor)` | `AloemacsEditor` | Editor of `(session current-buffer)`. |
| `(session path)` | `(Option Path)` | Path of `(session current-buffer)`. |

Keep `text`, `point`, and `quit` reading the current editor. Every command,
search, kill, save, label, and frame path reads through that focus. Store
no sibling editor/path, numeric index, second history, or second ring.
The editor's eight ordered fields remain `text`, `point`, `quit`,
`scroll-row`, `scroll-col`, `history`, `mark`, `text-rows`; UndoFrame
remains unchanged.

### 3. Existing rebuilds and file operations

Thread the existing collection through every reconstruction:

| Operation | Collection result | Other session state |
|---|---|---|
| `with-editor`, edit/motion/undo/quit wrappers, `ensure-visible` | Current buffer's `with-editor`, then collection's `with-current-buffer`. | Preserve all. |
| `with-kill-state(editor, ring)` | Replace only current editor. | Supplied ring and echo `""`; preserve fs, search, pending. |
| `with-search(editor, searching, query, origin, wrapped, failing)` | Replace only current editor. | Supplied search fields; preserve fs, echo, ring, pending. |
| `with-echo` | Preserve the entire collection. | Replace only echo. |
| `with-prefix`, `clear-prefix` | Preserve the entire collection. | Retain existing pending/echo rules and all other fields. |
| `unchanged`, direct successful `save` | Preserve the entire collection. | Preserve all. |
| Successful `visited`/`visit` | Replace only current buffer. | Preserve fs; apply existing fresh-visit resets below. |

Do not reconstruct a collection from only its current editor/path and
throw away its lists. Replace current through `with-current-buffer`;
unchanged-buffer rebuilds pass the original collection through.

Successful visit retains resolution and eligibility rules: Fs resolves
the requested path, inspects without following symlinks, and reads only
regular files. A missing path succeeds with empty contents bound to the
resolved path and creates no file. Directory, symlink, other node, or
`read None` refuses the visit with `None`. Refusal changes none of the
source session, including pending. Host failures still raise.

`visited` uses indexed Text from contents, point `(0,0)`, quit `#f`, both
origins zero, empty history, no mark, and `text-rows = 0`. The new buffer
stores `Some(resolved-path)`. Preserve neighbor lists and fs; set echo
`""`, searching `#f`, query `""`, origin `(0,0)`, wrapped/failing `#f`,
ring empty, and pending `None`. Visit replaces current; it never appends.

Direct `save` uses the current path and exact `(text to-string)`.
Untitled yields `None` without a write. `Fs.write None` yields `None`;
success yields `Some` of an equal session. Direct save preserves echo,
search, pending, ring, and every buffer payload. Every explicit eligible
save writes even without an edit. Strict UTF-8, CR/LF, BOM, final-newline
preservation, eligibility, and raised host-failure behavior remain as in
File. Ctrl-S and `C-x C-s` retain their saved/failed echo behavior.

Keep existing undo-frame rules, mark behavior, search movement, and the
session ring. No implicit save or new history frame is introduced by
the ownership migration.

### 4. Startup and all constructor sites

Use exactly the startup shape in spec §3.4: wrap the existing empty cold
Text editor and typed absent path in a singleton collection, then pass
Fs and the remaining session fields. Do not index startup Text or change
the initial `aloemacs-editor` binding, load, or state defaults.

Migrate every valid untyped `AloemacsSession new` site, including test
helpers and independent expected-value builders. Wrap its old editor
and path in a singleton collection, remove the old session path
argument, and preserve its other payloads.

At untyped construction sites, use the existing inferable empty Options:

```aloe
(if #t (Option None) (Option Some (Position new 0 0)))
(if #t (Option None) (Option Some (Path new "/typed-none")))
(if #t (Option None) (Option Some aloemacs-global-keymap))
```

The unselected Some branches supply the mark/path/pending types. Keep
fixture-specific existing typed spellings when appropriate. Do not
use bare `Option None` at untyped sites. A method's expected constructor
field type may supply the type of a direct None. Put cleared Options
directly in rebuilt constructors; add no Option-taking setter or
checker/evaluator workaround.

Keep intentional old-arity negatives as negatives. Migrate other
type-negative fixtures so they still test their original wrong argument.
Replace the old unknown-selector negative for `(session buffers)` with
its valid type assertion. Update stored-field inventories to the ten
fields above; retain checks of the computed editor/path sends. Update
`runner.rkt`'s exact main datums and any affected source/API expectations.
Independent dispatch expectations must construct their expected
buffer/collection rather than call the production dispatcher. Editor-only
constructors and assertions stay unchanged.

### 5. Frame, keys, and prefix preservation

`ensure-visible(columns, rows)` fits only current, using `rows - 1` text
rows when `rows >= 2`, otherwise the existing one-row fallback. Write
the result through session `with-editor`. `frame` remains pure, reads
stored origins, and appends the existing echo suffix without fitting.
Preserve clipping, safe cells, blank padding, complete ANSI bytes, final
text cursor, and one string per Term write.

Keep path/untitled labels, saved/failed tokens, and the existing active
search rows. No echo vocabulary changes. Ordinary commands clear echo
as before; Find retains its token; save keys report the existing outcome.
One-row frames have no echo suffix.

Preserve all 21 command constructors, their names and sole naming
method, the existing `execute-command` case, the 20 global command
bindings followed by the one ctrl-x prefix, and both maps' defaults.
Retain search-before-idle dispatch, the absorbing quit guard, plain
self-insertion, and pending miss consumption without global retry.
Prefix survives ordinary rebuilds, fitting, and framing; successful
visit resets it. Ctrl-S and `C-x C-s` still produce matching results.
The runner keeps zero-or-one-path argv, fit-before-frame, and its current
editor's quit check.

### 6. Focused proof, written first

Create `buffer-value.rkt` and write focused tests before product edits.
Run its verification command and observe the missing classes/accessors
fail, then implement this slice. Use the checked driver, rackunit, and
counted Fs doubles. No physical TTY or production files are needed.

The focused tests must prove:

- Exact buffer, collection, and session field shapes and checked
  constructor arities/types. Check new selectors' results and method
  signatures, rejecting wrong editor/path/collection arguments and
  wrong arities. The stored session surface contains no editor/path
  fields; those sends are methods.
- Names are exactly stored path text or `untitled`, including relative
  spelling. Buffer editor replacement preserves the optional path/name;
  collection replacement preserves neighbor lists and old values.
- A fresh checked load of `file.aloe` defines both classes without
  injected Fs/Term or host effects. Checked main startup with an Fs
  double has exactly one cold-Text untitled buffer and no filesystem
  operation; it needs explicit fs-host and no Term.
- Computed session accessors read that current buffer. Current-editor
  replacement and existing rebuilds preserve all specified state, using
  nontrivial history, mark, both viewport origins, remembered text rows,
  ring, echo, search fields, and pending fixtures.
- Existing/missing-path visits create the exact fresh defaults and
  reset session state. Refused visits preserve the entire source.
  Untitled and bound saves retain outcomes, exact contents, counted
  effects, direct-save preservation, and key-save echo contracts.
- Prefix survives ordinary reconstruction, fit, and frame. Ctrl-S and
  `C-x C-s` retain their equality and prefix-consumption contracts.
  Preserve complete ANSI goldens and one-row behavior.

Keep the migrated suite's substantive editor, keys, history, mark, ring,
search, viewport, filesystem, and exact-frame assertions. Do not weaken
them to obtain a pass. No test or production send adds, switches, or
kills a second buffer in 000; all valid session fixtures stay singleton.

## Non-goals

No `add-buffer`, focus movement, buffer removal, SwitchBuffer/KillBuffer
command values, new bindings, Term chords, or runner arguments. No
minibuffer, find-file, save-as, named selection, `C-x C-f`, `C-x b`, M-x,
another prefix, windows, splits, mode line, buffer menu, dirty bit,
kill confirmation, save-on-kill, region painting, clipboard, or new
editor field. No two-file interactive demo.

No Text/List extension, index or cached count, Vector, kernel message,
language amendment, global checkpoint, class method, delegation, Mirror,
inheritance, mutation, macro, implicit Int/Float coercion, or special
form. Evaluation remains send with a literal selector; function objects
execute only through `call`. Do not start Boids or checkpoint 001.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/buffer-value.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test run. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or hand check is
required. The optional launch remains
`racket host/racket/aloemacs-run.rkt [path]`; after a `.rkt` edit, first
run tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`, because
launchers load existing bytecode without rebuilding it. `.aloe` edits
alone need no rebuild.

Review the source as well as the test results: buffer is the sole
editor/path owner; session stores only the collection and its specified
session state; computed reads follow current; every reconstruction
preserves/replaces the collection correctly; no constructor site or
stored-field expectation was missed. Behavioral equality alone cannot
prove the ownership boundary. Confirm the runner, editor, maps, host,
libraries, and language boundaries remain intact.

Complete when both test commands pass, `git diff --check` is clean,
the structural review passes, all singleton results are preserved, and
the file scope is respected. Report changed files, the observed initial
focused failure, final verification results, and the structural review.
Stop when green for human review. Do not implement or issue 001.
