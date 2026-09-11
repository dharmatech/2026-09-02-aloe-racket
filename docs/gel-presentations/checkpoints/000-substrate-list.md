# gel-presentations 000 — substrate + List

**Spoken name.** gel-presentations 000. Not “checkpoint 118”. Not
“gel 000”.

**Branch.** Continue on `experiment/gel-directory-surface` after green
**global** checkpoint 117. Do not start from `main`. Do not merge to
`main`.

**Depends on.** Global 110–111 (List Values menus), global 117 (frozen
Directory paging). Predecessor Directory UX remains global 112–117
and `docs/gel-directory-surface.md`.

**Status.** Ready to implement.

**Authority.** `docs/gel-presentations/spec.md` is this experiment’s
law. `SPEC.md` is Aloe language law. Current Gel behavior is
`docs/gel.md` (Directory adapter language may remain until a later
slice). Frozen Directory UX is `docs/gel-directory-surface.md`; do
not reopen it.

The implementer receives only this document.

## Goal

Add `gel/presentations.aloe` and `GelPresentations`. Move
`List.gel-values` onto `(gel-presentations list-values items)`.
`GelMenus` recognizes a List TOS by `Signature.accepts?` on that
Gel-owned arity-1 row, not by scanning the specimen for
`"gel-values"`. Delete `define-methods List` from `gel/menu.aloe`.

After Gel loads, `List` has no `gel-values`. Global 110–111 List
behavior still holds. Point, Int, and derived menus stay
byte-for-byte.

This is the List half of the live-image bar (spec §2 item 4). It is
not the Directory family.

Stop and return this checkpoint for revision before writing any code
if the work starts to do any of:

- move Directory / File / SymbolicLink / Other off `define-methods`
- change paging, hidden names, item keys, or TOS path text
- edit `aloe/`, `lib/`, or `host/`
- add `Mirror.class` or any kernel hatch because `accepts?` looks
  impossible
- invent a presentation-type lattice, wrappers-as-TOS, or Listener

## Named hole (live-image bar not done)

Directory may stay patched. After this slice:

- `gel/directory.aloe` still `define-methods` disk classes
- `GelMenus.directory?`, `GelText.tos`, and `GelUps` still
  string-match `"gel-directory-values"` / `"gel-directory-all-values"`
  / `"gel-tos-text"` / `"gel-up"` on the **specimen**
- live-image bar items 1–2 remain true as today; item 3 is **not**
  done; item 4 **is** this slice

Do not claim the live-image bar complete. Do not silently enlarge
this slice to finish the Directory family.

## Required behavior

When TOS is a `List`:

- Gel still presents Values rows: first `(gel-item-keys len)` (22)
  elements, source order, one-based indexes, position-bound letters
  `a b c d e f g h i j k l m o r s t v w x y z`. Unpaged. Idle `n` /
  `p` remain no-ops and add no command line.
- Existing element mirrors are retained by identity (`gel-mirrors of`).
- Empty List: empty Values menu (empty string), not derived List
  messages.
- Nested List selection still pushes that exact mirror and the new
  TOS gets its own Values menu.
- Menu text still contains no `empty?`, `first`, `rest`, `cons`,
  `len`, `map`, `fold`, `reverse`, `gel-values`, or `list-values`
  selector row. Labels remain each value’s `(mirror raw)`.

When TOS is Point, Int, or any non-List, non-Directory object:
derived Messages menus stay byte-for-byte with global 110–111.

When TOS is a live `Directory`: existing patched selectors, paging,
hidden names, `u`, labels, and TOS path text stay as global 112–117.
This slice must not retarget those scans.

After Gel loads (ordinary `gel/loop.aloe` / `gel/main.aloe`, no
`gel/directory.aloe` required):

- `(Mirror of a-list) messages` / `signatures` have no `gel-values`
- `(gel-presentations list-values a-list)` is legal and returns
  `GelListValues`
- a List TOS still becomes `GelMenu Values` even though the specimen
  has no `gel-values` row

`lib/list.aloe` remains the only `define-methods List` in the image
for this concern (`fold` / `reverse` / `map`). Kernel List messages
are unchanged.

## Chosen shape

One Gel-owned service. Not a wrapper. Not a protocol with holes.
TOS remains `Mirror` of the specimen. `GelStack.items` stays
`(List Mirror)`. Do not add a presentation field to `GelStep`.

### Module and load order

```text
gel/presentations.aloe   GelPresentations, gel-presentations
gel/menu.aloe            loads presentations.aloe; List personality
                         via define-methods GelPresentations
```

Ordinary Gel (`gel/main.aloe` → `loop` → `stack` → `menu` →
`presentations`) always has the service and the List personality.

In `gel/presentations.aloe`:

```aloe
(define-class GelPresentations
  (fields)
  (methods))

(define gel-presentations (GelPresentations new))
```

`gel/menu.aloe` loads it with `(load "presentations.aloe")` after
`gel-mirrors` and `GelListValues` exist. Then:

```aloe
(define-methods GelPresentations
  (methods
    (list-values (type T)
      (items (List T))
      GelListValues
      (GelListValues new
        (items map
          (fn (value)
            (gel-mirrors of value)))))))
```

That body is today’s `List.gel-values`, with `items` in place of
`self`. Delete the entire `(define-methods List … gel-values …)`
block.

Public selector is `list-values`. Do not keep `gel-values`. Do not
prefix `gel-`. Helpers on `GelMenus` may be shortened; this selector
may not.

If the implementer prefers the method body inside
`presentations.aloe`, that is allowed only when that file is loaded
after `GelListValues` / `gel-mirrors` exist. The class, the binding,
and the public selector stay as above.

### How `GelMenus` finds a List

Keep the Directory specimen scan **first** and unchanged (the named
hole).

Replace only the `"gel-values"` specimen scan:

1. Collect arity-1 signatures of `(Mirror of gel-presentations)`
   whose selector name is `"list-values"`.
2. Keep those for which `(signature accepts? mirror)` is true.
3. If none, `(GelMenu Messages (gel-rows of mirror))` as today.
4. If one, invoke on the **service**, specimen as argument:

   ```text
   ((Mirror of gel-presentations) invoke signature (mirror subject))
   ```

   Expected type `GelListValues`. Then today’s `value-rows` builder
   (cap at `(gel-item-keys len)`, ignore `page`). Return
   `GelMenu Values`.

Use a typed invoke helper whose return type is `GelListValues`. Do
not bind a reflective result to an unconstrained `let`. Passing
`(mirror subject)` as an invoke **argument** is already
`GelStack.invoke-one`; do not revive a generic on `(top subject)`.

`(List T)` matches any list, including empty. Int, Point, Directory,
and File must not match.

Do not scan the specimen for `"gel-values"`. Do not send
`(list gel-values)`. Do not parse `(mirror raw)` for `#<List`. Do
not construct a `Signature`. Do not redispatch by a computed
selector.

`GelMenus.directory?`, `GelUps`, and `GelText.tos` stay on the
specimen in this slice.

### `accepts?` is the probe

`(signature accepts? mirror)` is true when the signature has exactly
one parameter and that parameter accepts the mirror’s subject under
the same relation `Mirror.invoke` uses (`SPEC.md` §7.4). Gel already
uses this for pending stack picks.

If this probe cannot recognize a List without a kernel hatch, **stop
and return this checkpoint**. Do not add `Mirror.class`. Do not
string-match `"first"` / `"rest"` on the specimen.

## Exact file scope

Implementation may edit only:

- `gel/presentations.aloe` (new)
- `gel/menu.aloe` (load the service; `define-methods GelPresentations`
  for `list-values`; delete `define-methods List`; List recognition
  in `GelMenus.of`)
- `tests/gel-presentations/000-substrate-list.rkt` (new)
- `tests/checkpoint-110.rkt` and `tests/checkpoint-111.rkt`, **only**
  where they send `gel-values` to a List, type that send, or assert
  `(define-methods List)` in `gel/menu.aloe`

Those living tests keep their List UX. Point their seam at
`(gel-presentations list-values items)`. Change the
`define-methods List` count in `gel/menu.aloe` from `1` to `0`. Do
not rewrite 110–111 as new UX.

Do not edit `gel/directory.aloe`, `gel/loop.aloe`, `gel/main.aloe`,
or `gel/stack.aloe`. Do not edit anything under `aloe/`, `lib/`, or
`host/`. Do not add `tests/checkpoint-118.rkt`. Do not write
`docs/checkpoints/0118-….md`. Do not append root `CHECKPOINTS.md`.
Do not apply spec §11 wording to `docs/gel.md` (that is a later
slice). Do not change frozen Directory UX tests except that 110–111
seam updates above.

Tests sit one directory deeper than the global suite. Use one extra
`../` in `require` and `define-runtime-path` (`../../aloe/…`, not
`../aloe/…`).

## Tests and acceptance

Add `tests/gel-presentations/000-substrate-list.rkt`. Cover at least:

1. **List signatures did not grow.** On a fresh driver (List library
   already loaded), snapshot unique selector names from
   `(Mirror of a-list) messages` / `signatures`. Load Gel. The
   snapshot is **equal**. It contains no `gel-values`. A second
   assertion: `list-values` exists as an arity-1 method on
   `gel-presentations`; `(signature accepts? list-mirror)` is true;
   `(signature accepts? (Mirror of 10))` is false; an empty List
   also accepts.
2. **Moved body.** `(gel-presentations list-values (List of 10 20
   30))` is `GelListValues` whose items are ordered mirrors of
   `10`, `20`, `30`. A List of existing mirrors retains those
   mirrors by `eq?`. Sending `gel-values` to a List is an error.
3. **`GelMenus` without a specimen nametag.** After Gel loads, a
   List still yields `GelMenu Values` with the same 0 / 1 / 22 /
   >22 capping as 110–111. Point and Int menu bytes match 110–111.
   Source of `gel/menu.aloe` has no `(define-methods List)` and no
   `"gel-values"` specimen scan.
4. **Directory hole is still the old seam.** Loading
   `lib/disk.aloe` then `gel/directory.aloe` still installs
   `gel-directory-values` on `Directory`. `gel-menus directory?` on
   a live Directory remains true. Do not treat that as success of
   the live-image bar.
5. **Scope.** No changes under `aloe/`, `lib/`, or `host/`. No
   `take` / `drop` on List. No Directory / File / SymbolicLink /
   Other methods moved onto `GelPresentations`. No page / hidden /
   key-pool / TOS-path edits. Global 110, 111, 112, 116, and 117
   plus the full suite remain green.

`GelPresentations` and `gel-presentations` are unbound before Gel
loads.

Run:

```sh
raco test tests/gel-presentations/000-substrate-list.rkt
raco test tests
git diff --check
```

Do **not** run `raco test tests/*.rkt`; that glob skips this folder.

When a physical TTY is available, `racket host/racket/gel-run.rkt
examples/gel-list.aloe` still shows letter-keyed values and `q`
leaves. List applications must not page. Directory TTY is not this
slice.

The checkpoint is complete when List is off `List`’s method table,
`GelMenus` finds it through `accepts?` on `gel-presentations`,
110–111 bytes still hold, and the Directory hole is still named
rather than “fixed”. Stop for review without committing and without
starting gel-presentations 001.

## Explicit non-goals

- No Directory / File / SymbolicLink / Other presentation methods
- No change to paging, hidden names, item-key pool, or TOS path bytes
- No `Mirror.class`, kernel type classes, or `aloe/` / `host/` edit
- No wrapper-as-TOS, forwarding, inheritance, or presentation lattice
- No Listener, Inspector, Browser, command tables, or translators
- No `docs/gel.md` law rewrite (later slice)
- No global checkpoint 118
