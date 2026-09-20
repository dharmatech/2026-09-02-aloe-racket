# aloemacs-file 000 — Whole-file contents through `Fs`

**Status.** Ready to implement.

## Goal

Add exact whole-file UTF-8 read and write to the existing optional filesystem
capability, its production receiver, its stateful test double, and the thin
`Fs` Aloe API. Expected missing and non-file cases become `Option` at the
thin wrapper; raw host misuse and real I/O failures retain the existing
guarded `FsHost` failure path.

This checkpoint is the complete filesystem-content substrate for the later
aloemacs file session. Stop when it is green. Do not create
`AloemacsSession`, visit or save an editor, normalize Ctrl-S, change the
aloemacs starting value, or extend the runner.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-file, 000)`, spoken **aloemacs-file 000**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md), especially send
  evaluation, immutable typed classes, exhaustive `case`, `load`, and section
  14's typed host boundary, is language law. The head of a list is the
  receiver and its second element is the literal selector. A function object
  runs only through `(f call ...)`.
- [`../spec.md`](../spec.md), especially sections 1–3, 5, 8.1, 9, and 10, is
  the local design authority. This checkpoint implements only the host and
  thin-`Fs` content portion of that design.
- Global filesystem checkpoints 101–104 are implemented and reviewed. They
  supply the optional `FsHost`, production and double receivers, `Option`,
  `Path`, `Entry`, and generic thin `Fs` with `inspect` and `entries`.
  Checkpoints 105–107's OO `Disk` surface are also reviewed but are not
  extended here.
- aloemacs Text, Term, and Loop are implemented and reviewed. This checkpoint
  neither loads nor edits their sources.

Do not add a special form, language feature, crossing type, ambient
capability, second filesystem interface, exception value, or implicit
`Int`/`Float` coercion.

## Starting point

[`../../../../../../host/racket/fs.rkt`](../../../../../../host/racket/fs.rkt)
currently provides one eight-row `FsHost` descriptor, an in-memory
classification/listing double, and a production receiver. The rows, in order,
are:

```racket
(current resolve child root? parent name kind names)
```

`make-fs-double` currently accepts exactly `current` and `nodes`. The node
table maps path strings to `'file`, `'directory`, `'symlink`, or an
other-kind String. The double copies the table and never consults the physical
filesystem. It has no file-content state.

[`../../../../../../lib/fs.aloe`](../../../../../../lib/fs.aloe) loads
`option.aloe` and defines `Path`, `Entry`, and `(Fs H)`. Its public sends are
`current`, `path`, `child`, `parent`, `name`, `inspect`, and `entries`. It has
no file-content methods. `Disk`, `Location`, and live `File` are a separate OO
API in `lib/disk.aloe`; in particular `(file text)` still means the path
spelling.

Fresh drivers contain neither `fs-host` nor the `Fs` library. Injection and
loading remain explicit and driver-local.

## Exact file scope

### May edit

- `host/racket/fs.rkt`
- `lib/fs.aloe`
- `tests/aloemacs/fs-contents.rkt` (new)
- `tests/checkpoint-101.rkt`, only its exact `FsHost` selector-list assertion

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- `lib/disk.aloe`, `lib/option.aloe`, `lib/text.aloe`, or another library
- any file under `aloe/`, `bin/`, `gel/`, or `examples/`
- `host/racket/term.rkt`, `host/racket/aloemacs-run.rkt`, or another host
  module
- any test other than the new focused test and the one exact assertion in
  `tests/checkpoint-101.rkt`
- the aloemacs maps, charter, specification, or predecessor checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Exact `FsHost` descriptor

Keep the existing descriptor object, nominal name `FsHost`, and first eight
rows unchanged. Append exactly these two rows:

| Order | Selector | Parameter types | Result type |
|---:|---|---|---|
| 9 | `read` | `(String)` | `String` |
| 10 | `write` | `(String String)` | `String` |

The exact final selector order is:

```racket
(current resolve child root? parent name kind names read write)
```

The same descriptor continues to drive checking, runtime dispatch, and host
reflection. Both implementations have the exact positional call shape
required by `make-host-method`: opaque state first, then one argument for
`read` or two for `write`, with no optional, keyword, or variadic shape.

Do not add `Bytes`, `(List Int)`, a port, a handle, a host `Option`, a second
host interface, or another descriptor row. Default `make-driver` and
`bin/aloe` remain capability-free.

## Raw `read`

The raw host send is:

```aloe
(fs-host read path) ; String
```

It resolves `path` with the same lexical resolution already used by every
other `FsHost` method. It then requires the resolved node itself to be a
regular file. Classification does not follow a symbolic link.

For a regular file, `read` returns its complete contents as one String. An
empty regular file returns `""`. Calling raw `read` on a missing path,
directory, symbolic link, or other node raises through the existing guarded
host boundary. The resulting exception names interface `FsHost` and selector
`read`.

The production implementation:

- opens and reads the entire file in binary mode;
- decodes those bytes as strict UTF-8;
- returns the decoded String through the existing crossing guard; and
- treats unreadability, invalid UTF-8, a classification race, or any other
  failed I/O as an ordinary guarded `FsHost/read` failure.

Invalid byte sequences are not replaced, skipped, or returned as bytes. Do
not use a text-mode read that performs newline conversion.

## Raw `write`

The raw host send is:

```aloe
(fs-host write path text) ; String
```

It resolves `path` by the existing rule and accepts exactly these target
shapes:

1. an existing regular file, whose complete contents are replaced by
   `text`; or
2. a missing final path whose existing parent is a directory, which becomes
   a regular file containing `text`.

After a successful close, `write` returns the same String value `text`.
Parent directories are never created.

An existing directory, symbolic link, or other node is not followed or
replaced. A missing parent, non-directory parent, permission failure,
classification race, close failure, or other I/O failure raises through the
guarded boundary as `FsHost/write`.

The production implementation encodes the complete Aloe String as UTF-8 and
writes those bytes in binary mode. It is ordinary overwrite: do not append a
newline or promise atomic replacement, a temporary file, backup, fsync,
permission repair, or recovery from a partial failed write.

## Stateful filesystem double

Change the compatible factory surface to:

```racket
(make-fs-double current nodes [contents (hash)])
```

Existing two-argument callers keep their exact meaning. The optional third
argument is a path-to-String hash:

- every key must name a node whose value in `nodes` is exactly `'file`;
- every value must be a String;
- a regular-file node omitted from `contents` begins with `""`; and
- directory, symbolic-link, other, and missing nodes are rejected as
  `contents` keys.

Retain all existing validation of `current` and `nodes`. Reject an invalid
`contents` argument at `make-fs-double` construction; do not defer malformed
fixture data to a later host send.

Privately copy both supplied hashes. The receiver must never mutate the
caller's tables, and later caller mutation must not alter the receiver's
model. Private mutable tables, boxes, or an equivalent private state
representation are permitted because the double models the external
filesystem; no Aloe value becomes mutable.

The double implements the raw sends with the same path-resolution,
regular-file, parent-directory, and non-following rules as production:

- `read` returns the current String of a regular-file node;
- `write` replaces the current String for an existing regular-file node;
- `write` to an eligible missing final path adds a `'file` node and its
  contents; and
- later `kind`, `names`, and `read` sends observe that new node.

All raw ineligible operations fail and acquire their `FsHost/read` or
`FsHost/write` context from the existing host boundary. The double stores
already-decoded Racket strings, so it has no invalid-UTF-8 mode; invalid bytes
belong only to the isolated production test.

## Thin `Fs` content API

Append exactly these public methods to `(Fs H)` in `lib/fs.aloe`:

| Send | Checked result | Meaning |
|---|---|---|
| `(fs read path)` | `(Option String)` | `Some(contents)` for a regular file; otherwise `None` |
| `(fs write path text)` | `(Option String)` | `Some(text)` after an eligible successful write; otherwise `None` |

Do not change `Path`, `Entry`, an existing `Fs` signature, or an existing
method body.

### Thin read

`read` first sends the existing `(self inspect path)` and exhaustively handles
the returned `Option Entry` and every `Entry` constructor.

- Only `RegularFile` sends raw host `read`, and wraps the returned String in
  `(Option Some ...)`.
- `None`, `Directory`, `SymbolicLink`, and `Other` return `(Option None)`
  without sending raw host `read`.

The method does not catch host failures. A permission failure, invalid UTF-8,
or race after inspection still propagates through the existing guarded host
boundary.

### Thin write

`write` classifies before performing an effect:

- `RegularFile` sends raw host `write` and wraps its returned String in
  `Some`.
- `Directory`, `SymbolicLink`, and `Other` return `None` without writing.
- For a missing target, send the existing `(self parent path)`. Creation is
  eligible only when this is `Some(parent)` and `(self inspect parent)` is
  `Some` of `Entry Directory`; then send raw host `write` and wrap its returned
  String in `Some`.
- A root path, missing parent, or parent observed as `RegularFile`,
  `SymbolicLink`, or `Other` returns `None` without sending raw host `write`.

Use exhaustive `case`; constructor names are selectors on `Option` and
`Entry`, not top-level functions. Do not add a catch form, `Result`, sentinel
String, Boolean success value, preflight method, helper class, or method to
`Path`.

These inspections represent expected refusal as Aloe data. They do not make
the effect atomic: if the filesystem changes after inspection, the raw host
send can still fail.

## Encoding and newline contract

Read and write preserve the exact decoded characters:

- UTF-8 is the only encoding;
- LF, CRLF, and lone CR receive no conversion;
- U+FEFF is ordinary String content, not stripped BOM metadata;
- no final newline is added or removed; and
- saving a String encodes exactly that String as UTF-8.

This checkpoint does not add encoding or newline state anywhere. The later
editor session will pass these Strings through `Text.from-string` and
`Text.to-string`; it is not part of this slice.

## Required tests

Create `tests/aloemacs/fs-contents.rkt`. It uses checked drivers and explicit
`fs-host` injection, requires no Term receiver or physical TTY, and never uses
a repository file as scratch space.

### Descriptor and capability boundary

Prove:

1. The `FsHost` descriptor has the exact ten selectors in the required order.
2. Every row retains its exact parameter and result types, including
   `read : (String) -> String` and
   `write : (String String) -> String`.
3. A fresh driver still has no `fs-host`; loading `lib/fs.aloe` does not inject
   one; the default environment remains otherwise usable.
4. Production and double receivers still share the exact `fs-interface`
   identity.
5. Two- and three-argument `make-fs-double` calls are accepted; one or four
   arguments are not.

In `tests/checkpoint-101.rkt`, change only the old exact selector expectation
to the ten-selector list. Do not move any new behavior matrix into that
historical test.

### Double construction and raw sends

Use fixtures containing a directory, regular files (including one omitted
from `contents`), a subdirectory, a symbolic link, and an other node. Prove:

1. Supplied contents can be read and an omitted regular file reads as `""`.
2. Invalid `contents` values and keys naming missing or non-regular nodes are
   rejected by `make-fs-double`.
3. Raw write overwrites a regular file and returns the supplied text.
4. Raw write to an eligible missing child creates it; later `kind`, sorted
   `names`, and raw `read` observe the new regular file and exact text.
5. Raw read of missing, directory, symbolic-link, and other nodes is a guarded
   `FsHost/read` failure.
6. Raw write over directory, symbolic-link, and other nodes, or beneath a
   missing or non-directory parent, is a guarded `FsHost/write` failure.
7. Writes and creations do not change the caller's original node or contents
   hashes. Also prove that mutating caller-owned mutable hashes after factory
   construction does not change the receiver's private model.

Use exact Strings that include Unicode and newline-sensitive content in the
double; do not introduce byte fixtures there.

### Thin wrapper

Load `lib/fs.aloe`, define `(define fs (Fs new fs-host))`, and prove the
checked types:

```text
(fs read path)        => (Option String)
(fs write path text)  => (Option String)
```

Then prove:

1. `read` returns `Some(contents)` only for a regular file, including
   `Some("")` for an empty one.
2. `read` returns `None` for missing, directory, symbolic-link, and other
   paths without exposing a raw host failure.
3. `write` returns `Some(text)` for an existing regular-file overwrite and an
   eligible missing-file creation; later thin `read`, `inspect`, and `entries`
   observe the effects.
4. `write` returns `None` for an existing directory, symbolic link, or other
   node; for root; for a target under a missing parent; and for a target whose
   parent is a regular file or another non-directory kind.
5. All refusal cases leave the double unchanged.

Unwrap `Option` with exhaustive `case` in at least one read assertion and one
write assertion. `present?` alone is not enough to prove the payload.

### Isolated production bytes

Create and clean a unique directory beneath `/tmp` with `dynamic-wind` (or an
equivalent always-run cleanup). With one production receiver, prove:

1. raw write creates an eligible missing file from the exact String
   `"λ\r\nlast"`;
2. the physical file bytes equal that String's exact UTF-8 encoding, with no
   extra final newline and no CRLF conversion;
3. raw read returns the exact decoded String;
4. a second raw write replaces the complete contents rather than appending;
5. an empty file reads as `""`; and
6. a symbolic link to a regular file is refused by both raw `read` and raw
   `write` as guarded selector-specific failures, and the link target remains
   unchanged; and
7. a separate file containing an invalid UTF-8 byte sequence raises a guarded
   `FsHost/read` failure.

Use binary Racket ports for both the byte golden and invalid fixture. Do not
make a permission-denied test depend on the account running the suite.

### Regression and hand check

Run the complete suite:

```sh
raco test tests
```

Then run one checked expression by hand with a three-argument double:

```racket
(require racket/runtime-path
         "aloe/driver.rkt"
         "host/racket/fs.rkt")

(define-runtime-path fs-path "lib/fs.aloe")
(define state (make-driver))
(driver-inject-host!
 state
 'fs-host
 (make-fs-double
  "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file)
  (hash "/cwd/a.txt" "old")))
(driver-eval! state `(load ,(path->string fs-path)))
(driver-eval! state '(define fs (Fs new fs-host)))
(list
 (driver-eval!
  state
  '((fs read (fs path "a.txt")) case
     (None () "none")
     (Some (text) text)))
 (driver-eval!
  state
  '((fs write (fs path "new.txt") "λ\r\nlast") present?))
 (driver-eval! state '(fs-host read "/cwd/new.txt")))
```

Expected:

```racket
'("old" #t "λ\r\nlast")
```

## Acceptance

- `fs-interface` is still one nominal `FsHost`, now with exactly ten ordered
  rows and no new crossing type.
- Production and double `read`/`write` satisfy all regular-file,
  parent-directory, non-following, strict-UTF-8, and exact-content rules.
- Existing two-argument double callers behave unchanged; the optional content
  state is private and correctly observes writes and creation.
- Thin `Fs.read` and `Fs.write` have the exact `(Option String)` surface and
  turn every specified observed refusal into `None` without hiding real host
  failures.
- `Path`, `Entry`, every existing `Fs` method, and all OO filesystem meanings
  are unchanged.
- `raco test tests` is green, the hand check yields the exact result above,
  and `git diff --check` is clean.
- Stop. Do not start aloemacs-file 001, editor sessions, key mapping, main, or
  runner work.

## Explicit non-goals

- `AloemacsSession`, editor visit/save, bound paths, dirty state, or any
  change under `examples/aloemacs/`
- Ctrl-S, another key normalization, a prefix map, Term changes, or TTY use
- command-line paths, filesystem injection into aloemacs, or runner changes
- methods on `Disk`, `Location`, or live `File`; changing `(file text)`
- bytes or streams in Aloe, ports, handles, `(List Int)`, a new crossing type,
  or a second filesystem capability
- following symbolic links, recursive traversal, globbing, changing cwd,
  mkdir, delete, rename, chmod, or parent creation
- newline normalization, BOM stripping, encoding selection, binary editing,
  replacement decoding, or final-newline insertion
- atomic replacement, temporary files, backups, fsync, autosave, locks, or
  recovery guarantees
- catching host failures in Aloe, a `Result` class, or a sentinel error String
- changing Gel, Text, the Loop editor, language law, or the global checkpoint
  spine
