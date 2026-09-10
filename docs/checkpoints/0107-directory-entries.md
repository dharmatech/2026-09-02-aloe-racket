# Checkpoint 107 — Directory.entries

**Branch.** Continue on `experiment/filesystem`.

**Depends on.** Checkpoint 106 (`inspect` and live `Item`)

**Status.** Complete (reviewed 2026-09-09 on `experiment/filesystem`)

## Goal

Add listing on a live `Directory` only: `(dir entries)` →
`(List Item)`, composed as vocabulary §6.

Do not add `(here entries)`, `enter`, `size`, `read`, `target`,
or a rewrite of `lib/fs.aloe`. Do not put `fs-host` on default
drivers. This is the last required OO-filesystem checkpoint.

## Depends on

- Parent: `experiment/filesystem` after checkpoint 106.
- Locked public Aloe API: `docs/filesystem-oo-vocabulary.md` §6
  listing, §4 `(dir entries)` only on live `Directory`.
- Host `names` already returns `(List String)` (checkpoints
  98 / 101–102). Do not add `(List Item)` as a crossing type.
- `lib/disk.aloe` already has `Disk`, `Location`, `inspect`,
  `Item`, and live classes (106). Keep those **byte-for-byte**
  except the `define-methods Directory` block below.
- `lib/list.aloe` (`fold` / `reverse`) is bootstrapped.
- Thin `lib/fs.aloe` `entries` already exists and must keep
  passing. This method is not thin `Fs.entries`.
- Not authority: Proposal A / `define-family`.

The implementer will not have the OO designer brief. Every rule
needed to implement this slice is in this document.

## Authority / starting point

Facts after checkpoint 106 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. `let` is
  `fn`/`call`. `cond` is nested `if` with a required `else`.
- Class definition order is `Location`, `Disk`, `Directory`,
  `File`, `SymbolicLink`, `Other`, `Item`, then
  `define-methods` `inspect`. Do not reorder.
- `Directory` already exists and already has `inspect` via
  `define-methods`. `entries` return type names `Item`, so it
  cannot go on the original `Directory` method list. Attach it
  in `define-methods Directory` beside `inspect`.
- Live objects reach the host through `(self location)`. They
  do not store a second `host` field.
- Host `names` of a missing path or non-directory is a host
  failure. Empty real directories return `len` 0.
- `fn` closes over the method environment, including `self`.
- Default drivers still have no `fs-host` / `term`.
- Thin `lib/fs.aloe` is unchanged. `Entry` and `Item` already
  coexist in one driver.
- 106 test-spec lesson: plant `"/"` `'directory` only if a
  golden inspects `/` as a `Directory`. `case` branches in one
  Aloe `case` must share a type. A Racket `list` of separate
  `driver-eval!` results may mix Racket types.

## Exact file scope

**May edit:**

- `lib/disk.aloe` (add `Directory.entries` only)
- `tests/checkpoint-107.rkt` (new)
- `tests/checkpoint-106.rkt` **only** as specified in
  “Living 106 tests” below
- `CHECKPOINTS.md` (append 107 only)
- `docs/handoff.md` (current-state / application pressures:
  both filesystem libraries complete through listing; no
  `(here entries)`, no file-text reading, no Gel filesystem UI;
  thin `lib/fs.aloe` unchanged)
- `docs/decisions.md` (short dated addendum: OO listing is
  `(dir entries)` → `(List Item)` on a live `Directory` only)
- `docs/filesystem-oo-vocabulary.md` status only (listing now
  exists; `(here entries)` / `enter` still later). Do not
  change locked selectors.

**Do not edit:**

- `aloe/`
- `host/` (including `host/racket/fs.rkt` and
  `host/racket/fs-repl.rkt`)
- `lib/fs.aloe`, `lib/option.aloe`, `lib/list.aloe`
- `bin/aloe`
- `SPEC.md`
- historical tests 100–105; 106 only as the living-test edit
  below
- `docs/checkpoints/0105-disk-and-location.md`
- `docs/checkpoints/0106-inspect-and-item.md`
- `examples/`, `gel/`, MPL
- no `(here entries)`, no `enter`, no `size` / `read` /
  `target`, no `text` method on `Location`, no rewrite of
  thin `Fs.entries`, no `archive/` worksheet in this slice

## Required behavior

### Library

Keep `lib/disk.aloe` byte-for-byte from checkpoint 106 except
replace the `define-methods Directory` block with this:

```aloe
(define-methods Directory
  (methods
    (inspect () (Option (Item H))
      ((self location) inspect))

    (entries () (List (Item H))
      (((((self location) host) names ((self location) text))
        fold
        (List empty)
        (fn (acc name)
          (((self child name) inspect) case
            (None () acc)
            (Some (item) (acc cons item)))))
       reverse))))
```

Do not add other methods, comments, or `#lang`. Do not move
`inspect` back onto the original `Directory` class. Do not add
`entries` to `Location`, `File`, `SymbolicLink`, `Other`,
`Item`, or `Disk`.

Lock:

- Public selector: `(dir entries)` → `(List (Item H))`.
- Listing only on a live `Directory`. A location does not list.
  Sugar `(here entries)` is a later layer, not this slice.
- Composition, same as thin `Fs.entries` but from the directory
  in hand:
  1. Host `names` on `((self location) text)`.
  2. For each name, `(self child name)` then `inspect`.
  3. `None` (vanished between list and inspect) is omitted.
  4. A host failure inspecting a name fails the whole `entries`
     send.
- Preserve host name order (`fold` / `cons` then `reverse`).
  The test double sorts names with `string<?`.
- Empty real directories return `len` 0.
- `names` on a non-directory remains a host failure. Programs
  reach `entries` after `inspect` has produced a `Directory`.
  `(Directory new file-location)` then `entries` is still a
  host failure (`FsHost` / `names`), not `None` and not an
  empty list.
- Do not add a TOCTOU test. The current double cannot plant a
  name whose `kind` is `"missing"`. The `None` omit branch must
  still exist in `entries`.
- Do not add `directory?` or `exists?`. Goldens use `case`.
- Return type must write `(List (Item H))`. Bare `Item` is a
  type error.

`(define fs (Disk new fs-host))` is unchanged.

### Construction and injection

Same as 106. After load and `(define fs (Disk new fs-host))`:

- Get a live directory from inspect, then
  `(dir entries)` typechecks as `(List (Item FsHost))`.
- `((fs current) entries)` remains an unknown-message (or type)
  error. Listing is not a `Location` message.

## Living 106 tests (required)

Checkpoint 106 required a living assertion that `entries` on a
live `Directory` was unknown. That cannot hold once this slice
defines it. Same pattern as 104 updating 103 and 106 updating
105.

**May edit `tests/checkpoint-106.rkt` as follows, and nothing
else in that file:**

1. In “entries and manager inspect remain outside this
   checkpoint”, delete the assertion that sending `entries` to
   a live `Directory` is unknown. **Keep** the assertion that
   sending `inspect` to `Disk` is unknown.
2. **Keep** every 106 inspect / live-parent / coexistence /
   production golden.
3. Do not add `entries` goldens to 106; those belong in 107.
4. **Keep** `tests/checkpoint-105.rkt` as 106 left it:
   `entries` on a **Location** stays unknown. That is 107’s
   forever contract for `(here entries)` sugar, not 106’s.

Do not rewrite `docs/checkpoints/0106-inspect-and-item.md`.

## Tests and hand check

Add `tests/checkpoint-107.rkt`. Do not repeat 106’s inspect
matrix except one missing-path `None` regression.

Use this double table (104’s mixed listing; no `/` unless you
add a root-inspect golden):

```racket
(hash
 "/cwd" 'directory
 "/cwd/a.txt" 'file
 "/cwd/dir" 'directory
 "/cwd/link" 'symlink
 "/cwd/pipe" "fifo")
```

Cover:

1. Fresh `make-driver`: no `fs-host`, `term`, `Disk`,
   `Location`, `Item`, `Directory`, `Option`.
2. Load `lib/disk.aloe`, inject the double, `(define fs
   (Disk new fs-host))`. After inspecting `cwd` as
   `Directory`, `(dir entries)` typechecks as
   `(List (Item FsHost))`.
3. **entries** on the double:
   - inspect `cwd`; `(dir entries)` has `len` 4, names in
     `string<?` order `a.txt`, `dir`, `link`, `pipe`, and those
     four `Item` constructors in that order. Identify each
     child with exhaustive `case`, not `directory?`.
   - inspect `/cwd/dir`; `(dir entries)` has `len` 0.
   - Sending `entries` to a `Location` (`(fs current)`,
     `(fs at "/cwd/dir")`) is unknown message.
   - Sending `entries` to a live `File` is unknown message.
   - `(Directory new (fs at "/cwd/a.txt"))` then `entries` is
     a host failure (`FsHost` / `names`).
4. Missing path inspect is still `None`.
5. **Both libraries** in one driver: `Entry` and `Item` both
   bound. Thin `(thin entries (thin current))` remains
   `(List Entry)` with `len` 4. Disk `(dir entries)` remains
   `(List Item)` with `len` 4. Case them separately. Do not
   mix those wrappers’ `Option` or list element types.
6. **Production**, isolated temp directory (create file,
   subdir, symlink-to-dir; delete afterward):
   - `entries` of the temp root includes at least two different
     constructors (file and directory). Identify them with
     `case`.
   - Do not send `entries` to a `Location` or to the file.
7. Term on a different driver still returns `"sealed"` from
   `(term write-line "sealed")`.
8. Thin tests 103–104 still pass (full `raco test`). Do not
   reimplement them here.

`case` branches inside one Aloe `case` must share a type.

### Hand check

```racket
(require racket/runtime-path
         "aloe/driver.rkt"
         "host/racket/fs.rkt")

(define-runtime-path disk-path "lib/disk.aloe")
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
(driver-eval! state `(load ,(path->string disk-path)))
(driver-eval! state '(define fs (Disk new fs-host)))
(list
 (driver-eval!
  state
  '(((fs current) inspect) case
     (None () -1)
     (Some (item)
       (item case
         (File (file) -1)
         (Directory (dir) ((dir entries) len))
         (SymbolicLink (link) -1)
         (Other (thing) -1)))))
 (driver-eval!
  state
  '(((fs at "/cwd/dir") inspect) case
     (None () -1)
     (Some (item)
       (item case
         (File (file) -1)
         (Directory (dir) ((dir entries) len))
         (SymbolicLink (link) -1)
         (Other (thing) -1)))))
 (driver-eval!
  state
  '(((fs current) inspect) case
     (None () "none")
     (Some (item)
       (item case
         (File (file) "file")
         (Directory (dir)
           (((dir entries) first) case
             (File (file) (file name))
             (Directory (d) "dir")
             (SymbolicLink (link) "link")
             (Other (thing) "other")))
         (SymbolicLink (link) "link")
         (Other (thing) "other"))))))
```

Expected: `'(4 0 "a.txt")`

Term check unchanged: `'("sealed" "sealed\r\n")`

## CHECKPOINTS.md and handoff

```text
## 107. [Directory.entries](docs/checkpoints/0107-directory-entries.md)

- Live `Directory.entries` returns mixed `(List Item)` via host
  `names` then `child` + `inspect`. Vanished names are omitted.
  No `(here entries)`. Thin `lib/fs.aloe` unchanged.
```

`docs/handoff.md`: tests through 107. Both filesystem libraries
are complete through listing on `experiment/filesystem`. Thin
`Path` / `Entry` / `Fs` and OO `Disk` / `Location` / `Item` /
live classes coexist. No `(here entries)`, no file-text reading,
no Gel filesystem UI. Default drivers still have no `fs-host`.
Constructors are not merged to `main`.

## Acceptance

- Still on `experiment/filesystem`. Do not create a new branch.
  Do not merge to `main`. Do not merge
  `codex/unified-nominal-adts`.
- `raco test` green, including 94, 95, 101–106 (after the living
  106 edit), and new 107.
- Hand checks hold.
- `git diff --check` clean.
- Default driver still has no `fs-host` / `term`.
- `lib/fs.aloe` unchanged. Host module unchanged in behavior.
  No `(here entries)`. No `text` method on `Location`.
- Stop. Do not add `enter`, `size`, `read`, `target`, Gel UI,
  or an `archive/` worksheet.

## Explicit non-goals

- `(here entries)`, `((fs at path) entries)`, `enter`.
- `size`, `read`, symlink `target`.
- A `text` method on `Location`.
- Loading `lib/fs.aloe` from `lib/disk.aloe`.
- Rewriting thin `lib/fs.aloe` or `Fs.entries`.
- `Missing`, `exists?`, `directory?` as the required API.
- `(List Item)` crossing, `Result`, a second host, ambient `fs`.
- Adding `lib/disk.aloe` or Option to `make-driver`.
- Read/write bytes, cwd mutation, recursive walk, Gel UI.
- An `archive/` worksheet for `Disk` (optional only after this
  checkpoint is green, as its own tiny follow-up).
- Redesigning injection, Term, or host path algebra.
- Merging to `main`.
- Checkpoint 108.
