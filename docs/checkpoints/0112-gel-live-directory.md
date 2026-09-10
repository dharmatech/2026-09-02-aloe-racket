# Checkpoint 112 — Live Gel `Directory` surface

**Branch.** Continue on `experiment/gel-directory-surface`.

**Depends on.** Checkpoint 111 (collision-free Gel item keys) and checkpoint
107 (`Directory.entries`)

**Status.** Complete (reviewed 2026-09-10 on
`experiment/gel-directory-surface`).

## Goal

Make the first focused directory browser real:

- a live `Directory` on Gel's TOS renders its immediate children on the main
  screen;
- each child row uses checkpoint 111's position-bound item key and a useful
  filesystem label;
- choosing a child pushes the nested live `Directory`, `File`,
  `SymbolicLink`, or `Other` object itself, not its `Item` wrapper;
- `u` asks the current `Directory` for `parent` and pushes that live parent;
- Escape remains stack back, so it is observably different from `u`; and
- a separate Gel runner injects both `term` and production `fs-host`, while
  the existing Gel runner stays Term-only.

Start the supplied directory application at the process's live current
directory. Keep all authored filesystem behavior under `gel/`; do not add Gel
messages to `lib/disk.aloe` and do not teach Racket about `Directory`, item
rows, or navigation.

This is one complete application slice. It does not add paging, search,
refresh, file reading, a workspace, or a general authored-surface framework.

## Depends on

- Parent: `experiment/gel-directory-surface` after reviewed checkpoint 111.
- Design authority: `docs/gel-directory-surface.md` §§1, 3–4, progression item
  5 in §7, and the remaining implementation choices in §8.
- Disk vocabulary authority: `docs/filesystem-oo-vocabulary.md` and
  `lib/disk.aloe` after checkpoint 107.
- `Directory.entries` returns a source-ordered `(List (Item H))`. Each `Item`
  constructor carries the corresponding nested live object with the same host
  capability.
- `Directory.parent` returns `(Option (Directory H))`. At root or when the
  parent can no longer be inspected as a directory, it returns `None`.
- `Directory.name`, `File.name`, `SymbolicLink.name`, and `Other.name` return
  the immediate name. `Directory.text` remains available for raw structural
  TOS presentation; no new disk-library display method is needed.
- Checkpoint 111 supplies the exact 24-letter `gel-item-keys` pool and
  letter-based `GelStep.handle-values` path.
- Checkpoint 110's exact-mirror `GelStack.push` path already leaves the
  containing object below the selected child as history.
- Checkpoint 109 handles `q` and Escape before idle menu selection.
- `make-fs-receiver` is the production filesystem capability and
  `make-fs-double` is its sealed test double. Neither is ambient in a fresh
  driver.

The implementer will not have a separate checkpoint-manager brief. Every rule
needed for this slice is in this document.

## Chosen architecture

Keep the existing `GelMenu.Values` route rather than adding another menu
constructor or a second selection engine.

1. Give `GelValueRow` an immutable `label String` alongside its existing
   one-based index and exact value mirror. Ordinary List rows capture the
   mirror's current `raw` text as that label, so checkpoints 110–111 retain
   their bytes.
2. Add one narrowly named private adapter on `Directory`:
   `(dir gel-directory-values)` returns `GelValueRows` already labeled for
   filesystem use. `GelMenus` recognizes and invokes that exact reflected
   zero-argument row before its existing List `gel-values` adapter.
3. Add a second private adapter `(dir gel-up)` whose nominal result represents
   no parent or an exact parent mirror. Gel only invokes it for the exact `u`
   command.
4. Put those two `Directory` methods and the Item-to-row case analysis in a
   new `gel/directory.aloe` file. `lib/disk.aloe` remains Gel-ignorant.
5. A new runner supplies authority. A small Aloe application loads the disk
   vocabulary and Gel Directory adapter and owns `gel-start-value`.

These selector names are private integration seams for this one built-in
surface. They are not a hook convention that other classes should implement,
and they must not be documented as an extension API.

## Authority / starting point

Facts before this checkpoint (do not redesign them):

- `GelValueRow` has `(index Int)` and `(value Mirror)` fields plus `key`.
- `GelMenus.value-rows` builds up to `(gel-item-keys len)` rows from a
  `GelListValues` carrier.
- `GelMenu` has exactly `Messages` and `Values` constructors. Existing cases
  are exhaustive and remain so.
- `GelText.value-line` currently uses `(row value)`'s raw text.
- `GelStep.handle-values` already selects by `item-index`, bounds-checks, and
  pushes `(row value)` through the exact Mirror overload.
- `GelKey.item-index` maps `u` to zero because `u` is absent from the pool.
- `GelKey.quit?` and `escape?` already have precedence in idle handling.
- The ordinary `host/racket/gel-run.rkt` requires one application path,
  injects only `term`, loads `gel/main.aloe`, loads the application, and sends
  `(gel-main start gel-start-value)`.
- A fresh `make-driver`, `bin/aloe`, and the ordinary Gel runner have no
  `fs-host` binding.
- `lib/disk.aloe` is complete for this screen. Do not grow it unless an
  acceptance test below is impossible with its current public messages.

## Exact file scope

**May edit during implementation:**

- `gel/menu.aloe` (labeled value rows, private Directory-row recognition, and
  nominal reflected-up result/service)
- `gel/loop.aloe` (`GelKey.up?`, Directory command presentation, and parent
  push)
- `gel/directory.aloe` (new; Gel-owned `Directory` adapter and row builder)
- `examples/gel-directory.aloe` (new live-current-directory application)
- `host/racket/gel-directory-run.rkt` (new; Term + filesystem-capable Gel
  runner)
- `tests/checkpoint-112.rkt` (new)
- `tests/checkpoint-110.rkt` and `tests/checkpoint-111.rkt` only for the narrow
  `GelValueRow` constructor/type migration caused by the new label field; do
  not change their established output or behavior
- `CHECKPOINTS.md` (append checkpoint 112 only)
- `docs/gel.md` (current Directory surface, labels, and runner contract)
- `docs/handoff.md` (current state and next pressure only)
- `docs/gel-directory-surface.md` status/progression and resolved exact-file
  notes after the checkpoint is green
- `docs/decisions.md` (optional short dated note recording the narrow adapter
  and separate-capability-runner choices)

**Do not edit:**

- `aloe/`, including evaluator, checker, parser, reflection, host descriptors,
  and the driver
- `lib/`, especially `lib/disk.aloe`, `lib/fs.aloe`, and `lib/option.aloe`
- `host/racket/fs.rkt`, `host/racket/term.rkt`,
  `host/racket/gel-run.rkt`, or any existing host runner
- `gel/stack.aloe` and `gel/main.aloe`
- existing examples, including `gel-list.aloe` and `gel-point.aloe`
- `bin/aloe`
- `SPEC.md`
- historical checkpoint documents
- historical tests 1–109
- checkpoint-110/111 assertions unrelated to the `GelValueRow` constructor
  shape
- thin-filesystem tests, Boids, MPL, Point, or unrelated documentation

Do not start paging/search or another post-directory checkpoint in this
change.

## Required behavior

### Labeled value rows

Extend `GelValueRow` in `gel/menu.aloe` to exactly these fields while keeping
its existing `key` method:

```aloe
(define-class GelValueRow
  (fields
    (index Int)
    (value Mirror)
    (label String))
  (methods
    (key () String
      ((gel-item-keys select (self index)) text))))
```

Update `GelMenus.value-rows` so the ordinary List path constructs:

```aloe
(GelValueRow new next-index value (value raw))
```

Locks:

- `value` remains the exact checkpoint-110 mirror. Adding a label must not
  unwrap, copy, or re-reflect it.
- Ordinary List rendering is byte-for-byte unchanged from checkpoint 111.
- The label is captured when the row is built. Rendering does not call a
  subject method and does not rescan reflection.
- Do not make `label` optional, add another row constructor, put labels on
  `GelRow`, or add a generic presentation protocol.

Change `GelText.value-line` in `gel/loop.aloe` to render `(row label)` instead
of `(row value)`'s `raw` message:

```text
key␠␠label\r\n
```

No other List, reflected-message, pending-pick, pending-Int, or TOS bytes
change.

### Private Directory-row recognition

Extend `GelMenus.of(Mirror)` with a first, narrow scan for an exact
zero-argument signature whose selector name is `"gel-directory-values"`.

- If present, invoke that owned signature through the same mirror and return
  `(GelMenu Values rows)` from its `GelValueRows` result.
- Supply `GelValueRows` as the invocation's expected type through a typed
  helper parameter/result. Do not bind the reflective result to an
  unconstrained `let` variable.
- If absent, continue through the existing `gel-values`/`GelListValues` route
  and then reflected `Messages` fallback exactly as checkpoint 110 specifies.
- Do not identify a Directory by raw text, class-name parsing, host state, or
  Racket predicates.
- Do not add a `Directory` constructor to `GelMenu`; all existing exhaustive
  `Messages`/`Values` cases remain unchanged.
- Do not turn the selector into a public authored-surface protocol.

The Directory adapter is loaded only by the directory application, so the
signature is absent in ordinary Gel sessions.

### Nominal `u` result and reflective service

In `gel/menu.aloe`, add:

```aloe
(define-class GelUp
  (constructors
    (Unavailable (fields))
    (NoParent (fields))
    (Parent (fields (value Mirror))))
  (methods))
```

Add a stateless `GelUps` service and `gel-ups` binding with:

- `(gel-ups available? mirror)` → `Bool`: true only when `mirror.signatures`
  contains an exact zero-argument selector named `"gel-up"`;
- `(gel-ups of mirror)` → `GelUp`: `Unavailable` when that row is absent,
  otherwise invoke that exact owned row with `GelUp` as the expected result
  type.

Use a typed helper for the invoke result, for the same reason as the
Directory-row invocation. `available?` must inspect signatures only; it must
not invoke `gel-up` or touch the filesystem merely to render a menu.

Locks:

- This service does not send `parent` itself. The Directory-owned adapter
  below performs the public disk-vocabulary send while its generic type is
  known.
- Absence is ordinary and total for Lists, Files, Points, integers, host
  receivers, and every unfamiliar object.
- Do not add Option to Gel's generic menu types or expose a host handle.
- Do not add general command tables, keymaps, hooks, or dynamic selectors.

### Gel-owned Directory adapter

Add `gel/directory.aloe`. It is Aloe application code and assumes the generic
Gel files and `lib/disk.aloe` have already been loaded. It contains no `load`,
top-level start value, `term`, or `fs-host` binding.

Define one stateless `GelDirectoryRows` service with a generic method that
turns `(Directory H).entries` into `GelValueRows`. It must use exhaustive
`Item` case analysis:

| `Item` constructor | row mirror | row label |
|---|---|---|
| `File (file)` | `(Mirror of file)` | `(file name)` |
| `Directory (directory)` | `(Mirror of directory)` | `name` plus `/` |
| `SymbolicLink (link)` | `(Mirror of link)` | `name` plus `@` |
| `Other (thing)` | `(Mirror of thing)` | `(thing name)` |

For a Directory whose name is the empty root name, its label is `/` rather
than an empty string plus `/` by accident. This mainly makes the helper total;
a normal child Directory has a nonempty name.

The builder:

- calls `(directory entries)` exactly once per `of` send;
- preserves the order supplied by `Directory.entries`;
- assigns indexes from one and keys through the shared `gel-item-keys` pool;
- exposes at most `(gel-item-keys len)` children;
- creates each row with its exact nested live-object mirror and label; and
- returns an empty `GelValueRows` for an empty Directory.

Then add only these two Gel-private methods to `Directory`:

```aloe
(define-methods Directory
  (methods
    (gel-directory-values () GelValueRows
      (gel-directory-rows of self))

    (gel-up () GelUp
      ((self parent) case
        (None () (GelUp NoParent))
        (Some (parent)
          (GelUp Parent (Mirror of parent)))))))
```

The exact helper layout may vary, but the selectors, public result types, and
semantics are locked.

Locks:

- The row value is the carried live `File`, `Directory`, `SymbolicLink`, or
  `Other`; an `Item` wrapper is never pushed onto Gel's stack.
- A Directory child has `/` solely in its presentation label. Its name and
  path data are unchanged.
- A symlink has `@` solely in its label and is not followed or reclassified.
- Other kinds retain their name; do not expose or append their host kind in
  this slice.
- `gel-up` sends the existing public `(self parent)` message. `None` means
  `NoParent`; `Some` preserves the returned Directory by exact mirror.
- Do not add Gel methods to `File`, `SymbolicLink`, `Other`, `Item`,
  `Location`, or `Disk`.
- Do not add `(here entries)`, `enter`, `read`, `size`, `target`, or any method
  to the disk library.

### Directory menu text

Add exactly one authored command line to a Directory value menu:

```text
u␠␠up\r\n
```

In the `GelText.menu(Mirror)` route:

1. Render the existing `GelMenu` normally.
2. Ask `(gel-ups available? mirror)` without invoking it.
3. When true, append a blank CRLF and `u  up\r\n` after nonempty child rows.
   For an empty Directory, render only `u  up\r\n` with no leading blank.
4. When false, return the ordinary menu bytes unchanged.

Examples:

```text
a  a.txt\r\n
b  lib/\r\n
c  link@\r\n
d  pipe\r\n
\r\n
u  up\r\n
```

The outer `term write-line` still supplies its existing final CRLF. Do not add
Directory-specific TOS formatting, stack-history lines, `q`/Escape help rows,
colors, columns, kind labels, or path headers.

A File, SymbolicLink, or Other selected from the listing receives its existing
derived digit menu and no `u  up` authored line. A nested Directory receives
another authored child menu.

### `u` transition

Add to `GelKey`:

```aloe
(up? () Bool
  ((self text) = "u"))
```

It is true only for exact lowercase `"u"`. Preserve `digit-value`,
`menu-index`, `item-index`, `quit?`, `escape?`, and `return?` exactly.

In `GelStep.handle-idle`, preserve command precedence in this order:

1. `q` requests quit;
2. Escape pops;
3. `u` routes through `(gel-ups of ((self stack) tos))`; and
4. all other keys route through the current menu selection logic.

Case on the `GelUp` result:

- `Unavailable`: return `self` by identity;
- `NoParent`: return `self` by identity; and
- `Parent (value)`: push that exact parent mirror and return a clean idle
  `GelStep` with quit false, empty pending rows, zero Int input, and no digits.

Consequences:

- On a Directory below root, `u` computes and pushes its live parent.
- On root, or if the parent cannot be produced as a live Directory, `u` is a
  no-op.
- On Lists and unfamiliar/derived objects, `u` stays a no-op and cannot become
  an item or reflected-message selection.
- While a send is pending, `u` remains an ordinary invalid pick/Int key and
  stays pending by identity. It does not bypass pending handling.
- `q` and Escape still win before `u` and never invoke `gel-up`.
- `u` does not replace or pop the current Directory. The parent is pushed as a
  result, so Escape immediately after `u` returns to the child Directory.

This is Aloe send semantics, not process-wide `chdir`: the private adapter's
body sends `parent` to its receiver, and Gel pushes the returned live object.

### Listing lifetime

`gel-directory-values` observes the host when Gel constructs that Directory's
menu. The returned `GelValueRows` is immutable and selection within that
`GelMenus.of` call uses its exact mirrors.

Do not add mutable caches, refresh keys, filesystem watchers, or new fields to
`GelStep`/`GelStack`. The current transcript loop may reconstruct the menu for
a redraw or subsequent pure key step; persistent per-TOS snapshots and an
explicit refresh command remain later pressure. Automated selection tests use
a stable test double, and the production hand check assumes the visible
directory is not concurrently reordered between display and selection.

### Filesystem-capable Gel runner

Add `host/racket/gel-directory-run.rkt`, parallel to the existing Gel runner.
It requires exactly one Aloe application path:

```sh
racket host/racket/gel-directory-run.rkt path/to/application.aloe
```

Inside `call-with-tty-term-receiver` it:

1. creates one checked driver;
2. injects `term` with the current TTY receiver;
3. injects `fs-host` with `(make-fs-receiver)`;
4. loads `gel/main.aloe` into that driver;
5. loads the supplied application path into the same driver; and
6. evaluates `(gel-main start gel-start-value)`.

Use this exact invalid-arity diagnostic and exit status `2`, before opening a
TTY:

```text
usage: racket host/racket/gel-directory-run.rkt path.aloe\n
```

Runtime/load failures print one concise `gel-directory: ...\r\n` diagnostic
and exit `1`, matching the existing runner's lifecycle shape.

Locks:

- Do not modify or share mutable state with `host/racket/gel-run.rkt`.
- The ordinary runner remains Term-only and still accepts ordinary Point/List
  applications.
- The new runner may know the `fs-host` binding and production receiver. It
  must not mention Aloe `Disk`, `Location`, `Directory`, `Item`,
  `gel-directory-values`, row labels, `u`, `parent`, or a hard-coded
  filesystem start path.
- The application, not Racket, loads the disk vocabulary/adapter and supplies
  the start value.
- Default drivers and `bin/aloe` remain capability-free.

### Live directory application

Add `examples/gel-directory.aloe` with exactly this load/order contract:

```aloe
(load "../lib/disk.aloe")
(load "../gel/directory.aloe")

(define gel-start-value
  (Directory new
    ((Disk new fs-host) current)))
```

The production process current directory is guaranteed to be a directory, so
the application may construct that live `Directory` directly around
`Disk.current`'s `Location`. Do not add a fake fallback for File/SymbolicLink,
hard-code a path, inspect the current location through a type-erasing case, or
perform process-wide `chdir`.

The application does not mention `term`, build a Gel stack, call `gel-main`,
perform output, or load thin `lib/fs.aloe`. Its inferred start type is
`(Directory FsHost)` in the filesystem-capable runner.

## Tests and hand checks

Add `tests/checkpoint-112.rkt`. Use checked drivers, `make-fs-double`, isolated
temporary directories for production filesystem checks, and scripted
production Term receivers. Automated tests must not open a physical TTY or
depend on the repository's mutable contents.

Cover at least:

1. `GelValueRow.label`, `GelUp`, `GelUps`, and `gel-ups` have the specified
   types. `Disk`, `Directory`, the Directory adapter names, `fs-host`, and
   `term` remain absent from a fresh default driver.
2. Generic Gel loaded without `lib/disk.aloe` still loads and preserves all
   Point/List behavior. The Directory-private selectors and
   `GelDirectoryRows` are absent until `gel/directory.aloe` is loaded after the
   disk library.
3. Loading the disk library and Directory adapter against a mixed test double
   gives the live Directory a zero-argument `gel-directory-values` signature
   returning `GelValueRows` and a zero-argument `gel-up` signature returning
   `GelUp`.
4. A double Directory containing a File, Directory, SymbolicLink, and Other
   renders them in host/source order with exact labels `name`, `name/`,
   `name@`, and `name`; then a blank line and exactly `u  up\r\n`. No reflected
   `entries`, `parent`, or private selector row is visible.
5. Each Directory row contains a mirror of the nested live object rather than
   an `Item`. Selecting every row pushes that exact row mirror and preserves
   the original Directory mirror directly below it.
6. A selected child Directory gets its own authored child listing. A selected
   File, SymbolicLink, and Other get ordinary derived digit menus with no
   Directory command line and no Gel-private reflected selector.
7. An empty Directory renders exactly `u  up\r\n`. A Directory with more than
   24 children exposes exactly the first 24 through the shared pool; no child
   gets `q` or `u`, and no overflow/paging/search text appears.
8. `GelKey.up?` recognizes only exact `"u"`; its item index remains zero.
   `q`, Escape, uppercase `U`, digits, named keys, and other strings preserve
   their established classifications.
9. `u` on a nested Directory pushes the exact parent Directory mirror returned
   by the adapter. The old child remains directly below it; Escape returns to
   that child. Repeated `u` walks by pushes, not replacement or process `cwd`.
10. `u` at root is a no-op by identity. `u` on List, File, Point, and Int is a
    no-op. Pending typed-pick and Int-entry states remain pending by identity.
11. `q` and Escape retain precedence and behavior on Directory states.
    Selecting a child uses its letter; digits do not select children.
12. `examples/gel-directory.aloe` has the exact minimal loads/start binding,
    infers `(Directory FsHost)`, and starts at the injected receiver's current
    path without hard-coded filesystem text.
13. A production filesystem test in an isolated temporary current directory
    creates `lib/disk.aloe`, injects `make-fs-receiver` and a scripted Term,
    loads the real application, and drives child Directory entry, File entry,
    Escape, `u`, and `q`. Its transcript and final stack prove live disk
    observation and the difference between back and up.
14. The new runner rejects zero or multiple application arguments before TTY
    setup with the exact usage/exit contract. Source assertions prove it
    injects exactly `term` and `fs-host`, then uses the existing application
    launch convention without Aloe Directory knowledge.
15. The existing ordinary Gel runner remains byte-for-byte Term-only in its
    authority and contains no `fs-host`; default `bin/aloe` and fresh drivers
    remain capability-free.
16. `lib/disk.aloe`, `lib/fs.aloe`, existing host capability implementations,
    `gel/main.aloe`, `gel/stack.aloe`, and existing applications are unchanged.
17. Checkpoints 108–111 and the full existing suite remain green after only
    the narrow labeled-row constructor migration in tests 110–111.

Use a stable double such as:

```racket
(hash
 "/cwd" 'directory
 "/cwd/a.txt" 'file
 "/cwd/lib" 'directory
 "/cwd/lib/disk.aloe" 'file
 "/cwd/link" 'symlink
 "/cwd/pipe" "fifo"
 "/" 'directory)
```

Its `/cwd` child rows are `a.txt`, `lib/`, `link@`, `pipe`; `b` enters `lib/`
and `a` there selects `disk.aloe`.

### Pure hand check

With a driver containing generic Gel, `lib/disk.aloe`,
`gel/directory.aloe`, and the double above injected as `fs-host`, evaluate:

```aloe
(define cwd
  (Directory new ((Disk new fs-host) current)))
(define cwd-stack (gel-empty-stack push cwd))
(define cwd-step
  (GelStep new cwd-stack #f (List empty) 0 #f))
(gel-text menu cwd-step)
(define lib-step (cwd-step handle-key "b"))
(gel-text menu lib-step)
(define parent-step (lib-step handle-key "u"))
(((parent-step stack) tos) raw)
(((parent-step handle-key "escape") stack) tos)
```

The first menu is:

```text
a  a.txt
b  lib/
c  link@
d  pipe

u  up
```

The second menu contains `a  disk.aloe`, then `u  up`. The `u` result is a
live `/cwd` Directory above the live `/cwd/lib` Directory; Escape restores the
exact `/cwd/lib` mirror.

### Physical-TTY hand check

From the project directory, when `tui-term` and a physical TTY are available:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

The main screen lists the project directory's immediate children with letters
and `/` on directories. In the current checkout `lib/` is the 16th sorted
entry and therefore uses `p`; follow the displayed label rather than relying
on that incidental position. Enter `lib/`, see `a  disk.aloe`, select it, and
press Escape to return to `lib/`. Press `u` to push the project Directory,
then `q` to leave and restore the terminal.

The scripted production-Term/production-filesystem equivalent is required;
this physical check is informative when the optional dependency or a real
terminal is unavailable.

## CHECKPOINTS.md and handoff

Append only:

```text
## 112. [Live Gel Directory surface](docs/checkpoints/0112-gel-live-directory.md)

- A Gel-authored live `Directory` menu labels and selects immediate children
  through the shared item-key pool; `u` pushes the live parent while Escape
  remains stack back. A separate application runner injects `term` and
  `fs-host`; the ordinary Gel runner and disk library remain unchanged.
```

Update `docs/handoff.md` to say tests are green through 112 on
`experiment/gel-directory-surface` and that the first live focused Directory
slice is complete. Record the exact runner/application command and the
remaining overflow/snapshot/stack-display pressures without claiming they are
implemented.

Update the current Gel/application/host-boundary paragraphs in `docs/gel.md`.
After the checkpoint is green, `docs/gel-directory-surface.md` may mark all
five first-progression items implemented, resolve the separate runner and
`gel/directory.aloe` choices, and move persistent snapshot/refresh, overflow,
and extra stack levels into follow-up pressure. Do not expand the locked job.

## Acceptance

This checkpoint is complete when the filesystem-capable application opens on
a live current `Directory`, its main Gel menu shows and letter-selects direct
live children with useful labels, nested directories remain browsable, `u`
pushes a live parent while Escape pops history, and the entire capability and
authored behavior remains outside the disk library, ordinary Gel runner,
default driver, and Aloe kernel.

Run:

```sh
raco test tests/checkpoint-112.rkt
raco test tests/*.rkt
git diff --check
```

The focused and full suites must pass. Run both hand checks where the optional
TTY is available. Stop for review without committing and without beginning a
later overflow, snapshot, or presentation checkpoint.

## Explicit non-goals

- No paging, `n`/`p` commands, search `/`, refresh, filesystem watcher,
  persistent per-TOS snapshot, prefix tree, two-key addressing, multi-column
  layout, or selection beyond the first 24 children.
- No extra stack-level rendering, stack editing, drop/swap, return stack,
  process-wide `cwd`, or `chdir`.
- No file contents, preview, edit, open, size, target resolution, symlink
  following, copy, move, delete, selection set, or mutation.
- No workspace/app/git/process/editor/shell commands.
- No `GelFS`/gel-disk package, general authored-surface protocol, keymap,
  hook/plugin/extension API, pane, or configurable labels.
- No public disk-vocabulary changes: no `(here entries)`, `enter`, `read`, or
  Gel selectors in `lib/disk.aloe`.
- No change to the ordinary Term-only Gel runner, generic application launch,
  `GelMain`, `GelStack`, Point/List apps, or default `bin/aloe`.
- No kernel collection/reflection primitive, host crossing type, host method,
  ambient capability, new Aloe syntax, special form, dispatch rule,
  inheritance, macro, or implicit numeric coercion.
- Do not implement a later checkpoint in the same change.
