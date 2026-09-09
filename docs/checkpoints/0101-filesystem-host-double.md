# Checkpoint 101 — filesystem host interface and test double

**Branch.** Continue on `experiment/filesystem` (created in
checkpoint 100 from `experiment/host-boundary`).

**Depends on.** Checkpoint 100 (loadable `lib/option.aloe`)

**Status.** Complete (reviewed 2026-09-08 on `experiment/filesystem`)

## Goal

Add a second optional host capability for read-only filesystem facts,
modeled on Term: one Racket module, one `host-interface`, crossing
values only, injected as `fs-host`.

This slice locks the host messages and ships a **test double** with
that exact interface identity and controlled state. Tests send
`String` / `Bool` / `(List String)` through `fs-host`.

Do not add Aloe `Path`, `Entry`, or `Fs`. Do not `stat` or
`directory-list` the real filesystem. Production POSIX I/O in
isolated temporary directories is the next checkpoint, using this
same interface.

## Depends on

- Parent: `experiment/filesystem` after checkpoint 100.
- Law: `SPEC.md` §14 (descriptor-driven hosts, crossing vocabulary,
  no ambient capability, no source-written host type names).
- Locked public Aloe API (do not implement it here):
  `docs/filesystem-vocabulary.md` §3. This checkpoint implements
  the **host** half of §4 / designer-brief §8.
- Pattern: `host/racket/term.rkt` (`term-interface`,
  `make-term-receiver`, injection as `term`).
- Crossing already includes `(List String)` (checkpoint 98).
- Generic wrappers can retain this interface later (checkpoint 99).
  Do not add `Fs` here.
- Not authority: Proposal A / `define-family`.

The implementer will not have the filesystem designer brief. Every
rule needed to implement this slice is in this document.

## Authority / starting point

Facts after checkpoint 100 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. `let` is
  `fn`/`call`. No inheritance, mutation, macros, or implicit
  `Int`/`Float` coercion. Do not invent special forms.
- Host capabilities are descriptor-defined, injected with
  `driver-inject-host!`, absent from default drivers.
- Crossing types are `Int`, `Bool`, `String`, and `(List String)`
  only. Nested lists and `(List Entry)` are not crossing types.
- Implementations live on the `host-interface`; receivers differ by
  opaque state. Term uses one interface and varies state (ports /
  readers). Filesystem must do the same: one `fs-interface` object,
  test-double state now, production state later.
- `Option` is loadable and not bootstrapped. This host slice does
  not need to load it.
- `fs-host` is not bound in existing tests except as a name that
  must stay unbound on a fresh driver (checkpoint 100). Keep that
  binding name.

## Exact file scope

**May edit:**

- `host/racket/fs.rkt` (new)
- `tests/checkpoint-101.rkt` (new)
- `CHECKPOINTS.md` (append 101 only)
- `docs/handoff.md` (current-state heading and bullets;
  application pressures: `fs-host` test double exists, production
  disk I/O and `Path` / `Entry` / `Fs` do not)
- `docs/decisions.md` (short dated addendum: second optional
  capability, test double first, parent-at-root returns the
  normalized root string)
- `docs/filesystem-vocabulary.md` **host-table status only**:
  change “Suggested host messages (names may tighten)” to locked
  names as in the table below; record parent-at-root. Do not change
  the public Aloe `fs` / `Path` / `Entry` API.
- `docs/host-boundary-extensions.md` (status only: a second
  capability has started; still no `lib/fs.aloe`)

**Do not edit:**

- `aloe/` (the boundary already admits this capability)
- `host/racket/term.rkt` and the Term runners
- `bin/aloe`
- `lib/option.aloe`, `lib/list.aloe`
- `SPEC.md`
- historical checkpoints 83–100, including
  `tests/checkpoint-100.rkt`
- `examples/`, `gel/`, MPL
- no `lib/fs.aloe`, no `Path` / `Entry` / `Fs`
- no `make-fs-receiver` production disk constructor yet

## Required behavior

### Module and identity

Create `host/racket/fs.rkt`, parallel to Term:

- Require `aloe/host.rkt`. Do not call Aloe eval from this module.
- Export `fs-interface` and `make-fs-double`.
- `fs-interface` is one `make-host-interface` value named `FsHost`
  (diagnostic only; not a source type).
- `make-fs-double` returns `(make-host-receiver fs-interface state)`
  for controlled state. Every double shares **that same**
  `fs-interface` object (`eq?`).
- Do not build a second interface in tests to stand in for this
  one. A locally rebuilt method list is a different nominal type.

Ordinary `bin/aloe` and `make-driver` must not inject this
capability. Tests inject it with:

```racket
(driver-inject-host! state 'fs-host (make-fs-double current nodes))
```

### Host methods

Declaration order and crossing types are locked:

| Selector | Parameters | Return | Meaning |
| --- | --- | --- | --- |
| `current` | none | `String` | absolute cwd from double state |
| `resolve` | `String` | `String` | absolutize against current, normalize |
| `child` | `String`, `String` | `String` | join **one** component, then normalize |
| `root?` | `String` | `Bool` | no parent after normalize |
| `parent` | `String` | `String` | parent after normalize |
| `name` | `String` | `String` | last component after normalize |
| `kind` | `String` | `String` | classify; do not follow symlinks |
| `names` | `String` | `(List String)` | immediate child names, no `.` or `..` |

Implementations take receiver state plus the declared positional
arguments (checkpoint 83A). They perform no manual Aloe crossing
checks.

Path arguments to every method except `current` are first resolved
the same way `resolve` resolves: relative strings are completed
against the double’s current directory, then normalized. Callers
may therefore pass `"a.txt"` and mean a child of current.

### Normalization (host-owned, POSIX/Linux)

Do not implement a Windows path layer. `/` is the separator.
`\` is an ordinary character in a component, not a separator.
Do not consult the real filesystem to normalize (`simplify-path`
must not stat or follow links).

Locked goldens, with double current `"/cwd"`:

| Send | Result |
| --- | --- |
| `(fs-host current)` | `"/cwd"` |
| `(fs-host resolve "/tmp/a/../b")` | `"/tmp/b"` |
| `(fs-host resolve "/tmp/a/")` | `"/tmp/a"` |
| `(fs-host resolve "/tmp//a")` | `"/tmp/a"` |
| `(fs-host resolve ".")` | `"/cwd"` |
| `(fs-host resolve "x")` | `"/cwd/x"` |
| `(fs-host resolve "/")` | `"/"` |
| `(fs-host child "/tmp" "a")` | `"/tmp/a"` |
| `(fs-host child "/tmp/" "a")` | `"/tmp/a"` |
| `(fs-host child "/tmp/a" "..")` | `"/tmp"` |
| `(fs-host child "/" "..")` | `"/"` |
| `(fs-host child "/" "a")` | `"/a"` |
| `(fs-host child "dir" "x")` | `"/cwd/dir/x"` |
| `(fs-host root? "/")` | `#t` |
| `(fs-host root? "/tmp")` | `#f` |
| `(fs-host root? "/tmp/..")` | `#t` |
| `(fs-host parent "/tmp/a")` | `"/tmp"` |
| `(fs-host parent "/tmp")` | `"/"` |
| `(fs-host parent "/")` | `"/"` |
| `(fs-host name "/tmp/a")` | `"a"` |
| `(fs-host name "/tmp")` | `"tmp"` |
| `(fs-host name "/")` | `""` |

**Parent at root.** Return the normalized root string `"/"` (POSIX
`dirname /`). Do not fail. Aloe will still not call `parent` when
`root?` is true; this slice still defines and tests the host fact.

**One-component `child`.** The second argument is a single
component. If it is `""` or contains `/`, the implementation must
raise a Racket error that becomes an Aloe host failure for `FsHost`
/`child`. `.` and `..` are allowed components (they normalize).

### Classification and listing (double state only)

`kind` and `names` consult only the double’s node table. They must
not `stat`, `link-exists?`, or `directory-list` the real disk.

Accepted constructor (positional is required; extra optional
keywords are allowed if tests still use this shape):

```racket
(make-fs-double
 "/cwd"
 (hash
  "/cwd" 'directory
  "/cwd/a.txt" 'file
  "/cwd/dir" 'directory
  "/cwd/link" 'symlink
  "/cwd/pipe" "fifo"))
```

Kind encoding:

- `'file` → `"file"`
- `'directory` → `"directory"`
- `'symlink` → `"symlink"`
- a string → that string unchanged (Other diagnostic)
- path absent from the table, after resolve → `"missing"`

`kind` never follows a symlink: a planted `'symlink` is `"symlink"`
even if another node looks like a target.

`names`:

- Allowed only when the resolved path is planted as `'directory`.
- Result is the list of immediate child **names** (not full paths)
  implied by other keys in the table. Example: keys `/cwd/a.txt`
  and `/cwd/dir` make `names` of `/cwd` be `"a.txt"` and `"dir"`.
- Omit `.` and `..` even if someone plants them.
- Order: `string<?` on the names, so the double is deterministic.
- Empty directory → empty `(List String)` (`len` 0).
- Missing path, file, symlink, or Other → host failure (`FsHost` /
  `names`), not `"missing"` and not an empty list.

Locked kind/names goldens on the table above:

| Send | Result |
| --- | --- |
| `(fs-host kind "/cwd")` | `"directory"` |
| `(fs-host kind "/cwd/a.txt")` | `"file"` |
| `(fs-host kind "dir")` | `"directory"` |
| `(fs-host kind "/cwd/link")` | `"symlink"` |
| `(fs-host kind "/cwd/pipe")` | `"fifo"` |
| `(fs-host kind "/cwd/nope")` | `"missing"` |
| `(fs-host names "/cwd")` | list of `"a.txt"`, `"dir"`, `"link"`, `"pipe"` in `string<?` order, `len` 4 |
| `(fs-host names "/cwd/dir")` | `len` 0 |
| `(fs-host names "/cwd/nope")` | host failure |
| `(fs-host names "/cwd/a.txt")` | host failure |
| `(fs-host names "/cwd/link")` | host failure |

Absence is the kind string `"missing"`. Permission and other I/O
errors are host failures. This double has no permission layer;
production will. Do not add `Result` as a crossing type.

### Injection, defaults, Term

- Fresh `make-driver`: `fs-host` and `term` unbound on both
  runtime and type environments.
- After injection, `(fs-host current)` typechecks as `String`,
  `(fs-host root? "/")` as `Bool`, `(fs-host names "/cwd")` as
  `(List String)`.
- Checker rejects `(fs-host current 1)` (arity) and
  `(fs-host kind 1)` (type).
- `FsHost` remains unlistable as a source type:
  `(fields (value FsHost))` is still a type error (same spirit as
  checkpoint 85 / 99 for `Term`).
- Term on a **different** driver, or on the same driver under the
  name `term` beside `fs-host`, still returns `"sealed"` from
  `(term write-line "sealed")`. Include one coexistence test:
  both injected, both answer.

Do not inject `fs-host` into the default driver used by `bin/aloe`.

## Tests and hand check

Add `tests/checkpoint-101.rkt`. Do not repeat 83–88 or 100.

Cover:

1. `(map host-method-selector (host-interface-methods fs-interface))`
   is `'(current resolve child root? parent name kind names)`.
2. Two doubles: `(eq? (host-receiver-interface a)
   (host-receiver-interface b))` is true, and both `eq?`
   `fs-interface`.
3. Fresh driver has no `fs-host` / `term`. List still works.
4. Inject the double from the kind/names table above as `fs-host`.
   Run the normalization table, parent-at-root, one-component
   `child` failures, and the kind/names table. `(List String)`
   results are ordinary Aloe lists (`len` / `first` / `rest`), not
   a delimiter `String`.
5. Host failure for `names` of a missing path identifies `FsHost`
   and `names` (`exn:fail:aloe-host?`). Same for `child` with
   `"a/b"` as the second argument (`FsHost` / `child`).
6. Coexistence: inject `term` and `fs-host` on one driver.
7. Term-only driver: `(term write-line "sealed")` still `"sealed"`.
8. Do not create files on disk. Do not load `lib/fs.aloe`.

### Hand check

```racket
(require "aloe/driver.rkt"
         "host/racket/fs.rkt"
         "host/racket/term.rkt")

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

(list (driver-eval! state '(fs-host current))
      (driver-eval! state '(fs-host parent "/"))
      (driver-eval! state '(fs-host kind "/cwd/link"))
      (driver-eval! state '((fs-host names "/cwd") len)))
```

Expected: `'("/cwd" "/" "symlink" 4)`

Term check unchanged:

```racket
'("sealed" "sealed\r\n")
```

## CHECKPOINTS.md and handoff

`CHECKPOINTS.md` compact entry:

```text
## 101. [Filesystem host interface and test double](docs/checkpoints/0101-filesystem-host-double.md)

- Optional `fs-host` capability with one `FsHost` interface and a
  test double. Crossing values only. Default drivers do not get it.
  No production disk I/O. No `Path` / `Entry` / `Fs`.
```

`docs/handoff.md`:

- Current-state heading should name `experiment/filesystem`, not
  still `experiment/host-boundary`.
- Tests through 101. `fs-host` can be injected as a test double.
  Production filesystem I/O, `Path`, `Entry`, and `Fs` still do
  not exist. Option remains loadable and not bootstrapped.
- Do not claim constructors are ready to merge to `main`.

`docs/decisions.md`: dated 2026-09-08 addendum. Second optional
host capability; test double before disk I/O; `parent` of root
returns `"/"`; `kind` of a missing path is `"missing"`; `names` of
a non-directory is a host failure.

## Acceptance

- Still on `experiment/filesystem`; do not branch off `main`.
- `raco test` green, including 88, 94, 98, 99, 100, and new 101.
- Hand checks above hold.
- `git diff --check` clean.
- Default driver still has no `fs-host` / `term`.
- No real-directory tests, no Aloe domain wrapper.
- Stop. Do not start production `make-fs-receiver` or `lib/fs.aloe`.

## Explicit non-goals

- Production `stat` / `directory-list` / temp-directory goldens
  (next checkpoint).
- `Path`, `Entry`, `Fs`, `lib/fs.aloe`, Gel UI.
- Following symlinks when classifying.
- Windows drives, backslash separators, cwd mutation as API,
  recursive walk, glob, bytes, mkdir, delete, `Result`.
- `(List Entry)` crossing, opaque directory handles.
- Adding Option or this host to `make-driver`.
- Source-written host type names.
- Redesigning injection, Term, or crossing validation.
- Merging to `main`.
