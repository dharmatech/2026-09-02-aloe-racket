# Checkpoint 104 — Entry, inspect, and entries

**Branch.** Continue on `experiment/filesystem`.

**Depends on.** Checkpoint 103 (`Path` and `Fs` path algebra)

**Status.** Complete (reviewed 2026-09-08 on `experiment/filesystem`)

## Goal

Add Aloe `Entry` and the remaining public `Fs` messages `inspect` and
`entries`. Mixed listings are homogeneous `(List Entry)` with
exhaustive `case`.

This completes Phase C of the filesystem pair. Stop. Do not start
file-text reading, Gel UI, or SPEC ratification.

## Depends on

- Parent: `experiment/filesystem` after checkpoint 103.
- Locked public API: `docs/filesystem-vocabulary.md` §2 Entry, §3
  `inspect` / `entries`, §5 listing composition.
- Host `kind` / `names` already return crossing strings / lists
  (checkpoints 101–102). Aloe maps those strings. Do not add
  `(List Entry)` as a crossing type.
- `lib/option.aloe` is loaded by `lib/fs.aloe`. `lib/list.aloe`
  (`fold` / `reverse`) is bootstrapped.
- `(define fs (Fs new fs-host))` already typechecks (103 / 99).
- Not authority: Proposal A / `define-family`.

The implementer will not have the filesystem designer brief. Every
rule needed to implement this slice is in this document.

## Authority / starting point

Facts after checkpoint 103 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. `let` is
  `fn`/`call`. `cond` is nested `if` with a required `else`.
- `lib/fs.aloe` defines `Path` and generic `Fs` with `current`,
  `path`, `child`, `parent`, and `name`. Keep those methods
  **byte-for-byte**.
- `Path` has no host-effect methods and does not capture `fs-host`.
- Host `kind` of a missing path is `"missing"`. Host `names` of a
  missing path or non-directory is a host failure.
- String equality is `(s = other)`.
- `fn` closes over the method environment, including `self`.
- Default drivers still have no `fs-host` / `term`. Option and `Fs`
  are still not bootstrapped.

## Exact file scope

**May edit:**

- `lib/fs.aloe` (add `Entry` and the two `Fs` methods)
- `tests/checkpoint-104.rkt` (new)
- `tests/checkpoint-103.rkt` **only** as specified in
  “Living 103 tests” below
- `CHECKPOINTS.md` (append 104 only)
- `docs/handoff.md` (current-state / application pressures:
  `Path`, `Entry`, and `Fs` exist; no file-text reading, no Gel
  filesystem UI, constructors not merged to `main`)
- `docs/decisions.md` (short dated addendum: mixed listings are
  `(List Entry)` built in Aloe; absence is `None`; `names` of a
  non-directory fails the `entries` send)
- `docs/filesystem-vocabulary.md` status only (the library now
  exists at `lib/fs.aloe`; do not change locked selectors)
- `docs/host-boundary-extensions.md` status only (Aloe wrappers
  exist; still no `(List Entry)` crossing)

**Do not edit:**

- `aloe/`
- `host/` (including `host/racket/fs.rkt`)
- `lib/option.aloe`, `lib/list.aloe`
- `bin/aloe`
- `SPEC.md`
- historical tests 100–102; 103 only as the living-test edit below
- `examples/`, `gel/`, MPL
- no `Missing`, `exists?`, `directory?`, nested `File`/`Directory`
  classes, Path host-effect methods, or `show` on `Entry`

## Required behavior

### Library

Replace `lib/fs.aloe` with this complete file. Do not add other
methods, comments, or `#lang`.

```aloe
(load "option.aloe")

(define-class Path
  (fields
    (text String))
  (methods
    ))

(define-class Entry
  (constructors
    (RegularFile (fields (path Path)))
    (Directory (fields (path Path)))
    (SymbolicLink (fields (path Path)))
    (Other (fields (path Path) (kind String))))
  (methods
    (path () Path
      (self case
        (RegularFile (path) path)
        (Directory (path) path)
        (SymbolicLink (path) path)
        (Other (path kind) path)))))

(define-class (Fs H)
  (fields
    (host H))
  (methods
    (current () Path
      (Path new ((self host) current)))

    (path (string String) Path
      (Path new ((self host) resolve string)))

    (child (path Path) (name String) Path
      (Path new ((self host) child (path text) name)))

    (parent (path Path) (Option Path)
      (if ((self host) root? (path text))
          (Option None)
          (Option Some
            (Path new ((self host) parent (path text))))))

    (name (path Path) String
      ((self host) name (path text)))

    (inspect (path Path) (Option Entry)
      (let ((kind ((self host) kind (path text)))
            (resolved (self path (path text))))
        (cond
          ((kind = "missing") (Option None))
          ((kind = "file")
           (Option Some (Entry RegularFile resolved)))
          ((kind = "directory")
           (Option Some (Entry Directory resolved)))
          ((kind = "symlink")
           (Option Some (Entry SymbolicLink resolved)))
          (else
           (Option Some (Entry Other resolved kind))))))

    (entries (path Path) (List Entry)
      ((((self host) names (path text))
        fold
        (List empty)
        (fn (acc name)
          ((self inspect (self child path name)) case
            (None () acc)
            (Some (entry) (acc cons entry)))))
       reverse))))
```

Lock:

- `Entry` constructors, in order: `RegularFile`, `Directory`,
  `SymbolicLink`, `Other`. No `Missing`. The only method is
  `path`. Other’s diagnostic string is bound through `case`, not
  a whole-class `kind` method.
- Constructors are not top-level bindings: `(RegularFile p)` is
  unbound. Construction is `(Entry RegularFile path)`.
- `inspect` maps host `kind` strings:
  `"missing"` → `None`
  `"file"` → `RegularFile`
  `"directory"` → `Directory`
  `"symlink"` → `SymbolicLink`
  any other string → `Other` with that string
- The `Entry` payload path is `(self path (path text))` (host
  `resolve`), so it is absolute/normalized even if the argument
  `Path` was not.
- `entries` is Aloe composition: host `names`, then `child` +
  `inspect` per name. Preserve host name order (`fold`/`cons` then
  `reverse`). Omit `None` (vanished between list and inspect). A
  host failure from `inspect` fails the whole `entries` send.
- `entries` of a missing path or non-directory is a **host
  failure** (host `names` fails), not `None` and not an empty
  list. Empty real directories return `len` 0.
- Do not add `directory?` or `exists?`. Goldens use `case`.
- Do not add a TOCTOU test. The current double cannot plant a
  name whose `kind` is `"missing"`. The `None` omit branch must
  still exist in `entries`.

Public types:

```text
(fs inspect path)    ; (Option Entry)
(fs entries path)    ; (List Entry)
(entry path)         ; Path
```

`(define fs (Fs new fs-host))` is unchanged.

## Living 103 tests (designer addendum, 2026-09-08)

Checkpoint 103 required living assertions that `Entry` / `inspect` /
`entries` were absent after loading `lib/fs.aloe`. Checkpoint 104
forbade editing that file. Those two rules cannot both hold once
`lib/fs.aloe` defines `Entry`. That is a design defect, not an
implementer miss. Same pattern as checkpoint 98 updating living
checkpoint-83 declaration tests.

**May edit `tests/checkpoint-103.rkt` as follows, and nothing else
in that file:**

1. After `(load lib/fs.aloe)`, stop asserting that `Entry` is
   unbound. `Option` / `Path` / `Fs` stay bound; `Some` / `None` /
   `fs-host` / `term` stay unbound until injected.
2. Delete the assertions that `(fs inspect …)` and
   `(fs entries …)` are unknown messages, and that `Entry` is
   unbound after load. Those are 104’s feature, not 103’s forever
   contract.
3. **Keep** the assertion that sending `current` to a `Path` is
   unknown message. Path still has no host-effect methods.
4. **Keep** `Entry` unbound on a **fresh** `make-driver`. The
   library is still not bootstrapped.

Do not rewrite `docs/checkpoints/0103-fs-path-algebra.md`. Do not
weaken 103’s path-algebra goldens.

Also finish the 104 status-only edit of
`docs/host-boundary-extensions.md`: the opening “Not this file”
sentence and the “Explicitly later” list still say there is no
`Path` / `Entry` / `Fs` / `lib/fs.aloe`. Strike those leftovers.
Keep `(List Entry)` crossing and Gel UI as later.

## Tests and hand check

Add `tests/checkpoint-104.rkt`. Do not repeat 103’s path-algebra
matrix except one parent-at-root regression.

Use this double table (same shape as 101):

```racket
(hash
 "/cwd" 'directory
 "/cwd/a.txt" 'file
 "/cwd/dir" 'directory
 "/cwd/link" 'symlink
 "/cwd/pipe" "fifo")
```

Cover:

1. Fresh `make-driver`: no `fs-host`, `term`, `Fs`, `Path`,
   `Entry`, `Option`.
2. Load `lib/fs.aloe`, inject the double as `fs-host`,
   `(define fs (Fs new fs-host))`. Types:
   `(fs inspect (fs current))` is `(Option Entry)`;
   `(fs entries (fs current))` is `(List Entry)`.
3. **inspect** on the double:
   - missing path → `None` (`present?` `#f`, exhaustive `case`)
   - `a.txt` → `Some` `RegularFile`
   - `dir` → `Some` `Directory`
   - `link` → `Some` `SymbolicLink`
   - `pipe` → `Some` `Other` whose `case`-bound `kind` is `"fifo"`
   - `cwd` → `Some` `Directory`
   Each `Some` entry’s `(entry path)` text is the resolved
   absolute path (e.g. `"/cwd/a.txt"`, not `"a.txt"`).
4. Exhaustive `case` over `Entry` with four live clauses and no
   `else`. Incomplete `case` missing a constructor is a type
   error. Do not add a `directory?` golden.
5. **entries** on the double:
   - `(fs entries (fs current))` has `len` 4, names in
     `string<?` order `a.txt`, `dir`, `link`, `pipe`, and those
     four constructors in that order.
   - `(fs entries (fs path "/cwd/dir"))` has `len` 0.
   - `entries` of `a.txt`, `link`, and a missing path are host
     failures (`FsHost` / `names`).
6. Parent at root is still `None`.
7. `(RegularFile (fs current))` / unbound `RegularFile` is not
   valid construction.
8. **Production**, isolated temp directory (create file, subdir,
   symlink-to-dir, missing name; delete afterward):
   - `inspect` of the file / dir / link / missing matches 3.
   - `entries` of the temp root includes at least two different
     constructors (file and directory). Identify them with
     `case`, not `directory?`.
   - `entries` of the file and of the symlink fail.
   - `inspect` of a missing child is `None`.
9. Term on a different driver still returns `"sealed"` from
   `(term write-line "sealed")`.

### Hand check

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
  (hash
   "/cwd" 'directory
   "/cwd/a.txt" 'file
   "/cwd/dir" 'directory
   "/cwd/link" 'symlink
   "/cwd/pipe" "fifo")))
(driver-eval! state `(load ,(path->string fs-path)))
(driver-eval! state '(define fs (Fs new fs-host)))
(list
 (driver-eval! state '((fs inspect (fs path "/cwd/nope")) present?))
 (driver-eval! state '((fs parent (fs path "/")) present?))
 (driver-eval! state '((fs entries (fs current)) len))
 (driver-eval!
  state
  '((fs inspect (fs path "/cwd/pipe")) case
     (None () "none")
     (Some (entry)
       (entry case
         (RegularFile (path) "file")
         (Directory (path) "dir")
         (SymbolicLink (path) "link")
         (Other (path kind) kind))))))
```

Expected: `'(#f #f 4 "fifo")`

Term check unchanged: `'("sealed" "sealed\r\n")`

## CHECKPOINTS.md and handoff

```text
## 104. [Entry, inspect, and entries](docs/checkpoints/0104-fs-entry-and-listing.md)

- `lib/fs.aloe` adds `Entry` and `Fs` `inspect` / `entries`. Mixed
  listings are `(List Entry)` with exhaustive `case`. Absence is
  `None`. No file-text reading. No Gel UI.
```

`docs/handoff.md`: tests through 104. The filesystem vocabulary is
implemented on `experiment/filesystem`. Default drivers still have
no `fs-host`. Constructors are not merged to `main`.

## Acceptance

- Still on `experiment/filesystem`.
- `raco test` green, including 94, 95, 101–103 (after the living
  103 edit), and new 104.
- Hand checks hold.
- `git diff --check` clean.
- Default driver still has no `fs-host` / `term`.
- No `(List Entry)` crossing. No Path host effects. No `directory?`
  as the required API.
- Stop. Do not start file-text reading, Gel filesystem UI, or a
  SPEC ratification checkpoint.

## Explicit non-goals

- Read/write bytes, copy, move, delete, mkdir, chmod, cwd
  mutation, recursive walk, glob, watch, Git.
- `Missing`, `exists?`, `directory?` as the required API, nested
  `File` / `Directory` classes.
- `(List Entry)` crossing, `Result`, opaque directory handles.
- Gel filesystem UI, Entry `show` / Mirror as a Gel prerequisite.
- Source-written host type names. Path capturing `fs-host`.
- Adding Option or `Fs` to `make-driver`.
- Redesigning injection, Term, or host path algebra.
- Merging to `main` or claiming class constructors are proven
  enough to merge.
