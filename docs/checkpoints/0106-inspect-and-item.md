# Checkpoint 106 — inspect and live Item

**Branch.** Continue on `experiment/filesystem`.

**Depends on.** Checkpoint 105 (`Disk` and `Location` algebra)

**Status.** Complete (reviewed 2026-09-09 on `experiment/filesystem`)

## Goal

Add `Location.inspect` → `(Option Item)` and the nested live classes
`File` / `Directory` / `SymbolicLink` / `Other`. Each live object
carries a `location`, forwards `name` / `text` / `child` / `inspect`,
and answers live `parent` as `(Option Directory)`.

Do not add `Directory.entries`. Do not load or edit `lib/fs.aloe`.
Do not put `fs-host` on default drivers.

## Depends on

- Parent: `experiment/filesystem` after checkpoint 105.
- Locked public Aloe API: `docs/filesystem-oo-vocabulary.md` §3
  `Location.inspect`, `Item` and nested live classes, live `parent`;
  §4 public sends `inspect` / `(file location)` / live `parent`;
  §7 absence is `None`. Ignore `Directory.entries` and later sugar.
- Host `kind` already returns crossing strings (checkpoints 101–102).
  Duplicate the kind-string table in `Location.inspect`. Do not add
  `(List Item)` as a crossing type. Do not call thin `Fs`.
- `lib/disk.aloe` already defines generic `Disk` / `Location` path
  algebra (105). Keep those methods **byte-for-byte**.
- `lib/option.aloe` is loaded by `lib/disk.aloe`.
- `(define fs (Disk new fs-host))` already typechecks (105 / 99).
- Not authority: Proposal A / `define-family`.

The implementer will not have the OO designer brief. Every rule
needed to implement this slice is in this document.

## Authority / starting point

Facts after checkpoint 105 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. `let` is
  `fn`/`call`. `cond` is nested `if` with a required `else`.
- `lib/disk.aloe` defines generic `Location` (`name`, path `parent`,
  `child`) and generic `Disk` (`current`, `at`). `text` is a
  **field** on `Location`, not a method. Keep that.
- Path `parent` is `(Option (Location H))`, `None` at root, no disk
  look.
- Host `kind` of a missing path is `"missing"`. Classification does
  not follow symbolic links.
- String equality is `(s = other)`.
- Aloe has no forward declarations. `inspect` return types name
  `Item`. `Item` payloads name the live classes. Live `parent`
  return types name `Directory`. Live classes name `Location`.
  That forces the class order locked below: `Directory` before
  `File` / `SymbolicLink` / `Other`; `inspect` via
  `define-methods` after `Item`.
- `define-methods` may add instance methods after a class exists.
  It may not add constructors.
- Generic `(fields ...)` method bodies are checked at each send,
  not at definition.
- Default drivers still have no `fs-host` / `term`. Option, `Disk`,
  and `Location` are still not bootstrapped.
- Thin `lib/fs.aloe` is unchanged. `Entry` stays thin’s name; this
  library’s listing/inspect type is **`Item`**.

## Exact file scope

**May edit:**

- `lib/disk.aloe` (add live classes, `Item`, and `inspect`)
- `tests/checkpoint-106.rkt` (new)
- `tests/checkpoint-105.rkt` **only** as specified in
  “Living 105 tests” below
- `CHECKPOINTS.md` (append 106 only)
- `docs/handoff.md` (current-state / application pressures:
  `Disk`, `Location`, `inspect`, `Item`, and live classes exist;
  `Directory.entries` does not; thin `lib/fs.aloe` unchanged)
- `docs/decisions.md` (short dated addendum: inspect returns
  `(Option Item)` of nested live objects; live `parent` is
  `(Option Directory)` and does not follow symlinks; `text` stays
  a `Location` field)
- `docs/filesystem-oo-vocabulary.md` status only (`inspect` / `Item`
  / live classes now exist; `entries` still does not). Do not
  change locked selectors.

**Do not edit:**

- `aloe/`
- `host/` (including `host/racket/fs.rkt` and
  `host/racket/fs-repl.rkt`)
- `lib/fs.aloe`, `lib/option.aloe`, `lib/list.aloe`
- `bin/aloe`
- `SPEC.md`
- historical tests 100–104; 105 only as the living-test edit below
- `docs/checkpoints/0105-disk-and-location.md`
- `examples/`, `gel/`, MPL
- no `Directory.entries`, no `(here entries)`, no `enter`, no
  `size` / `read` / `target`, no `text` method on `Location`, no
  `Missing`, no `directory?` / `exists?` as the required API

## Required behavior

### Library

Replace `lib/disk.aloe` with this complete file. Do not add other
methods, comments, or `#lang`. Keep `Location` algebra and `Disk`
byte-for-byte from 105.

Aloe has no forward declarations, so two order constraints are
locked:

- Live `parent` is declared `(Option (Directory H))`. Define
  `Directory` **before** `File`, `SymbolicLink`, and `Other`.
  `Directory` may mention itself in that return type; the class
  is bound before its method types are checked. Case clauses
  named `File` in a `parent` body are constructor selectors, not
  type annotations, and are not checked at definition.
- `inspect` cannot live in the original `Location` / live-class
  method lists: those return types name `Item`, and `Item`
  payloads name the live classes. Path algebra and live `parent`
  do not name `Item`, so they stay on the classes. `inspect` is
  attached with `define-methods` after `Item`.

`Item` constructor order stays `File`, `Directory`,
`SymbolicLink`, `Other`. That is not class-definition order.

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

(define-class (Directory H)
  (fields
    (location (Location H)))
  (methods
    (name () String
      ((self location) name))

    (text () String
      ((self location) text))

    (child (name String) (Location H)
      ((self location) child name))

    (parent () (Option (Directory H))
      (((self location) parent) case
        (None () (Option None))
        (Some (here)
          ((here inspect) case
            (None () (Option None))
            (Some (item)
              (item case
                (File (file) (Option None))
                (Directory (dir) (Option Some dir))
                (SymbolicLink (link) (Option None))
                (Other (thing) (Option None))))))))))

(define-class (File H)
  (fields
    (location (Location H)))
  (methods
    (name () String
      ((self location) name))

    (text () String
      ((self location) text))

    (child (name String) (Location H)
      ((self location) child name))

    (parent () (Option (Directory H))
      (((self location) parent) case
        (None () (Option None))
        (Some (here)
          ((here inspect) case
            (None () (Option None))
            (Some (item)
              (item case
                (File (file) (Option None))
                (Directory (dir) (Option Some dir))
                (SymbolicLink (link) (Option None))
                (Other (thing) (Option None))))))))))

(define-class (SymbolicLink H)
  (fields
    (location (Location H)))
  (methods
    (name () String
      ((self location) name))

    (text () String
      ((self location) text))

    (child (name String) (Location H)
      ((self location) child name))

    (parent () (Option (Directory H))
      (((self location) parent) case
        (None () (Option None))
        (Some (here)
          ((here inspect) case
            (None () (Option None))
            (Some (item)
              (item case
                (File (file) (Option None))
                (Directory (dir) (Option Some dir))
                (SymbolicLink (link) (Option None))
                (Other (thing) (Option None))))))))))

(define-class (Other H)
  (fields
    (location (Location H))
    (kind String))
  (methods
    (name () String
      ((self location) name))

    (text () String
      ((self location) text))

    (child (name String) (Location H)
      ((self location) child name))

    (parent () (Option (Directory H))
      (((self location) parent) case
        (None () (Option None))
        (Some (here)
          ((here inspect) case
            (None () (Option None))
            (Some (item)
              (item case
                (File (file) (Option None))
                (Directory (dir) (Option Some dir))
                (SymbolicLink (link) (Option None))
                (Other (thing) (Option None))))))))))

(define-class (Item H)
  (constructors
    (File (fields (file (File H))))
    (Directory (fields (directory (Directory H))))
    (SymbolicLink (fields (link (SymbolicLink H))))
    (Other (fields (thing (Other H)))))
  (methods
    ))

(define-methods Location
  (methods
    (inspect () (Option (Item H))
      (let ((kind ((self host) kind (self text)))
            (resolved (Location new (self host) ((self host) resolve (self text)))))
        (cond
          ((kind = "missing") (Option None))
          ((kind = "file")
           (Option Some (Item File (File new resolved))))
          ((kind = "directory")
           (Option Some (Item Directory (Directory new resolved))))
          ((kind = "symlink")
           (Option Some (Item SymbolicLink (SymbolicLink new resolved))))
          (else
           (Option Some (Item Other (Other new resolved kind)))))))))

(define-methods File
  (methods
    (inspect () (Option (Item H))
      ((self location) inspect))))

(define-methods Directory
  (methods
    (inspect () (Option (Item H))
      ((self location) inspect))))

(define-methods SymbolicLink
  (methods
    (inspect () (Option (Item H))
      ((self location) inspect))))

(define-methods Other
  (methods
    (inspect () (Option (Item H))
      ((self location) inspect))))
```

Lock:

- Keep 105 path algebra unchanged. No `text` method on `Location`.
- Live classes are generic in `H`. Each has a `location` field of
  type `(Location H)`. They do not store a second `host` field;
  they reach the host through that location. `H` is still inferred
  from `fs-host` at `(Disk new fs-host)`.
- `Other` also stores `kind` as a **field** (`String`), the host
  diagnostic from inspect time. It is an immutable observation, not
  a fresh host `kind` send.
- Path questions on a live object forward to `(self location)`,
  except live `parent`. `text` on a live object is a forwarding
  **method**; that is not a `text` method on `Location`.
- `child` on a live object is still a path: a name under here, not
  a `cd`. The string might be missing or a file. Return type is
  `(Location H)`, never `Directory`.
- Live `parent` is **not** path algebra. It inspects the path
  parent and returns `(Option (Directory H))`:
  - `None` at root (path parent is already `None`);
  - `None` if that parent location is missing;
  - `None` if inspect is `File`, `SymbolicLink`, or `Other`;
  - `Some` only for constructor `Directory`.
  Do not follow symbolic links.
- Duplicate the four live `parent` bodies. No inheritance.
- Class **definition** order is `Location`, `Disk`, `Directory`,
  `File`, `SymbolicLink`, `Other`, `Item`, then `define-methods`
  `inspect`. `Directory` before `File` is required. Do not put
  `File` first. `Item` constructor order remains `File` first.
- `inspect` maps host `kind` strings on `Location` (same table as
  thin `Fs.inspect`, duplicated on purpose):
  `"missing"` → `None`
  `"file"` → `Item` constructor `File`
  `"directory"` → `Item` constructor `Directory`
  `"symlink"` → `Item` constructor `SymbolicLink`
  any other string → `Item` constructor `Other` with that string
- The live object’s location is `(Location new host (host resolve
  text))`, so `(file location)` text is absolute even if `self`
  was not. Round-trip goldens compare `text`, not object identity.
- `Item` constructors, in order: `File`, `Directory`,
  `SymbolicLink`, `Other`. No `Missing`. Empty methods. Payload
  field names: `file`, `directory`, `link`, `thing`.
- Constructor selectors match the nested classes (`File`, not thin
  `RegularFile`). Thin `Entry` is untouched.
- `Item` constructors are not top-level bindings in the thin
  sense: construction of an `Item` is `(Item File file)`. `File`
  **is** a class, so `(File new location)` exists; it is not the
  public way to classify a path. Public goldens obtain live
  objects from `inspect`.
- `inspect` on a live object forwards to `(self location)` so you
  can look again after the world changes.
- Do not add `entries`, `enter`, `size`, `read`, `target`,
  `directory?`, or `exists?`. Goldens use `case`.
- Do not `load` `lib/fs.aloe`.

Public types:

```text
(here inspect)          ; (Option (Item H)); None if missing
(file location)         ; (Location H)
(file name)             ; String
(file text)             ; String
(file child name)       ; (Location H)
(file inspect)          ; (Option (Item H))
(file parent)           ; (Option (Directory H))
(dir parent)            ; (Option (Directory H))
(thing kind)            ; String (Other field)
```

`(define fs (Disk new fs-host))` is unchanged.

### Construction and injection

Same as 105: inject `fs-host`, load `lib/disk.aloe`,
`(define fs (Disk new fs-host))`.

After that:

- `((fs current) inspect)` typechecks as `(Option (Item FsHost))`.
- Path parent is still `(Option (Location FsHost))`.
- Live parent typechecks as `(Option (Directory FsHost))`.
- `(define-class HostHolder (fields (value FsHost)) (methods))`
  is still a type error.

## Living 105 tests (required)

Checkpoint 105 required living assertions that `Item` was unbound
and that `inspect` on a `Location` was unknown. Those cannot both
hold once `lib/disk.aloe` defines them. Same pattern as checkpoint
104 updating living 103 tests.

**May edit `tests/checkpoint-105.rkt` as follows, and nothing else
in that file:**

1. After `(load lib/disk.aloe)`, stop asserting that `Item` is
   unbound. `Option` / `Location` / `Disk` stay bound; `Path` /
   `Fs` / `Entry` stay unbound; `Some` / `None` / `fs-host` /
   `term` stay unbound until injected. `Item`, `File`,
   `Directory`, `SymbolicLink`, and `Other` become bound.
2. In “Disk and Location expose only the checkpoint path
   vocabulary”, delete `inspect` from the `Location`
   unknown-message list. **Keep** `entries`, `current`, and `at`
   unknown on a `Location`, and **keep** `path` / `name` unknown
   on `Disk`.
3. In the coexistence test, stop asserting that `Item` is unbound.
   After loading both libraries, `Path`, `Fs`, `Entry`, `Disk`,
   `Location`, `Option`, and `Item` are bound. Keep
   `((thin current) text)` and `((fs current) text)` as `"/cwd"`.
4. **Keep** every 105 path-algebra golden, including relative
   `at`, root path `parent` `None`, and file-path `name`.
5. **Keep** `Item` unbound on a **fresh** `make-driver`. The
   library is still not bootstrapped.

Do not rewrite `docs/checkpoints/0105-disk-and-location.md`.

## Tests and hand check

Add `tests/checkpoint-106.rkt`. Do not repeat 105’s path-algebra
matrix except one Location parent-at-root regression.

Use this double table (104’s nodes plus live-parent edges):

```racket
(hash
 "/cwd" 'directory
 "/cwd/a.txt" 'file
 "/cwd/dir" 'directory
 "/cwd/link" 'symlink
 "/cwd/pipe" "fifo"
 "/linkdir" 'symlink
 "/linkdir/a.txt" 'file
 "/ghost/a.txt" 'file)
```

`/ghost` is deliberately absent so inspect of that parent is
`None`. `/linkdir` is a symlink, not a directory.

Cover:

1. Fresh `make-driver`: no `fs-host`, `term`, `Fs`, `Path`,
   `Entry`, `Disk`, `Location`, `Item`, `File`, `Directory`,
   `SymbolicLink`, `Other`, `Option`.
2. Load `lib/disk.aloe`, inject the double as `fs-host`,
   `(define fs (Disk new fs-host))`. Types:
   `((fs current) inspect)` is `(Option (Item FsHost))`;
   `((fs current) parent)` is still `(Option (Location FsHost))`.
3. **inspect** on the double:
   - missing path → `None` (`present?` `#f`, exhaustive `case`)
   - `a.txt` → `Some` `File`
   - `dir` → `Some` `Directory`
   - `link` → `Some` `SymbolicLink`
   - `pipe` → `Some` `Other` whose field `kind` is `"fifo"`
   - `cwd` → `Some` `Directory`
   Each `Some` live object’s `(obj location)` text is the resolved
   absolute path (e.g. `"/cwd/a.txt"`, not `"a.txt"`).
   `(fs at "a.txt")` inspect round-trips to that same absolute
   text via `(file location)`.
4. Exhaustive `case` over `Item` with four live clauses and no
   `else`. Incomplete `case` missing a constructor is a type
   error. Do not add a `directory?` golden.
   `(File (fs current))` is not valid `Item` construction
   (selector must be a symbol / not an `Item` send).
5. Forwarding: for the `a.txt` `File`, `(file name)` is `"a.txt"`,
   `(file text)` is `"/cwd/a.txt"`, `(file child "nope")` text is
   `"/cwd/a.txt/nope"`, and `(file inspect)` is `Some` `File`
   again.
6. **Live parent** on the double:
   - inspect `/` as `Directory`; `(dir parent)` is `None`
     (exhaustive `case`, not only `present?`).
   - inspect `/cwd/a.txt` as `File`; `(file parent)` is `Some` of
     a `Directory` whose location text is `"/cwd"`.
   - inspect `/linkdir/a.txt` as `File`; live `parent` is `None`
     (parent path is a symlink; do not follow).
   - inspect `/ghost/a.txt` as `File`; live `parent` is `None`
     (parent missing).
   - Location path `parent` of `/` is still `None`.
7. Sending `entries` to a live `Directory` is an unknown-message
   (or type) error in this slice. Sending `inspect` to `Disk` is
   unknown message.
8. **Both libraries** in one driver, same injected `fs-host`:
   load `lib/fs.aloe` and `lib/disk.aloe` (either order). `Entry`
   and `Item` are both bound. `(define thin (Fs new fs-host))` and
   `(define fs (Disk new fs-host))` both work. Case thin
   `(thin inspect (thin current))` as `Entry` and disk
   `((fs current) inspect)` as `Item` **separately**. Do not mix
   those wrappers’ `Option` values.
9. **Production**, isolated temp directory (create file, subdir,
   symlink-to-dir, missing name; delete afterward):
   - `inspect` of the file / dir / link / missing matches 3.
   - `(file location)` text equals `((fs at <file>) text)`.
   - live `parent` of the file is `Some` of a `Directory`.
   - live `parent` of inspect `/` is `None`.
   - `inspect` of a missing child is `None`.
   - Do not send `entries`.
10. Term on a different driver still returns `"sealed"` from
    `(term write-line "sealed")`.

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
   "/cwd/pipe" "fifo"
   "/linkdir" 'symlink
   "/linkdir/a.txt" 'file
   "/ghost/a.txt" 'file)))
(driver-eval! state `(load ,(path->string disk-path)))
(driver-eval! state '(define fs (Disk new fs-host)))
(list
 (driver-eval! state '(((fs at "/cwd/nope") inspect) present?))
 (driver-eval! state '(((fs at "/") parent) present?))
 (driver-eval!
  state
  '(((fs at "/cwd/a.txt") inspect) case
     (None () "none")
     (Some (item)
       (item case
         (File (file) (file name))
         (Directory (dir) "dir")
         (SymbolicLink (link) "link")
         (Other (thing) "other")))))
 (driver-eval!
  state
  '(((fs at "/cwd/pipe") inspect) case
     (None () "none")
     (Some (item)
       (item case
         (File (file) "file")
         (Directory (dir) "dir")
         (SymbolicLink (link) "link")
         (Other (thing) (thing kind))))))
 (driver-eval!
  state
  '(((fs at "/") inspect) case
     (None () "none")
     (Some (item)
       (item case
         (File (file) "file")
         (Directory (dir) ((dir parent) present?))
         (SymbolicLink (link) "link")
         (Other (thing) "other")))))
 (driver-eval!
  state
  '(((fs at "/cwd/a.txt") inspect) case
     (None () #f)
     (Some (item)
       (item case
         (File (file) ((file parent) present?))
         (Directory (dir) #f)
         (SymbolicLink (link) #f)
         (Other (thing) #f))))))
```

Expected: `'(#f #f "a.txt" "fifo" #f #t)`

Term check unchanged: `'("sealed" "sealed\r\n")`

## Accepted test corrections (review 2026-09-09)

Two defects in the original test spec, not implementer misses:

1. The double table omitted `"/"`. Host `kind` of an unplanted
   path is `"missing"`, so inspect of `/` is `None`, not
   `Directory`. Root live-parent goldens must plant
   `"/"` `'directory` (a root-specific table is enough; do not
   force `/` into every listing table).
2. The sample hand-check `case` for inspect `/` mixed `String`
   (`"none"` / `"file"` / …) with `Bool` (`present?`). Aloe `case`
   branches must share a type. The accepted tests use
   same-typed branches (`String` text `"none"` or `Bool`
   throughout).

Library shape, live `parent` rules, and non-goals are unchanged.

## CHECKPOINTS.md and handoff

```text
## 106. [inspect and live Item](docs/checkpoints/0106-inspect-and-item.md)

- `lib/disk.aloe` adds `Location.inspect` → `(Option Item)` and nested
  live `File` / `Directory` / `SymbolicLink` / `Other`. Live `parent`
  is `(Option Directory)` and does not follow symlinks. No
  `Directory.entries`.
```

`docs/handoff.md`: tests through 106. `Disk`, `Location`, `inspect`,
`Item`, and live classes exist on `experiment/filesystem`.
`Directory.entries` still does not. Thin `lib/fs.aloe` is unchanged.
Default drivers still have no `fs-host`. Constructors are not merged
to `main`.

## Acceptance

- Still on `experiment/filesystem`. Do not create a new branch.
  Do not merge to `main`. Do not merge
  `codex/unified-nominal-adts`.
- `raco test` green, including 94, 100–105 (after the living 105
  edit), and new 106.
- Hand checks hold.
- `git diff --check` clean.
- Default driver still has no `fs-host` / `term`.
- `lib/fs.aloe` unchanged. Host module unchanged in behavior.
  No `Directory.entries`. No `text` method on `Location`.
- Stop. Do not start `Directory.entries`.

## Explicit non-goals

- `Directory.entries`, `(here entries)`, `enter`.
- `size`, `read`, symlink `target`.
- A `text` method on `Location`.
- Loading `lib/fs.aloe` from `lib/disk.aloe`.
- Rewriting or extending `lib/fs.aloe`.
- `Missing`, `exists?`, `directory?` as the required API.
- `(List Item)` crossing, `Result`, a second host, ambient `fs`.
- Source-written host type names.
- Adding `lib/disk.aloe` or Option to `make-driver`.
- Read/write bytes, cwd mutation, recursive walk, Gel UI.
- Redesigning injection, Term, or host path algebra.
- Merging to `main`.
- Checkpoint 107.
