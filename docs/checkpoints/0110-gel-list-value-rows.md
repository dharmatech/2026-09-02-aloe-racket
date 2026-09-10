# Checkpoint 110 — Gel `List` value rows

**Branch.** Continue on `experiment/gel-directory-surface`.

**Depends on.** Checkpoint 109 (Gel back / pop)

**Status.** Complete (reviewed 2026-09-10 on
`experiment/gel-directory-surface`).

## Goal

When a `List` is Gel's TOS, present its values as directly choosable rows
instead of presenting reflected `List` messages such as `first` and `rest`.
Selecting a visible row pushes that exact value mirror. Escape then returns to
the list through checkpoint 109's ordinary stack pop.

Use the current one-based digit mechanism provisionally for at most nine
visible values. The item-key alphabet and reusable collision-free key policy
remain checkpoint 111 pressure; this checkpoint does not decide them.

Prove the behavior with an in-memory Aloe list. Do not load `lib/disk.aloe`,
inject `fs-host`, add a `Directory` surface, or start a live filesystem
session.

## Depends on

- Parent: `experiment/gel-directory-surface` after reviewed checkpoint 109.
- Design authority: `docs/gel-directory-surface.md` §3 children/value rows,
  §4 stack behavior, §6 disposable Point mechanics, and progression item
  3 in §7.
- Current Gel structure and behavior: `docs/gel.md`, `gel/menu.aloe`,
  `gel/stack.aloe`, and `gel/loop.aloe`.
- Aloe law: `SPEC.md`. All detection, row construction, and selection in this
  checkpoint use ordinary Aloe methods plus existing `Mirror` / `Signature`
  exact-row invocation. There is no new evaluator rule.
- `List.map` is an Aloe method loaded by the ordinary driver. It invokes its
  function with `call` and may build a `(List Mirror)` wholly inside Aloe.
- `Mirror.signatures`, `Signature.selector` / `params`, and `Mirror.invoke`
  already provide the type-erased exact-row boundary needed by Gel.
- `GelStack.push` has an exact `Mirror` overload, so a selected value mirror
  can be pushed without reflecting it twice.
- Checkpoint 109 reserves idle/pending Escape and universal `q` before any
  digit-row handling.

The implementer will not have a separate checkpoint-manager brief. Every
rule needed for this slice is in this document.

## Why this stays in Aloe

`GelStack` intentionally stores `(List Mirror)`, so the static element type of
a mirrored list is not available at the key-step boundary. Do not solve that
by adding Racket list inspection, a `Mirror.list?` kernel primitive, host
handles, or a second dispatch path.

Instead, Gel itself adds one private adapter message to built-in `List` while
Gel is loaded:

```aloe
(list gel-values) ; GelListValues containing a (List Mirror)
```

The existing signature table lets Gel recognize and invoke that exact
zero-argument row on a mirrored list. This is a narrow built-in `List`
adapter, not a public plugin protocol. Do not document `gel-values` as an
extension point and do not add it to reusable libraries or Aloe law.

## Authority / starting point

Facts before this checkpoint (do not redesign them):

- `GelRow` and `GelRows` represent reflected message rows only. Keep those
  meanings and their public fields/methods intact.
- `GelText.menu` currently renders only `(List GelRow)` message rows.
- `GelStep.handle-idle` handles `q` then Escape, derives message rows from the
  TOS mirror, and interprets digits as one-based message indexes.
- `GelStep.pending` stores `(List GelRow)` for a selected arity-one message.
  Value selection is immediate and must never enter this pending-send path.
- `GelStack.items` remains `(List Mirror)` with first as TOS. A selected list
  value is pushed above the list, leaving the list as history.
- Idle Escape pops with a one-item floor. Pending Escape cancels without
  popping. `q` quits from either state.
- The current key parser maps only digits `1`–`9` to nonzero menu indexes.
  `0`, multi-character digit strings, letters, and named keys map to zero.
- Current Point, Int, pending-send, typed-pick, and integer-entry menus are
  derived message surfaces and must remain byte-for-byte.

## Exact file scope

**May edit during implementation:**

- `gel/menu.aloe` (Gel-local `List` adapter and value/menu row data)
- `gel/loop.aloe` (render and select the new value menu while preserving
  message and pending behavior)
- `examples/gel-list.aloe` (new in-memory list launch application)
- `tests/checkpoint-110.rkt` (new)
- `CHECKPOINTS.md` (append checkpoint 110 only)
- `docs/gel.md` (current List/menu behavior only)
- `docs/handoff.md` (current state and next pressure only)
- `docs/gel-directory-surface.md` status/progression notes only after the
  checkpoint is green; do not change the locked screen or deferred scope
- `docs/decisions.md` (optional short dated note: List values are a Gel-local
  authored surface built through existing reflection)

**Do not edit:**

- `aloe/`, including evaluator, checker, parser, `Mirror`, and `Signature`
- `host/`, including Term, filesystem, and both runners
- `gel/stack.aloe` and `gel/main.aloe`
- `lib/`, including `lib/list.aloe`, `lib/disk.aloe`, and `lib/fs.aloe`
- `examples/gel-point.aloe`, Point, Boids, MPL, or unrelated examples
- `bin/aloe`
- `SPEC.md`
- historical checkpoint documents or tests 1–109
- filesystem tests or documentation beyond the permitted current-status note

Do not begin checkpoint 111's item-key policy or checkpoint 112's live
directory integration in this change.

## Required behavior

### Exact mirror normalization

In `gel/menu.aloe`, add one stateless service that normalizes ordinary values
to mirrors while retaining existing mirrors by identity:

```aloe
(define-class GelMirrors
  (fields)
  (methods
    (of (value Mirror) Mirror
      value)

    (of (type T)
      (value T)
      Mirror
      (Mirror of value))))

(define gel-mirrors (GelMirrors new))
```

Lock:

- The exact `Mirror` overload wins over the generic overload.
- A `(List Mirror)` therefore yields its original mirrors, not mirrors whose
  subjects are other mirrors.
- This service only supports the `List` adapter below. Do not move it to the
  kernel, add unwrapping, or replace `GelStack.push` behavior.

### Gel-local `List` adapter

Add a nominal carrier:

```aloe
(define-class GelListValues
  (fields
    (items (List Mirror)))
  (methods))
```

Then add exactly one Gel-owned method to built-in `List`:

```aloe
(define-methods List
  (methods
    (gel-values () GelListValues
      (GelListValues new
        (self map
          (fn (value)
            (gel-mirrors of value)))))))
```

Lock:

- This code lives in `gel/menu.aloe`, not `lib/list.aloe` or the Racket List
  implementation.
- Every list element becomes one mirror in original list order.
- Ordinary elements are mirrored once. Existing Mirror elements retain exact
  mirror identity through `gel-mirrors`.
- Empty lists produce `GelListValues` with an empty `(List Mirror)`.
- Do not add `gel-values` to any other class in this checkpoint.
- Do not expose `gel-values` as a general Gel hook, protocol, plugin API, or
  host boundary. Its sole supported producer is built-in `List` while Gel is
  loaded.
- `gel-values` is an ordinary zero-argument message. It is not a special form,
  computed selector, or alternate evaluation rule.

### Value row data

Add these nominal row classes in `gel/menu.aloe`:

```aloe
(define-class GelValueRow
  (fields
    (index Int)
    (value Mirror))
  (methods))

(define-class GelValueRows
  (fields
    (items (List GelValueRow)))
  (methods
    (len () Int
      ((self items) len))

    (select (index Int) GelValueRow
      ((self items) fold
        ((self items) first)
        (fn (found candidate)
          (if ((candidate index) = index)
              candidate
              found))))))
```

`GelValueRows.select` has the same valid-index precondition as
`GelPicks.select`: callers check `1 <= index <= len` first. Do not call it on
an empty row set or invalid index.

Give `GelMenus` (or an equivalent stateless builder) a method whose parameter
is `GelListValues` and whose result is `GelValueRows`. Pass the reflective
invoke directly into that typed parameter:

```aloe
(self value-rows
  (mirror invoke signature))
```

That parameter supplies `Mirror.invoke`'s required expected result type. Do
not first bind the invoke result to an unconstrained `let` name; its result
type would otherwise remain fresh when the body tries to send `items`.

Rows are one-based and preserve source list order. Build only the first nine
rows:

```aloe
(((mirrors fold
    (List empty)
    (fn (rows value)
      (if ((rows len) < 9)
          (rows cons
            (GelValueRow new
              ((rows len) + 1)
              value))
          rows)))
  reverse))
```

The exact helper/method containing that fold is an implementation choice, but
its input is `(List Mirror)` and its result is `GelValueRows`.

Lock:

- A list with 0–9 elements gets the same number of visible rows.
- A list with more than nine elements shows only its first nine in this
  checkpoint. Later elements are not rendered or selectable.
- This truncation is the explicit temporary boundary while paging/search are
  deferred. Do not display an unselectable row `10`.
- No page number, overflow marker, search row, continuation row, or two-key
  address is added yet.
- `index` is presentation position, not a permanent item key contract.

### Message-versus-value menu

Add an explicit menu sum and service in `gel/menu.aloe`:

```aloe
(define-class GelMenu
  (constructors
    (Messages (fields (rows (List GelRow))))
    (Values (fields (rows GelValueRows))))
  (methods))

(define-class GelMenus
  (fields)
  (methods
    ...))

(define gel-menus (GelMenus new))
```

`(gel-menus of mirror)` takes exactly one `Mirror` and returns `GelMenu`:

1. Scan `(mirror signatures)` in declaration order.
2. Collect only signatures whose selector name is exactly `"gel-values"`
   and whose parameter count is zero.
3. If no such signature exists, return
   `(GelMenu Messages (gel-rows of mirror))`.
4. If it exists, invoke the first matching owned signature through
   `(mirror invoke signature)` with the expected result type
   `GelListValues` supplied by the typed value-row builder above, build rows
   from `(result items)`, and return
   `(GelMenu Values rows)`.

The List adapter installs exactly one matching signature. The service must not
construct a `Signature`, redispatch by a computed selector, call
`(list gel-values)` directly after unwrapping, or inspect raw printer text.

This signature recognition is private implementation machinery for built-in
List. Do not advertise arbitrary classes implementing `gel-values`; no public
authored-surface protocol is accepted by this checkpoint.

Keep `GelRow`, `GelRows`, and the `gel-rows` binding intact. Direct lower-level
`gel-rows` calls still mean reflected message rows. `GelMenu` chooses which
kind of rows the user-facing menu and idle key step consume.

### Value-row text

Extend `GelText` in `gel/loop.aloe` with value-row rendering. One row is:

```text
index␠␠raw-value\r\n
```

For example:

```text
1  "alpha"\r\n
2  "beta"\r\n
3  "gamma"\r\n
```

Use `(row value)`'s `raw` message. Do not call an optional subject `show`
method, unwrap the mirror, or add punctuation/type labels.

Add a helper that cases on `GelMenu`:

- `Messages` delegates to the existing `rows-text` unchanged.
- `Values` folds `(rows items)` through the new value-row line helper.

Route all non-pending public menu overloads through `(gel-menus of mirror)`:

- `(gel-text menu mirror)` uses that exact mirror;
- `(gel-text menu ordinary-value)` reflects once, then uses the same route;
- idle `(gel-text menu step)` uses the TOS mirror; and
- pending `(gel-text menu step)` remains the existing pending renderer and
  does not construct a value menu.

Consequences:

- A nonempty List menu contains only its visible values. It contains no
  `empty?`, `first`, `rest`, `cons`, `len`, `map`, `fold`, `reverse`, or
  internal `gel-values` message row.
- An empty List menu is the empty string. TOS text still prints the List
  structurally before that empty menu.
- Point, Int, String, class, host receiver, and all unfamiliar-object menus
  retain their existing derived bytes.
- Pending-send and matching-pick text remain byte-for-byte.

### Value selection

Refactor only the non-command part of `GelStep.handle-idle` so it cases on
`(gel-menus of ((self stack) tos))`:

- `Messages` follows the existing message-row behavior exactly.
- `Values` follows the value-row behavior below.

It is acceptable to move the existing message-index body into a method such
as:

```aloe
(handle-messages
  (rows (List GelRow))
  (key GelKey)
  GelStep
  ...existing behavior...)
```

Do not alter that behavior while moving it. In particular, arity zero invokes
immediately, arity one becomes pending, other arities return an idle state,
and existing invalid-message-index behavior is not part of this checkpoint.

For a `Values` menu:

1. Read `(key menu-index)`.
2. If the index is zero or greater than `(rows len)`, return `self` without
   changing the stack or state.
3. Otherwise select the valid `GelValueRow`, push its `(row value)` through
   the exact `GelStack.push(Mirror)` overload, and return:

   ```aloe
   (GelStep new
     ((self stack) push (row value))
     #f
     (List empty)
     0
     #f)
   ```

Lock:

- Selection pushes the exact row mirror by identity. It does not invoke a
  signature or unwrap/re-reflect the value.
- The List mirror remains immediately below the chosen value as history.
- Selection is immediate: it never populates `pending` and never treats the
  element as an argument to a List message.
- `q` and Escape remain handled before menu selection exactly as checkpoint
  109 specifies.
- `u`, `0`, letters, named keys, and out-of-range digits are no-ops on the
  value menu for now.
- After selection, the new TOS gets its own ordinary derived or value menu.
- Idle Escape returns from the selected value to the same List mirror.

Do not add a `choose` send to List, a computed-selector send, or a second
stack evaluation rule.

### In-memory launch application

Add `examples/gel-list.aloe`:

```aloe
(define gel-start-value
  (List of "alpha" "beta" "gamma"))
```

The file contains only that binding. It does not load Gel or a library,
mention `term`, build a stack, call `gel-main`, or perform output.

The checkpoint-108 application-supplied runner remains unchanged and can
launch it with:

```sh
racket host/racket/gel-run.rkt examples/gel-list.aloe
```

## Tests and hand checks

Add `tests/checkpoint-110.rkt`. Use ordinary checked drivers and scripted
production Term receivers. Automated tests must not require a physical TTY.

Cover at least:

1. `GelMirrors.of`, `List.gel-values`, `GelValueRow`, `GelValueRows`,
   `GelMenu`, and `GelMenus.of` have the specified types. These names remain
   absent from a fresh default driver before Gel is loaded.
2. `(List of 10 20 30)` produces three value rows in source order with
   one-based indexes and mirror subjects `10`, `20`, `30`.
3. A `(List Mirror)` preserves each original mirror by identity through
   `gel-values` and its value rows; no row contains a mirror whose subject is
   another Mirror.
4. An empty typed list produces `GelMenu.Values` with zero rows and renders
   an empty menu without an error.
5. A ten-or-more-element list renders and exposes exactly the first nine
   values. There is no row `10`, overflow marker, next/search action, or way
   to select the hidden tenth value.
6. List menu text is exactly the one-based index, two spaces, raw value, and
   CRLF per row. It contains none of the List message selectors or the private
   `gel-values` selector.
7. `(gel-text menu list)`, `(gel-text menu (Mirror of list))`, and idle
   `(gel-text menu step)` produce identical value-row bytes.
8. Point, Int, and pending Point/Int menu transcripts retain their existing
   exact bytes. Unfamiliar objects still receive `GelMenu.Messages`.
9. A valid digit pushes the selected exact mirror, leaves the List mirror
   directly below it, clears no unrelated history, and stays out of pending
   mode. Escape restores that exact List TOS.
10. `0`, `u`, a letter, a named key, and an out-of-range digit are no-ops on
    Lists shorter than nine. `q` still quits and Escape still pops/floors.
11. A nested List value pushes as an ordinary selected mirror and then gets
    its own value menu.
12. A scripted `gel-main start` over `(List of 10 20)` with keys
    `("2" "escape" "q")` renders the two value rows, pushes `20`, redraws
    its Int menu, echoes Escape, redraws the original List value menu, and
    returns the original one-item stack by observable contents.
13. `examples/gel-list.aloe` has the exact minimal binding and launches
    through the unchanged application-supplied runner contract.
14. Source/dependency assertions confirm no `aloe/`, host, runner, filesystem,
    or reusable library change; default drivers remain capability-free.
15. Checkpoints 108–109 and the full existing suite remain green.

When testing an empty list, give it a concrete element type through context or
derive it from a nonempty list's `rest`; do not weaken `List empty` inference.

### Pure hand check

With Gel loaded, evaluate:

```aloe
(define values (List of "alpha" "beta" "gamma"))
(define stack (gel-empty-stack push values))
(gel-text menu (stack tos))
(define step
  (GelStep new stack #f (List empty) 0 #f))
(define chosen (step handle-key "2"))
(((chosen stack) tos) subject)
(((chosen handle-key "escape") stack) tos)
```

Expected menu:

```text
1  "alpha"
2  "beta"
3  "gamma"
```

The chosen subject is `"beta"`. The final TOS is the original List mirror.

### Physical-TTY hand check

When `tui-term` and a physical TTY are available:

```sh
racket host/racket/gel-run.rkt examples/gel-list.aloe
```

The menu shows the three values, not List methods. Press `2` to push
`"beta"`, Escape to return to the list, then `q` to leave and restore the
terminal.

The scripted equivalent is required; this physical check is informative when
the optional dependency or a real terminal is unavailable.

## CHECKPOINTS.md and handoff

Append only:

```text
## 110. [Gel List value rows](docs/checkpoints/0110-gel-list-value-rows.md)

- A List TOS presents up to nine directly choosable value rows through a
  Gel-local Aloe adapter; selection pushes the exact value mirror and Escape
  returns to the list. Item-key policy and filesystem integration remain
  deferred.
```

Update `docs/handoff.md` to say tests are green through 110 on
`experiment/gel-directory-surface`; application launch, back/pop, and
in-memory List value selection are complete; and collision-free item-key
policy is the next pressure. Do not claim a Directory surface, `u`, paging,
search, `fs-host` injection, or a live directory start.

Update current List/menu paragraphs in `docs/gel.md`. After the checkpoint is
green, `docs/gel-directory-surface.md` may mark progression item 3 complete
and item 4 next without choosing that policy in the design document.

## Acceptance

This checkpoint is complete when a List TOS shows and selects its first nine
values through existing Aloe reflection, selected mirrors are pushed without
double wrapping, back returns to the List, unfamiliar objects retain derived
message menus, and no kernel, host, key-policy, or filesystem work has begun.

Run:

```sh
raco test tests/checkpoint-110.rkt
raco test
git diff --check
```

The checkpoint test and full suite must pass. Run both hand checks where the
optional TTY is available. Stop for review without committing and without
starting checkpoint 111.

## Explicit non-goals

- No final item-key alphabet or collision-free key-pool abstraction. Digits
  are a provisional bridge to checkpoint 111.
- No visible or selectable row 10, paging, next/previous, search, armed
  window, prefix tree, multi-column layout, or overflow UI.
- No `Directory` surface, `u`/`parent`, `fs-host`, directory runner, live
  start value, filesystem load, path operation, or process-wide `chdir`.
- No generic authored-surface protocol, plugin/hook/extension API, GelFS
  package, pane, or workspace framework.
- No File surface, reading, size, enter, `(here entries)`, Git, process,
  editor, shell, selection set, copy, move, or mutation.
- No changes to stack storage, pop semantics, argument picking, pending-send
  behavior, integer entry, extra stack-level rendering, or Point application.
- No kernel List/Mirror primitive, host crossing type, host method, default
  capability, new Aloe syntax, special form, dispatch rule, inheritance,
  macro, or implicit numeric coercion.
- Do not implement checkpoint 111 in the same change.
