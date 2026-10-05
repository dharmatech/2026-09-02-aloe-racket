# aloemacs completion specification

**Status: Accepted on 2026-10-04 after review.** Previously accepted
behavior stays. §§2 and 3.3 place recursive scans on the nongeneric
`AloemacsCompletionScan`; Fs queries and prompt results stay on
`(AloemacsSession H)`. Checkpoint 000 has been rewritten against this
accepted revision and is ready to implement. This file is the complete
design input to the checkpoint manager and implementers. This is application design;
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law and
[`docs/workflow.md`](../../../../workflow.md) governs the review boundaries.

Find-file and save-as open an editable path prompt with initial text. Tab
completes its last path component by case-sensitive prefix. A unique
directory gains `/`; an ambiguous Tab that cannot extend the text prepares
matching base names, which the second checkpoint paints above the prompt.
Return submits the editable string. The names are display, with no
selection or movement through them.

## 1. Series, predecessors, and authority

The series identity is **aloemacs-completion**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code stays in
`examples/aloemacs/`, with the Tab conversion in `host/racket/term.rkt`.
Tests stay in `tests/aloemacs/`. This folder receives design documents
and later checkpoints, never program code.

There are two intended checkpoints, in this order:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-completion 000** | `checkpoints/000-complete-on-tab.md` | Prompt metadata and constructor migration, prefill, plain Tab conversion, prefix completion, prompt-row notes, and readable prepared lines. Return/Escape retain their command results. No list rows are painted or reserved; the root remains `rows - 1` when an echo row exists. |
| **aloemacs-completion 001** | `checkpoints/001-show-matches.md` | Paint prepared lines above the last-row prompt, shorten session fit/frame geometry, and prove split/fallback/resize composition. Without a list, retain 000's complete frames and fit results. |

Numbers have three digits, start at 000, and are never renumbered. Slugs
are lowercase words separated by hyphens. After human acceptance, the
manager rewrites the existing **000 only**, then stops. Human review of
that implementation precedes issuing 001. Each implementer writes focused tests first,
implements only the approved slice, runs verification, and stops when
green. Do not issue both documents together or use a global integer in
`CHECKPOINTS.md`.

Keep these two checkpoints. 000 changes the prompt constructor but leaves
all session construction arities intact; its migrations belong to the
same slice as the result they enable. If the manager's exact inventory
shows that Term-plus-prefill and the Tab result cannot fit one implementer
conversation, those two pieces may be separated, adding no behavior and
keeping list painting last. Record the new mapping in this folder's README
before issuing an affected number. Never renumber an issued checkpoint;
the manager still writes one at a time and leaves the full suite green
at every stop.

Layers 1–18 in the [parent map](../README.md) are implemented predecessors.
Required seams are prompt commands and their waiting slot; prompt editing
and cursor clamp; windows geometry and the last-row echo; mode-line leaf
rows and selected fit; `Fs.current`, `path`, `parent`, `name`, `inspect`,
and `entries`; and String `starts-with?` and clamped `take`. Final human
review of windows or mode line may remain open; this series does not wait
for it or repair those layers.

**aloemacs-idle-echo 000 is not a predecessor.** It may land before or
after completion. Preserve whichever accepted idle echo behavior is
present. An active prompt owns the echo row in either case. Do not edit
that checkpoint or change its idle payload.

**checker-recursion is not a predecessor or an assignment.** The current
checker rechecks method bodies on each send to a legacy generic
`(fields ...)` class such as `(AloemacsSession H)`. Recursive sends on
that receiver do not finish checking. Nongeneric class bodies are checked
once at definition, as are generic classes with explicit constructors
such as `SPEC.md` §9's `(Tree T)`. This series uses the nongeneric receiver
specified in §3.3 and leaves the checker unchanged.

Authority for preserved seams is:

- [`../prompt-commands/spec.md`](../prompt-commands/spec.md): command
  constructors, labels/chords, waiting/submission protocol, Return,
  Escape, buffer reuse, writes, and exact-name selection.
- [`../minibuffer/spec.md`](../minibuffer/spec.md): prompt ownership,
  start guards, editing, ignored keys, and screen-column clamp.
- [`../windows/spec.md`](../windows/spec.md): tree/ID/origin ownership,
  nominal geometry, dividers, command/lock rules, selected fit, and
  the global too-small-tree fallback.
- [`../mode-line/spec.md`](../mode-line/spec.md): derived buffer-name
  rows, leaf `text-rows`, and complete one-view/multi-view composition.
- [`../echo/spec.md`](../echo/spec.md),
  [`../safe-cells/spec.md`](../safe-cells/spec.md), and
  [`../keymap/spec.md`](../keymap/spec.md): the reserved last row,
  three stored tokens, clipping before safe cells, input precedence,
  pending-prefix consumption, and the idle named-key miss.
- [`lib/fs.aloe`](../../../../../lib/fs.aloe),
  [`host/racket/fs.rkt`](../../../../../host/racket/fs.rkt), and
  [`lib/string.aloe`](../../../../../lib/string.aloe): existing thin
  filesystem messages, entry classifications, directory-only `names`,
  and library `starts-with?`.
- [`file.aloe`](../../../../../examples/aloemacs/file.aloe),
  [`main.aloe`](../../../../../examples/aloemacs/main.aloe), and
  [`term.rkt`](../../../../../host/racket/term.rkt): implementation
  starting points. `SPEC.md` §9 governs typed absent Options.

This spec supersedes predecessor refusals of prefill and completion,
the three-field prompt inventory, and ignored named Tab on the two file
prompts. In 001 it supersedes only the session fit/frame root height while
prepared lines are visible. Return, idle echo, root height without a list,
window commands, and all other predecessor behavior remain authoritative.
Do not edit predecessor documents or language law to update their old
inventories. The charter was the designer assignment; it supplies no
additional rule a later conversation must recover.

## 2. Product, host, and file boundary

The implementation is checked Aloe. Racket tests use the existing checked
driver, `rackunit`, counted readable Fs doubles, and scripted Term doubles
without a TTY. Keep `file.aloe`'s two existing loads and relative declaration
order. In 000, add exactly one fieldless nongeneric class,
`AloemacsCompletionScan`, immediately after `AloemacsPrompt` and before
`AloemacsBuffer`. Its data section is `(fields)`, with no type parameters;
its ordinary constructor is `(AloemacsCompletionScan new)`.
It owns only the pure character scan and common-prefix fold in §3.3.
`complete-prompt`, every Fs query, filtering, the prompt result, notes,
and prepared lines remain on the existing generic `(AloemacsSession H)`,
where the concrete injected Fs host is available. The session asks a
local scanner value for an offset or prefix; it stores no scanner.
There is no other new class, result object, dependency, module, or host
interface.

| Part | Product files it may edit | Focused tests to add |
|---|---|---|
| 000 | `examples/aloemacs/file.aloe`; `examples/aloemacs/main.aloe` only for the absent-prompt witness; `host/racket/term.rkt` only for plain Tab normalization | `tests/aloemacs/completion-session.rkt`, `tests/aloemacs/completion-key-mapping.rkt` |
| 001 | `examples/aloemacs/file.aloe` only, for list composition and session fit/frame geometry | `tests/aloemacs/completion-frame.rkt` |

Affected existing tests under `tests/aloemacs/` may receive prompt-constructor,
prefill, Tab, and exact-frame/fit expectation updates for their owning part.
The manager searches the inventory in §3.6 and names the exact subset;
this is not permission for unrelated test cleanup. Neither slice leaves
a regression failure for its successor.

Leave `examples/aloemacs/editor.aloe`, `host/racket/aloemacs-run.rkt`,
`host/racket/fs.rkt`, all libraries and language implementation, `SPEC.md`,
`CHECKPOINTS.md`, the global checkpoint spine, and predecessor design and
checkpoint documents untouched. The editor, UndoFrame, buffer, view,
window configuration, command constructors, and both keymaps keep their
shapes. The session keeps its fourteen fields in the existing order:
`buffers`, `fs`, `echo`, `searching`, `query`, `origin`, `wrapped`,
`failing`, `kill-ring`, `pending`, `prompt`, `last-submission`,
`waiting-command`, `windows`.

The runner retains its arguments and `aloemacs-editor` binding, queries
the full terminal size, fits before framing at that same size, writes
one frame String through one `term write`, then reads/handles one key.
Neither prompt work nor frame runs fit or Term effects itself. The existing
optional launch is `racket host/racket/aloemacs-run.rkt [path]` from the
project root; no build step or dependency is added.

Explicit non-goals are a live list, fuzzy/substring/partial matching,
Up/Down or a highlighted row, buffer-name/command completion, `M-x`, `~`
expansion, wildcards, history, `mkdir`, a directory browser, opening a
directory with Return, paging/cycling names, Tab indentation, symlink
traversal for completion, prompt undo, a dirty bit, and a new echo token.
No host, String, Text, or Term method, List index, `SPEC.md` row, runner
change, Mirror, mutation, inheritance, delegation, macro, or new special
form belongs here. Evaluation is send; function objects run only through
`call`. Do not add recursive completion methods to any legacy generic
`(fields ...)` class, edit `aloe/`, or take checker-recursion as a
prerequisite. Do not specify a later project or start Boids.

## 3. Layer 000 — prefill and completion result

### 3.1 Prompt-owned display state

Append two fields to `AloemacsPrompt`, keeping its existing fields first:

```aloe
(label String)
(text String)
(column Int)
(completion-note String)
(completion-lines (List String))
```

Construction becomes `(AloemacsPrompt new label text column note lines)`.
The generated reads `completion-note` and `completion-lines` return
`String` and `(List String)`. Normal starts use `""` and `(List empty)`.
Normal completion results contain either no display state, one of the
two exact notes in §3.4, or at most eight prepared lines in §3.5. A note
and a nonempty list are never both present. Raw constructors supply these
invariants; do not introduce a validator or another active flag.

Add these prompt methods:

| Send | Result | Contract |
|---|---|---|
| `with-completion(text : String, note : String, lines : (List String))` | `AloemacsPrompt` | Preserve label. Install the three arguments. If the text differs, set column to its new length; otherwise retain the old column. Callers supply the display-state invariants above. |
| `clear-completion()` | `AloemacsPrompt` | Preserve label/text/column, set note `""` and lines empty. |

`row()` now returns `label append text append completion-note`, before
clipping or safe cells. The note is never editable, submitted, or included
in `screen-column`. Keep the existing cursor rule, for positive width:
`min(columns, label.len + column + 1)`. Notes can be clipped away, and the
cursor can clamp onto the last visible cell, without changing stored data.

Valid one-character `insert` clears completion state before editing.
`backward-delete` clears it before deleting, **including at column zero**.
The four horizontal motions preserve both fields, including boundary
motions. Invalid insert arguments and direct LF input keep today's
unchanged result and do not clear anything. All other editing arithmetic
is unchanged. In particular a direct one-character `"\t"` remains an
editable control; it is distinct from the named key `"tab"`.

The user cannot insert LF through the existing prompt key rule. Completion
copies raw filesystem names, including any controls such as LF, without
sanitizing them. Such a result still paints on one row through `row`,
`take`, and `safe-cells`; it is never split into text lines. Column counts
String characters as before. This extends the old no-LF prompt-content
invariant only for raw completion data, as required by character retention.

No session field is added. Add these session reads, independent of Fs:

| Send | Result | Active prompt | No prompt |
|---|---|---|---|
| `completion-note()` | `String` | Its `completion-note` | `""` |
| `completion-lines()` | `(List String)` | Its `completion-lines` | Empty list |

000 exposes the prepared lines through these reads without painting or
reserving a row for them. Reading them neither recomputes nor consumes
them. All existing reconstructions that preserve the prompt preserve its
whole new value. Successful direct visit still discards the prompt, and
therefore its note/list; a refused visit retains it exactly.

At an untyped absent-prompt constructor use the lawful witness:

```aloe
(if #t
    (Option None)
    (Option Some (AloemacsPrompt new "" "" 0 "" (List empty))))
```

The unselected branch supplies the Option type. Do not replace it with
bare `(Option None)`, add an Option setter, or change checking. Method
constructor positions with an expected type retain their lawful direct
`None` spelling. Session arity and every other startup default stay exact.

### 3.2 Starting a prefilled command prompt

Use the existing selector
`start-command-prompt(command : AloemacsCommand, label : String)` as the
prefilled starter, retaining its concrete `(AloemacsSession H)` result
and signature. `execute-command` keeps the installed command constructors,
labels, and chords: `C-x C-f` / `FindFile` / `"Find file: "`,
`C-x C-w` / `SaveAs` / `"Save as: "`, and
`C-x b` / `SelectBuffer` / `"Buffer: "`. Its key argument still supplies
neither initial text nor a path. Dispatch cases on command values, never
on label or command-name strings.

First apply the existing start gate: quit, active search, pending prefix,
or an active prompt each returns the whole receiver unchanged. Perform
this gate **before any prefill query**. Refusal cannot replace the prompt,
metadata, waiting slot, submission, or echo. The normal chord still clears
its prefix before execution and therefore passes that part of the gate.

On a permitted start, choose the editable text:

| Command and current binding | Initial text |
|---|---|
| FindFile, bound path | That path's parent-directory text with a trailing `/` |
| FindFile, pathless | `(fs current)` text with a trailing `/` |
| SaveAs, bound path | Stored path text exactly |
| SaveAs, pathless | Same directory text as pathless FindFile |
| SelectBuffer or another command passed directly to this helper | `""`, as before |

Add session `file-prompt-directory() -> String` for the shared directory
rule. With a bound path, send `Fs.parent` on it; use the `Some` parent's
text, or the stored path text itself on `None`. With no path, use
`Fs.current` text. Keep text that already ends in `/`; otherwise append
one `/`. Root stays `/`, and `/home/me` becomes `/home/me/`. Bound save-as
does not call this helper or add a slash to its full file path.

Start an `AloemacsPrompt` with the chosen text, column `text.len`, empty
note, and empty list, and store the actual waiting command. Preserve the
other session state and any previous submission/echo. A permitted start
may replace an orphaned waiting slot, as today. The directory/path text
is editable data, separate from the label; it is not painted as a default
outside the editable string.

Prefill may query `current` or `parent`. It never sends `inspect`,
`entries`, `name`, `read`, or `write`, and does not resolve a typed path
through `Fs.path`. It makes no directory listing. Bound save-as, select-
buffer, bare start, and all refused starts make zero Fs calls. Paths
produced by ordinary buffer operations are stored absolute paths; save-as
also preserves the exact stored text of a directly constructed path.
Return still resolves through `Fs.path`; no `~` expansion is introduced.

`start-prompt(label : String)` remains an empty-text start at column zero
with the same gate and no Fs calls. It neither fills nor clears the
waiting slot. With that slot absent its Return remains storage-only.
Keep this distinct from the command starter.

### 3.3 One shared session decision

Add `complete-prompt() -> (AloemacsSession H)`. Called directly, it
requires an active prompt and a waiting `FindFile` or `SaveAs`; otherwise
it returns the whole receiver unchanged and makes no Fs call. In the
active-prompt key table, named `"tab"` sends this method. SelectBuffer,
a bare prompt, and any non-file waiting constructor therefore ignore
Tab. The ordinary `handle-key` quit/search guards still own key precedence.

Both eligible constructors use the same completion algorithm on the
whole prompt `text`. The stored column does not choose a component.
The session owns the decision and Fs operations; self-recursive scans
and folds belong to the fieldless nongeneric `AloemacsCompletionScan`.
Do not move Fs, Entry classification, prompt metadata, or result application
onto that receiver. It takes only String, Int, and `(List String)` data,
returns an Int or String, and has no host, session, prompt, or buffer
payload. It introduces no callback interface, host helper, or String
method. Use existing String `take`, `drop`, `len`, `=`, `append`, and
`starts-with?`, and existing Int/List sends; no List index or buffer Text
materialization is needed.

The scanner has these exact typed sends in 000:

| Send | Result | Contract |
|---|---|---|
| `split-offset(text : String)` | `Int` | Character offset immediately after the last `/`, or `0` if absent. Starts `scan-slashes(text, 0, 0)`. |
| `scan-slashes(remaining : String, offset : Int, latest : Int)` | `Int` | Internal scan with `0 <= latest <= offset`. Empty remainder returns `latest`; otherwise consume one character, advance `offset`, set `latest` to that advanced offset only for `/`, and recurse on this scanner. |
| `common-prefix(names : (List String))` | `String` | Empty list returns `""`; otherwise starts `prefix-in` with the first raw name and the rest. |
| `prefix-in(prefix : String, names : (List String))` | `String` | Empty list returns `prefix`; otherwise reduce it with `shared-prefix(prefix, first name)`, then recurse on this scanner with the rest. |
| `shared-prefix(prefix : String, name : String)` | `String` | Return `prefix` if `name starts-with? prefix`; otherwise remove its final character with `take` and recurse on this scanner. The empty prefix always matches, so shortening stops. |

`scan-slashes` consumes a shorter String on each recursive step;
`prefix-in` consumes a shorter List; `shared-prefix` shortens its prefix.
Keep these bodies on this nongeneric receiver, with the declared result
types, so definition checking finishes without re-entering a legacy
generic session body. Do not replace it with another `(Name H)`
`(fields ...)` class or add recursive session wrappers. Filtering and
prepared-line assembly on the session use existing List sends and local
values, without new self-recursive session helpers.

For an eligible Tab the session constructs a local scanner, sends
`split-offset` the prompt text, and obtains the directory string with
`text.take(offset)` and the leaf with `text.drop(offset)`. After its
guarded Fs query and name filtering, it sends `common-prefix` the raw
matching names when at least two remain. It then applies §3.4 and §3.5
on the session through prompt `with-completion`. No scanner or prefix is
cached between Tabs. The scanner can be checked and exercised without
an Fs injection, active prompt, terminal, or session.

Split at the **last** slash:

| Text | Directory string | Leaf |
|---|---|---|
| Contains `/` | Prefix through that slash | Suffix after it, possibly empty |
| No `/` | `""` | Whole text |

An empty directory string uses `(fs current)`. Otherwise use
`(fs path directory-string)`. Inspect that directory Path. Only
`Some(Entry Directory)` permits exactly one `entries` send; every other
classification or `None` supplies zero candidates and sends no `entries`.
Do not send the host's `names` directly. This guard keeps the directory-
only host operation from being called on missing, regular, symlink, or
Other paths. A host failure, including an unreadable real directory or
a race after the guard, still propagates. There is no new error channel.

For each returned Entry, obtain its raw name with `(fs name (entry path))`.
Keep it only if both conditions hold:

- Name `starts-with?` the leaf, case-sensitively.
- A name beginning with `.` is allowed only when the leaf begins with `.`.

Keep `entries` order after filtering; never sort again. `.` and `..`
are already absent from directory names. Empty leaf matches every
non-hidden name. Preserve spaces, controls, and case exactly. Classification
comes from the Entry already returned by `entries`; do not inspect a
symlink as a directory or follow it to decide a display slash.

The original directory string is the replacement prefix. It is not
rewritten to the resolved absolute spelling. `src/../src/fi`, `./fi`,
`/cwd//fi`, and slashless `fi` retain their respective typed prefixes
when extended. Filesystem resolution serves lookup only.

The completion decision sends only the existing Fs `current`, `path`,
`parent`, `name`, `inspect`, and `entries` vocabulary as needed. It never
sends `read` or `write`. `entries` internally sends host `names`, `child`,
and classifications/resolutions under the unchanged thin Fs implementation;
tests count those underlying calls rather than inventing a one-call host
listing. No listing occurs on ordinary typing, motion, start, fit, or paint.

### 3.4 Exact result and prompt-row notes

Let `prefix` be the original directory string, `leaf` its suffix, and
`names` the remaining raw names. The longest common prefix is computed
from raw names, without any display `/`. Recompute from the current text
on **every** Tab, replacing the previous note/list even when text stays.

| Candidates | Replacement text | New note | New prepared lines |
|---|---|---|---|
| None, including an ineligible directory | Original text | `" [No match]"` | Empty |
| One, replacement differs | `prefix + name`, plus `/` only for a Directory Entry | `""` | Empty |
| One, replacement equals original text | Original text | `" [Sole completion]"` | Empty |
| Two or more, common-prefix length exceeds leaf length | `prefix + common-prefix`, with no added slash | `""` | Empty |
| Two or more, common-prefix length does not exceed leaf length | Original text | `""` | §3.5's prepared lines |

Here `+` means String concatenation. Use prompt `with-completion` so any
text change sets its column to the new end; unchanged text keeps its
column, even when a note/list changes. A unique Directory Entry always
adds exactly its component's trailing `/`. Its next Tab has an empty
leaf and looks inside it. RegularFile, SymbolicLink, and Other contribute
only their name. A symlink receives no slash, and `link/` is an ineligible
directory to inspect for listing.

Both notes start with the one space shown. The note follows editable text
on the prompt row, then the combined row is clipped with `take columns`
and passed through existing `safe-cells`. The note is not an echo token
or an extra row. 000 already paints notes, while storing lists without
painting them. At one terminal row both remain readable in state but
there is still no echo row.

For an ordered directory containing `alpha.txt`, `alpine.txt`, `docs`
(Directory), `link` (SymbolicLink), `pipe` (Other), and `.secret`:

| Typed text | Tab result | Display state |
|---|---|---|
| `/cwd/a` | `/cwd/alp` | Empty |
| `/cwd/alp`, column 2 | Unchanged, column 2 | `alpha.txt`, `alpine.txt` |
| `/cwd/alph` | `/cwd/alpha.txt`, cursor at end | Empty |
| `/cwd/alpha.txt`, column 3 | Unchanged, column 3 | ` [Sole completion]` |
| `/cwd/do` | `/cwd/docs/`, cursor at end | Empty |
| `./do` | `./docs/`, cursor at end | Empty |
| `li` | `link`, cursor at end | Empty |
| `/cwd/z` | Unchanged | ` [No match]` |
| `/cwd/.s` | `/cwd/.secret`, cursor at end | Empty |

With an empty leaf, `.secret` is excluded. Unique results and common-
prefix growth show no list until a later Tab cannot add a character.

### 3.5 Preparing names, independent of terminal size

For the ambiguous unchanged-text case only, prepare display lines from
the filtered entries in order. Each line is its raw base name, with `/`
appended only for a Directory Entry. That slash never participates in
common-prefix calculation. Do not add paths, markers, a selected row,
ANSI, padding, clipping, safe-cell replacement, or an ellipsis to a name
at preparation time.

| Match count | Prepared lines |
|---|---|
| At most eight | Every display name |
| More than eight | First seven display names, then `...(+N)` where `N = total matches - 7` |

Nine matches prepare seven names and `...(+2)`; eight matches prepare all
eight names. Use existing Int `text` and String `append` to form the
summary. These raw lines are stored as prompt `completion-lines`, with
note `""`. Terminal dimensions do not influence preparation. A new Tab
queries the directory again, so a changed double/filesystem can replace
the result; Tab neither pages nor cycles a candidate into the text.

### 3.6 Keys, command outcomes, migration, and proof

`handle-key` retains quit, search, active prompt, pending prefix, then
idle map in that order. Named `"tab"` has length greater than one and
receives no keymap binding:

| State when Tab arrives | Result |
|---|---|
| Already quit | Whole session unchanged |
| Search active | Existing other-key rule: end search, then idle dispatch; no prompt completion |
| Active FindFile or SaveAs prompt | §3.3–§3.5 |
| Active other/bare prompt | Whole session unchanged, zero Fs calls |
| Pending prefix, no search/prompt | Consume the miss, clear prefix and echo, no retry |
| Idle | Named-key miss clears echo, inserts nothing, indents nothing |

Insert and backspace clear note/list under §3.1, with no lookup. Left,
right, line-start, and line-end preserve them. LF and every other ignored
prompt key, including Up/Down, preserve the whole active session. Return
and Escape end the prompt and thereby drop both fields. Raw mixed-state
fixtures follow the same existing precedence; search's idle fall-through
does not retry Tab through a preserved prompt.

Return stores **only `prompt.text`**, deactivates the prompt before running
the waiting command, then clears that slot after a returned outcome.
Notes and prepared names never affect submission. Empty input still
fails a file command without any Fs call/write, even though ordinary file
starts now prefill nonempty text. A second inactive submit still does
nothing. Escape retains the previous submission and echo, runs nothing,
and does not quit; direct cancel still clears an orphaned waiting slot.

Find-file still resolves the submitted string, reuses the first exact
buffer name before reading, opens a regular file, or adds an empty bound
buffer for a missing path without creating it. A directory, symlink,
Other, or returned read refusal fails without adding/switching a buffer.
Save-as still writes current exact text and changes only its binding on
success; write refusal preserves that binding/editor. Select-buffer
still matches the typed exact derived name, with no Fs query. Host failures
retain the existing propagation. Completion of a directory does not
authorize Return to open it. Direct selection during a prompt preserves
its whole value/slot; Return acts on the buffer current then.

Start, completion, clearing, and paint preserve the buffer collection,
focus, every buffer/editor value (exact Text/focus, point, quit, history,
mark, origins, remembered rows, path/name/ID), window tree/selection/locks,
Fs, ring, search fields, echo, pending, submission, and waiting command,
except the existing start slot update or the key-table transitions above.
They push no UndoFrame, fit no buffer, and add/switch/kill none. Rendering
never writes the stored `""`, `"saved"`, or `"failed"` token.

In `tkeymsg->aloe-key`, before both printable branches, install exactly
this mapping:

| tkeymsg key | mods | char | Aloe key |
|---|---|---|---|
| `#\tab` | Exactly `'()` | `#f` or `#\tab` | `"tab"` |

Shift-Tab stays on the existing unsupported path. Other modifiers and a
mismatched decoded character retain their existing conversion/error
behavior. The byte Tab already arrives as `#\tab`; add no Ctrl-I mapping,
decoder change, Term method, or second representation.

Migrate every valid `AloemacsPrompt new`, including independent expected
values and absent-prompt witnesses, by appending `""` and `(List empty)`
unless the fixture deliberately tests new metadata. Search product and
the whole aloemacs suite again. Current sites include `main.aloe`, prompt
editing/submit witnesses in `file.aloe`, `minibuffer-*.rkt`, the three
`prompt-commands-*.rkt` files, `windows-*.rkt`, `mode-line-*.rkt`,
`buffer-*.rkt`, and runner, echo, keymap, file, kill, motion, safe-cells,
search, undo, viewport, visited-unchanged, and idle-echo tests. Update the
exact prompt inventory only; no session arity migration is required.
Keep intentional old-arity negatives; other negatives must retain their
original field/type error at the new arity.

For predecessor command proofs that typed into an empty file prompt,
make the replacement input explicit. To keep a relative submission,
send `line-end`, then `backspace` once per initial-text character, then
type the original relative string. To prove empty submission, delete all
prefill before Return. A direct non-runner fixture may install the intended
five-field prompt with `with-active-prompt`, preserving the actual waiting
slot, when start itself is not under test. Normal absolute prefill may
instead remain when the scenario deliberately tests that absolute string.
Do not concatenate an old full-path input onto prefill accidentally or
change the intended Return target/result. Keep assertions on the exact
submission and Fs calls. Runner scripts must account for deletion keys
and their drawn iterations, or explicitly expect submission of the
prefilled absolute path. Prefill query calls are counted separately
from submission effects; old zero-call start assertions change only for
the starts §3.2 explicitly allows to query Fs.

000's tests first prove the five-field prompt, its reads/helpers and
types/argument/arity negatives; fieldless nongeneric scanner construction,
all §3.3 helper signatures and argument/arity negatives, and checked
recursive results without Fs injection; concrete session result types
with two injected Fs host identities; unchanged session/command/map inventories;
effect-free fresh checked loads and startup. Direct scanner proofs cover
empty/slashless/root/trailing/repeated/multiple-slash strings, and raw
controls; empty/single/multiple name lists; equal names, an empty name,
no shared prefix, and successive names that shorten the prefix more than
once. Expected offsets and prefixes are independent literals. Exercise
recursive paths through checked sends, not an unchecked evaluator or a
host implementation; do not add a hanging legacy-generic negative test.
They then prove every start case/guard, each result-table arm,
unchanged-column vs moved-to-end
behavior, spelling retention, hidden-name filtering, Entry classifications,
zero/one/eight/nine-or-more candidates, raw controls, and order from an
intentionally unsorted names double. Cover empty/slashless/root/multiple-
slash/relative directory inputs and every non-directory inspection result.
Count one host `names` enumeration per eligible Tab and none on ineligible
directories; count no file read/write before Return. Do not assert that
`inspect` performs no resolve or that `entries` performs no child inspection.

Also prove repeated Tab recomputes, edit/backspace/motion/ignored-key
lifetimes, start/prefill/Tab buffer preservation using rich multi-buffer
and shared-view fixtures, every routing-table case, unchanged tokens,
and exact notes/cursor/clipping in full ANSI frames. Prepared lines remain
readable but unused by fit/frame: root height and mode-line allocation
still follow the predecessors at every size. Preserve Return outcomes,
buffer reuse, missing-file no-creation, save-as writes/refusals, empty
submission, exact selection, cancellation, and direct-operation prompt
preservation. A scripted no-TTY runner sequence proves prefill, Tab,
Return/cancel, fit-before-frame, and one write per drawn iteration.
The separate converter proof covers both plain Tab shapes, Shift-Tab,
modifier/decoded-character exclusions, and representative existing keys.

Stop with 000's focused tests and the full suite green. Do not paint
prepared lines or reduce the root in this checkpoint.

## 4. Layer 001 — paint the prepared list

### 4.1 Shared session root and selected fit

Use only stored prepared lines; fit/frame perform no Fs operation.
Introduce these ordinary session sends in 001, without adding fields:

| Send | Result | Contract |
|---|---|---|
| `completion-row-count(rows : Int)` | `Int` | `0` for `rows < 2`; otherwise `min(completion-lines.len, max(0, rows - 2))` |
| `root-rect(columns : Int, rows : Int)` | `AloemacsWindowRect` | `(0, 0, columns, rows)` for `rows < 2`; otherwise `(0, 0, columns, rows - 1 - completion-row-count(rows))` |
| `fit-rect(columns : Int, rows : Int)` | `AloemacsWindowRect` | From that root, use the selected nominal leaf when the whole tree has positive layout; otherwise the root, retaining the existing selected-lookup fallback |

Positive terminal dimensions remain the normative frame/fit contract.
Let `k = completion-row-count(rows)` and `h = root-rect.rows`. An active
prompt with no prepared list has `k = 0`; an inactive session's list read
is empty. The root always retains at least one row at positive sizes.
Prepared lines are not shortened or rewritten when only part fits:
paint the first `k` lines, without recalculating `...(+N)`.

Session `frame`, `single-frame`, `multi-frame`, and `ensure-visible`
use this same root and selected rectangle. Single-view and the global
too-small-tree fallback use `root.text-rows`; visible splits use the
selected leaf's unchanged `text-rows` rule for fit. A leaf of height at
least two still has its name in its last row and text above; a shorter
leaf has only text. Recompute all tree layout and divider/junction cells
within the shorter root using existing algorithms. If any leaf has a
zero axis, use the existing whole-root fallback, even if selected alone
has a positive rectangle. No tree, ID, lock, or inactive origin is lost.

Fit still changes only current editor origins/remembered text rows, the
selected-origin mirror, and remembered full terminal dimensions. It
preserves the prompt, metadata, all other buffer payloads, inactive origins,
selection, locks, and shape. Shrink/growth uses this derived height on the
next runner fit. Clearing the list restores normal available height on
the next fit; minimal fit may retain a previously needed selected origin.
No old origin is saved/restored specially. Repeated fit remains idempotent.
Frame never fits or records a size. Page distance remains the editor's
existing rule for its remembered selected text height.

Keep `AloemacsWindows.text-rect`, `fit-rect`, and window command/lock
geometry methods unchanged. They remain the command geometry based on
the full remembered terminal dimensions and reserved echo row. The new
session helpers govern list-aware fit/paint only. Normal prompt keys do
not dispatch window commands; direct window/buffer sends retain their
existing transitions and preserve the whole active prompt. An existing
post-split call to session fit naturally uses the list-aware fit. There
is no new split refusal, lock policy, or command-owned list state.

### 4.2 Full-width lines and exact composition

Each prepared line paints in one full-width terminal row immediately
above the prompt, below the root. For line number `j` in `1..k`, address
terminal row `h + j`, column 1, then paint:

```text
shown-line = current-editor.safe-cells(prepared-line.take(columns))
```

No marker, selection, padding, ellipsis, extra newline, or per-line cursor
is added. The frame's existing clear leaves unused cells blank. Controls
0–31 and 127, including raw LF/CR/Tab/ESC in names, paint as one space
after clipping. Raw text and prepared lines remain intact. At `rows >= 2`
the prompt stays on row `rows`, with its unchanged `screen-column`; a
list never owns a cursor.

For one leaf or fallback, retain the complete
`editor.frame(columns, root.text-rows)` prefix, including its intermediate
cursor show. Append the existing suffix in this exact order:

```text
ESC[?25l
[ESC[h;1H shown-mode, only when h >= 2]
[ESC[h+j;1H shown-line-j, for j = 1..k in order]
ESC[rows;1H shown-echo
ESC[final-row;final-columnH ESC[?25h
```

For visible split leaves, keep the one envelope and compose:

```text
ESC[?25l ESC[2J ESC[H joined-root-rows
[ESC[h+j;1H shown-line-j, for j = 1..k in order]
[ESC[rows;1H shown-echo, only when rows >= 2]
ESC[final-row;final-columnH ESC[?25h
```

The notation's spaces, brackets, and newlines add no bytes.
`joined-root-rows` contains exactly `h` full-width rows joined with CRLF,
with no trailing CRLF. Single/fallback keeps its unpadded editor rows and
derived name row. Both composers use the existing safe/clipped echo
selection, now including §3.1's note when a prompt is active. With a
visible prompt, the final cursor is `(rows, prompt.screen-column(columns))`;
otherwise retain the selected text cursor formula. At `rows = 1`, paint
no echo/list/mode row and keep the predecessor frame and text cursor.
There is still one clear and one resulting frame String, written once.

When no list is present, all root/fit values and **complete frame bytes**
match 000, including single-frame's intermediate show/hide sequences,
short leaves, fallback, prompt notes, search, saved/failed status, and
the existing idle echo payload. Direct editor frames never change.

For example, with eight prepared lines:

| Terminal rows | Painted list rows | Root height | Prompt row |
|---|---|---|---|
| 1 | 0 | 1 | Absent |
| 2 | 0 | 1 | 2 |
| 3 | 1 | 1 | 3 |
| 5 | 3 | 1 | 5 |
| 10 | 8 | 1 | 10 |
| 12 | 8 | 3 | 12 |

At height five the first three prepared lines appear, even if line eight
is a summary. At height twelve a one-view root has two buffer-text rows,
its mode line on row 3, eight list rows on 4–11, and prompt on row 12.

### 4.3 Focused proof and migration

Add `tests/aloemacs/completion-frame.rkt` before product edits. Construct
prepared-list prompts directly for pure painter tests, and drive actual
Tab for integration proofs. Build expected geometry and complete ANSI
strings independently of the production helpers. Keep 000's metadata,
completion, converter, and command proofs green. Migrate existing frame
expectations only where a test now explicitly shows a list; with no list
those frames and fit expectations must be byte/value identical to 000.

Prove typed helper signatures and negatives, the row-count/root formulas,
all small-height cases above, and prepared counts below/at/above eight.
At narrow widths and width one, compare clipped/safe row data, list/echo
addresses, the unchanged note cursor rule, and full ANSI envelopes.
Include directory slashes, summary clipping, ESC followed by printable
`[31m`, LF/CR/Tab/another low control/DEL, and a control beyond the clip.
Assert that a terminal-truncated list does not acquire a new summary.

Cover one leaf, both split directions, mixed trees with T/cross junctions,
shared buffers at distinct origins, tall and short mode-line leaves, and
a list-induced global fallback. Shrink/grow preserves the tree, locks,
selected ID, and inactive origins. Fit is minimal/idempotent, uses the
shorter selected text height, mirrors only selected origin, and remembers
the full size. Frame twice and at another size to prove purity and zero
Fs calls. Complete no-list goldens retain the inherited idle payload.

An insert or backspace clears the list and restores the normal root on
the next fit/frame; horizontal motions retain it. Return/Escape drop it
while preserving their exact command effects. Use a counted Fs and
scripted Term runner sequence with ambiguous Tab, redraw, short/tall
resize, clear, a repeated lookup, submission/cancel, and quit. Prove
fit-before-frame, last-row prompt cursor, one write per drawn iteration,
no lookup during paint/resize/edit, and no read/write until a submitted
file action. Do not edit the runner to inject or paint a list.

Stop with this proof, 000's proofs, and the full suite green. No live
list, selection, directory buffer, or following exploration belongs here.

## 5. Verification and acceptance

Each implementer writes the focused tests first, observes the missing
behavior fail, implements only the assigned slice, then verifies from
the project root. Every agent test command includes `TMPDIR=/tmp` and
`-y`, even when a predecessor omits them.

For **aloemacs-completion 000**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/completion-session.rkt tests/aloemacs/completion-key-mapping.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **aloemacs-completion 001**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/completion-session.rkt tests/aloemacs/completion-key-mapping.rkt tests/aloemacs/completion-frame.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

The no-TTY aloemacs suite is the acceptance bar. Use readable doubles;
an unreadable-directory host failure still propagates without a recovery
test requirement. No benchmark, timing gate, wider suite, or physical
TTY hand check is required. A hands-on tour can wait until both checkpoints
are green. Keep existing substantive buffer, editor, undo, search, prefix,
file-effect, window, and frame assertions. Review source as well as tests
for guarded enumeration, one shared session algorithm, raw-name common
prefix on the specified nongeneric scanner, no recursive completion send
on a legacy generic `(fields ...)` receiver, no extra host/String/Text
sends, unchanged checker/commands/runner, and no state written by paint.

Do not commit `compiled/`. Launchers load bytecode without rebuilding it.
After a `.rkt` edit, run the tests above or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching.
`.aloe` edits need no rebuild; do not add `raco make` to every launch.

The completed series is accepted when all of these hold:

1. Find-file starts in the current buffer's directory or Fs current
   directory, ending in `/`; save-as starts at its exact bound path or
   that pathless directory. The cursor starts at the editable end, and
   opening/refusing a prompt does not enumerate a directory.
2. Tab changes only eligible file prompts, with the exact prefix/unique/
   no-match/sole/list results, case-sensitive hidden-name filtering,
   unchanged typed directory spelling, and the specified cursor rule.
   Ineligible directories are never enumerated; no completion reads or
   writes file contents or follows a symlink for a slash/list.
3. Ambiguous unchanged-text Tab prepares at most eight raw display lines
   in entry order. The second checkpoint paints only those that fit above
   the last-row prompt, safely at full width, and shrinks the root used
   by single, split, fallback, and selected fit. Names have no selection.
4. Insert/backspace clear notes/lists; horizontal motions keep them;
   Return/Escape discard them with the prompt. Return submits exact
   editable text, keeps reuse/missing/regular/refusal/write/exact-name
   results, and empty submission still performs no filesystem write.
   Escape runs no command and preserves echo/previous submission.
5. Prefill, Tab, clearing, and painting leave every buffer/editor value,
   point, path/name, history, mark, scroll, IDs, focus, and undo unchanged.
   Only an explicit inherited fit may adjust selected origin/remembered
   height. Select-buffer and bare prompts ignore Tab; idle Tab cannot
   indent. Quit, search, and prefix precedence retain their exact effects.
6. Notes/list/prefill introduce no echo token or idle-payload change.
   The prompt cursor remains on the terminal's last row when it exists;
   mode lines retain their leaf rule, frame remains one String/write,
   and without a list 001 retains 000's complete frames and fit behavior.
7. At each checkpoint stop its focused proofs and
   `TMPDIR=/tmp raco test -y tests/aloemacs` pass without a TTY, with
   no product change beyond the named files, language amendment,
   checkpoint batch, or later feature.
8. Checked recursive character scans and prefix folds finish on the
   fieldless nongeneric `AloemacsCompletionScan`. The session retains
   `complete-prompt`, all Fs queries, and note/list/result ownership;
   its fourteen fields and concrete injected-host result type stay.
   No checker change or checker-recursion predecessor is required.

The designer's assignment ends at this specification and this folder's
README status update. Human acceptance precedes checkpoint work. The
manager rewrites **aloemacs-completion 000 only**, and stops. That rewrite
is complete; human review of its implementation precedes issuing 001.
If you have been told to read this file as the manager assignment, it is the whole
assignment; do not write later checkpoints in advance.
