# Gel presentations — TOS stays the specimen

**Status.** Issued series **done**. 000, 002, and 003 are implemented.
**001 stays blocked** and must not be implemented or rewritten. No
next local slice. Spec leftovers are later Gel-as-Genera work
(§13), not gel-presentations 004. Do not write global checkpoint
118.

Not Aloe language law. Directory bodies are §4.3 (the generic
`GelDirectoryPresentations` class holding `fs-host`), not 001 and
not a written `FsHost` type. Current Gel law is [`docs/gel.md`](../../gel.md).

**Branch.** `experiment/2026-09-11-gel-presentations` after green
gel-presentations 003. Do not start from `main`. Do not merge to
`main` from this conversation.

**Authority.** `SPEC.md` is language law. Directory UX (paging, hidden
names, listing, keys, TOS path bytes) is frozen by **predecessor**
global checkpoints 112–117 and
[`docs/gel-directory-surface.md`](../../gel-directory-surface.md). Those
are another project, not “the previous integers” of this series. Disk
messages remain [`docs/filesystem-oo-vocabulary.md`](../../filesystem-oo-vocabulary.md).
Current Gel behavior is [`docs/gel.md`](../../gel.md); 003 applied the
doc amendments.

Originating charter: [`docs/gel/presentations/charter.md`](charter.md).
The checkpoint manager will not have that charter. Every rule needed
to implement is here, including where slice files live (§9).

---

## 1. Job

A live `Directory` on Gel's stack stays a `Directory`. Gel still
browses it. After Gel is loaded, disk classes still only answer disk.

Today Gel installs `gel-tos-text`, `gel-directory-values`,
`gel-directory-all-values`, and `gel-up` on disk types, and
`gel-values` on `List`. `GelMenus` / `GelText` / `u` find them by
string-matching those selector names on the specimen's `Mirror`. That
is monkey-patching. It does not survive a process that has loaded
disk, Gel, MPL, a process browser, and a workspace together.

This experiment moves that equipment onto **Gel-owned presentation
methods, indexed by Aloe type**. The specimen is an argument to a Gel
method, not the owner of a Gel method. Reflection of a `Directory`
shows the disk vocabulary from `lib/disk.aloe`. Reflection of a `List`
shows the list library vocabulary from `lib/list.aloe`.

It is not a CLIM clone, not a presentation-type lattice, not command
tables, not translators, not Listener, and not a second product.

---

## 2. Live-image bar (acceptance)

The implementation is wrong unless all of these are true:

1. `lib/disk.aloe` and Gel can load in the same process.
2. A live `Directory` can sit on the stack and be browsed (listing,
   hidden names, paging, `u`, child push, TOS path text).
3. After Gel is loaded, `Directory`, `File`, `SymbolicLink`, and
   `Other` still have only the disk vocabulary from `lib/disk.aloe`.
   No `gel-tos-text`, `gel-directory-values`, `gel-directory-all-values`,
   or `gel-up` on those classes.
4. After Gel is loaded, `List` still has only the list library
   vocabulary for this concern. No `gel-values` on `List`.

The observable directory browser does not shrink. Checkpoints 112–117
behavior stays: children as the menu, 22-row page, idle `n` / `p`,
`.` hidden toggle, `u` parent, Escape pop, `q` quit, filesystem TOS
text, labels `/` and `@`. Paging is **frozen**: this experiment moves
where those behaviors live, it does not redesign them.

List is on the same substrate, not a named hole. The live-image rule
is not done until both disk types and `List` are off Gel's method
tables.

---

## 3. Locked (do not reopen)

1. **TOS subject is the specimen.** A `Directory` on the stack is a
   `Directory`, via `Mirror`. Not a `GelDirectory` wrapper. Not a
   `FileSystemBrowser` session object.
2. **Equipment lives in Gel.** Directory and File must not know about
   Gel. Gel's filesystem module should know about Directory and File.
3. **Presentations, not patches.** Gel associates a presentation with
   an object by Aloe type. Commands and TOS text come from that
   presentation.
4. **No inheritance.** Do not add forwarding or a wrapper-as-TOS.
5. **No kernel type classes.** No generic-function dispatch, no
   protocol-owned method table. If a dictionary is needed, it is a
   Gel object. Aloe protocols remain extra types (`SPEC.md` §3.3).
6. **Do not monkey-patch disk types or `List` for Gel.**
7. **This work stays named Gel.** Presentations are internal
   equipment. **Listener** remains reserved in `docs/gel.md` for a
   Genera-style typed REPL. Do not rename Gel, do not implement
   Listener, do not start a sibling codebase.
8. **Browser-as-TOS is filed away.**
9. **C# extension-method sugar is this design**, not a separate one:
   methods on a Gel class that take a `Directory`. They are invisible
   to `Mirror` of the specimen.
10. **Paging / hidden / listing / keys / TOS path bytes are frozen**
    at checkpoints 112–117.

---

## 4. Type recognition (the whole experiment)

GelStack stores `(List Mirror)`. The static element type is gone by
the time `GelMenus`, `GelText`, and `u` run. Gel must answer “is this
TOS a `Directory`?” without sending a Gel question to that object.

### 4.1 Options considered

| Option | Verdict |
|---|---|
| String-match a disk selector such as `entries` on the specimen | **Reject.** Same smell as today's `gel-` nametag. Two libraries can both have `entries`. |
| Parse `(mirror raw)` for `#<Directory` | **Reject.** Printer text is not a type. |
| Kernel `(mirror class)` / class identity hatch | **Not needed.** Existing `Signature.accepts?` already tests a mirror's subject against a parameter type. Do not edit `aloe/` or `host/`. |
| Typed `case` on `(mirror subject)` | **Impossible here.** `case` needs a known algebraic type. `subject` without an expected type is a fresh variable; with the wrong expected type it is a runtime error, not a probe. |
| Construct a presentation once at push and store a pair / `GelStep` field | **Larger than lookup.** Allowed by the charter, but every push, pop, and `u` would have to rebuild it, and the stack would stop being `(List Mirror)`. |
| Gel-owned one-argument methods whose parameter type is the specimen class; probe with `Signature.accepts?` | **Pick.** |

### 4.2 Chosen mechanism

Aloe already exposes a runtime type test:

```text
(signature accepts? mirror)
```

It is true when the signature has exactly one parameter and that
parameter accepts the mirror's subject under the same relation
`Mirror.invoke` uses (`SPEC.md` §7.4). Gel already uses this to
filter pending stack picks (`GelRow.accepts?`).

So: **put a one-argument method on a Gel class** whose parameter is
`(Directory H)`, `(File H)`, `(List T)`, and so on. Reflect **that
Gel object**, not the specimen. The matching signature is the type
index.

```text
((Mirror of gel-presentations) signatures)
  → rows named directory-values, list-values, tos-text, up, …
(signature accepts? tos-mirror)
  → this TOS is a Directory / File / List / …
((Mirror of gel-presentations) invoke signature (tos-mirror subject))
  → run the presentation, specimen as argument
```

The specimen's method table is never consulted for Gel selector
names.

`accepts?` is arity one. That is why the presentation operations that
need a type probe are one-argument methods taking the specimen.
`show-hidden` continues to choose between two one-argument Directory
listings (`directory-values` vs `directory-all-values`), as
checkpoints 116–117 already split those selectors. Do not make
`directory-values` take a `Bool` if that would lose the probe.

**The probe is not the body.** `(signature accepts? mirror)` against
a method whose parameter is `(Directory H)` does bind like
`(Point +)` in today's pick filter. gel-presentations 000 and an
implementer probe on 001 proved that. No `Mirror.class`. No `aloe/`
change for type recognition. List 000 is green because `list-values`
only sends `List.map`, which does not talk to a host.

**Disk sends are a different fact.** A Gel method whose parameter is
`(Directory H)` cannot send `(directory entries)` or
`(directory parent)`. For a generic `(fields …)` class, the checker
revalidates the callee’s body at each send (`aloe/type.rkt`,
`infer-instance-send`). Those bodies send host `names` and `root?`,
which exist only on a concrete host interface, not on a type
parameter. An implementer probe of 001 failed with
`unknown message: names` and `unknown message: root?`.

That is why today's adapters live on `Directory`: generic `Directory`
method bodies are **not** checked at `define-methods` time; they are
checked later at a send whose `H` is the injected host. Moving the
same body onto non-generic `GelPresentations` checks it immediately
with abstract `H`. The spec’s original “generic `H` works like
`(Point +)`” sentence was true for the probe and false for these
sends. It is withdrawn.

Do not edit `aloe/` to make abstract `H` accept host messages. That
would be a sibling language project, not this experiment. Type
recognition was never blocked. Default remains: solve the body in
Gel with existing types.

### 4.3 Chosen body shape (Directory family)

Measured in `tests/gel/presentations/probe-directory-fshost.rkt`
(not a slice):

| Body | Result |
|---|---|
| `define-methods GelPresentations` with `(type H)` / `(Directory H)` sending `entries` | `unknown message: names` |
| The same methods with parameter `(Directory FsHost)` | `unbound symbol: FsHost` — injection binds `fs-host`, not the type name (checkpoint 101) |
| Generic Gel class with a host field, constructed with `fs-host`, methods taking `(Directory H)` / `(File H)` | Typechecks and runs `directory-values`, `up`, `tos-text`; `accepts?` still distinguishes Directory from File and Int |

The earlier “write `(Directory FsHost)`” pick is **withdrawn**. Aloe
source cannot name `FsHost`.

**Pick:** a Gel-owned generic class (name in §6; probe used
`GelDirectoryOps`) that **holds the host**, never the specimen, and
is never TOS. Construct it in `gel/directory.aloe` with `fs-host`.
Its methods take `(Directory H)` and send `entries` / `parent` /
`text`. Because the class is generic and has no explicit
constructors, those bodies are not checked at definition; they are
checked at a send whose `H` is the injected host — the same delay
that makes today’s adapters on `Directory` typecheck, but the
methods live on a Gel class.

List stays on non-generic `GelPresentations`. It does not hold a
host.

Rejected for this experiment:

| Shape | Why not |
|---|---|
| Keep `gel-*` methods on `Directory` | Fails the live-image bar |
| Checker change so abstract `H` can send `names` / `root?` | Language project; type recognition did not need it |
| Write `(Directory FsHost)` in Aloe | `FsHost` is not a bound type name |
| Methods on non-generic `GelPresentations` with `(type H)` | 001’s failure; checked immediately with abstract `H` |
| Generic holder of a `Directory` as `Mirror.invoke` result | Checkpoint 113’s generic-result hole |
| String-match specimen selector `entries` | Already rejected in §4.1 |

001’s written bodies used abstract `H` on `GelPresentations`. That
file stays **blocked history**. Do not implement it. Do not rewrite
it. The next issued Directory-family slice (only when the human
asks) must use this host-holding generic Gel class.

---

## 5. Stack representation

**TOS remains `Mirror` of the specimen.** `GelStack.items` stays
`(List Mirror)`. Gel looks up a presentation **beside** that mirror
on each menu, TOS line, and `u`.

Do not store a pair. Do not stuff a presentation into the mirror. Do
not add a presentation field to `GelStep`. `GelStep.show-hidden` and
`GelStep.page` already hold listener state; they stay there.

The subject the user is standing on is the disk object. A
presentation is never TOS. Holding a `Directory` as a field of a
presentation object is therefore legal, but this spec does not do it:
the smaller spelling is methods on a Gel service that take the
specimen as an argument (charter locked item 9).

---

## 6. Presentation shape

One Gel-owned service, `GelPresentations`, bound as
`gel-presentations`. Personality is **overloading on that class**:
methods that take `Directory`, `File`, `SymbolicLink`, `Other`, or
`List`. Not a family of wrapper instances. Not a protocol with
missing pieces. Not a type lattice.

Existing row builders (`GelDirectoryListing`, `GelDirectoryRows`,
`GelMirrors`, `GelValueRows`) stay as helpers. They are not the
index.

### 6.1 Module and load order

```text
gel/presentations.aloe   GelPresentations, gel-presentations
                         (List personality; loaded by gel/menu.aloe)
gel/menu.aloe            GelRow, GelMenu, GelMenus, GelUp, GelUps,
                         item keys; loads presentations.aloe
gel/directory.aloe       filesystem personality: generic host-holding
                         Gel class constructed with fs-host, plus
                         listing helpers. Must not define-methods
                         disk types.
gel/loop.aloe            GelText, GelStep; asks Gel-owned presentation
                         objects instead of scanning the specimen
```

Ordinary Gel (`gel/main.aloe` → `loop` → `stack` → `menu` →
`presentations`) always has the service and the List personality.
The directory application keeps:

```aloe
(load "../lib/disk.aloe")
(load "../gel/directory.aloe")
```

`gel/directory.aloe` still assumes disk, generic Gel, and injected
`fs-host` are already present. It **must not** `define-methods` on
`Directory`, `File`, `SymbolicLink`, or `Other`. It defines and
constructs the host-holding generic Gel class (§4.3). Ordinary Gel
does not load this file, so `menu.aloe` must not mention that
binding as a source symbol. `GelMenus` / `GelText` / `GelUps` find
it without an unbound name (for example by an optional
zero-argument index installed onto `GelMenus` from
`gel/directory.aloe`, then discovered via `Mirror` of `self`). Do
not scan the specimen.

`lib/disk.aloe` and `lib/list.aloe` gain no Gel methods. `lib/` is
not in the edit set for this experiment.

### 6.2 `GelPresentations` methods

Names below are the spec's names. An implementer may shorten helpers,
not the public selectors, without a spec revision.

**Always present** (defined in `gel/presentations.aloe`, List
personality in the same file or in `gel/menu.aloe` via
`define-methods GelPresentations`):

```aloe
(list-values (type T)
  (items (List T))
  GelListValues
  …)    ; today's List.gel-values body, moved
```

**Filesystem personality** (generic Gel class in `gel/directory.aloe`,
§4.3). The host field exists to pin `H`; it is not TOS. Probe name
`GelDirectoryOps` is fine to keep or rename.

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

    (tos-text (directory (Directory H)) String …)
    (tos-text (file (File H)) String …)
    (tos-text (link (SymbolicLink H)) String …)
    (tos-text (thing (Other H)) String …)))

(define gel-directory-presentations
  (GelDirectoryPresentations new fs-host))
```

TOS-text bodies stay the checkpoint-113 bytes: class name plus
escaped `(object text)` via `(Mirror of string) raw`. No host,
`Location`, `Other.kind`, trailing slash, or `@` in TOS text. Child
row labels remain `name/`, `name@`, `name` as in 112.

`GelDirectoryListing` keeps hidden-name filtering and labels. It
already takes `(List (Item H))` and a `Bool`; it does not need to
live on `Directory`.

Do **not** prefix these selectors `gel-`. The `gel-` prefix was a
nametag on someone else's class. On `GelPresentations` they are
ordinary methods.

### 6.3 Optional operations

Different overloads, not one protocol with holes.

| Specimen | `tos-text` | authored values | `up` | menu |
|---|---|---|---|---|
| `Directory` | yes | `directory-values` / `directory-all-values` | yes | Values, paged |
| `File` / `SymbolicLink` / `Other` | yes | no | no | derived Messages |
| `List` | no (keep `raw`) | `list-values` | no | Values, unpaged, first 22 |
| anything else | no | no | no | derived Messages |

Absence is “no matching `accepts?`”, which is `GelUp Unavailable`,
`(mirror raw)` for TOS, and `GelMenu Messages`.

### 6.4 How `GelMenus`, `GelText`, and `u` find a presentation

They reflect **Gel-owned presentation objects**, never the TOS method
table, for Gel behavior. List lives on `gel-presentations`. Directory
lives on `gel-directory-presentations`, found through the
`directory-presentations` index, not through `gel-presentations`.

Ordinary Gel does not load `gel/directory.aloe`, so `gel/menu.aloe` and
`gel/loop.aloe` cannot name the optional instance. `gel/directory.aloe`
installs an arity-zero `directory-presentations` method on `GelMenus`.
The generic Gel code reflects `gel-menus` (or `self` when already in
`GelMenus`), selects that exact arity-zero signature, and invokes it
with expected type `Mirror`. The returned mirror owns the Directory
family methods. If the index is absent, there is no Directory
personality.

**`GelMenus.of(mirror, show-hidden, page)`**

1. If the Directory index exists, collect arity-1 signatures of its
   returned mirror whose selector is `directory-all-values` or
   `directory-values` according to `show-hidden`.
2. If one `(signature accepts? mirror)`, invoke it on that Directory
   presentation mirror with `(mirror subject)`, expected type
   `GelValueRows`. Window the full listing with today's Directory page
   window. Return `GelMenu Values`.
3. Else collect arity-1 `list-values` signatures from
   `gel-presentations`. If one accepts, invoke it there,
   build at most 22 `GelValueRow`s from `GelListValues` as today,
   ignore `page`. Return `GelMenu Values`.
4. Else `GelMenu Messages (gel-rows of mirror)`.

**`GelMenus.directory?(mirror)`** is “the Directory index exists and a
`directory-values` signature of its returned mirror accepts this
mirror”, not a scan of the specimen. Paging, hidden toggle, and `n` /
`p` keep using this predicate. Lists still do not page.

**`GelText.tos`**

1. If the Directory index exists, collect arity-1 `tos-text`
   signatures of its returned mirror.
2. If one accepts the TOS mirror, invoke it on that mirror with
   `(top subject)`, expected type `String`.
3. Else `(top raw)`.
4. Prefix `"TOS: "` as today.

Stop scanning the specimen for `"gel-tos-text"`. Stop hiding
`"gel-tos-text"` from derived menus by name: after this experiment
that selector is not on disk types. `GelText.message-rows` may drop
that filter. Derived File menus still must not show a Gel-private
row, because none exists.

**`GelUps`**

1. `available?` / `of`: if the Directory index exists, find an
   arity-1 `up` on its returned mirror that `accepts?` the TOS mirror.
2. If none, `GelUp Unavailable` (no invoke).
3. If one, invoke with `(mirror subject)`, expected type `GelUp`.

Stop scanning the specimen for `"gel-up"`.

Typed invoke helpers stay required: do not bind a reflective result
to an unconstrained `let`. Do not revive checkpoint 113's failed
`tos-value` generic on `(top subject)`. Passing `(mirror subject)` as
an **argument** to `Mirror.invoke` is already how
`GelStack.invoke-one` fills a hole; the checker infers invoke
arguments normally and runtime `invoke` checks them. The receiver of
that invoke is the presentation service, not the specimen.

Idle precedence, command chrome, and page reset rules are unchanged
from checkpoint 117.

### 6.5 `u` and parent

Who sends `(directory parent)`: the `up` method on
`GelDirectoryPresentations`, where `directory` is a typed parameter
and the class's `H` is pinned by its `fs-host` field.

Who pushes: `GelStep.handle-up`, unchanged. `GelUp Parent` still
carries a `Mirror` of the live parent `Directory`. Root /
non-directory parent is `NoParent` (no-op). Non-Directory TOS is
`Unavailable` (no-op). Pending `u` stays a no-op.

`u` does not pop, replace TOS, or change process cwd.

---

## 7. What is deleted

| Class | Delete |
|---|---|
| `Directory` | `gel-tos-text`, `gel-directory-values`, `gel-directory-all-values`, `gel-up` |
| `File` | `gel-tos-text` |
| `SymbolicLink` | `gel-tos-text` |
| `Other` | `gel-tos-text` |
| `List` | `gel-values` |

After the move, `(define-methods List)` in `gel/menu.aloe` is gone.
The only `define-methods List` in the image for this concern is
`lib/list.aloe` (`fold` / `reverse` / `map`).

`gel/directory.aloe` keeps `GelDirectoryListing` / `GelDirectoryRows`
and the Item-to-row case analysis. It loses every
`define-methods` block whose target is a disk class.

---

## 8. Tests

Smallest proof of the live-image bar, plus the frozen runner.

### 8.1 Signatures did not grow

Load `lib/disk.aloe` (and `lib/list.aloe`, already in the default
driver). Snapshot unique selector names from
`(Mirror of specimen) messages` / `signatures` for:

- a live `Directory`, `File`, `SymbolicLink`, `Other`
- a `List`

Then load Gel, then `gel/directory.aloe`. The snapshots must be
**equal**. In particular they must not contain `gel-tos-text`,
`gel-directory-values`, `gel-directory-all-values`, `gel-up`, or
`gel-values`.

A second assertion: those same selectors **do** exist as one-argument
methods on `gel-presentations` after the filesystem module loads
(and `list-values` after generic Gel loads).

Do not prove this by string-matching `"entries"` on the specimen.

### 8.2 Directory runner still behaves

Keep the checkpoint 112–117 scenarios, pointed at menus / keys / TOS
text rather than at `cwd gel-directory-values`:

- children as Values rows, nested live objects not `Item`s
- labels `name`, `name/`, `name@`
- idle `.` hidden toggle, filter before the page window
- 22-row window, idle `n` / `p`, page reset on push / pop / `u` / `.`
- `u` pushes live parent; root no-op; Escape pops; `q` quits
- TOS path text for all four live classes; `Mirror.raw` of those
  objects stays the structural dump
- File / SymbolicLink / Other keep derived menus; List stays unpaged
- generic Gel without `gel/directory.aloe` keeps Point / List / Int
  bytes
- no physical TTY; `make-fs-double` + isolated production checks as
  today

Living tests that currently send `gel-directory-values` to a
Directory, assert `define-methods Directory` in `gel/directory.aloe`,
or require `gel-values` on `List`, update those expectations in the
implementing checkpoints. Do not rewrite 112–117 as new UX.

---

## 9. How this experiment is sliced

This spec does not write checkpoint files. A later checkpoint-manager
conversation writes **one local slice at a time**. After slicing, list
the issued numbers in
[`docs/gel/presentations/README.md`](README.md) (and optionally here)
so it is obvious which slices came out of this spec.

### 9.1 Local series (this experiment only)

Identity is `(project, number)`, not the next global integer.

| | Path |
|---|---|
| Checkpoint | `docs/gel/presentations/checkpoints/000-short-slug.md` |
| Test | `tests/gel/presentations/000-short-slug.rkt` |

Spoken name: **gel-presentations 000**. Not “checkpoint 118”. Not
“gel 000” (Gel already has global checkpoints 72–82). Zero-pad to
three digits. Keep a short slug in the filename. The test uses the
same project folder name, same local number, and same slug.

**Do not** write Gel presentations slices as
`docs/checkpoints/0118-….md` or `tests/checkpoint-118.rkt`. Leave the
existing global spine alone (`docs/checkpoints/0072`–`0117`,
`tests/checkpoint-N.rkt` for 1–117). Do not invent a parallel global
118–N for the same work, and do not refile 1–117.

`gel-presentations 000` starts after global 117 is green. Frozen
Directory UX remains global checkpoints 112–117 and
`docs/gel-directory-surface.md`. Predecessor project, not previous
integers of this series.

Tests sit under `tests/gel/presentations/` (two directories deeper
than the global suite). Use `../../../aloe/…` in `require` and
`define-runtime-path`. Do not also create a global
`tests/checkpoint-118.rkt` for the same slice.

**How to run tests.** `raco test` walks directories recursively. The
shell glob `tests/*.rkt` does not. Full suite and per-slice:

```sh
raco test tests/gel/presentations/000-short-slug.rkt
raco test tests
```

Do not tell the implementer to run `raco test tests/*.rkt`; that
would skip this folder.

**Sibling projects.** If this experiment blocks on unrelated work (a
string primitive, a kernel hole, etc.), that is a sibling under
`docs/`, with its own charter/spec/checkpoints/tests. Do not nest it
under `docs/gel/presentations/`. Link it: “gel-presentations 001
depends on \<other-project\> 000.”

### 9.2 Issued slices

**gel-presentations 000 — substrate + List** (`substrate-list`) is
green. It added `gel/presentations.aloe` and `GelPresentations`, moving
`List.gel-values` onto
`(gel-presentations list-values items)`. `GelMenus` recognizes List
by `accepts?` on that Gel-owned row, not by scanning the specimen
for `"gel-values"`. Delete `define-methods List` from `gel/menu.aloe`.
Point, Int, and derived menus stay byte-for-byte. Proof: after Gel
loads, `List` has no `gel-values`; global checkpoint 110–111 List
behavior still holds.

**gel-presentations 001 — Directory family** (slug `directory-family`).
**Blocked. Do not implement. Do not rewrite this file into a new
design.** The issued checkpoint required `(type H)` / `(Directory H)`
bodies. Those do not typecheck (§4.2–4.3).

**gel-presentations 002 — Directory host** (`directory-host`) is
green. It followed §4.3 / §6.2: Directory-family behavior lives on
`GelDirectoryPresentations`, a generic Gel class holding `fs-host`.
Disk classes retain only disk vocabulary; 001 remains blocked history.

**gel-presentations 003 — doc law** (`doc-law`) is implemented. It
applied §11 to current Gel law. Historical global checkpoint 110–117
files still describe the old seam; they were not rewritten.

**No next slice.** Do not issue 004. Do not implement 001.

---

## 10. Non-goals

Do not specify or implement as this experiment:

- Browser / session object as TOS
- Wrapper-as-TOS, forwarding, inheritance
- Asterisk-proxy (“TOS looks like a Directory but is a wrapper”)
- Kernel type classes, generic functions, protocol-owned method tables
- `Mirror.class` or any `aloe/` / `host/` edit (including a checker
  change so abstract `H` can send host `names` / `root?`)
- Fuller Genera: command tables, presentation translators, input
  context, transcript-wide mouse/keyboard sensitivity, history as
  live presentations, cycling views
- Mouse in the terminal
- Changing paging, hidden names, item-key pool, or Directory UX
- A second product named Listener or Genera
- Search `/`, home/root jumps, visible stack levels, persistent
  listing snapshots (still later pressure on the directory surface)

**Paging is frozen.** Checkpoints 112–117 remain the UX authority.

---

## 11. Doc amendments (applied by gel-presentations 003)

### `docs/gel.md` §4

Replace:

> Adding a capability means adding an Aloe class or method (plus host
> primitives when the OS must be touched). Gel itself does not grow a
> new framework per personality.

with:

> Adding a capability means adding an Aloe class or method (plus host
> primitives when the OS must be touched). Gel does not grow a
> plugin, hook, pane, or extension API per personality. A personality
> is a Gel-owned presentation: methods indexed by Aloe type via
> `Signature.accepts?`, taking the specimen as an argument. The List
> personality lives on `GelPresentations`; the Directory personality
> lives on generic `GelDirectoryPresentations`, which holds `fs-host`.
> Domain classes keep their own vocabulary. After Gel loads,
> `Directory` still only answers disk.

### `docs/gel.md` §5 (current adapter paragraphs)

Replace the private-seam story (`List.gel-values` on `List`,
`gel-directory-values` / `gel-up` / `gel-tos-text` on disk types,
string-matching those names on the specimen) with: `GelMenus`,
`GelText`, and `u` consult Gel-owned presentation objects, never the
TOS method table. List uses `list-values` on `gel-presentations`.
Directory uses `directory-values`, `directory-all-values`, `up`, and
`tos-text` on `gel-directory-presentations`, found through the
optional `directory-presentations` index. The directory application
still loads `gel/directory.aloe` after `lib/disk.aloe`; that file
defines and installs the host-holding Gel presentation without
extending a disk class.

Keep the frozen UX sentences (22-row page, `.`, `n` / `p`, `u`,
labels, TOS path form). Keep the reserved-name table: Listener,
Inspector, Browser.

### `docs/gel-directory-surface.md`

Replace “private Gel adapter” / “private seam” language with
“Gel-owned presentation”. Keep “`lib/disk.aloe` stays Gel-ignorant”
and strengthen it: after Gel loads, disk method tables are unchanged.
Authored keys remain in Gel, not in the disk vocabulary.

### Global checkpoints 110–117

Leave the historical documents on the global spine. New
gel-presentations checkpoints state that the private-seam selectors
are gone from domain classes.

---

## 12. Do not paint into a corner

This spec is one presentation per type, looked up each time from TOS.
That is enough for GelFS. Leave these doors open; do not walk through
them.

- **Cycling presentations.** Authored listing vs `.` (raw `Mirror`)
  is already two views of a Directory. A later cycle key would pick
  among presentations for one specimen. Do not add a cycle key. Do
  not store “the” presentation on `GelStep` in a way that implies
  there can be only one forever. Lookup-from-type leaves a second
  overload or an ordered list as a later design.
- **A second personality.** A process browser should use Gel-owned
  one-argument presentation methods indexed by the process type, not
  install `gel-values` on a process object. If its bodies require an
  optional host capability, a host-holding Gel presentation plus an
  optional index is the Directory precedent. Directory itself lives
  on `GelDirectoryPresentations`; `gel/directory.aloe` does not extend
  `GelPresentations`.
- **History as live presentations.** Stack items stay specimens
  (`Mirror` of the value). A later Listener-shaped history line can
  re-present the same object. Do not snapshot presentation objects
  into `GelStack`.

---

## 13. Ranked leftovers (not another local checkpoint)

1. **This experiment (done)** — Gel presentations, TOS stays the
   specimen. Issued series: 000, 002, 003 green; 001 blocked.
2. **Filed** — browser as TOS (session object).
3. **Later Gel-as-Genera** — cycle key, then command tables,
   translators, transcript-wide sensitivity, history as live
   presentations. Same program (Gel), later design conversation.
4. **Wings** — language-level type classes, if a second application
   needs a real dictionary. Not unblocked by this spec; this spec
   does not need them.
