# aloemacs file specification

**Status.** Design for the local **aloemacs-file** project. This is not Aloe
language law, a checkpoint, or an implementation assignment. A later
checkpoint-manager conversation will slice `aloemacs-file 000`, `001`, …
under `checkpoints/`. The authority for Aloe evaluation, checking, host
crossing, classes, and immutability remains
[`SPEC.md`](../../../../../SPEC.md), especially section 14.

This project gives the one-buffer aloemacs program whole-file load and save.
It appends two `String` methods to the existing `FsHost`, exposes them through
thin [`Fs`](../../../../../lib/fs.aloe), and wraps the unchanged Loop editor in
one immutable session that carries the filesystem capability and an optional
bound `Path`. A command-line path visits an existing regular file or a new
file location, and one Ctrl-S key saves the current `(text to-string)`.

The implemented Text, Term, and Loop layers are predecessors. In particular,
this specification does not change `Text`, the Term descriptor, or the pure
three-field `AloemacsEditor` defined by
[`../loop/spec.md`](../loop/spec.md).

## 1. Scope and locked choices

This layer makes the following choices from the charter:

- The public filesystem API is thin `Fs`, not OO `Disk` and not a third
  wrapper. The editor program loads `lib/fs.aloe`; it does not load
  `lib/disk.aloe`.
- `AloemacsEditor` stays exactly the Loop value with fields `text`, `point`,
  and `quit`. A new `AloemacsSession` wraps that value together with one
  `Fs` and an `(Option Path)`.
- The optional `Path` is the file binding. `None` means untitled. A visited
  path is host-resolved before it is stored.
- There is no dirty bit. Every explicit save of a bound session attempts a
  write, even if the text has not changed.
- A visit starts at `(Position new 0 0)` and with `quit` equal to `#f`.
- Quit never saves. The existing quit command is still the Loop key
  `"escape"`; printable `"q"` remains self-insert.
- File text is strict UTF-8. CR, LF, CRLF, a UTF-8 BOM, and final-newline
  presence are content and receive no conversion.
- The running program maps one physical Ctrl-S to the named key `"save"`.
  There is no prefix map.

There is still exactly one buffer and one point. The session wrapper is the
runner state, not a workspace, buffer list, window, or second text
representation. Nested editing remains rebuild: a session transition embeds
the new immutable `AloemacsEditor` in a new immutable session.

### 1.1 Project boundary

The implementation surface is limited to:

- `host/racket/fs.rkt` for the two appended host methods and their production
  and double implementations;
- `lib/fs.aloe` for the two thin `Fs` methods;
- a new `examples/aloemacs/file.aloe` for `AloemacsSession`;
- `examples/aloemacs/main.aloe` for the empty untitled starting session;
- `host/racket/term.rkt` only for Ctrl-S normalization;
- `host/racket/aloemacs-run.rkt` for filesystem injection and the optional
  command-line path; and
- focused tests under `tests/aloemacs/`.

`tests/checkpoint-101.rkt` may update its exact `FsHost` selector list to
include the two appended rows. Historical filesystem assertions retain their
meaning; no historical test is rewritten around a different API.

Do not change `examples/aloemacs/editor.aloe`, `lib/text.aloe`,
`lib/disk.aloe`, `SPEC.md`, `CHECKPOINTS.md`, either predecessor spec, Gel,
or a global checkpoint document. Pure Loop editor, movement, frame, and
existing key tests continue to construct the three-field `AloemacsEditor`
unchanged.

## 2. Filesystem host contents

`FsHost` remains the one optional, explicitly injected filesystem
capability. Its existing eight rows keep their order and behavior. Two rows
are appended:

| Order | Host send | Type | Meaning |
|---:|---|---|---|
| 1 | `(fs-host current)` | `() -> String` | Existing absolute cwd. |
| 2 | `(fs-host resolve path)` | `(String) -> String` | Existing path resolution. |
| 3 | `(fs-host child path name)` | `(String String) -> String` | Existing one-component join. |
| 4 | `(fs-host root? path)` | `(String) -> Bool` | Existing root test. |
| 5 | `(fs-host parent path)` | `(String) -> String` | Existing parent spelling. |
| 6 | `(fs-host name path)` | `(String) -> String` | Existing last component. |
| 7 | `(fs-host kind path)` | `(String) -> String` | Existing non-following kind. |
| 8 | `(fs-host names path)` | `(String) -> (List String)` | Existing immediate names. |
| 9 | `(fs-host read path)` | `(String) -> String` | Read one regular file in full. |
| 10 | `(fs-host write path text)` | `(String String) -> String` | Replace or create one regular file and return `text`. |

The exact selector order is therefore:

```racket
(current resolve child root? parent name kind names read write)
```

These rows use only the existing crossing type `String`. There is no byte
value, `(List Int)`, stream, port, file handle, host `Option`, or second host
interface. The same descriptor continues to drive checking, dispatch, and
reflection. Default `make-driver` and `bin/aloe` remain capability-free.

### 2.1 Read

The host resolves `path` by the same rule as every existing host method and
requires the resulting node itself to be a regular file. Classification does
not follow a symbolic link. It reads the entire file and returns one immutable
Racket string through the guarded host boundary. The empty file returns `""`.

Production reading obtains the file bytes in binary mode and decodes them as
strict UTF-8. An invalid UTF-8 sequence is a host failure; it is not replaced,
discarded, or exposed as bytes. Valid Unicode crosses as a `String`, so
`String.len` and `Text` see the same character-count unit as every other Aloe
string.

Calling the raw host method on a missing path, directory, symbolic link,
other node, unreadable file, invalid UTF-8 file, or failed I/O raises through
the existing Aloe host-failure path with interface `FsHost` and selector
`read`.

### 2.2 Write

The host resolves `path` and accepts exactly two shapes:

1. an existing regular file, which is replaced with `text`; or
2. a missing final path whose existing parent is a directory, which becomes
   a new regular file containing `text`.

An existing directory, symbolic link, or other node is never followed or
replaced. A missing parent, non-directory parent, permission failure, or
other I/O failure is a host failure at the raw host method. Parent directories
are not created.

Production writing encodes the entire Aloe string as UTF-8 and writes those
bytes in binary mode. It returns the same `String` after a successful close.
It is ordinary overwrite, with no appended newline. Atomic replacement,
temporary files, durability, backup copies, permission repair, and recovery
from a partial failed write are not promised.

### 2.3 Stateful filesystem double

The compatible factory shape is:

```racket
(make-fs-double current nodes [contents (hash)])
```

Existing two-argument calls keep their meaning. `nodes` keeps its existing
path-to-kind vocabulary. `contents` is a path-to-string hash whose keys must
name regular-file nodes in `nodes`. A regular-file node omitted from
`contents` starts with `""`. Directory, symbolic-link, and other nodes have
no contents and are rejected as `contents` keys.

The double privately copies both input hashes; it does not mutate caller
hashes. Its private state is allowed to change because it models the external
filesystem:

- `read` returns the current string of a regular-file node;
- `write` replaces that string for a regular-file node;
- `write` to an eligible missing path adds a regular-file node and its
  contents; and
- subsequent `kind`, `names`, and `read` sends observe that creation.

The double enforces the same regular-file, parent-directory, and non-following
rules as production. It stores already-decoded Racket strings, so invalid
UTF-8 is tested only against an isolated production temporary file.

## 3. Thin `Fs` contents API

[`lib/fs.aloe`](../../../../../lib/fs.aloe) adds exactly these public sends:

| Send | Result | Meaning |
|---|---|---|
| `(fs read path)` | `(Option String)` | `Some(contents)` for a regular file; `None` for the observed missing or non-file path. |
| `(fs write path text)` | `(Option String)` | `Some(text)` after a successful overwrite or creation; `None` for an observed ineligible target. |

`Path`, `Entry`, all existing `Fs` sends, and the meanings of `(path text)`
and `(entry path)` are unchanged.

`read` first sends the existing `(fs inspect path)`. Only `RegularFile`
sends host `read`; `None`, `Directory`, `SymbolicLink`, and `Other` return
`(Option None)` without calling host `read`.

`write` also classifies before performing the effect:

- `RegularFile` sends host `write` and wraps its returned `String` in `Some`;
- `Directory`, `SymbolicLink`, and `Other` return `None` without writing;
- a missing path may be created only when `(fs parent path)` is `Some` and
  inspecting that parent yields `Directory`; then it sends host `write` and
  returns `Some`;
- root, a missing parent, or a parent of any other observed kind returns
  `None` without writing.

These checks turn the expected missing/non-file cases into Aloe data. The
filesystem remains live: a permission error, invalid UTF-8, or a race after
inspection can still produce the existing host failure. No preflight can
remove that race, and this project does not invent an exception or `Result`
crossing to pretend otherwise.

The OO `Disk`, `Location`, and live `File` classes receive no contents method
in this project. In particular `(file text)` remains the location's path
spelling.

## 4. Session value and starting state

`examples/aloemacs/file.aloe` loads `editor.aloe` and `../../lib/fs.aloe`,
then declares this application class. Field order and types are normative:

```aloe
(define-class (AloemacsSession H)
  (fields
    (editor AloemacsEditor)
    (fs (Fs H))
    (path (Option Path)))
  (methods ...))
```

For an injected `FsHost`, its checked type is `(AloemacsSession FsHost)`.
The host interface name remains inferred and cannot be source-written as a
field type.

The fields are the entire persistent file-session state. There is no dirty
bit, saved-text snapshot, newline style, encoding field, display name,
message, second buffer, or Term receiver. `AloemacsEditor` remains the sole
owner of `Text`, point, and quit state.

`examples/aloemacs/main.aloe` loads `file.aloe` and defines the initial
runner binding as the equivalent of:

```aloe
(define aloemacs-editor
  (AloemacsSession new
    (AloemacsEditor new
      (Text from-string "")
      (Position new 0 0)
      #f)
    (Fs new fs-host)
    (if #t
        (Option None)
        (Option Some (Path new "/typed-none")))))
```

The `if` is the typed-`None` form: its unselected `Some` branch determines
`T = Path`. A bare `(Option None)` in this `AloemacsSession` constructor is
rejected because `T` remains unknown; the outer generic construction does not
push `(Option Path)` onto that argument before `H` is known.

Thus loading `main.aloe` requires `fs-host` to have been explicitly injected.
It still requires no `term` binding. The zero-argument program is empty and
untitled, and performs no file operation during this construction.

### 4.1 Forwarded editor surface

The session supplies the following sends so it can replace the Loop editor as
the one runner value:

| Send | Result | Rule |
|---|---|---|
| `(session text)` | `Text` | `(session editor)`'s text. |
| `(session point)` | `Position` | `(session editor)`'s point. |
| `(session quit)` | `Bool` | `(session editor)`'s quit fact. |
| `(session insert string)` | `(AloemacsSession H)` | Delegate and rebuild around the returned editor. |
| `(session newline)` | `(AloemacsSession H)` | Same. |
| `(session backward-delete)` | `(AloemacsSession H)` | Same. |
| `(session move-left)` | `(AloemacsSession H)` | Same. |
| `(session move-right)` | `(AloemacsSession H)` | Same. |
| `(session move-up)` | `(AloemacsSession H)` | Same. |
| `(session move-down)` | `(AloemacsSession H)` | Same. |
| `(session request-quit)` | `(AloemacsSession H)` | Delegate; never save. |
| `(session handle-key key)` | `(AloemacsSession H)` | Section 6. |
| `(session frame columns rows)` | `String` | Return the nested editor's exact frame. |

Every transition preserves the exact `fs` and `path` values. The input
session and nested editor remain unchanged. Edge and unknown-key no-ops may
rebuild equal values, matching the Loop contract.

### 4.2 Visit

The file send is:

```aloe
(session visit path) ; (Option (AloemacsSession H))
```

`visit` first resolves again through `(session fs)` using
`(fs path (path text))`; the resolved `Path` is the only path it may store.
It then inspects that path:

- For `RegularFile`, `(fs read resolved)` must be `Some(contents)`. The
  result is `Some` of a new session whose nested editor contains
  `(Text from-string contents)`, whose point is `(Position new 0 0)`, whose
  quit fact is `#f`, and whose path is `Some(resolved)`. If the second live
  read returns `None`, visit returns `None`.
- For missing, visit succeeds as a new-file location: the new nested editor
  contains `(Text from-string "")`, starts at `(0, 0)` with quit `#f`, and
  stores `Some(resolved)`. No file is created until save.
- For `Directory`, `SymbolicLink`, or `Other`, visit returns `None` and does
  not read.

`visit` never changes its receiver. A caller keeps the original session when
it receives `None`. This `Option` is the named refusal for a non-file path;
missing is the separately specified successful new-file case.

### 4.3 Save

The save send is:

```aloe
(session save) ; (Option (AloemacsSession H))
```

For `path = None`, save returns `None` and performs no host write. It does not
choose a name or prompt.

For `Some(path)`, save sends:

```aloe
((session fs) write path ((session text) to-string))
```

An `Fs.write` `None` becomes save `None`; the receiver remains the caller's
unchanged value. An `Fs.write` `Some` becomes `Some` of a newly rebuilt
session equal in editor, filesystem, and path payloads to the receiver.
Point and quit are preserved. Because there is no dirty state, every such
successful call performs the overwrite.

Calling `request-quit`, sending the quit key, or ending the runner does not
send `save`. A direct `(session save)` remains an explicit operation even if
the nested editor's quit fact is already true.

## 5. Encoding and newline policy

The complete policy is **strict UTF-8 with exact newline preservation**:

- load decodes UTF-8 and changes no decoded character;
- save encodes the exact `(text to-string)` as UTF-8;
- LF is the only line break recognized by `Text`, exactly as before;
- CR before LF remains an ordinary final character in that `Text` line;
- lone CR remains CR;
- no final newline is added or removed; and
- a decoded U+FEFF BOM remains content rather than metadata.

Normative goldens include:

| File text | Visited `(text to-string)` | Saved text without edits |
|---|---|---|
| `"one\ntwo\n"` | `"one\ntwo\n"` | `"one\ntwo\n"` |
| `"one\ntwo"` | `"one\ntwo"` | `"one\ntwo"` |
| `"one\r\ntwo\r\n"` | `"one\r\ntwo\r\n"` | `"one\r\ntwo\r\n"` |
| `"λ\n"` | `"λ\n"` | `"λ\n"` |

For the CRLF case, `(session text)` has lines equivalent to
`(List of "one\r" "two\r" "")`. Neither `Text` nor the session receives a
CRLF flag or conversion method. Invalid UTF-8 fails at host `read` as stated
in section 2.1.

## 6. Save key and dispatch

`tkeymsg->aloe-key` gains one normalization before its printable-character
cases:

```racket
(make-tkeymsg #\s '(ctrl) #f) ; => "save"
(make-tkeymsg #\s '(ctrl) #\s) ; => "save"
```

The key must be `#\s`, modifiers must be exactly `'(ctrl)`, and the decoded
character may be `#f` or `#\s`. The current `tui-term` VT decoder emits the
second shape (including when the character defaults to the key). Focused
no-TTY tests cover both shapes, especially the live `#\s` character case.
Ctrl-Shift-S, Alt-S, printable `s`, Backspace, and every other mapping retain
their current behavior. This is not a Term method or a general modifier
keymap; the five-row Term interface remains unchanged.

`AloemacsSession.handle-key` follows this order:

1. If the nested editor is already quit, return an equal session and perform
   no save or editor transition.
2. If `key = "save"`, send `(session save)`. Return the successful session
   from `Some`; on `None`, return an equal unchanged session.
3. Otherwise delegate the key to the nested editor's existing `handle-key`
   and rebuild the session around its result.

Consequently printable `"s"` still inserts `s`; `"q"` still inserts `q`;
`"escape"` still requests quit; Return, Backspace, arrows, and unknown named
keys retain the Loop behavior. Saving an untitled session or a path that has
become ineligible is a silent equal no-op in the current UI because this
layer has no status line or prompt. The direct `save` result remains
observable and testable as `Option`.

## 7. Runner and command line

`host/racket/aloemacs-run.rkt` remains the effect and iteration skin. It
provides:

```racket
(run-aloemacs [path])
(run-aloemacs-with-term term [path])
(run-aloemacs-with-hosts term fs-host [path])
```

The bracketed argument means a Racket optional argument; each procedure
accepts both listed arities. `path`, when present, is a Racket string.

`run-aloemacs` obtains the physical Term receiver with the existing
`call-with-tty-term-receiver`, constructs one production
`make-fs-receiver`, and delegates. `run-aloemacs-with-term` is the compatible
Loop test seam: it constructs the production filesystem receiver and
delegates. It performs no disk I/O when no path is supplied.
`run-aloemacs-with-hosts` is the file-layer no-TTY seam and is what focused
tests use with `make-term-receiver` and `make-fs-double`.

`run-aloemacs-with-hosts` performs this setup in order:

1. make one checked driver;
2. inject `term` and `fs-host` into that same driver;
3. load `examples/aloemacs/main.aloe`; and
4. if a path string was supplied, obtain a resolved thin `Path` through the
   session's `Fs`, send `visit`, and rebind `aloemacs-editor` to the `Some`
   session.

A missing supplied path succeeds as the empty bound new-file session in
section 4.2. A supplied directory, symbolic link, or other node yields visit
`None`; the runner raises a deliberate `aloemacs` visit error naming the
argument before drawing or reading a key. A host failure retains the existing
host context and is reported by the main-module handler.

After setup, the iteration is the Loop sequence unchanged in shape:

```aloe
(term write
  (aloemacs-editor frame (term columns) (term rows)))

(define aloemacs-editor
  (aloemacs-editor handle-key (term read-key)))

(aloemacs-editor quit)
```

The session handles `"save"`; the Racket loop contains no save-key branch,
text extraction, path classification, read, or write call. A quit transition
still ends without a second frame and without saving.

The main module accepts exactly these forms:

```text
racket host/racket/aloemacs-run.rkt
racket host/racket/aloemacs-run.rkt path
```

Zero arguments select the empty untitled session. One argument is passed as
the visit string; relative spelling is resolved by thin `(fs path string)`
against the filesystem receiver's cwd. More than one argument is a usage
error and does not start the loop. There is no prompt and no later interactive
visit command.

## 8. Required tests

All new tests live under `tests/aloemacs/`, use a checked driver, and require
no physical TTY. New file-layer test names do not reuse the Text numbered
files or Loop's `editor-keys.rkt`, `frame.rkt`, `key-mapping.rkt`, and
`runner.rkt`. Existing tests are changed only where the intentionally enlarged
main/runner or descriptor surface makes their old exact assertion stale.

### 8.1 Host and thin wrapper — `fs-contents.rkt`

This file proves:

- exact `FsHost` selector order, parameter types, and result types from
  section 2;
- default drivers still contain no `fs-host`;
- the optional `contents` hash, including an empty regular file;
- raw double read, overwrite, and missing-file creation, with later `kind`,
  `names`, and `read` observing the creation;
- raw host failures for read of missing/directory/symlink and write over a
  directory/symlink/other node;
- `(fs read path)` returns `Some` only for a regular file and `None` for every
  observed other kind;
- `(fs write path text)` returns `Some(text)` for overwrite and eligible
  creation, and `None` for an existing non-file, root, missing parent, or
  non-directory parent; and
- the input node and contents hashes supplied to the double are unchanged.

An isolated `/tmp` production test reads and writes `"λ\r\nlast"` and checks
the exact UTF-8 bytes and exact decoded string. A separate invalid UTF-8 file
proves `FsHost/read` raises a guarded host failure. The test cleans up its
temporary directory and never uses a repository file as scratch space.

`tests/checkpoint-101.rkt` changes only its exact descriptor selector list to
the ten-row list. The existing checkpoint-101 through checkpoint-107 tests
remain green.

### 8.2 Visit, editing, and save — `file-session.rkt`

With one injected double and `examples/aloemacs/file.aloe`, this file proves:

- checked field and method types, including
  `(AloemacsSession FsHost)`, `(Option Path)`, visit, and save;
- visiting a small LF fixture yields `Some(session)`, stores the resolved
  path, starts at `(0, 0)` with quit `#f`, and has `Text` structurally equal
  to `(Text from-string fixture)`;
- visiting a missing relative path yields `Some` of an empty session bound to
  the resolved new-file path without creating it yet;
- visiting a directory, symlink, or other node returns `None` and leaves the
  original session unchanged;
- an untitled save returns `None` and performs no write;
- editing a visited file through both a direct existing command such as
  `insert` and through `handle-key`, saving, and visiting it again round-trips
  the exact current `(text to-string)`;
- saving the missing-path session creates the file, and a later visit loads
  it;
- save always writes even when the text is unchanged, while all source
  sessions and nested editors remain immutable;
- the four exact newline/Unicode goldens in section 5; and
- insert, Return, Backspace, all arrows, printable `s`, printable `q`,
  unknown-key no-op, Escape quit, absorbing post-quit dispatch, and exact
  frame delegation retain the Loop results.

No test in this file injects Term or touches the production disk.

### 8.3 Ctrl-S — `file-key-mapping.rkt`

This focused no-TTY test proves both Ctrl-S `tkeymsg` forms in section 6
become `"save"`, including the live `char = #\s` message.
It also proves printable `s` remains `"s"` and Ctrl-Shift-S and Alt-S are not
silently normalized to save. Existing Return, Escape, Backspace, arrow,
printable, and unknown-symbol mapping tests remain green.

### 8.4 Main and runner — `file-runner.rkt`

With scripted Term and filesystem doubles, this file proves:

- `main.aloe` constructs the exact empty untitled session after explicit
  `fs-host` injection and still needs no Term binding;
- the three runner procedures have the arities in section 7;
- zero-path startup draws the empty frame and Escape quits without any
  filesystem read or write;
- an existing relative path is resolved, loaded before the first frame, and
  shown from point `(0, 0)`;
- a missing path starts empty and bound; a script that inserts, sends
  `"save"`, and then escapes creates exact contents in the shared double;
- a directory/symlink/other startup path is deliberately rejected before a
  frame or key read;
- a `"save"` script writes through the session rather than a Racket runner
  branch; and
- more than one command-line argument is a usage error.

The existing Loop runner assertions are updated only for the new required
filesystem injection, main value, and expanded helper arities. Frame count,
size-query count, key-read count, checked-driver use, and stop-without-redraw
retain their meanings.

### 8.5 Regression

The full test suite remains green, including all aloemacs Text, Term, Loop,
Gel, host descriptor/reflection, and filesystem checkpoint tests. Tests do
not depend on execution order or a physical terminal.

## 9. Acceptance

The design is implemented when all of the following are true:

1. One explicitly injected `FsHost` has the exact ten ordered rows in
   section 2, using only the existing crossing vocabulary.
2. Production and double receivers implement strict UTF-8 whole-file read,
   exact whole-file overwrite, and eligible final-file creation with the
   failure and non-following rules in section 2.
3. Thin `Fs.read` and `Fs.write` expose expected missing/non-file cases as
   `Option` without changing any existing thin or OO filesystem meaning.
4. The unchanged three-field `AloemacsEditor` is nested in the exact session
   state from section 4; visit, delegated editing, frame, quit, and save
   preserve all stated immutability and validity rules.
5. Visit starts at `(0, 0)`, missing paths become empty bound new-file
   sessions, non-file paths are refused, untitled save is refused, and quit
   never saves.
6. UTF-8, CR/LF, BOM, and final-newline handling is exactly section 5; no
   encoding or newline metadata is added to `Text` or the editor.
7. Plain Ctrl-S is the one interactive save command, while every existing
   Loop key retains its established behavior and the Term descriptor is
   unchanged.
8. The runner supports zero or one command-line path, keeps file policy in
   Aloe, and remains testable with both host doubles and no TTY.
9. The tests in section 8 pass together with the existing suite, and no
   feature outside this specification has been added.

## 10. Explicit non-goals

- A minibuffer, `find-file`, `write-file`, save-as prompt, path completion,
  prefix map, `C-x C-s`, or `C-x C-f`
- A second buffer, buffer list, windows, splits, dired, directory UI,
  `*scratch*`, or a status/mode line
- Dirty state, saved snapshots, external-change detection, merge, revert,
  insert-file, recent files, or file identity beyond resolved `Path`
- Backup files, autosave, lock files, atomic rename, fsync/durability,
  permission preservation policy, chmod, delete, rename, or mkdir
- Following symbolic links for contents, TRAMP, remote files, watch, glob,
  recursive traversal, or changing cwd
- Binary editing, replacement decoding, encoding selection, BOM stripping,
  CRLF normalization, platform text mode, or final-newline insertion
- Streaming, ports, bytes, `(List Int)`, a new crossing type, a new host
  capability, ambient filesystem access, or a kernel file operation
- Changes to `Disk`, `Location`, live `File`, Gel, `Text`, Loop movement or
  frame rules, the Term descriptor, `SPEC.md`, or global checkpoints
- Save-on-quit, quit confirmation, user-visible save diagnostics, general
  modifier keymaps, or porting Chez Emacs or Legmacs file commands
