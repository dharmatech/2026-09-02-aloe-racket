# Charter — aloemacs file

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for **load and
save of the one aloemacs buffer** through the existing filesystem
host, so a session can visit a path and write `(text to-string)`
back. Then **stop**. Do not write checkpoints. Do not implement.
Do not specify windows, a minibuffer, prefix keymaps, dired, or
live eval.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Confirm predecessors in §2 exist. If not, **stop**.
3. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.9.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-file 000**, `001`, … under
   `docs/design/implementation/aloemacs/file/checkpoints/` (not
   `docs/checkpoints/0116`, not `docs/editor/`).
5. Stop. The human reviews it. Do not write those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. Find-file with a prompt,
`C-x C-s` as a prefix map, backups, dired, and a port of Legmacs
file commands are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../loop/`](../loop/) | aloemacs-loop 000–003: `AloemacsEditor`, `handle-key`, `frame`, runner |
| [`../text/`](../text/) | `Text from-string` / `to-string`; CRLF is this layer's problem |
| Filesystem host | [`host/racket/fs.rkt`](../../../../../host/racket/fs.rkt): path algebra, `kind`, `names`; **no file contents** |
| Thin Fs | [`lib/fs.aloe`](../../../../../lib/fs.aloe), [`docs/filesystem-vocabulary.md`](../../../../filesystem-vocabulary.md) |
| OO Disk | [`lib/disk.aloe`](../../../../../lib/disk.aloe), [`docs/filesystem-oo-vocabulary.md`](../../../../filesystem-oo-vocabulary.md) |

`(file text)` on Disk's live `File` is the **path spelling**
(`Location.text`), not bytes of the file. Vocabulary already says
reading file text was the next filesystem feature. This layer is
that consumer. Do not pretend contents already exist.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. An Aloe program with an injected filesystem host can **read** a
   regular file's contents as a `String` and **write** a `String`
   over that path. Crossing stays in `SPEC.md` §14 (`String`, not
   bytes, not `(List Int)`).
2. Visiting a path builds an `AloemacsEditor` (or a documented
   extension of it) whose `(text to-string)` is that contents
   after the newline policy in §4.8. Saving writes the current
   `(text to-string)` (after the inverse policy) to the bound
   path.
3. **Unit tests are the first consumer**, under `tests/aloemacs/`,
   with names that do not reuse Loop/Term/Text files. They use
   `make-fs-double` (extended as needed) and a checked driver.
   They do not require a TTY or the production disk. At least:
   - load a small LF fixture and see the same `Text` as
     `(Text from-string …)`;
   - edit with existing `insert` / `handle-key`, save, load
     again, round-trip;
   - missing path and non-file path have named results (`Option`,
     unchanged editor, or a small result class — not an uncaught
     host crash in the editor loop);
   - Loop keys (insert, arrows, backspace, `q`) still work;
   - existing filesystem checkpoint tests stay green.
4. The runner can start a session on a path (command-line
   argument is the expected shape). Zero-argument start remains
   the empty untitled editor. The runner still does not implement
   insert, movement, or ANSI.
5. No minibuffer, no prefix keymap, no second buffer, no
   directory listing UI.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Capability, not kernel

Filesystem stays an injected host (`fs-host`), like Term. Do not
add ambient file I/O, a `load` of disk files as Aloe source (that
is already language `load`), or a kernel `open`. Default
`make-driver` / `bin/aloe` stay capability-free.

### 4.2 One public Aloe filesystem API

Pick **thin `Fs` or OO `Disk`**, not a third wrapper. Same
`fs-host`. Do not `load` both into the editor unless a named
test requires it (they can coexist; the editor should not).

Do not change the meaning of existing sends. In particular
`(location text)` / `(file text)` remain path strings.

### 4.3 Contents are `String`

The host reads and writes the whole file as one `String` in the
same character-count unit as `len` / `Text`. No `Char`, no byte
array, no streaming API in this layer. Overwrite on save is
enough; no backup file, no atomic-rename requirement unless the
spec can test it on the double.

### 4.4 Where code lives

- Host contents methods: `host/racket/fs.rkt` (production and
  `make-fs-double`)
- Aloe wrappers: `lib/fs.aloe` and/or `lib/disk.aloe` matching
  §4.2
- Editor visit/save: `examples/aloemacs/` (extend
  `AloemacsEditor` and/or `main.aloe`; do not move the editor
  into `lib/`)
- Runner: `host/racket/aloemacs-run.rkt` may inject `fs-host`
  and accept a path argument
- Tests: `tests/aloemacs/`
- Historical Fs checkpoint tests may be updated **only** for an
  appended host-descriptor row, the way Term 000 updated
  checkpoint-53/84/87
- Do not invent `docs/checkpoints/0116-…`. The human may
  promote a host contents lift to the language spine after
  review

### 4.5 Out of this layer

- Minibuffer, `find-file`, `write-file` to a prompted path
- Prefix maps (`C-x C-s`, `C-x C-f`)
- Windows, multiple buffers, dired, `*scratch*` file
- Autosave timers, lock files, TRAMP, encoding menus
- Creating parent directories, deleting files
- Changing Gel, Term methods, or the Text public table
- Reopening Loop movement/frame rules except as needed to
  carry a path on the editor value

### 4.6 Editor state (resolve this)

Loop's `AloemacsEditor` fields are `text`, `point`, `quit` only.
This layer needs a bound path (and maybe dirty).

- Add fields to `AloemacsEditor` (update Loop tests that
  construct `AloemacsEditor new` with three arguments), **or**
  wrap it in a session class. Pick one. Nested edit is still
  rebuild.
- Path type: `Path`, `Location`, `String`, or
  `(Option …)` for untitled. Untitled save with no path cannot
  prompt; it is `None` / no-op / documented refusal.
- Dirty bit: in or out. If out, save always writes. If in, say
  when it becomes `#t` / `#f`.
- Point after visit: `(Position new 0 0)` is the default unless
  you name another rule.
- `quit` still does not save unless you explicitly specify
  save-on-quit (default: **do not** save on `q`).

### 4.7 Host contents messages (resolve this)

`FsHost` today ends at `names`. Append the smallest methods that
make §3 true.

Name selector, arity, crossing types, and failure:

- Read of a missing path, a directory, or a permission error:
  host exception (then Aloe host-failure) vs a sentinel `String`
  vs forcing all failure to Aloe `Option` **before** the host
  throws. Prefer Aloe `Option` or a small result class at the
  **wrapper**, even if the host still errors on impossible
  paths — then the wrapper must `inspect`/`kind` first so the
  editor loop does not die.
- Write of a missing path: create a regular file, or fail?
  Creating a new file at a resolved path is in scope; creating
  intermediate directories is not.
- The test double must store contents for regular-file nodes.
  Directory/symlink nodes have no contents.

Do not add `(List Int)` or a `Bytes` crossing.

### 4.8 Newline and encoding (resolve this)

Text treats only LF as a line break; `"\r"` is an ordinary
character. This layer owns CRLF.

Pick a closed policy and goldens:

1. **Exact:** load UTF-8 (or host default) bytes as a `String`
   with no newline conversion; save writes `to-string` exactly.
   A CRLF file shows `"\r"` at line ends in the buffer.
2. **Normalize LF:** load converts CRLF (and maybe lone CR) to
   LF; save writes LF only, or writes CRLF if the original file
   used it (that needs stored policy — say so).

Name the encoding. UTF-8 is the expected choice; binary/invalid
UTF-8 is fail-or-replace, named, tested on the double if
possible. Do not add an encoding field to `Text`.

### 4.9 How the user saves (resolve this)

No prefix map. No minibuffer. Still need a way to save in the
running program **or** an honest statement that save is only a
method plus runner.

Pick a closed set:

1. **CLI visit + method:** `(editor save)` / `(editor visit
   path)` are Aloe sends. Tests prove them. The runner visits
   `argv` if present. Saving in the TTY session is a **single**
   extra `read-key` (not a prefix). If Term does not yet produce
   that string, this layer may add the smallest
   `tkeymsg->aloe-key` mapping (for example control-S →
   `"save"`), same move as Loop's backspace. Unknown keys remain
   no-ops.
2. **CLI only:** visit from `argv`; save only via the method in
   tests, not from a key. The interactive program cannot save.
   Allowed only if the spec says so in one sentence; do not hide
   it.

Self-insert must not steal `"s"`. `q` remains quit.

Runner shape: `racket host/racket/aloemacs-run.rkt` and
`racket host/racket/aloemacs-run.rkt path`. Zero args: empty
untitled. Relative `path` uses Fs `resolve` / Disk `at`.

## 5. Authority

- [`../README.md`](../README.md) — locks, paths, non-goals
- [`../loop/spec.md`](../loop/spec.md) — editor value, keys,
  runner skin
- [`../text/spec.md`](../text/spec.md) — `from-string` /
  `to-string`; CRLF deferred here
- [`../term/spec.md`](../term/spec.md) — do not change Term
  except a possible save-key mapping in §4.9
- `SPEC.md` §14 — host crossing
- [`docs/filesystem-vocabulary.md`](../../../../filesystem-vocabulary.md)
  — thin Fs; contents were explicitly future
- [`docs/filesystem-oo-vocabulary.md`](../../../../filesystem-oo-vocabulary.md)
  — Disk / Location; `(file text)` is path
- [`host/racket/fs.rkt`](../../../../../host/racket/fs.rkt),
  [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt)
- Legmacs visit/save and Chez Emacs file commands — seam
  catalogs, not law

`SPEC.md` remains Aloe language law. This spec is not language
law. It may extend the `FsHost` descriptor the way Term gained
`write`, without becoming a kernel feature.

## 6. Non-goals

- Windows, status line as a product, minibuffer, prefix maps
- Dired, multiple files, revert, insert-file
- Backup (`file~`), autosave, file locks
- Creating directories, deleting, renaming, chmod
- Binary editing, encoding conversion UI
- `Mirror`, eval of buffer text
- Changing Gel
- Porting Chez Emacs `files` or Legmacs file commands wholesale
