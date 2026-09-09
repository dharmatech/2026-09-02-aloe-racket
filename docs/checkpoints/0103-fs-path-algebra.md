# Checkpoint 103 — Path and Fs path algebra

**Branch.** Continue on `experiment/filesystem`.

**Depends on.** Checkpoint 102 (production `make-fs-receiver`)

**Status.** Complete (reviewed 2026-09-08 on `experiment/filesystem`)

## Goal

Add the Aloe `Path` class and an `Fs` wrapper whose public path
messages are `current`, `path`, `child`, `parent`, and `name`.

The public receiver is `fs`, constructed as
`(define fs (Fs new fs-host))` after injecting `fs-host` and loading
the library. Host methods still take and return crossing values.
Aloe builds `Path` and `(Option Path)` from those strings.

Do not add `Entry`, `inspect`, or `entries`. Those are the next
checkpoint. Do not put host effects on `Path`. Do not add `fs-host`
to default drivers.

## Depends on

- Parent: `experiment/filesystem` after checkpoint 102.
- Locked public Aloe API: `docs/filesystem-vocabulary.md` §2 Path,
  §3 selectors `current` / `path` / `child` / `parent` / `name`.
- Host messages already locked in 101–102. Do not reimplement
  POSIX path rules in Aloe.
- `lib/option.aloe` (checkpoint 100). `parent` returns
  `(Option Path)`.
- Generic host-type retention (checkpoint 99): `T`/`H` is inferred
  from the injected receiver. Do not write `FsHost` as a source type.
- Law: `SPEC.md` (send, `fn`/`call`, `let`, `if`/`cond`, `load`,
  constructors, `case`, expected-type `None`).
- Not authority: Proposal A / `define-family`.

The implementer will not have the filesystem designer brief. Every
rule needed to implement this slice is in this document.

## Authority / starting point

Facts after checkpoint 102 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. `let` is
  `((fn (names ...) body) call exprs ...)`. No new special forms.
- `fs-host` is injected. Default drivers do not have it.
- Host `current` / `resolve` / `child` / `root?` / `parent` /
  `name` already exist on both the test double and production.
- Host `parent` of `"/"` returns `"/"`. Aloe `parent` must still
  return `None` at root by asking host `root?` first and **not**
  calling host `parent` when that is true.
- `lib/list.aloe` is bootstrapped. `lib/option.aloe` is not.
  `lib/fs.aloe` must `load` Option itself.
- Crossing remains `Int` / `Bool` / `String` / `(List String)`.
  `(List Entry)` is not a crossing type and is not needed here.

## Exact file scope

**May edit:**

- `lib/fs.aloe` (new)
- `tests/checkpoint-103.rkt` (new)
- `CHECKPOINTS.md` (append 103 only)
- `docs/handoff.md` (current-state / application pressures:
  `Path` and `Fs` path messages exist; `Entry` / `inspect` /
  `entries` do not)
- `docs/decisions.md` (short dated addendum: Aloe `Path` is a
  string-holding product; path algebra is `Fs` messages; parent
  at root is `None`)
- `docs/filesystem-vocabulary.md` status only if it still says
  Path / Fs are unimplemented. Do not change locked selectors.

**Do not edit:**

- `aloe/`
- `host/` (including `host/racket/fs.rkt`)
- `lib/option.aloe`, `lib/list.aloe`
- `bin/aloe`
- `SPEC.md`
- historical tests 100–102
- `examples/`, `gel/`, MPL
- no `Entry` class, no `inspect`, no `entries`
- no `directory?`, `exists?`, `Missing`, or Path host-effect
  methods

## Required behavior

### Library

`lib/fs.aloe` is Aloe source (no `#lang`). It begins by loading
Option as a sibling of this file, then defines `Path` and `Fs`.

```aloe
(load "option.aloe")

(define-class Path
  (fields
    (text String))
  (methods
    ))

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
      ((self host) name (path text)))))
```

Lock:

- `Path` has one field `text` of type `String` and no methods.
  Programs read `(path text)`. Path does not store `fs-host` and
  does not send to the host.
- `(Path new string)` exists because every `(fields ...)` class
  has `new`. It is **not** the public way to make a location.
  Public goldens obtain paths from `fs`.
- `Fs` is generic. Field name is `host`. `H` is inferred from
  `(Fs new fs-host)`. Do not annotate the field as `FsHost`.
- Public selectors and types are exactly:
  `(fs current)` → `Path`
  `(fs path string)` → `Path`
  `(fs child path name)` → `Path`
  `(fs parent path)` → `(Option Path)`
  `(fs name path)` → `String`
- `name` in `child` is one component. Multi-component strings
  fail at the host (`FsHost` / `child`), not via Aloe joining.
- `parent` of a root path is `(Option None)` with `T = Path`.
  Use the method return type so `(Option None)` typechecks.
  Do not call host `parent` when host `root?` is true.
- Do not add `inspect`, `entries`, `map`, `show`, `directory?`,
  or `exists?`.
- Do not add `Path` methods that wrap host sends.

Match `lib/option.aloe`: no narrative comments.

Tests load this file with Aloe `load` (same pattern as
checkpoint 100). Relative `(load "option.aloe")` inside
`lib/fs.aloe` must resolve next to that file. Do not add `fs`
or Option to `make-driver`.

### Construction and injection

```racket
(define state (make-driver))
(driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
(driver-eval! state `(load ,(path->string fs-library-path)))
(driver-eval! state '(define fs (Fs new fs-host)))
```

`nodes` may be a directory at `"/cwd"` plus whatever the path
tests need. Path algebra does not require planted children.

After that:

- `fs` typechecks as `(Fs FsHost)` (diagnostic name `FsHost`).
- `(fs current)` typechecks as `Path`.
- `(fs parent (fs path "/"))` typechecks as `(Option Path)`.
- `(define-class HostHolder (fields (value FsHost)) (methods))`
  is still a type error.

Production tests use `make-fs-receiver` instead of the double,
still `(define fs (Fs new fs-host))`.

## Tests and hand check

Add `tests/checkpoint-103.rkt`. Do not repeat 101–102 host
matrices.

Cover:

1. Fresh `make-driver`: no `fs-host`, no `term`, no `Fs`, no
   `Path`. `Option` still unbound. `List` still works.
2. Aloe `(load <lib/fs.aloe>)` then inject (or inject then load;
   both orders are legal as long as `Fs new` happens after both).
   `Option`, `Path`, and `Fs` become bound. `Some` / `None` stay
   unbound as top-level names.
3. **Double**, current `"/cwd"`:
   - `((fs current) text)` is `"/cwd"`.
   - `((fs path "/tmp/a/../b") text)` is `"/tmp/b"`.
   - `((fs path "x") text)` is `"/cwd/x"`.
   - `((fs child (fs path "/tmp") "a") text)` is `"/tmp/a"`.
   - `(fs name (fs path "/tmp/a"))` is `"a"`.
   - `(fs name (fs path "/"))` is `""`.
   - `((fs parent (fs path "/tmp/a")) present?)` is `#t`;
     unwrapping `Some` yields text `"/tmp"`.
   - `((fs parent (fs path "/")) present?)` is `#f`
     (None at root). Exhaustive `case` on that Option is
     required, not only `present?`.
   - `(fs child (fs current) "a/b")` is a host failure
     (`FsHost` / `child`).
4. Sending `inspect` or `entries` to `fs` is an unknown-message
   (or type) error in this slice. Sending `current` to a `Path`
   is unknown message.
5. **Production**, isolated temp directory (create, delete in
   `dynamic-wind` / `after`):
   - `parameterize` `current-directory` to that dir.
   - `((fs current) text)` equals the normalized absolute temp
     path.
   - `((fs path "a.txt") text)` equals
     `((fs child (fs current) "a.txt") text)` after creating
     `a.txt` (the file need only exist if you also want a
     later inspect; path algebra does not require it — creating
     it is fine).
   - `(fs parent (fs path "/"))` is still `None`.
6. Term on a different driver:
   `(term write-line "sealed")` still `"sealed"`.
7. Do not implement `Entry`.

### Hand check

```racket
(require racket/runtime-path
         "aloe/driver.rkt"
         "host/racket/fs.rkt")

(define-runtime-path fs-path "lib/fs.aloe")
(define state (make-driver))
(driver-inject-host!
 state 'fs-host (make-fs-double "/cwd" (hash "/cwd" 'directory)))
(driver-eval! state `(load ,(path->string fs-path)))
(driver-eval! state '(define fs (Fs new fs-host)))
(list (driver-eval! state '((fs current) text))
      (driver-eval! state '((fs path "x") text))
      (driver-eval! state '((fs parent (fs path "/")) present?)))
```

Expected: `'("/cwd" "/cwd/x" #f)`

Term check unchanged: `'("sealed" "sealed\r\n")`

## CHECKPOINTS.md and handoff

```text
## 103. [Path and Fs path algebra](docs/checkpoints/0103-fs-path-algebra.md)

- `lib/fs.aloe` defines `Path` and generic `Fs`. Public `current`,
  `path`, `child`, `parent`, and `name` wrap `fs-host`. Parent at
  root is `None`. No `Entry`, `inspect`, or `entries`.
```

`docs/handoff.md`: tests through 103. `Path` and `Fs` path
messages exist on `experiment/filesystem`. `Entry` / `inspect` /
`entries` still do not. Option still not bootstrapped.
Constructors not ready for `main`.

## Acceptance

- Still on `experiment/filesystem`.
- `raco test` green, including 94, 100–102, and new 103.
- Hand checks hold.
- `git diff --check` clean.
- Default driver still has no `fs-host` / `term` / `Fs`.
- Host module unchanged in behavior. No `Entry`.
- Stop. Do not start `inspect` / `entries`.

## Explicit non-goals

- `Entry`, `inspect`, `entries`, `directory?`, `exists?`,
  `Missing`.
- Host effects on `Path`. Path capturing `fs-host`.
- Source-written `FsHost` type names.
- Adding `lib/fs.aloe` or Option to `make-driver`.
- Read/write bytes, cwd mutation API, recursive walk, Gel UI.
- `(List Entry)` crossing, `Result`.
- Redesigning injection, Term, or host path algebra.
- Merging to `main`.
