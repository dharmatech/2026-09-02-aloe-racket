# Checkpoint 105 — Disk and Location algebra

**Branch.** Continue on `experiment/filesystem`.

**Depends on.** Checkpoint 104 (`Entry`, `inspect`, and `entries`)

**Status.** Complete (reviewed 2026-09-09 on `experiment/filesystem`)

## Goal

Create the second filesystem library, `lib/disk.aloe`, with `Disk` and
`Location` path algebra only.

Public construction is `(define fs (Disk new fs-host))`. Locations
come from `(fs current)` and `(fs at string)`. Path questions are
sends to the location: `(here name)`, field `(here text)`,
`(here parent)`, `(here child "lib")`.

Do not add `inspect`, `Item`, or live `File` / `Directory` /
`SymbolicLink` / `Other`. Do not load or edit `lib/fs.aloe`. Do not
put `fs-host` on default drivers.

## Depends on

- Parent: `experiment/filesystem` after checkpoint 104.
- Locked public Aloe API: `docs/filesystem-oo-vocabulary.md` §2
  construction, §3 `Disk` / `Location` (algebra only), §4 public
  sends `current` / `at` / `name` / `text` / `parent` / `child`.
  Ignore `inspect`, `Item`, live classes, and `entries` in that
  file; they are later checkpoints.
- Host messages already locked in 101–102. Do not reimplement
  POSIX path rules in Aloe.
- `lib/option.aloe` (checkpoint 100). Location `parent` returns
  `(Option (Location H))`.
- Generic host-type retention (checkpoint 99): `H` is inferred
  from the injected receiver. Do not write `FsHost` as a source
  type.
- Thin library `lib/fs.aloe` already owns `Fs`, `Path`, and
  `Entry`. This library uses different class names so both can
  load in one environment later.
- Law: `SPEC.md` (send, `fn`/`call`, `let`, `if`/`cond`, `load`,
  constructors, `case`, expected-type `None`, type grammar
  `(Name Type ...)`).
- Not authority: Proposal A / `define-family`.
  `docs/filesystem-designer.md` is the finished thin-library
  pair. Do not continue it.

The implementer will not have the OO designer brief. Every rule
needed to implement this slice is in this document.

## Authority / starting point

Facts after checkpoint 104 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. `let` is
  `((fn (names ...) body) call exprs ...)`. No new special forms.
- `fs-host` is injected. Default drivers do not have it.
  `bin/aloe` does not have it.
- Host `current` / `resolve` / `child` / `root?` / `parent` /
  `name` already exist on both the test double and production.
- Host `parent` of `"/"` returns `"/"`. Aloe `parent` must still
  return `None` at root by asking host `root?` first and **not**
  calling host `parent` when that is true.
- `lib/list.aloe` is bootstrapped. `lib/option.aloe` is not.
  `lib/disk.aloe` must `load` Option itself.
- Crossing remains `Int` / `Bool` / `String` / `(List String)`.
- Thin `lib/fs.aloe` is complete through 104. Leave it
  byte-for-byte. This library talks to `H` directly. It does not
  store or construct thin `Fs`.
- `load` shares one environment. Two classes named `Entry` cannot
  coexist; that is why this library is `Disk` / `Location`, not a
  second `Fs` / `Path`.
- Generic `(fields ...)` method bodies are checked at each send
  with the instantiated substitution, not at definition.

## Exact file scope

**May edit:**

- `lib/disk.aloe` (new)
- `tests/checkpoint-105.rkt` (new)
- `CHECKPOINTS.md` (append 105 only)
- `docs/handoff.md` (current-state / application pressures:
  `Disk` and `Location` path messages exist; `inspect` / `Item` /
  live classes / `entries` do not; thin `lib/fs.aloe` unchanged)
- `docs/decisions.md` (short dated addendum: `Location` carries
  the host; `text` is a field; `parent` at root is `None`; the
  second library does not `load` `lib/fs.aloe`)
- `docs/filesystem-oo-vocabulary.md` status only if it still
  reads as unimplemented. Do not change locked selectors.

**Do not edit:**

- `aloe/`
- `host/` (including `host/racket/fs.rkt` and
  `host/racket/fs-repl.rkt`)
- `lib/fs.aloe`, `lib/option.aloe`, `lib/list.aloe`
- `bin/aloe`
- `SPEC.md`
- historical tests 100–104
- `examples/`, `gel/`, MPL
- no `Item` class, no `inspect`, no live `File` / `Directory` /
  `SymbolicLink` / `Other`, no `entries`
- no `text` method on `Location`
- no `directory?`, `exists?`, `Missing`, or thin-library rewrite

## Required behavior

### Library

`lib/disk.aloe` is Aloe source (no `#lang`). It begins by loading
Option as a sibling of this file, then defines `Location` and
`Disk` in that order (`Disk` return types name `Location`).

Replace nothing else. This is the complete file. Do not add other
methods, comments, or `#lang`.

```aloe
(load "option.aloe")

(define-class (Location H)
  (fields
    (host H)
    (text String))
  (methods
    (name () String
      ((self host) name (self text)))

    (parent () (Option (Location H))
      (if ((self host) root? (self text))
          (Option None)
          (Option Some
            (Location new (self host) ((self host) parent (self text))))))

    (child (name String) (Location H)
      (Location new (self host) ((self host) child (self text) name)))))

(define-class (Disk H)
  (fields
    (host H))
  (methods
    (current () (Location H)
      (Location new (self host) ((self host) current)))

    (at (string String) (Location H)
      (Location new (self host) ((self host) resolve string)))))
```

Lock:

- `Location` is generic. Fields in order: `host` of type `H`,
  `text` of type `String`. It carries the host so later messages
  do not go back to a manager.
- There is **no** `text` method. `text` is the field accessor.
  `(here text)` is the resolved absolute spelling, same word as
  thin `Path`. Writing `(text () String (self text))` would
  recurse forever.
- `(Location new host text)` exists because every `(fields ...)`
  class has `new`. It is **not** the public way to make a
  location. Public goldens obtain locations from `Disk`.
- Return types must write `(Location H)` and
  `(Option (Location H))`. Bare `Location` is a type error
  (`generic type Location needs arguments`).
- `name` is the host last-component rule. `parent` is path
  algebra: `(Option (Location H))`, `None` at root, no disk look.
  `child` takes one component (`"lib"`), not a slash-separated
  string, and returns a `Location`.
- `name` in `child` is one component. Multi-component strings
  fail at the host (`FsHost` / `child`), not via Aloe joining.
- `parent` of a root path is `(Option None)` with
  `T = (Location H)`. Use the method return type so
  `(Option None)` typechecks. Do not call host `parent` when host
  `root?` is true.
- `Disk` is generic. Field name is `host`. `H` is inferred from
  `(Disk new fs-host)`. Do not annotate the field as `FsHost`.
- `Disk` cannot be named `Fs`. Everyday code still binds the
  wrapper as `fs`.
- `(fs at string)` always returns one `Location`. It asks the
  host to **resolve** the string (relative against cwd, result
  absolute). It does not ask `kind`. Missing paths are locations.
- Public selectors and types are exactly:
  `(fs current)` → `(Location H)`
  `(fs at string)` → `(Location H)`
  `(here name)` → `String`
  `(here text)` → `String` (field)
  `(here parent)` → `(Option (Location H))`
  `(here child name)` → `(Location H)`
- Do not add `inspect`, `entries`, `path`, `map`, `show`,
  `directory?`, or `exists?`.
- Do not `load` `lib/fs.aloe`. Do not mention `Path`, `Fs`, or
  `Entry` in this file.
- Do not duplicate the host kind-string table yet. That table is
  for `inspect`.

Match `lib/option.aloe`: no narrative comments.

Tests load this file with Aloe `load` (same pattern as
checkpoint 103). Relative `(load "option.aloe")` inside
`lib/disk.aloe` must resolve next to that file. Do not add `Disk`
or Option to `make-driver`.

### Construction and injection

```racket
(define state (make-driver))
(driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
(driver-eval! state `(load ,(path->string disk-library-path)))
(driver-eval! state '(define fs (Disk new fs-host)))
```

`nodes` may be a directory at `"/cwd"` plus whatever the path
tests need. Path algebra does not require planted children.

After that:

- `fs` typechecks as `(Disk FsHost)` (diagnostic name `FsHost`).
- `(fs current)` typechecks as `(Location FsHost)`.
- `(fs at "x")` typechecks as `(Location FsHost)`.
- `((fs current) parent)` typechecks as
  `(Option (Location FsHost))`.
- `((fs current) name)` typechecks as `String`.
- `((fs current) text)` typechecks as `String`.
- `((fs current) child "lib")` typechecks as `(Location FsHost)`.
- `(define-class HostHolder (fields (value FsHost)) (methods))`
  is still a type error.

Production tests use `make-fs-receiver` instead of the double,
still `(define fs (Disk new fs-host))`.

## Tests and hand check

Add `tests/checkpoint-105.rkt`. Do not repeat 101–102 host
matrices. Do not repeat 103–104 thin goldens except the
coexistence load below.

Cover:

1. Fresh `make-driver`: no `fs-host`, no `term`, no `Fs`, no
   `Path`, no `Entry`, no `Disk`, no `Location`, no `Item`, no
   `Option`. `List` still works.
2. Aloe `(load <lib/disk.aloe>)` then inject (or inject then
   load; both orders are legal as long as `Disk new` happens
   after both). `Option`, `Location`, and `Disk` become bound.
   `Path`, `Fs`, `Entry`, and `Item` stay unbound. `Some` /
   `None` stay unbound as top-level names.
3. **Double**, current `"/cwd"`:
   - `((fs current) text)` is `"/cwd"`.
   - `((fs at "/tmp/a/../b") text)` is `"/tmp/b"`.
   - `((fs at "x") text)` is `"/cwd/x"` (relative `at` becomes
     absolute).
   - `((fs at "nope") text)` is `"/cwd/nope"` (missing paths are
     still locations).
   - `(((fs at "/tmp") child "a") text)` is `"/tmp/a"`.
   - `((fs at "/tmp/a") name)` is `"a"`.
   - `((fs at "/cwd/a.txt") name)` is `"a.txt"` (last component
     of a file path; the file need not exist).
   - `((fs at "/") name)` is `""`.
   - `(((fs at "/tmp/a") parent) present?)` is `#t`; unwrapping
     `Some` yields text `"/tmp"`.
   - `(((fs at "/") parent) present?)` is `#f` (None at root).
     Exhaustive `case` on that Option is required, not only
     `present?`.
   - `((fs current) child "a/b")` is a host failure
     (`FsHost` / `child`).
4. Sending `inspect` or `entries` to a `Location` is an
   unknown-message (or type) error in this slice. Sending
   `current` or `at` to a `Location` is unknown message. Sending
   `path` or `name` to `Disk` is unknown message (`path` / `name`
   on the wrapper are thin `Fs` selectors; OO `name` lives on
   `Location`).
5. **Both libraries** in one driver, same injected `fs-host`:
   load `lib/fs.aloe` and `lib/disk.aloe` (either order).
   `Path`, `Fs`, `Entry`, `Disk`, `Location`, and `Option` are
   bound. `Item` is still unbound. Then
   `(define thin (Fs new fs-host))` and
   `(define fs (Disk new fs-host))` both work.
   `((thin current) text)` and `((fs current) text)` are both
   `"/cwd"`. Do not mix those wrappers’ `Option` values. Do not
   add `inspect` goldens here.
6. **Production**, isolated temp directory (create, delete in
   `dynamic-wind` / `after`):
   - `parameterize` `current-directory` to that dir.
   - `((fs current) text)` equals the normalized absolute temp
     path.
   - `((fs at "a.txt") text)` equals
     `(((fs current) child "a.txt") text)` after creating
     `a.txt` (the file need only exist if you also want a later
     inspect; path algebra does not require it — creating it is
     fine).
   - `(((fs at "/") parent) present?)` is still `#f`.
7. Term on a different driver:
   `(term write-line "sealed")` still `"sealed"`.
8. Do not implement `Item` or `inspect`.

### Hand check

```racket
(require racket/runtime-path
         "aloe/driver.rkt"
         "host/racket/fs.rkt")

(define-runtime-path disk-path "lib/disk.aloe")
(define state (make-driver))
(driver-inject-host!
 state 'fs-host (make-fs-double "/cwd" (hash "/cwd" 'directory)))
(driver-eval! state `(load ,(path->string disk-path)))
(driver-eval! state '(define fs (Disk new fs-host)))
(list (driver-eval! state '((fs current) text))
      (driver-eval! state '((fs at "x") text))
      (driver-eval! state '(((fs at "/") parent) present?))
      (driver-eval! state '((fs at "/tmp/a") name)))
```

Expected: `'("/cwd" "/cwd/x" #f "a")`

Term check unchanged: `'("sealed" "sealed\r\n")`

## CHECKPOINTS.md and handoff

```text
## 105. [Disk and Location algebra](docs/checkpoints/0105-disk-and-location.md)

- `lib/disk.aloe` defines generic `Disk` and `Location`. Public
  `current` / `at` wrap `fs-host`; `name` / `text` / `parent` /
  `child` are location messages. Parent at root is `None`. No
  `inspect`, `Item`, or live classes. Does not load `lib/fs.aloe`.
```

`docs/handoff.md`: tests through 105. `Disk` and `Location` path
messages exist on `experiment/filesystem`. `inspect` / `Item` /
live classes / `Directory.entries` still do not. Thin `lib/fs.aloe`
is unchanged. Option still not bootstrapped. Default drivers still
have no `fs-host`. Constructors not ready for `main`.

## Acceptance

- Still on `experiment/filesystem`. Do not create a new branch.
  Do not merge to `main`. Do not merge
  `codex/unified-nominal-adts`.
- `raco test` green, including 94, 100–104, and new 105.
- Hand checks hold.
- `git diff --check` clean.
- Default driver still has no `fs-host` / `term` / `Disk` /
  `Location`.
- `lib/fs.aloe` unchanged. Host module unchanged in behavior.
  No `Item`. No `inspect`.
- Stop. Do not start `inspect` / `Item` / live classes.

## Explicit non-goals

- `Item`, `inspect`, `entries`, live `File` / `Directory` /
  `SymbolicLink` / `Other`.
- A `text` method on `Location`.
- Loading `lib/fs.aloe` from `lib/disk.aloe`.
- Rewriting or extending `lib/fs.aloe`.
- Source-written `FsHost` type names.
- Adding `lib/disk.aloe` or Option to `make-driver`.
- `(here entries)`, `enter`, `size`, `read`, `target`.
- Read/write bytes, cwd mutation API, recursive walk, Gel UI.
- `Result`, a second host, ambient `fs`.
- Redesigning injection, Term, or host path algebra.
- Merging to `main`.
- Checkpoint 106.
