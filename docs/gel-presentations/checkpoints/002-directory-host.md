# gel-presentations 002 — Directory family on a host-holding class

**Spoken name.** gel-presentations 002. Not “checkpoint 118”. Not
“gel 002”. Not doc-law. Not a rewrite of 001.

**Branch.** Continue on `experiment/2026-09-11-gel-presentations`
after green gel-presentations 000. Do not start from `main`. Do not
merge to `main`.

**Depends on.** gel-presentations 000 (List on `GelPresentations`).
**001 stays blocked** (abstract `H` on `GelPresentations`). Do not
implement 001. Frozen Directory UX remains global 112–117.

**Status.** Complete (implemented; live-image bar holds in code).

**Authority.** `docs/gel-presentations/spec.md` §4.3 and §6.2 are
this slice’s law. `SPEC.md` is Aloe language law. Frozen Directory
UX is `docs/gel-directory-surface.md` and global 112–117. Current
`docs/gel.md` adapter language stays until a later doc-law slice.

The implementer receives only this document.

## Goal

Move the Directory family onto a **generic Gel class that holds
`fs-host`**, not onto `GelPresentations`. Construct it in
`gel/directory.aloe` with `fs-host`. Its methods take
`(Directory H)` / `(File H)` / `(SymbolicLink H)` / `(Other H)` and
send `entries` / `parent` / `text`. Delete every disk
`define-methods` in that file.

`GelMenus`, `GelText.tos`, and `GelUps` find that instance without
naming it in `gel/menu.aloe` or `gel/loop.aloe`. Drop specimen scans
for `"gel-directory-values"`, `"gel-directory-all-values"`,
`"gel-up"`, and `"gel-tos-text"`.

After Gel and `gel/directory.aloe` load, disk classes have only the
`lib/disk.aloe` vocabulary. List still has no `gel-values`. Global
112–117 runner behavior stays. That is the live-image bar (spec §2).

Stop and return this checkpoint for revision before writing any code
if the work starts to do any of:

- implement or rewrite 001
- write `(Directory FsHost)` (or any `FsHost` type name) in Aloe
- put Directory bodies on non-generic `GelPresentations` with
  `(type H)`
- edit `aloe/`, `lib/`, or `host/`
- mention `gel-directory-presentations` or
  `GelDirectoryPresentations` as a source symbol in `gel/menu.aloe`
  or `gel/loop.aloe`
- change paging, hidden names, item keys, or TOS path text
- make `directory-values` take a `Bool`
- apply spec §11 wording to `docs/gel.md` (doc-law is later)

## Required behavior

Live-image bar, all four items:

1. `lib/disk.aloe` and Gel load in the same process.
2. A live `Directory` can sit on the stack and be browsed (listing,
   hidden names, paging, `u`, child push, TOS path text).
3. After Gel then `gel/directory.aloe` load, `Directory`, `File`,
   `SymbolicLink`, and `Other` still have only the disk vocabulary.
   No `gel-tos-text`, `gel-directory-values`,
   `gel-directory-all-values`, or `gel-up` on those classes.
4. After Gel loads, `List` still has no `gel-values` (000; do not
   regress).

Frozen UX (do not redesign): children as Values rows; labels
`name`, `name/`, `name@`; idle `.` then filter then the 22-row
window; idle `n` / `p` and page reset on push / pop / `u` / `.`;
`u` pushes live parent; root `NoParent`; Escape pops; `q` quits;
TOS path text for all four live classes; `(mirror raw)` stays the
structural dump; File / SymbolicLink / Other keep derived Messages;
List stays unpaged, first 22; generic Gel without
`gel/directory.aloe` keeps Point / List / Int bytes.

TOS-text bytes stay checkpoint 113: class name plus escaped
`(object text)` via `(Mirror of string) raw`. No host, `Location`,
`Other.kind`, trailing slash, or `@` in TOS text.

`show-hidden` still chooses between two one-argument Directory
listings. Do not collapse them into one method that takes a `Bool`.

Absence is “no matching `accepts?`”: `GelUp Unavailable`,
`(mirror raw)` for TOS, `GelMenu Messages`. Ordinary Gel (no
directory module) has no Directory index, so every TOS takes the
List-or-Messages path from 000.

## Chosen shape

TOS remains `Mirror` of the specimen. `GelStack.items` stays
`(List Mirror)`. The host-holding object is never TOS. Do not add
a presentation field to `GelStep`. Do not store a pair.

List stays on non-generic `GelPresentations`. It does not hold a
host. Do not move `list-values`.

### Host-holding class (`gel/directory.aloe`)

`gel/directory.aloe` still assumes disk, generic Gel, and injected
`fs-host` are already present. It **must not** `define-methods` on
`Directory`, `File`, `SymbolicLink`, or `Other`. Keep
`GelDirectoryListing` / `GelDirectoryRows`.

The host field exists to pin `H`. Do not send `names` / `root?` to
it. Disk sends go to the specimen parameter.

```aloe
(define-class (GelDirectoryPresentations H)
  (fields
    (host H))
  (methods
    (directory-values
      (directory (Directory H))
      GelValueRows
      ((GelDirectoryListing new (directory entries)) values #f))

    (directory-all-values
      (directory (Directory H))
      GelValueRows
      ((GelDirectoryListing new (directory entries)) values #t))

    (up
      (directory (Directory H))
      GelUp
      ((directory parent) case
        (None () (GelUp NoParent))
        (Some (parent)
          (GelUp Parent (Mirror of parent)))))

    (tos-text
      (directory (Directory H))
      String
      (("#<Directory " append ((Mirror of (directory text)) raw))
       append ">"))

    (tos-text
      (file (File H))
      String
      (("#<File " append ((Mirror of (file text)) raw)) append ">"))

    (tos-text
      (link (SymbolicLink H))
      String
      (("#<SymbolicLink " append ((Mirror of (link text)) raw))
       append ">"))

    (tos-text
      (thing (Other H))
      String
      (("#<Other " append ((Mirror of (thing text)) raw))
       append ">"))))

(define gel-directory-presentations
  (GelDirectoryPresentations new fs-host))
```

Public selectors are those names. Do not prefix `gel-`. Do not
write `(Directory FsHost)`. Parameter types are `(Directory H)`
with `H` the **class** type parameter, pinned by constructing with
`fs-host`.

Because this class is generic and has no explicit constructors, the
bodies are not checked at definition. They are checked at a send
whose `H` is the injected host — the same delay that makes today’s
adapters on `Directory` typecheck, but the methods live on a Gel
class. Spec probe:
`tests/gel-presentations/probe-directory-fshost.rkt`.

Delete every `(define-methods Directory / File / SymbolicLink /
Other)` block.

### How `menu.aloe` finds it (no unbound name)

Ordinary Gel does not load `gel/directory.aloe`. `gel/menu.aloe`
and `gel/loop.aloe` must not mention `gel-directory-presentations`
or `GelDirectoryPresentations` as source symbols.

Install a zero-argument index onto `GelMenus` **from**
`gel/directory.aloe`:

```aloe
(define-methods GelMenus
  (methods
    (directory-presentations () Mirror
      (Mirror of gel-directory-presentations))))
```

`GelMenus`, `GelText`, and `GelUps` discover it by reflecting
`gel-menus` (or `self` when already `GelMenus`): collect arity-0
signatures whose selector name is `"directory-presentations"`; if
one exists, invoke it, expected type `Mirror`. That mirror is the
Directory-family service. If none, there is no Directory
personality.

Do not scan the specimen. Do not send
`(self directory-presentations)` from `menu.aloe` (unknown before
the directory module loads).

**`GelMenus.of(mirror, show-hidden, page)`**

1. If the index mirror exists, collect arity-1 signatures of
   **that** mirror named `directory-all-values` or
   `directory-values` according to `show-hidden`. If one
   `(signature accepts? mirror)`, invoke it on that mirror with
   `(mirror subject)`, expected type `GelValueRows`. Window with
   today’s Directory page window. Return `GelMenu Values`.
2. Else today’s `list-values` path on `gel-presentations` (000).
   Ignore `page`.
3. Else `(GelMenu Messages (gel-rows of mirror))`.

**`GelMenus.directory?(mirror)`** is “the index exists and a
`directory-values` signature of that mirror accepts this TOS”, not
a scan of the specimen. Paging, hidden toggle, and `n` / `p` keep
using this predicate. Lists still do not page.

Today’s Directory invoke helper sends to the **specimen**. Change
it to invoke on the **index mirror** with `(mirror subject)`.
Typed invoke helpers stay required: do not bind a reflective
result to an unconstrained `let`. Do not revive a generic on
`(top subject)`.

**`GelText.tos`**

1. If the index mirror exists, collect arity-1 `tos-text`
   signatures of that mirror.
2. If one accepts the TOS mirror, invoke on that mirror with
   `(top subject)`, expected type `String`.
3. Else `(top raw)`.
4. Prefix `"TOS: "` as today.

Stop scanning the specimen for `"gel-tos-text"`. Drop the
`"gel-tos-text"` filter in `GelText.message-rows`. Derived File
menus still must not show a Gel-private row, because none exists.

**`GelUps`**

1. If the index mirror exists, arity-1 `up` on that mirror that
   `accepts?` the TOS.
2. If none, `GelUp Unavailable` (no invoke).
3. If one, invoke with `(mirror subject)`, expected type `GelUp`.

Stop scanning the specimen for `"gel-up"`.

`GelStep.handle-up` stays the pusher. `u` still does not pop,
replace TOS, or change process cwd. Pending `u` stays a no-op.
Idle precedence, command chrome, and page reset stay checkpoint
117.

If `accepts?` cannot recognize a Directory on this host-holding
class, **stop and return**. Do not add `Mirror.class`. Do not
string-match `"entries"` on the specimen.

## Exact file scope

Implementation may edit only:

- `gel/directory.aloe` (the class above; construct with `fs-host`;
  `define-methods GelMenus` for the index; delete disk
  `define-methods`)
- `gel/menu.aloe` (`GelMenus.of`, `directory?`, Directory invoke
  via the index mirror, `GelUps`)
- `gel/loop.aloe` (`GelText.tos` and the `message-rows` filter
  only)
- `tests/gel-presentations/002-directory-host.rkt` (new)
- `tests/gel-presentations/000-substrate-list.rkt`, **only** the
  Directory-hole case and source assertions that require
  `define-methods Directory` / a specimen `"gel-directory-values"`
  seam. Keep the List proof.
- living global tests that send `gel-directory-values` /
  `gel-directory-all-values` / `gel-up` / `gel-tos-text` to disk
  objects, bind those signatures on the specimen, or assert
  `define-methods Directory` in `gel/directory.aloe`: checkpoints
  112, 113, 116, and 117. Point those seams at
  `gel-directory-presentations`. Keep UX byte expectations.
- `tests/gel-presentations/probe-directory-fshost.rkt` may be
  deleted once 002 covers the same measurements.

Do not edit `gel/presentations.aloe`, `gel/main.aloe`, or
`gel/stack.aloe`. Do not edit
`docs/gel-presentations/checkpoints/001-directory-family.md`. Do
not edit anything under `aloe/`, `lib/`, or `host/`. Do not add
`tests/checkpoint-118.rkt`. Do not write
`docs/checkpoints/0118-….md`. Do not append root `CHECKPOINTS.md`.
Do not apply spec §11 to `docs/gel.md`,
`docs/gel-directory-surface.md`, or `docs/handoff.md`.

Tests sit one directory deeper than the global suite. Use one extra
`../` in `require` and `define-runtime-path` (`../../aloe/…`, not
`../aloe/…`).

## Tests and acceptance

Add `tests/gel-presentations/002-directory-host.rkt`. Cover at
least:

1. **Signatures did not grow.** Load `lib/disk.aloe` with `fs-host`
   injected. Snapshot unique selector names from
   `(Mirror of specimen) messages` / `signatures` for a live
   `Directory`, `File`, `SymbolicLink`, `Other`, and a `List`. Load
   Gel, then `gel/directory.aloe`. The snapshots are **equal**.
   They contain no `gel-tos-text`, `gel-directory-values`,
   `gel-directory-all-values`, `gel-up`, or `gel-values`. Do not
   prove this by string-matching `"entries"` on the specimen.
2. **Selectors live on the host-holding instance.** After generic
   Gel, `list-values` is still arity-1 on `gel-presentations` and
   `gel-menus` has no `"directory-presentations"` index. After
   `gel/directory.aloe`, that index exists; `directory-values`,
   `directory-all-values`, `up`, and the four `tos-text` overloads
   are arity-1 on `gel-directory-presentations`.
   `(signature accepts? directory-mirror)` is true for
   `directory-values` / `up` / Directory `tos-text` and false for a
   List, File, and Int. `list-values` still accepts a List and
   rejects a Directory. File `tos-text` accepts a File and rejects
   a Directory.
3. **Moved bodies.** `(gel-directory-presentations directory-values
   dir)` and `directory-all-values` return the **full** filtered /
   unfiltered labeled lists (more than 22 when the fixture has
   more). `up` at root is `NoParent`; with a parent it carries a
   `Mirror` of that live Directory. `tos-text` matches checkpoint
   113 for all four classes. Sending `gel-directory-values` /
   `gel-up` / `gel-tos-text` to a disk object is an error.
4. **Lookup without a specimen nametag.** `gel-menus directory?` is
   true for a Directory and false for a List after the disk methods
   are gone from the specimen. `gel-menus of` still windows
   Directory pages and leaves List unpaged. `gel-ups` is available
   only for Directory. `gel-text tos` uses path text for the four
   disk classes and `(top raw)` for List / Point / Int. File menus
   are derived Messages with no `gel-tos-text` row and no `n` /
   `p` / hidden commands.
5. **Forbidden spellings do not typecheck.** Loading
   `define-methods GelPresentations` with `(type H)` /
   `(Directory H)` sending `entries` still fails `unknown message:
   names`. A method parameter `(Directory FsHost)` still fails
   `unbound symbol: FsHost`. (Fold the probe file into this case.)
6. **Frozen runner.** Controlled filesystem doubles, not repository
   contents. Re-prove the 112–117 scenarios at menus / keys / TOS
   text: labels, hidden filter before the window, 22-row pages,
   idle `n` / `p` and page reset, `u` / Escape / `q`, exact command
   bytes. Generic Gel without `gel/directory.aloe` still has Point /
   List / Int bytes.
7. **Scope.** No `(define-methods Directory / File / SymbolicLink /
   Other)` in `gel/directory.aloe`. `gel/menu.aloe` and
   `gel/loop.aloe` contain no source symbol
   `gel-directory-presentations`, `GelDirectoryPresentations`, or
   `FsHost`, and no specimen scan for `"gel-directory-values"`,
   `"gel-directory-all-values"`, `"gel-up"`, or `"gel-tos-text"`.
   No changes under `aloe/`, `lib/`, or `host/`. gel-presentations
   000 List tests and global 110–113, 116, 117 plus the full suite
   remain green.

`000-substrate-list.rkt` must not keep asserting the Directory hole.
Replace that case so a live Directory has no `gel-directory-values`
and `gel-menus directory?` is still true. Leave the List snapshot
and `list-values` proof.

Run:

```sh
raco test tests/gel-presentations/002-directory-host.rkt
raco test tests
git diff --check
```

Do **not** run `raco test tests/*.rkt`; that glob skips this folder.

When a physical TTY and `tui-term` are available, run:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

From a directory that still overflows after dots are hidden (`/etc`
or `/usr/bin`), confirm page one is 22 ordinary names, `n` / `p`
page, `.` toggles hidden, `u` pushes parent, and `q` leaves. List
applications must not page.

The checkpoint is complete when the live-image bar holds, 112–117
bytes still hold, disk types no longer own Gel selectors, and
Directory bodies live on the host-holding class. Stop for review
without committing and without starting doc-law.

## Explicit non-goals

- No rewrite or implementation of 001
- No `(Directory FsHost)` in Aloe
- No Directory methods on `GelPresentations`
- No `Mirror.class`, checker change, or `aloe/` / `host/` edit
- No change to paging, hidden names, item-key pool, or TOS path bytes
- No wrapper-as-TOS, forwarding, inheritance, or presentation lattice
- No Listener, Inspector, Browser, command tables, or translators
- No `docs/gel.md` law rewrite (doc-law is later)
- No global checkpoint 118
