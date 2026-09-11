# gel-presentations 001 — Directory family

**Spoken name.** gel-presentations 001. Not “checkpoint 118”. Not
“gel 001”.

**Branch.** Continue on `experiment/2026-09-11-gel-presentations`
after green gel-presentations 000. Do not start from `main`. Do not
merge to `main`.

**Depends on.** gel-presentations 000 (List on `GelPresentations`).
Frozen Directory UX remains global 112–117.

**Status.** Blocked. Return to the spec conversation. Do not implement.

**Authority.** `docs/gel/presentations/spec.md` is this experiment’s
law. `SPEC.md` is Aloe language law. Frozen Directory UX is
`docs/gel-directory-surface.md` and global 112–117; do not reopen
it. Current `docs/gel.md` adapter language stays until 002.

The implementer receives only this document.

## Blocked (2026-09-11)

An implementer probe found `Signature.accepts?` **does** recognize a
live `Directory`. No `Mirror.class` hatch is required for the type
index. gel-presentations 000 remains green.

The spec’s required bodies do **not** typecheck. `directory-values` /
`directory-all-values` fail with `unknown message: names`. `up` fails
with `unknown message: root?`.

Cause: for a generic class without explicit constructors, the checker
revalidates the callee’s method body at each send
(`aloe/type.rkt` ~1189). `(directory entries)` and
`(directory parent)` therefore recheck `Directory.entries` /
`Directory.parent` / `Location.parent` under the presentation
method’s abstract `H`. Those bodies send host `names` and `root?`,
which exist only on a concrete host interface, not on a type
parameter. Today’s `gel-directory-values` on `Directory` skips that
path: generic `Directory` method bodies are not checked at
`define-methods` time; they are checked later at a send whose `H` is
the injected host.

List 000 escaped this because `List.map` does not send host messages.

The spec claimed `(directory-values (type H) (directory (Directory
H)) …)` binds `H` the same way `(Point +)` binds `T`. That is true
for `accepts?`. It is false for these disk sends.

Resolving it is a spec choice (checker change, or a different
presentation body / parameter shape). This conversation does not
pick one. Do not implement 001. Do not start 002.

## Goal

Move the Directory family onto the same substrate as List.
`define-methods GelPresentations` in `gel/directory.aloe` for
`Directory`, `File`, `SymbolicLink`, and `Other`. Delete every disk
`define-methods` in that file. Point `GelMenus`, `GelText.tos`, and
`GelUps` at `gel-presentations`. Drop specimen scans for
`"gel-directory-values"`, `"gel-directory-all-values"`, `"gel-up"`,
and `"gel-tos-text"`.

After Gel and `gel/directory.aloe` load, disk classes have only the
`lib/disk.aloe` vocabulary. List still has no `gel-values`. Global
112–117 runner behavior stays: paging, hidden names, `u`, labels,
TOS path bytes. That is the live-image bar (spec §2).

Stop and return this checkpoint for revision before writing any code
if the work starts to do any of:

- change paging, hidden names, item keys, or TOS path text
- edit `aloe/`, `lib/`, or `host/`
- add `Mirror.class` or any kernel hatch because `accepts?` looks
  impossible
- make `directory-values` take a `Bool` (that loses the arity-1
  probe)
- invent a presentation-type lattice, wrappers-as-TOS, or Listener
- apply spec §11 wording to `docs/gel.md` (that is 002)

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

Frozen UX (do not redesign):

- children as Values rows; nested live objects, not `Item`s
- labels `name`, `name/`, `name@`
- idle `.` hidden toggle; filter before the 22-row page window
- idle `n` / `p`; page reset on push / pop / `u` / `.`
- `u` pushes live parent; root `NoParent` no-op; Escape pops; `q`
  quits
- TOS path text for all four live classes; `(mirror raw)` of those
  objects stays the structural dump
- File / SymbolicLink / Other keep derived Messages menus
- List stays unpaged, first 22
- generic Gel without `gel/directory.aloe` keeps Point / List / Int
  bytes

TOS-text bytes stay checkpoint 113: class name plus escaped
`(object text)` via `(Mirror of string) raw`. No host, `Location`,
`Other.kind`, trailing slash, or `@` in TOS text.

`show-hidden` still chooses between two one-argument Directory
listings. Do not collapse them into one method that takes a `Bool`.

Absence is “no matching `accepts?`”: `GelUp Unavailable`,
`(mirror raw)` for TOS, `GelMenu Messages`.

## Chosen shape

One Gel-owned service. TOS remains `Mirror` of the specimen.
`GelStack.items` stays `(List Mirror)`. Do not add a presentation
field to `GelStep`. Helpers (`GelDirectoryListing`,
`GelDirectoryRows`, `GelMirrors`, `GelValueRows`) stay helpers.

`gel/presentations.aloe` stays the empty class plus
`gel-presentations`. Disk methods do **not** go there: that file
loads with generic Gel, before `Directory` exists.

`gel/directory.aloe` still assumes disk and generic Gel are already
loaded. It **must not** `define-methods` on `Directory`, `File`,
`SymbolicLink`, or `Other`. It **may** `define-methods
GelPresentations`.

### Methods to install

Public selectors are these names. Do not prefix `gel-`. Helpers on
`GelMenus` / `GelText` / `GelUps` may be shortened; these selectors
may not.

```aloe
(define-methods GelPresentations
  (methods
    (directory-values (type H)
      (directory (Directory H))
      GelValueRows
      ((GelDirectoryListing new (directory entries)) values #f))

    (directory-all-values (type H)
      (directory (Directory H))
      GelValueRows
      ((GelDirectoryListing new (directory entries)) values #t))

    (up (type H)
      (directory (Directory H))
      GelUp
      ((directory parent) case
        (None () (GelUp NoParent))
        (Some (parent)
          (GelUp Parent (Mirror of parent)))))

    (tos-text (type H)
      (directory (Directory H))
      String
      (("#<Directory " append ((Mirror of (directory text)) raw))
       append ">"))

    (tos-text (type H)
      (file (File H))
      String
      (("#<File " append ((Mirror of (file text)) raw)) append ">"))

    (tos-text (type H)
      (link (SymbolicLink H))
      String
      (("#<SymbolicLink " append ((Mirror of (link text)) raw))
       append ">"))

    (tos-text (type H)
      (thing (Other H))
      String
      (("#<Other " append ((Mirror of (thing text)) raw))
       append ">"))))
```

Those TOS-text bodies are today’s `gel-tos-text` with the typed
parameter in place of `self`. Listing and `up` bodies are today’s
Directory methods the same way.

Delete every `(define-methods Directory / File / SymbolicLink /
Other)` block from `gel/directory.aloe`. Keep
`GelDirectoryListing` / `GelDirectoryRows` and the Item-to-row
case analysis.

`list-values` stays where 000 put it. Do not move it.

### How lookup works

Reflect **`gel-presentations`**, never the TOS method table, for Gel
behavior. Copy 000’s List pattern: collect arity-1 signatures of
`(Mirror of gel-presentations)` whose selector name matches, keep
those for which `(signature accepts? mirror)` is true, invoke on the
service.

**`GelMenus.of(mirror, show-hidden, page)`**

1. Collect arity-1 `directory-all-values` or `directory-values`
   according to `show-hidden`.
2. If one accepts, invoke on `gel-presentations` with
   `(mirror subject)`, expected type `GelValueRows`. Window with
   today’s Directory page window. Return `GelMenu Values`.
3. Else today’s `list-values` path (000). Ignore `page`.
4. Else `(GelMenu Messages (gel-rows of mirror))`.

**`GelMenus.directory?(mirror)`** is “a `directory-values` signature
of `gel-presentations` accepts this mirror”, not a scan of the
specimen. Paging, hidden toggle, and `n` / `p` keep using this
predicate. Lists still do not page.

Today’s `directory-values` helper invokes on the **specimen**. Change
it to:

```text
((Mirror of gel-presentations) invoke signature (mirror subject))
```

Expected type `GelValueRows`. Same typed-helper rule as 000: do not
bind a reflective result to an unconstrained `let`. Do not revive a
generic on `(top subject)`.

**`GelText.tos`**

1. Collect arity-1 `tos-text` signatures of `gel-presentations`.
2. If one accepts the TOS mirror, invoke on the service with
   `(top subject)`, expected type `String`.
3. Else `(top raw)`.
4. Prefix `"TOS: "` as today.

Stop scanning the specimen for `"gel-tos-text"`. Drop the
`"gel-tos-text"` filter in `GelText.message-rows`: after this slice
that selector is not on disk types. Derived File menus still must
not show a Gel-private row, because none exists.

**`GelUps`**

1. `available?` / `of`: arity-1 `up` on `gel-presentations` that
   `accepts?` the mirror.
2. If none, `GelUp Unavailable` (no invoke).
3. If one, invoke with `(mirror subject)`, expected type `GelUp`.

Stop scanning the specimen for `"gel-up"`.

`GelStep.handle-up` stays the pusher. `u` still does not pop,
replace TOS, or change process cwd. Pending `u` stays a no-op.
Non-Directory TOS is `Unavailable`. Root is `NoParent`.

Idle precedence, command chrome, and page reset stay checkpoint
117.

Do not scan the specimen for `"gel-directory-values"` or
`"gel-directory-all-values"`. Do not send those messages to a
Directory. Do not parse `(mirror raw)`. Do not construct a
`Signature`. Do not redispatch by a computed selector.

If `accepts?` cannot recognize a Directory without a kernel hatch,
**stop and return this checkpoint**.

## Exact file scope

Implementation may edit only:

- `gel/directory.aloe` (install the methods above; delete disk
  `define-methods`)
- `gel/menu.aloe` (`GelMenus.of`, `directory?`, Directory invoke
  helper, `GelUps`)
- `gel/loop.aloe` (`GelText.tos` and the `message-rows` filter only)
- `tests/gel/presentations/001-directory-family.rkt` (new)
- `tests/gel/presentations/000-substrate-list.rkt`, **only** the
  Directory-hole case and the source assertions that require
  `define-methods Directory` / a specimen `"gel-directory-values"`
  seam. Keep the List proof.
- living global tests that send `gel-directory-values` /
  `gel-directory-all-values` / `gel-up` / `gel-tos-text` to disk
  objects, bind those signatures on the specimen, or assert
  `define-methods Directory` in `gel/directory.aloe`: checkpoints
  112, 113, 116, and 117. Point those seams at
  `(gel-presentations …)`. Keep UX byte expectations.

Do not edit `gel/presentations.aloe`, `gel/main.aloe`, or
`gel/stack.aloe`. Do not edit anything under `aloe/`, `lib/`, or
`host/`. Do not add `tests/checkpoint-118.rkt`. Do not write
`docs/checkpoints/0118-….md`. Do not append root `CHECKPOINTS.md`.
Do not apply spec §11 to `docs/gel.md`,
`docs/gel-directory-surface.md`, or `docs/handoff.md`.

Tests sit one directory deeper than the global suite. Use one extra
`../` in `require` and `define-runtime-path` (`../../../aloe/…`, not
`../aloe/…`).

## Tests and acceptance

Add `tests/gel/presentations/001-directory-family.rkt`. Cover at
least:

1. **Signatures did not grow.** Load `lib/disk.aloe`. Snapshot
   unique selector names from `(Mirror of specimen) messages` /
   `signatures` for a live `Directory`, `File`, `SymbolicLink`,
   `Other`, and a `List`. Load Gel, then `gel/directory.aloe`. The
   snapshots are **equal**. They contain no `gel-tos-text`,
   `gel-directory-values`, `gel-directory-all-values`, `gel-up`, or
   `gel-values`. Do not prove this by string-matching `"entries"` on
   the specimen.
2. **Selectors live on the service.** After generic Gel,
   `list-values` is arity-1 on `gel-presentations`. After
   `gel/directory.aloe`, `directory-values`,
   `directory-all-values`, `up`, and the four `tos-text` overloads
   are arity-1 there. `(signature accepts? directory-mirror)` is
   true for `directory-values` / `up` / Directory `tos-text` and
   false for a List, File, and Int. `list-values` still accepts a
   List and rejects a Directory. File `tos-text` accepts a File and
   rejects a Directory.
3. **Moved bodies.** `(gel-presentations directory-values dir)` and
   `directory-all-values` return the **full** filtered / unfiltered
   labeled lists (more than 22 when the fixture has more). `up` at
   root is `NoParent`; with a parent it carries a `Mirror` of that
   live Directory. `tos-text` matches checkpoint 113 for all four
   classes. Sending `gel-directory-values` / `gel-up` /
   `gel-tos-text` to a disk object is an error.
4. **Lookup without a specimen nametag.** `gel-menus directory?` is
   true for a Directory and false for a List after the disk methods
   are gone from the specimen. `gel-menus of` still windows
   Directory pages and leaves List unpaged. `gel-ups` is available
   only for Directory. `gel-text tos` uses path text for the four
   disk classes and `(top raw)` for List / Point / Int. File menus
   are derived Messages with no `gel-tos-text` row and no `n` /
   `p` / hidden commands.
5. **Frozen runner.** Controlled filesystem doubles, not repository
   contents. Re-prove the 112–117 scenarios at menus / keys / TOS
   text: labels, hidden filter before the window, 22-row pages,
   idle `n` / `p` and page reset, `u` / Escape / `q`, exact command
   bytes. Generic Gel without `gel/directory.aloe` still has Point /
   List / Int bytes and no `directory-values` on
   `gel-presentations`.
6. **Scope.** No `(define-methods Directory / File / SymbolicLink /
   Other)` in `gel/directory.aloe`. That file has
   `(define-methods GelPresentations)`. `gel/menu.aloe` has no
   specimen scan for `"gel-directory-values"`,
   `"gel-directory-all-values"`, or `"gel-up"`. `gel/loop.aloe` has
   no specimen scan for `"gel-tos-text"`. No changes under `aloe/`,
   `lib/`, or `host/`. gel-presentations 000 List tests and global
   110–113, 116, 117 plus the full suite remain green.

`000-substrate-list.rkt` must not keep asserting the Directory hole.
Replace that case so a live Directory has no `gel-directory-values`
and `gel-menus directory?` is still true. Leave the List snapshot
and `list-values` proof.

Run:

```sh
raco test tests/gel/presentations/001-directory-family.rkt
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
bytes still hold, and disk types no longer own Gel selectors. Stop
for review without committing and without starting gel-presentations
002.

## Explicit non-goals

- No change to paging, hidden names, item-key pool, or TOS path bytes
- No `Mirror.class`, kernel type classes, or `aloe/` / `host/` edit
- No wrapper-as-TOS, forwarding, inheritance, or presentation lattice
- No Listener, Inspector, Browser, command tables, or translators
- No `docs/gel.md` law rewrite (002)
- No global checkpoint 118
- No List `take` / `drop`, search, armed window, or GelFS
