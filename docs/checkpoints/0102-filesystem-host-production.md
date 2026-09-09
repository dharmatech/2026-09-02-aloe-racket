# Checkpoint 102 — production filesystem host

**Branch.** Continue on `experiment/filesystem`.

**Depends on.** Checkpoint 101 (`FsHost` interface + test double)

**Status.** Complete (reviewed 2026-09-08 on `experiment/filesystem`)

## Goal

Add the production filesystem receiver on the **same** `fs-interface`
identity as the test double. It answers the locked host messages with
real POSIX/Linux facts. Tests that touch the disk use isolated
temporary directories.

Do not add Aloe `Path`, `Entry`, or `Fs`. Do not follow symbolic
links when classifying. Do not inject this capability into default
drivers or `bin/aloe`.

This finishes Phase B (injected filesystem host). Stop. Phase C
(`Path` / `Entry` / `Fs`) is a later checkpoint.

## Depends on

- Parent: `experiment/filesystem` after checkpoint 101.
- Law: `SPEC.md` §14. Host failures already wrap Racket `exn:fail?`
  and pass breaks through (checkpoint 84). Do not add `Result`.
- Locked messages and kind strings:
  `docs/filesystem-vocabulary.md` §4 as locked in 101.
- Pattern: Term’s one interface, two states (`host/racket/term.rkt`).
- Not authority: Proposal A / `define-family`.

The implementer will not have the filesystem designer brief. Every
rule needed to implement this slice is in this document.

## Authority / starting point

Facts after checkpoint 101 (do not redesign them):

- Evaluation is send. `(f x)` does not call `f`. `let` is
  `fn`/`call`. No new special forms.
- One `fs-interface` named `FsHost`. Implementations live on that
  interface. Receivers differ only by opaque state.
- `make-fs-double` already constructs a receiver on `fs-interface`.
  Production must `eq?` that same interface object. Do **not**
  call `make-host-interface` a second time.
- Path algebra is lexical POSIX (`/` separator, `\` ordinary,
  `..` / trailing slashes / empty segments). It must not stat or
  follow links. Keep that lexical normalizer for production; do
  not switch `resolve` / `child` / `parent` / `name` / `root?` to
  filesystem-respecting `simplify-path`.
- Double `kind` / `names` consult only the node table. Production
  adds a second state that consults the disk for those two
  messages and for `current`.
- Crossing remains `Int` / `Bool` / `String` / `(List String)`.
- `Option` is loadable and unused here.
- Default drivers still have no `fs-host` / `term`.

## Exact file scope

**May edit:**

- `host/racket/fs.rkt` (add production state and `make-fs-receiver`;
  keep `fs-interface` and `make-fs-double`)
- `tests/checkpoint-102.rkt` (new)
- `CHECKPOINTS.md` (append 102 only)
- `docs/handoff.md` (current-state / application pressures:
  production `fs-host` exists; `Path` / `Entry` / `Fs` do not)
- `docs/decisions.md` (short dated addendum: production receiver
  on the same `FsHost` identity; classify with
  `file-or-directory-type`; `names` sorts with `string<?`)
- `docs/host-boundary-extensions.md` (status: production filesystem
  receiver exists; still no `lib/fs.aloe`)
- `docs/filesystem-vocabulary.md` only if a status sentence still
  says the host is double-only. Do not change public Aloe API.

**Do not edit:**

- `aloe/`
- `host/racket/term.rkt` and Term runners
- `bin/aloe`
- `lib/`
- `SPEC.md`
- `tests/checkpoint-101.rkt` and other historical tests
- `examples/`, `gel/`, MPL
- no `lib/fs.aloe`, no `Path` / `Entry` / `Fs`

## Required behavior

### Same interface, second state

Export `make-fs-receiver` from `host/racket/fs.rkt` alongside
`fs-interface` and `make-fs-double`.

```racket
(define (make-fs-receiver)
  (make-host-receiver fs-interface production-state))
```

Zero arguments. Do not capture a cwd at construction. Tests inject:

```racket
(driver-inject-host! state 'fs-host (make-fs-receiver))
```

`(eq? (host-receiver-interface (make-fs-receiver)) fs-interface)`
and the same `eq?` against a double’s interface.

Extend the **existing** method implementations to branch on state.
Do not attach a second method list. Double behavior from 101 must
remain unchanged (`tests/checkpoint-101.rkt` stays green without
edits).

### `current` and relative `resolve`

On production state, `current` is the process working directory at
**send** time, as a normalized absolute POSIX string (no trailing
slash except root). Use Racket `current-directory`, complete it if
needed, then the same lexical normalizer as 101.

Relative `resolve` / `child` / `kind` / `names` / … complete
against that same live cwd, then normalize, same as the double
completes against its stored current.

Tests must not mutate the process cwd as a global. Use
`parameterize` on `current-directory` around the relevant
`driver-eval!` forms.

### Path algebra (no disk)

Production must still pass the **absolute** 101 goldens that do
not depend on the double’s `"/cwd"`:

```text
(fs-host resolve "/tmp/a/../b")     ; "/tmp/b"
(fs-host resolve "/tmp/a/")         ; "/tmp/a"
(fs-host resolve "/tmp//a")         ; "/tmp/a"
(fs-host resolve "/")               ; "/"
(fs-host child "/tmp" "a")          ; "/tmp/a"
(fs-host child "/tmp/" "a")         ; "/tmp/a"
(fs-host child "/tmp/a" "..")       ; "/tmp"
(fs-host child "/" "..")            ; "/"
(fs-host child "/" "a")             ; "/a"
(fs-host root? "/")                 ; #t
(fs-host root? "/tmp")              ; #f
(fs-host root? "/tmp/..")           ; #t
(fs-host parent "/tmp/a")           ; "/tmp"
(fs-host parent "/tmp")             ; "/"
(fs-host parent "/")                ; "/"
(fs-host name "/tmp/a")             ; "a"
(fs-host name "/tmp")               ; "tmp"
(fs-host name "/")                  ; ""
```

`child` of `""` or `"a/b"` is still a host failure (`FsHost` /
`child`). These paths need not exist on disk.

### Classification (disk, do not follow links)

Production `kind` after resolve:

| Disk fact | Result |
| --- | --- |
| does not exist | `"missing"` |
| regular file | `"file"` |
| directory (not a link) | `"directory"` |
| symbolic link | `"symlink"` |
| any other `file-or-directory-type` symbol | `symbol->string` of that symbol (`"fifo"`, `"socket"`, …) |

Lock the implementation to `file-or-directory-type` with
`must-exist?` `#f`. Do **not** classify with `file-exists?` or
`directory-exists?`; those follow links. A symlink to a directory
is `"symlink"`, not `"directory"`.

Absence is `"missing"`, not a host failure. Permission / I/O errors
raised by Racket become the existing Aloe host-failure wrap
(`exn:fail:aloe-host?`, interface `FsHost`, selector `kind`). Do
not add a portable unreadable-directory golden; it is
environment-dependent.

### Listing (disk)

Production `names`:

1. Resolve the path.
2. If `kind` is not `"directory"`, host failure (`FsHost` /
   `names`) — including missing, file, symlink-to-directory, and
   Other. Do not call `directory-list` on a symlink; Racket’s
   `directory-list` follows links.
3. Immediate children only. Omit `.` and `..` if they appear.
4. Return names, not full paths.
5. Sort with `string<?` (same deterministic order as the double).
6. Empty directory → `len` 0, not a failure.

### Isolated temporary directories

Every production test that creates files, directories, or links
must use a fresh temporary directory (`make-temporary-directory`
or equivalent) and delete it afterward (`delete-directory/files`
in `dynamic-wind` / `after`, including on failure).

Do not list, stat, or write inside the repository tree.

Minimum disk goldens in that temp directory:

1. Empty directory: `kind` `"directory"`, `names` `len` 0.
2. A regular file `a.txt`: `kind` `"file"`; `names` of the file
   fails; parent directory `names` includes `"a.txt"`.
3. A subdirectory `dir`: `kind` `"directory"`.
4. A symlink `link` whose target is `dir`: `kind` of `link` is
   `"symlink"`; `names` of `link` fails; `kind` of `dir` remains
   `"directory"`; `names` of `dir` still works.
5. A missing path under the temp dir: `kind` `"missing"`; `names`
   fails.
6. Mixed listing: the temp root contains at least two different
   kinds (file and directory is enough). `names` `len` matches
   the planted children (plus the symlink if present); each
   name’s `kind` matches. Use `child` of the temp path with each
   name rather than string concatenation in Aloe.
7. One non-ASCII file name (`"café"` or `"λ.txt"`) round-trips
   through `names` and `kind` `"file"`.
8. `current` under `parameterize` of `current-directory` to the
   temp dir equals the normalized absolute temp path.
   `(fs-host resolve "a.txt")` in that parameterization equals
   `(fs-host child current "a.txt")`.

POSIX/Linux only. No Windows drive or backslash-separator tests.

### Defaults, Term, double

- Fresh `make-driver`: no `fs-host`, no `term`.
- Double still works: one 102 test may inject `make-fs-double` only
  to show `eq?` of interfaces with production; do not duplicate 101.
- Term on a different driver: `(term write-line "sealed")` still
  `"sealed"`. Optional coexistence: `term` + production `fs-host`
  on one driver.
- Do not load `lib/option.aloe` unless a test truly needs it (it
  does not).

## Tests and hand check

Add `tests/checkpoint-102.rkt`. Do not repeat 101’s double matrix.

Cover the identity `eq?`, the absolute path-algebra table on a
production receiver, isolated temp-dir goldens above, default
driver isolation, and the Term sealed check.

### Hand check

From the repository root, in a throwaway temp directory you delete
afterward:

```racket
(require racket/file
         "aloe/driver.rkt"
         "host/racket/fs.rkt"
         "host/racket/term.rkt")

(define tmp (make-temporary-directory))
(display-to-file "hi" (build-path tmp "a.txt") #:exists 'truncate)
(make-directory (build-path tmp "dir"))
(make-file-or-directory-link "dir" (build-path tmp "link"))

(define state (make-driver))
(driver-inject-host! state 'fs-host (make-fs-receiver))
(define root (path->string tmp))

(define result
  (list (driver-eval! state `(fs-host kind ,root))
        (driver-eval! state `(fs-host kind ,(path->string (build-path tmp "a.txt"))))
        (driver-eval! state `(fs-host kind ,(path->string (build-path tmp "link"))))
        (driver-eval! state `((fs-host names ,root) len))))

(delete-directory/files tmp)
result
```

Expected: `'("directory" "file" "symlink" 3)`

Term check unchanged: `'("sealed" "sealed\r\n")`

## CHECKPOINTS.md and handoff

```text
## 102. [Production filesystem host](docs/checkpoints/0102-filesystem-host-production.md)

- Production `make-fs-receiver` shares the `FsHost` interface with
  the test double. Isolated temp-directory goldens. Default drivers
  still have no `fs-host`. No `Path` / `Entry` / `Fs`.
```

`docs/handoff.md`: tests through 102. Production `fs-host` can be
injected. `Path`, `Entry`, and `Fs` still do not exist. Option
still loadable, not bootstrapped. Constructors not ready for
`main`.

## Acceptance

- Still on `experiment/filesystem`.
- `raco test` green, including 101 and new 102.
- Hand checks hold.
- `git diff --check` clean.
- Default driver still has no `fs-host` / `term`.
- No Aloe domain wrapper. No cwd-mutation API.
- Stop. Do not start `lib/fs.aloe` or `Path` / `Entry` / `Fs`.

## Explicit non-goals

- `Path`, `Entry`, `Fs`, `lib/fs.aloe`, Gel UI.
- Following symlinks when classifying or listing.
- Windows path layer.
- Read/write bytes, copy, move, delete, mkdir, chmod, cwd
  mutation as an Aloe API, recursive walk, glob, watch, Git.
- `(List Entry)` crossing, `Result`, opaque directory handles.
- Adding this host or Option to `make-driver`.
- Source-written host type names.
- Redesigning injection, Term, or crossing validation.
- Merging to `main`.
