# Charter — Gel presentation catalog

**Status.** Handoff from a brainstorm conversation into a **design
conversation**. Not Aloe law. Not Gel law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md).

**Your job.** Turn this charter into a specification for the first Gel
catalog experiment. Then **stop**. Do not write checkpoints. Do not
implement. Do not reopen gel-presentations 001. Do not issue
gel-presentations 004. Do not implement a process personality. Do not
start a second product called Listener or Genera.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority files in §8.
2. Resolve the open questions in §7.
3. Write a specification (this folder's `spec.md`). The spec is what
   a later checkpoint-manager conversation will slice into
   **gel-catalog 000**, `001`, … under
   `docs/gel/catalog/checkpoints/` (not `docs/checkpoints/0118`, not
   `docs/gel/presentations/checkpoints/004-…`).
4. Stop. The human reviews it. The spec conversation does not write
   those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A plugin framework, a
mutable `register!`, a process browser, command tables, and moving
`show-hidden` / `page` off `GelStep` in this experiment are defects
in this document.

---

## 2. Why this experiment exists

gel-presentations 000/002/003 solved one half of the live-image bar:
filesystem classes no longer contain Gel methods. Gel's generic
machinery still knows that Directory is special:

- `gel/menu.aloe` has `directory-index`, `directory-signatures`,
  `directory?`, and a Directory-specific branch in `GelMenus.of`.
- `gel/loop.aloe` puts `show-hidden` and `page` directly in every
  `GelStep`.
- `gel/loop.aloe` renders Directory status and the `u`, `.`, `n`,
  and `p` commands itself.
- `gel/loop.aloe` has Directory-aware transitions for paging and
  hidden names.
- `gel/directory.aloe` installs a specially named
  `directory-presentations` method on `GelMenus`.

That last mechanism is a one-entry registry disguised as an
extension method. It was a reasonable way to prove the presentation
idea. Adding `process-presentations`, `repository-presentations`,
and so forth would reproduce the same knowledge across `GelMenus`,
`GelText`, and `GelStep`.

The current code is compact. The spill is understandable: Directory
was the first serious authored personality. Now that the first
specimen has established the behavior, a catalog can replace the
special index without turning Gel into a speculative plugin
framework.

---

## 3. Live-image bar (acceptance)

The specification is wrong unless all of these remain true, and the
new catalog bar in item 5 holds:

1. `lib/disk.aloe` and Gel can load in the same process.
2. A live `Directory` can sit on the stack and be browsed (listing,
   hidden names, paging, `u`, child push, TOS path text).
3. After Gel is loaded, `Directory`, `File`, `SymbolicLink`, and
   `Other` still have only the disk vocabulary from `lib/disk.aloe`.
4. After Gel is loaded, `List` still has only the list library
   vocabulary for this concern. No `gel-values` on `List`.
5. **Catalog bar.** Adding a second authored personality must not
   require another conditional in Gel's central loop, nor another
   specially named index method on `GelMenus`. The proof in this
   experiment may be a test-double presentation in the catalog, not
   a real process application. If the generic resolver still
   string-matches `"directory-values"` or asks `directory?`, the
   seam is still too narrow.

The observable directory browser does not shrink. Checkpoints
112–117 behavior stays: children as the menu, 22-row page, idle
`n` / `p`, `.` hidden toggle, `u` parent, Escape pop, `q` quit,
filesystem TOS text, labels `/` and `@`, listing count, `page N of
M`, dimmed `n` / `p` when that move is a no-op. Paging is
**frozen**: this experiment moves where lookup lives, it does not
redesign Directory UX.

---

## 4. Locked by the brainstorm (do not reopen)

These are decided. Argue against them only if the spec is impossible
without breaking one. Do not spend the design conversation
re-ranking the brainstorm.

1. **TOS subject is the specimen.** Unchanged from gel-presentations.
   A `Directory` on the stack is a `Directory`, via `Mirror`.
2. **Immutable catalog, assembled by the application.** Something
   conceptually like:

   ```text
   Gel application
     catalog:
       core/list presentation
       directory presentation holding fs-host
       (later) process presentation holding process-host
   ```

3. **No mutable global `register!`.** An ordinary immutable catalog
   value passed into `GelMain` or a Gel session fits Aloe better,
   avoids load-order magic, and preserves capability discipline.
4. **Capability discipline.** Only the filesystem application
   includes the presentation holding `fs-host`. Only a process
   application would include one holding process authority. Ordinary
   Point Gel does not hold `fs-host`.
5. **One generic resolver.** Gel's generic machinery is the one
   place that uses `Mirror`, `Signature`, and `accepts?` to find an
   applicable presentation operation. Reflection stays; it is
   localized. Adding a process presentation should require adding
   `gel/process.aloe` and including its presentation object in the
   catalog, without modifying `menu.aloe`, `loop.aloe`, or
   `main.aloe`.
6. **Delete the special Directory index.** The arity-zero
   `directory-presentations` method on `GelMenus` goes away. So do
   `directory-index`, `directory-signatures`, and `directory?` as
   Directory-named APIs. Lookup walks the catalog.
7. **Do not monkey-patch disk types or `List`.** Live-image bar
   from gel-presentations remains law.
8. **No inheritance, no kernel type classes, no wrappers-as-TOS.**
   Unchanged from gel-presentations.
9. **This work stays named Gel.** Presentations and the catalog are
   internal equipment. **Listener** remains reserved. Do not
   implement a process browser in this experiment.
10. **Do not move presentation-local state out of `GelStep` yet.**
    `show-hidden` and `page` stay on the universal `GelStep` until a
    later second personality, probably processes, demonstrates the
    required shape. A lookup catalog alone will not solve that
    leak; do not pretend it does.
11. **Paging / hidden / listing / keys / TOS path bytes / status /
    dimmed `n` `p` are frozen.** Predecessor global 112–117 plus
    gel-directory-status 000 and gel-directory-dim 000.
12. **gel-presentations 001 stays blocked.** Do not implement it.
    Do not rewrite it. Do not issue 004 under that project.

---

## 5. What to design (candidate 1)

An application-supplied catalog of Gel-owned presentation objects,
with a generic resolver that probes those objects — not the
specimen, and not a specially named index on `GelMenus`.

Sketch of the intended split (the spec may name things differently):

| Lives in | Examples |
|---|---|
| Disk (`lib/disk.aloe`) | `entries`, `parent`, `text`, `name` |
| Listener / stack (`GelStep`, `GelStack`) | paging, hidden toggle (still universal for now), keys |
| Presentation object | TOS text, authored value rows, `u` / parent, filesystem labels |
| Catalog (new, application-owned value) | ordered set of presentation objects this session may use |
| Generic resolver (Gel) | `Mirror` / `Signature` / `accepts?` over the catalog |

The presentation **uses** disk messages. It does not install Gel
messages on disk classes. The catalog **holds** presentation
objects. It does not become TOS.

A complete presentation boundary eventually needs more than “how do
I render this object?” It needs some notion of:

- Authored value rows
- Status or supplementary text
- Available command rows
- Whether a command is enabled
- What transition a command performs
- Any presentation-local state

For example, hidden-name visibility belongs to the Directory
presentation. `u` should eventually be an offered presentation
command rather than a universal Gel branch. Paging might prove to
be generic Gel behavior, but that should be because a presentation
declares a pageable collection — not because `GelStep` asks whether
TOS is a Directory.

**This experiment does not build that complete boundary.** It
replaces the one-entry index with a catalog and makes menu and TOS
lookup uniform. Commands-as-data are a door to leave open. Moving
state off `GelStep` is a later experiment, gated on a second
personality.

---

## 6. In scope / out of scope

**In scope for the specification**

- Catalog representation (class, construction, what a slot holds).
- How the application assembles the catalog and passes it into
  `GelMain` or a Gel session. Ordinary Point / List Gel must still
  start.
- How `GelMenus`, `GelText`, and `GelUps` walk that catalog with
  `Signature.accepts?` and **generic** operation names. Personality-
  specific selector names (`directory-values`, `list-values`,
  `directory-presentations`) in the generic resolver are the spill
  this experiment exists to remove.
- What happens to `gel/directory.aloe`'s `define-methods GelMenus`
  index.
- Where List's presentation lives relative to the catalog (always
  present vs application-supplied).
- Proof of the catalog bar: generic Gel source does not mention
  Directory-named index APIs; a second catalog entry can contribute
  TOS text and/or authored values without editing `menu.aloe`,
  `loop.aloe`, or `main.aloe`.
- Proposed doc amendments (`docs/gel.md` §4–§5, the presentations
  leftover that said “optional index is the Directory precedent”).
  Those amendments are applied later, by checkpoints.
- A “do not paint into a corner” note for: commands as data,
  presentation-local state, a real process personality, cycling
  presentations.

**Out of scope (do not specify as this experiment)**

- A real process / repository personality or `gel/process.aloe`.
- Mutable `register!`, load-order side effects, global mutation.
- Moving `show-hidden` / `page` off `GelStep`.
- Command rows as data, enabled-bit, command transitions owned by
  the presentation (sketch the door; do not design the protocol).
- Browser / session object as TOS, wrappers-as-TOS, inheritance.
- Kernel type classes, generic functions, `Mirror.class`, `aloe/`
  or `lib/` edits.
- Fuller Genera: command tables, translators, cycle key, Listener.
- Changing paging, hidden names, item-key pool, status text, dim
  bytes, or Directory UX.
- Implementing anything.

**Paging is frozen.** Checkpoints 112–117 plus directory-status and
directory-dim stay the UX authority. The spec relocates lookup; it
does not reopen that UX.

---

## 7. Open questions the spec must answer

1. **Catalog type.** Is it a `GelCatalog` holding `(List Mirror)` of
   presentation objects? A list of ordinary values that Gel reflects
   on demand? Something else. Pick the smaller one that still lets
   the resolver invoke a matching signature.

2. **Where the catalog lives at runtime.** Field on `GelMain`?
   Copied through every `GelStep`? Argument to `GelMenus.of` /
   `GelText.menu` only? If `GelStep` holds it, that is session
   equipment, not presentation-local state — say so. Do not stuff
   the catalog into `GelStack` items.

3. **Start API.** Today runners eval `(gel-main start
   gel-start-value)`. How does the application supply the catalog
   without load-order magic? A second binding (`gel-catalog`)? An
   overloaded `start`? A session object that is not TOS? If a host
   runner must change, name the smallest change. Prefer keeping
   Point's runner working with a default catalog that includes List.

4. **Generic operation names.** The resolver cannot look up
   `"directory-values"` and `"list-values"` as special cases. What
   selectors does it probe on each catalog entry? Candidates:
   `values`, `tos-text`, `up`. Hidden listings today are a second
   selector (`directory-all-values`) chosen by `GelStep.show-hidden`.
   Keep that split in this experiment if renaming would reopen UX;
   say how the generic resolver chooses between the two without a
   `directory?` predicate.

5. **Lookup order.** Walk the catalog in application order, first
   `accepts?` wins? Last wins (today's `reverse` then `first`)? What
   if two presentations accept the same TOS? Pick one rule.

6. **List personality.** Always in every catalog, or only when the
   application includes it? Ordinary Gel without `gel/directory.aloe`
   must keep Point / List / Int bytes.

7. **Directory paging and commands in the loop.** Stage 1–2 may
   still render `u` / `.` / `n` / `p` and apply the 22-row window
   from universal `GelStep` fields, because moving that out is
   stage 4. How does the loop know to page / toggle hidden / offer
   `u` **without** `directory?`? Options: any Values menu with more
   rows than the key pool is pageable; `up` exists when a catalog
   entry accepts `up`; hidden toggle exists when both listing
   selectors exist. Pick something that does not name Directory in
   `loop.aloe`. If that is impossible without stage 3/4, **stop**
   and say so rather than leaving `directory?` in the loop.

8. **Proof without a process application.** What is the smallest
   second catalog entry that proves the catalog bar? A test-only
   presentation that supplies `tos-text` and/or `values` for a
   boring existing type (for example a tagged test value), loaded
   only by the gel-catalog tests, not by production Gel. Do not
   invent a process host.

9. **Tests.** Smallest proof that:
   - disk / List method tables still did not grow
   - Directory runner bytes (including status and dim) still hold
   - `gel/menu.aloe` and `gel/loop.aloe` no longer contain
     `directory-presentations` / `directory?` / `directory-index`
   - a second catalog entry is found by the same resolver

10. **`docs/gel.md` wording.** Propose replacement for the sentence
    that personalities live on `GelPresentations` plus a Directory
    index. The catalog is an ordinary value, not a plugin API.

If two answers both pass the live-image bar and the catalog bar,
pick the smaller one.

---

## 8. Authority

Read, in order:

- `SPEC.md` (language law)
- `docs/philosophy.md`, `docs/decisions.md`
- `docs/gel.md` (Gel law today; this experiment may propose amendments)
- `docs/gel-directory-surface.md` (directory UX; paging/hidden/listing)
- `docs/gel/presentations/spec.md` (predecessor law; 000/002/003 done,
  001 blocked, no 004)
- `docs/gel/directory-status/` and `docs/gel/directory-dim/` (frozen
  footer and dim bytes)
- `lib/disk.aloe`, `lib/list.aloe` (must not gain Gel methods)
- `gel/directory.aloe`, `gel/menu.aloe`, `gel/loop.aloe`,
  `gel/main.aloe`, `gel/presentations.aloe` (current seams)
- `examples/gel-point.aloe`, `examples/gel-list.aloe`,
  `examples/gel-directory.aloe` (how applications start today)

Parent branch: `experiment/2026-09-11-gel-presentations` with
gel-presentations 003, gel-directory-status 000, and
gel-directory-dim 000 already green.

Do not start from `main`. Do not merge to `main` in this work.

Do not treat gel-presentations `checkpoint-manager.md` as an
assignment. That series is closed.

---

## 9. Ranked leftovers (not this spec's implementation slices)

Evolve in small stages. The spec designs stage 1–2. It sketches
stage 3 as a door. It forbids stage 4.

1. **This experiment** — replace the special Directory index with an
   application-supplied presentation catalog; menu and TOS lookup
   operate uniformly across that catalog.
2. **Later, same program** — presentations contribute commands as
   data, so the loop dispatches generic command rows (`u` becomes an
   offered presentation command).
3. **Later, gated on a second personality** — move genuinely
   presentation-specific state (`show-hidden`, and page if it is
   not generic) out of universal `GelStep`. A process specimen
   should drive that generalization.
4. **Filed** — browser as TOS; cycle key; command tables;
   translators; Listener.

The key acceptance test remains: adding the process personality
should not require another conditional in Gel's central loop. If it
does, the integration seam is still too narrow. This experiment
must make that test *possible*; it must not implement the process
personality in order to pass.

---

## 10. Deliverable

One specification document that a checkpoint-manager conversation
can slice into small **gel-catalog 000**, `001`, … files under
`docs/gel/catalog/checkpoints/` (not `docs/checkpoints/0118`, not
gel-presentations 004).

The spec must include:

- The live-image bar and the catalog bar, copied as acceptance.
- The chosen catalog representation and start API.
- The chosen generic operation names and lookup rule.
- Module and class sketch (names, who owns what, load order).
- What is deleted (`directory-presentations` index and Directory-
  named lookup helpers).
- How `GelMenus`, `GelText`, `GelUps`, and `GelMain` change.
- How the loop pages, toggles hidden, and offers `u` without
  `directory?`, or an explicit stop if that belongs to stage 3/4.
- A first vertical slice suggestion (what gel-catalog 000 could
  be), without writing the checkpoint file.
- Explicit non-goals from §6.

When the spec is written, stop.
