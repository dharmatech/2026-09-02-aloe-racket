# aloemacs-file 001 — Immutable file session

**Status.** Ready to implement.

## Goal

Wrap the reviewed three-field `AloemacsEditor` in one immutable generic
`AloemacsSession` that carries the thin filesystem capability and an optional
resolved `Path`. Complete the pure editor forwarding surface plus explicit
visit, save, and named-`"save"` key behavior. Existing files load as exact
Text, missing paths become empty bound new-file sessions, and successful
saves write the current `(text to-string)`.

This checkpoint is the complete Aloe application policy for one file-bound
session. Stop when it is green. Do not change the starting `main.aloe` value,
normalize physical Ctrl-S, inject `fs-host` into the runner, accept command-line
paths, or touch a physical terminal or production disk.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-file, 001)`, spoken **aloemacs-file 001**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md), especially send
  evaluation, typed immutable generic classes, constructors, exhaustive
  `case`, parallel `let`, `load`, and section 14's typed host boundary, is
  language law. The head of a list is the receiver and its second element is
  the literal selector. A function object runs only through `(f call ...)`.
- [`../spec.md`](../spec.md), especially sections 1, 3–6, 8.2, 9, and 10, is
  the local design authority. This checkpoint implements the session value,
  visit/save policy, editor forwarding, and named-save dispatch exactly.
- **aloemacs-file 000** is implemented and reviewed. Preserve its exact
  ten-row `FsHost`, stateful double, strict UTF-8 content behavior, and thin
  `(Option String)` `Fs.read` / `Fs.write` surface.
- **aloemacs-loop 000–003** are implemented and reviewed. Preserve the exact
  three-field `AloemacsEditor`, all command and key transitions, pure frame,
  empty main value, and runner behavior. This checkpoint composes the editor;
  it does not alter it.
- **aloemacs-text 000–003** and **aloemacs-term 000** remain reviewed
  predecessors. `Text.from-string` / `to-string` provide exact String
  round-trips. Term is not used in this slice.

Do not add a special form, mutation, inheritance, macro, implicit numeric
coercion, crossing type, ambient capability, exception value, or alternate
evaluation path.

## Starting point

The implemented surface now contains:

- `examples/aloemacs/editor.aloe`, which source-relatively loads Text and
  defines the unchanged `AloemacsEditor` fields `text`, `point`, and `quit`,
  its editing/movement/quit/key commands, and pure `frame`;
- `lib/fs.aloe`, which defines `Path`, `Entry`, generic `(Fs H)`, inspection,
  listing, and the reviewed `read` / `write` Option API;
- `host/racket/fs.rkt`, whose stateful double accepts optional initial file
  contents and observes overwrites and eligible creation; and
- `examples/aloemacs/main.aloe`, which still loads `editor.aloe` and binds a
  bare empty `AloemacsEditor`.

There is no `examples/aloemacs/file.aloe`, `AloemacsSession`, or
`tests/aloemacs/file-session.rkt`. The existing terminal key normalization has
no `"save"` mapping. Direct test sends may still pass the named String
`"save"` to the new session.

## Exact file scope

### May edit

- `examples/aloemacs/file.aloe` (new)
- `tests/aloemacs/file-session.rkt` (new)

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, or another
  example
- `lib/fs.aloe`, `lib/text.aloe`, `lib/option.aloe`, `lib/disk.aloe`, or
  another library
- `host/racket/fs.rkt`, `host/racket/term.rkt`,
  `host/racket/aloemacs-run.rkt`, or another host module
- any existing test, including aloemacs-file 000 and all Text, Term, and Loop
  tests
- any file under `aloe/`, `bin/`, or `gel/`, or package metadata
- the aloemacs maps, charter, specification, or predecessor checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Source loads and exact session state

Create `examples/aloemacs/file.aloe`. Its first two top-level forms load the
reviewed application and filesystem layers source-relatively:

```aloe
(load "editor.aloe")
(load "../../lib/fs.aloe")
```

Tests load only `file.aloe`; they do not separately load or repeat its
dependencies. Loading it is explicit and driver-local. The source declares
exactly this application state class, generic parameter, field order, and
field types:

```aloe
(define-class (AloemacsSession H)
  (fields
    (editor AloemacsEditor)
    (fs (Fs H))
    (path (Option Path)))
  (methods
    ...))
```

For `(Fs new fs-host)`, the checker infers `H` from the injected receiver and
a constructed session has checked type `(AloemacsSession FsHost)`. `FsHost`
remains a diagnostic name for the opaque host type; it is not a source-bound
type name and must not appear in an Aloe annotation.

The three fields are the entire persistent session state. Do not add a dirty
bit, saved-text snapshot, display name, message, encoding, newline style,
terminal receiver, second buffer, window, selection, cached text, or another
constructor. Do not add fields to `AloemacsEditor`; it remains the sole owner
of Text, point, and quit state.

Small pure session helper selectors are permitted only to rebuild around an
editor, construct the standard visited editor, or construct an equal session.
They must not add state, effects, another class, top-level helper bindings, or
new application policy. Tests do not depend on helper names.

## Forwarded editor surface

The session exposes these exact application sends and checked results:

| Send | Result |
|---|---|
| `(session text)` | `Text` |
| `(session point)` | `Position` |
| `(session quit)` | `Bool` |
| `(session insert string)` | `(AloemacsSession H)` |
| `(session newline)` | `(AloemacsSession H)` |
| `(session backward-delete)` | `(AloemacsSession H)` |
| `(session move-left)` | `(AloemacsSession H)` |
| `(session move-right)` | `(AloemacsSession H)` |
| `(session move-up)` | `(AloemacsSession H)` |
| `(session move-down)` | `(AloemacsSession H)` |
| `(session request-quit)` | `(AloemacsSession H)` |
| `(session handle-key key)` where `key : String` | `(AloemacsSession H)` |
| `(session frame columns rows)` | `String` |

`text`, `point`, and `quit` return the corresponding value from
`(self editor)`. `frame` returns exactly:

```aloe
((self editor) frame columns rows)
```

It does not rebuild the session or add presentation bytes.

Every direct editing, movement, or quit command sends the same selector and
arguments to `(self editor)`, then constructs a new session around that
returned `AloemacsEditor`, the exact `(self fs)`, and the exact `(self path)`.
Do not reimplement Text edits, movement, quit, key dispatch, viewport, or ANSI
logic in the session.

The source session and its nested editor remain unchanged. Successful
transitions preserve the same filesystem receiver and path payload. Edge
no-ops may be structurally equal, but nested editing remains rebuild and no
field is mutated.

`request-quit` delegates only to the nested editor. It never sends `save` or
`Fs.write`.

## Visit

Add exactly this public method:

```aloe
(visit (path Path) (Option (AloemacsSession H))
  ...)
```

Visit performs these steps in order:

1. Resolve again through the session's thin filesystem:

   ```aloe
   ((self fs) path (path text))
   ```

   Call this value `resolved`. It is the only `Path` the returned session may
   store.
2. Inspect `resolved` through `(self fs)`.
3. Exhaustively select the `Option Entry` and every `Entry` constructor as
   below.

### Existing regular file

For `RegularFile`, send:

```aloe
((self fs) read resolved)
```

Exhaustively handle that second live result:

- `Some(contents)` returns `Some` of a new session containing exactly:
  - `(Text from-string contents)`;
  - `(Position new 0 0)`;
  - nested-editor `quit = #f`;
  - the exact existing `(self fs)`; and
  - `(Option Some resolved)` as its path.
- `None` returns `(Option None)`. This is the named outcome if the live target
  is no longer readable as a regular file after inspection.

Do not preserve the old editor's point, quit fact, or text on a successful
visit. Do not normalize contents before `Text.from-string`.

### Missing target

An `inspect` result of `None` is a successful new-file visit. Return `Some`
of a new session with an empty `(Text from-string "")`, point `(0, 0)`, quit
`#f`, the same `Fs`, and path `Some(resolved)`.

Visit does not create the missing file, test its parent for writability, or
send `Fs.write`. Eligibility is decided later by an explicit save.

### Existing non-file

`Directory`, `SymbolicLink`, and `Other` return `(Option None)` without
reading. There is no fallback to an untitled session and no following of a
symbolic link.

Visit never mutates its receiver. On `None`, callers retain the original
session. Real host failures such as invalid UTF-8 or a live I/O failure remain
guarded host failures; do not catch or translate them.

## Save

Add exactly this public method:

```aloe
(save () (Option (AloemacsSession H))
  ...)
```

Exhaustively select `(self path)`:

- `None` returns `(Option None)` and performs no filesystem write. It does not
  choose a path, prompt, or create a default file.
- `Some(path)` sends exactly:

  ```aloe
  ((self fs) write path ((self text) to-string))
  ```

  An `Fs.write` `None` becomes save `None`. An `Fs.write` `Some` becomes
  `Some` of a newly constructed session with the exact existing editor,
  filesystem, and path payloads.

A successful save preserves point and quit exactly. It does not replace Text,
move point, reset quit, or clear state. There is no dirty bit or saved
snapshot, so every explicit save of a currently eligible bound session sends
`Fs.write`, even when its Text has not changed since visit or the previous
save.

Direct `(session save)` remains permitted when `(session quit)` is already
`#t`. Conversely, `request-quit`, the `"escape"` key, and reaching quit never
save implicitly.

## Named save and key dispatch

`AloemacsSession.handle-key` follows this exact order:

1. If `(self quit)` is already `#t`, construct an equal session and perform no
   save and no nested editor transition.
2. If `(key = "save")`, send `(self save)` and exhaustively select the result:
   return the session carried by `Some`; for `None`, construct an equal
   unchanged session.
3. Otherwise send `((self editor) handle-key key)` and rebuild the session
   around the returned editor while preserving the exact `fs` and `path`.

The session owns this named command. Do not put save policy in Racket or add a
save branch to `AloemacsEditor`.

Consequences that must remain exact:

- printable `"s"` is one character and inserts `s`;
- printable `"q"` inserts `q` and does not quit;
- `"escape"` delegates to quit and does not save;
- Return, Backspace, all four arrows, and unknown named keys retain their Loop
  behavior;
- an untitled or ineligible save key is a silent equal no-op; and
- all keys, including `"save"`, are absorbing after quit.

This checkpoint does not map a physical key to `"save"`. Tests send that
String directly. Ctrl-S normalization belongs to aloemacs-file 002.

## Exact content policy

Session visit and save add no transformation around the checkpoint-000
filesystem and reviewed Text algebra:

- visit passes the decoded String directly to `Text.from-string`;
- save passes exact `(text to-string)` to `Fs.write`;
- LF is the only Text line separator;
- CR before LF and lone CR remain ordinary characters;
- U+FEFF remains content, not metadata;
- no final newline is added or removed; and
- no encoding or newline metadata is added to the session or editor.

The normative no-edit round trips are:

| Initial file contents | Visited and saved contents |
|---|---|
| `"one\ntwo\n"` | `"one\ntwo\n"` |
| `"one\ntwo"` | `"one\ntwo"` |
| `"one\r\ntwo\r\n"` | `"one\r\ntwo\r\n"` |
| `"λ\n"` | `"λ\n"` |

For the CRLF fixture, `(session text)` has exactly three lines equivalent to
`(List of "one\r" "two\r" "")`.

## Required tests

Create `tests/aloemacs/file-session.rkt`. Behavioral tests use a checked
driver, one explicitly injected `make-fs-double`, and
`examples/aloemacs/file.aloe`; load-boundary assertions may additionally use
fresh uninjected drivers. No test injects Term, constructs a production
filesystem receiver, touches a physical file, or requires a TTY.

### Load, state, and checked surface

Prove:

1. Before explicit load, `AloemacsSession`, `AloemacsEditor`, `Text`, `Fs`,
   `Path`, and `Option` are absent from a fresh driver.
2. Loading only `file.aloe` source-relatively supplies all those class
   bindings in that driver and not in a second fresh driver. It does not
   inject `fs-host` or `term`.
3. After injecting one double and constructing an untitled session with
   `(Fs new fs-host)`, its checked type is `(AloemacsSession FsHost)`.
4. The exact field sends have types:

   ```text
   (session editor) => AloemacsEditor
   (session fs)     => (Fs FsHost)
   (session path)   => (Option Path)
   ```

5. Every forwarded method has the checked result in the table above;
   `visit` and `save` have result `(Option (AloemacsSession FsHost))`.
6. Wrong arities and argument types are rejected for `insert`, `frame`,
   `handle-key`, `visit`, and `save`. Sending `dirty`, `encoding`, or a second
   buffer selector is rejected.
7. `FsHost` still cannot be written as an Aloe field type.

Do not assert helper-selector names or exact reflected ordering beyond the
normative fields and application sends.

### Visit and refusal

Use a double rooted at `"/cwd"` with a small LF regular-file fixture plus a
directory, symbolic link, and other node. Starting from one nonempty,
nonzero-point, quit untitled session, prove:

1. Visiting a relative spelling of the regular file returns `Some(session)`.
2. The stored path is the resolved absolute `Path`, the new editor starts at
   `(0, 0)` with quit `#f`, and its Text is structurally equal to
   `(Text from-string fixture)`.
3. Visiting a missing relative path returns `Some` of an empty session bound
   to its resolved absolute path, while raw `kind` still reports `"missing"`
   and the parent listing has not gained the file.
4. Visiting the directory, symbolic link, and other node returns `None`.
5. Every visit leaves the source session's editor, filesystem, and optional
   path structurally unchanged.

Unwrap successful and refused visit results with exhaustive `case`; do not
test only `present?`.

### Save, creation, and immutability

Prove:

1. Saving an untitled session returns `None` and leaves the double unchanged.
2. Saving a visited regular file returns `Some` of a session structurally
   equal to the source session and writes exact current `(text to-string)`.
   The source session and nested editor remain unchanged.
3. Save has no dirty optimization: visit a file, make no session edit, change
   the double's file contents externally with a raw `FsHost/write`, then save
   the unchanged visited session. The original visited text must overwrite
   that external text. Repeat if needed to prove each explicit save performs
   the effect.
4. Edit a visited file through at least one direct forwarded command and at
   least one ordinary `handle-key` transition, save it, then visit it again.
   The revisited `(text to-string)` is the exact edited String and its point
   has reset to `(0, 0)`.
5. Edit and save the bound missing-path session. The save creates a regular
   file with exact contents, and a later visit loads those contents.
6. A manually bound directory, symbolic-link, other, missing-parent, or
   non-directory-parent target receives save `None` through thin `Fs.write`;
   the source session and double contents remain unchanged.
7. `request-quit` and `handle-key "escape"` after an edit leave the external
   file unchanged. A later direct `save` on the quit session does write and
   returns a session whose quit fact remains `#t`.

All successful save assertions unwrap `Some` and check the carried session,
not only its presence.

### Exact text goldens

Plant the four normative fixture Strings in separate regular-file nodes. For
each fixture, visit, check exact `(text to-string)`, save without edits, and
check exact raw contents afterward. For CRLF, also check the exact three Text
line Strings. Add a U+FEFF fixture or assertion proving a leading BOM remains
ordinary Text content through visit and save.

Do not duplicate checkpoint 000's binary-port or invalid-UTF-8 production
tests; this file tests only session-level String preservation through the
double.

### Editor and key regression through the wrapper

For direct sends, prove `insert`, `newline`, `backward-delete`, all four
movement commands, and `request-quit` produce a session whose nested editor is
structurally equal to sending the same command to the source nested editor.
Every result preserves the exact `Fs` and `Option Path` payloads.

For `handle-key`, cover Return, Backspace, all four arrows, printable `"s"`,
printable `"q"`, one unknown named key, Escape, and direct named `"save"`.
Prove:

- each non-save key matches the reviewed nested-editor transition;
- `"s"` and `"q"` insert and do not request quit;
- Escape requests quit without writing;
- an untitled `"save"` and an ineligible bound `"save"` are structurally
  equal no-ops;
- after quit, an ordinary printable key does not edit and a `"save"` key does
  not write; and
- direct `save` after quit remains effective as specified above.

Finally, compare `(session frame columns rows)` with the nested editor's exact
frame String for at least one nonempty, nonzero-point session. Calling frame
must leave every session payload unchanged.

### Regression and hand check

Run the complete suite:

```sh
raco test tests
```

Then run one checked expression sequence by hand:

```racket
(require racket/runtime-path
         "aloe/driver.rkt"
         "host/racket/fs.rkt")

(define-runtime-path file-path "examples/aloemacs/file.aloe")
(define state (make-driver))
(driver-inject-host!
 state
 'fs-host
 (make-fs-double
  "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file)
  (hash "/cwd/a.txt" "old")))
(driver-eval! state `(load ,(path->string file-path)))
(driver-eval!
 state
 '(define base
    (AloemacsSession new
      (AloemacsEditor new
        (Text from-string "untitled")
        (Position new 0 0)
        #f)
      (Fs new fs-host)
      (Option None))))
(driver-eval!
 state
 '(define visited
    ((base visit (Path new "a.txt")) case
      (None () base)
      (Some (session) session))))
(driver-eval! state '(define edited (visited insert "!")))
(driver-eval!
 state
 '(define saved
    ((edited save) case
      (None () edited)
      (Some (session) session))))
(list
 (driver-eval! state '((saved text) to-string))
 (driver-eval!
  state
  '((saved path) case
     (None () "none")
     (Some (path) (path text))))
 (driver-eval! state '(fs-host read "/cwd/a.txt")))
```

Expected:

```racket
'("!old" "/cwd/a.txt" "!old")
```

## Acceptance

- `examples/aloemacs/file.aloe` defines the exact generic three-field session
  and loads only the reviewed editor and thin filesystem dependencies.
- The session forwards every required editor command and exact frame while
  preserving immutable editor behavior, filesystem identity, and path state.
- Visit resolves before storage, loads exact regular-file contents at `(0, 0)`
  with quit false, binds missing paths without creating them, and refuses all
  observed non-file nodes as `None`.
- Save refuses untitled or ineligible sessions as `None`, writes exact current
  Text for every eligible explicit call, rebuilds an equal successful
  session, and never occurs implicitly on quit.
- Named `"save"` dispatch has the exact pre-quit/success/refusal/post-quit
  behavior, while every existing Loop key and printable `s`/`q` retain their
  meanings.
- LF, absent-final-LF, CRLF, Unicode, and BOM content survive exact no-edit
  visit/save round trips with no metadata or conversion.
- `examples/aloemacs/main.aloe`, `AloemacsEditor`, Text, Fs, both host modules,
  the runner, and every existing test remain unchanged.
- `raco test tests` is green, the hand check yields the exact result above,
  and `git diff --check` is clean.
- Stop. Do not start aloemacs-file 002, Ctrl-S normalization, main, or runner
  integration.

## Explicit non-goals

- changing the three-field `AloemacsEditor`, Text, thin Fs, OO Disk, or either
  host descriptor
- changing `main.aloe`, injecting `fs-host` in the runner, accepting
  command-line paths, or using the production filesystem
- physical Ctrl-S normalization, another Term method, a general modifier
  keymap, a prefix map, `C-x C-s`, or `C-x C-f`
- a minibuffer, prompt, save-as, find-file command, path completion, status
  line, or user-visible save diagnostic
- dirty state, saved snapshots, external-change detection, merge, revert,
  autosave, backup, lock, or save-on-quit
- a second buffer, window, split, dired, directory UI, or workspace
- newline normalization, BOM stripping, encoding selection, binary editing,
  final-newline insertion, or encoding/newline fields
- following symbolic links, parent creation, delete, rename, chmod, changing
  cwd, globbing, recursive traversal, or remote files
- catching host failures, adding `Result`, changing language law, changing
  Gel, or using a global checkpoint number
