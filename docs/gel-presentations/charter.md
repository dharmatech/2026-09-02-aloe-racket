# Charter — Gel presentations (TOS stays the specimen)

**Status.** Handoff from a brainstorm conversation into a **design
conversation**. Not Aloe law. Not Gel law. Not a checkpoint. Not an
implementer assignment. Specification:
[`docs/gel-presentations/spec.md`](spec.md).

**Your job.** Turn this charter into a specification for the first Gel
presentations experiment. Then **stop**. Do not write checkpoints. Do
not implement. Do not open a second product called Listener or Genera.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter and the authority files in §8.
2. Resolve the open questions in §7.
3. Write a specification (this folder's `spec.md`). The spec is what
   a later checkpoint-manager conversation will slice into
   **gel-presentations 000**, `001`, … under
   `docs/gel-presentations/checkpoints/` (not `docs/checkpoints/0118`).
4. Stop. The human reviews it. The spec conversation does not write
   those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A CLIM clone, a presentation
type lattice, command tables, and translators are defects in this
document. So is leaving `define-methods Directory` in place.

---

## 2. Why this experiment exists

GelFS currently lights up a live `Directory` by installing Gel-private
methods onto disk types after `lib/disk.aloe` loads:

- `Directory`: `gel-tos-text`, `gel-directory-values`,
  `gel-directory-all-values`, `gel-up`
- `File`, `SymbolicLink`, `Other`: `gel-tos-text`
- `List`: `gel-values` in `gel/menu.aloe`

`lib/disk.aloe` never mentions Gel. That was the old “Disk stays
Gel-ignorant” rule. It is only half a rule. Once Gel loads, those
classes grow methods. `GelMenus` / `GelText` / `u` find them by
string-matching selector names on `Mirror` signatures. The `gel-`
prefix is a nametag, not a scope.

That is monkey-patching. It is also how Glamorous Toolkit’s inspector
works (`gtView` on the domain class). It does not scale to a process
that has loaded disk, Gel, MPL, a process browser, and a workspace
together. Two applications can both add `gel-tos-text`. Reflection
shows a pile of methods that are not the disk vocabulary. A “private”
send is still a public send.

The live-image rule is the missing half:

> Somebody should be able to load every library and application into
> one image and have them play together.

After every file is loaded, `Directory` still only answers disk.
Gel still browses directories. Nobody had to win the method table.

`define-methods List` for `fold` / `map` is different: that is the
library finishing `List`. Gel hanging `gel-values` on `List` is the
same smell as Gel hanging `gel-directory-values` on `Directory`.

---

## 3. Live-image bar (acceptance)

The specification is wrong unless all of these are true:

1. `lib/disk.aloe` and Gel can load in the same process.
2. A live `Directory` can sit on the stack and be browsed (listing,
   hidden names, paging, `u`, child push, TOS path text).
3. After Gel is loaded, `Directory`, `File`, `SymbolicLink`, and
   `Other` still have only the disk vocabulary from `lib/disk.aloe`.
   No `gel-tos-text`, `gel-directory-values`, `gel-directory-all-values`,
   or `gel-up` on those classes.
4. After Gel is loaded, `List` still has only the list library
   vocabulary for this concern. No `gel-values` on `List` if that
   adapter is in the spec’s first slice; if List is deferred, the spec
   must say so and must not pretend the live-image rule is done.

The observable directory browser does not shrink. Checkpoints 112–117
behavior stays: children as the menu, 22-row page, idle `n` / `p`,
`.` hidden toggle, `u` parent, Escape pop, `q` quit, filesystem TOS
text, labels `/` and `@`. Paging is **frozen**: the experiment moves
where those behaviors live, it does not redesign them.

---

## 4. Locked by the brainstorm (do not reopen)

These are decided. Argue against them only if the spec is impossible
without breaking one. Do not spend the design conversation re-ranking
the brainstorm.

1. **TOS subject is the specimen.** A `Directory` on the stack is a
   `Directory`, via `Mirror`. Not a `GelDirectory` wrapper. Not a
   `FileSystemBrowser` session object.
2. **Equipment lives in Gel.** Directory and File must not know about
   Gel. Gel’s filesystem module **should** know about Directory and
   File. That is the practical split.
3. **Presentations, not patches.** Gel associates a presentation with
   an object by Aloe type. Commands and TOS text come from that
   presentation. This is Option B spoken in Genera’s vocabulary: a
   triple of (object, presentation type, visual). Cut down to what
   GelFS needs. Not a wrapper painted as a directory with an asterisk.
4. **No inheritance.** Wrappers-as-TOS are expensive here because
   Aloe cannot forward. Do not add inheritance to make wrappers cheap.
5. **No kernel type classes.** Aloe protocols today are extra types,
   not a second method table (`SPEC.md` §3.3). Do not invent
   generic-function dispatch or a protocol-owned method table to
   unblock this. If a dictionary is needed, it is a Gel object.
6. **Do not monkey-patch disk types or `List` for Gel.**
7. **Gel grows toward Genera in a terminal; it is not a second
   product.** `docs/gel.md` reserves the name **Listener** for a
   Genera-style typed REPL. This experiment does not rename Gel, does
   not implement Listener, and does not start a sibling codebase.
   Presentations inside Gel are the first bone of that environment.
8. **Browser-as-TOS is filed away.** A `FileSystemBrowser` session
   object on the stack is a future curiosity, not this design.
9. **C# extension-method sugar is not a separate design.** Methods on
   a Gel class that take a `Directory` are a spelling of presentations.
   They are invisible to `Mirror` of the specimen, which is what we
   want.
10. **Revisit the old Gel sentence** “Gel itself does not grow a
    framework per personality.” That sentence pushed knowledge into
    magic methods on `Directory`. A small explicit presentation, owned
    by Gel and indexed by type, is smaller than a stringly-typed
    protocol on every library class. The spec should propose
    replacement wording for `docs/gel.md` / `docs/gel-directory-surface.md`.

---

## 5. What to design (candidate 1)

Gel-owned presentation objects, indexed by Aloe types, with the
specimen remaining TOS.

Sketch of the intended split (the spec may name things differently):

| Lives in | Examples |
|---|---|
| Disk (`lib/disk.aloe`) | `entries`, `parent`, `text`, `name` |
| Listener / stack (`GelStep`, `GelStack`) | paging, hidden toggle, path, keys |
| Gel presentation (new, Gel-owned) | TOS text, value rows, `u` / parent presentation, filesystem labels |

The presentation **uses** disk messages. It does not install Gel
messages on disk classes.

Aloe’s type system is the index. Genera needed a parallel presentation
type lattice because Lisp types did not carry UI. We already have
`Directory`, `File`, `SymbolicLink`, `Other`, `List`. Do not clone
CLIM’s type lattice, `present`/`accept`, translators, or command
tables in this spec.

Vimium is the keyboard rhyme: hint labels over things that were
already presentable. The listing should feel like hintable
presentations of children, not like `Directory` grew a keyboard API.

You already have a germ of multiple presentations: authored listing vs
`.` (raw `Mirror`). Do not implement a cycle key. Do not paint the
spec into a corner that makes a later cycle key impossible.

---

## 6. In scope / out of scope

**In scope for the specification**

- Where presentation objects live (`gel/` modules, load order).
- How `GelMenus`, `GelText`, and `u` find a presentation **without**
  scanning for `"gel-tos-text"` / `"gel-directory-values"` /
  `"gel-up"` / `"gel-values"` on the specimen’s method table.
- How Gel recognizes “this `Mirror` is a `Directory`” (and File,
  SymbolicLink, Other, and List if included) without asking the
  specimen a Gel question. This is the typed-language problem Scheme
  and the Lisp machine did not have. It is the whole experiment.
- Proof of the live-image bar (tests: signatures of disk classes after
  Gel load).
- What happens to `gel/directory.aloe`’s `define-methods` blocks.
- Whether `List.gel-values` moves onto the same substrate in this
  spec’s first implementation slices, or is a named follow-up. Prefer
  including it in the **design** even if checkpoints do Directory
  first: one substrate, two personalities, not two mechanisms.
- Proposed doc amendments (`docs/gel.md`,
  `docs/gel-directory-surface.md`, private-seam language in
  checkpoints 110–117). Those amendments are applied later, by
  checkpoints, not in this conversation.
- A “do not paint into a corner” note for: cycling presentations,
  a second personality, history as live presentations.

**Out of scope (do not specify as this experiment)**

- Browser / session object as TOS.
- Wrapper-as-TOS, forwarding, inheritance.
- Asterisk-proxy (“TOS looks like a Directory but is a wrapper”).
- Kernel type classes, generic functions, protocol-owned method tables.
- Fuller Genera: command tables, presentation translators, input
  context, transcript-wide mouse/keyboard sensitivity, history as
  live presentations, cycling views.
- Mouse in the terminal.
- Changing paging, hidden names, item-key pool, or Directory UX.
- Editing `aloe/` or `host/` unless the spec proves type recognition
  is impossible without a `Mirror` affordance. If you believe a
  kernel/`Mirror` change is required, say so as an open language
  question with the smallest possible hatch. Default: solve it in
  Gel with existing reflection and types.
- Implementing anything.

**Paging is frozen.** Checkpoints 112–117 stay the UX authority for
the directory surface. The spec relocates implementation; it does not
reopen that UX.

---

## 7. Open questions the spec must answer

1. **Type recognition.** How does Gel know the TOS subject is a
   `Directory` (etc.) without a method on that class? Enumerate
   options you actually have (class identity on `Mirror`, a Gel
   registry keyed by something `Mirror` already exposes, an explicit
   GelFS entry point that constructs a presentation once, a typed
   `case` you can run, something else). Pick one. “String-match a disk
   selector like `entries`” is a hack; reject it unless nothing else
   works.
2. **Stack representation.** `GelStack` stores `(List Mirror)`. Does
   TOS remain `Mirror of directory` with Gel looking up a presentation
   beside it, or does the stack store a pair? The subject the user is
   standing on must still be the disk object. A presentation field on
   `GelStep` is allowed if that is cleaner than stuffing the
   presentation into the mirror.
3. **Presentation shape.** One registry service (`GelPresentations`)
   plus small per-type objects? Methods on `GelDirectoryPresentation`
   that take a `Directory`? A presentation that *holds* a directory as
   a field (careful: that starts to look like a wrapper; if the
   presentation is never TOS, holding a field is fine)?
4. **Optional operations.** Directory needs listing + `u` + TOS text.
   File needs TOS text and the derived message menu. Same protocol
   with missing pieces, or different presentation classes?
5. **`u` and parent.** Today `gel-up` is a method on `Directory`.
   After the move, who sends `(directory parent)` and who pushes the
   resulting live object?
6. **List.** Same substrate in this spec, or a written follow-up with
   the live-image hole named?
7. **Load and registration.** Who registers the filesystem
   presentation, and when? `gel/directory.aloe` may remain the
   filesystem module; it must stop calling `define-methods` on disk
   types.
8. **Tests.** What is the smallest proof that disk class signatures
   did not grow, and that the directory runner still behaves?
9. **`docs/gel.md` reserved name Listener.** Confirm: this work stays
   named Gel; presentations are internal equipment; Listener remains
   reserved.

If two answers both pass the live-image bar, pick the smaller one.

---

## 8. Authority

Read, in order:

- `SPEC.md` (language law)
- `docs/philosophy.md`, `docs/decisions.md`
- `docs/gel.md` (Gel law today; this experiment may propose amendments)
- `docs/gel-directory-surface.md` (directory UX; paging/hidden/listing)
- `docs/filesystem-oo-vocabulary.md` (disk messages)
- `lib/disk.aloe`, `lib/list.aloe` (must not gain Gel methods)
- `gel/directory.aloe`, `gel/menu.aloe`, `gel/loop.aloe` (current seams)
- Checkpoints 110–117 under `docs/checkpoints/` (current adapter
  history; their “private seam” language is what we are replacing)

Parent branch: `experiment/gel-directory-surface` with paging (117)
already green and **frozen**.

Do not start from `main`. Do not merge to `main` in this work.

---

## 9. Ranked leftovers (not this spec)

1. **This experiment** — Gel presentations, TOS stays the specimen.
2. **Filed** — browser as TOS (session object). Experimental, later.
3. **Later Gel-as-Genera** — multiple presentations and a cycle key;
   then command tables, translators, transcript-wide sensitivity,
   history as live presentations. Same program (Gel), later design
   conversation, not a sibling codebase.
4. **Wings** — language-level type classes, if a second application
   needs a real dictionary.

---

## 10. Deliverable

One specification document that a checkpoint-manager conversation can
slice into small **gel-presentations 000**, `001`, … files under
`docs/gel-presentations/checkpoints/` (not `docs/checkpoints/0118`).

The spec must include:

- The live-image bar copied as acceptance.
- The chosen type-recognition mechanism.
- Module and class sketch (names, who owns what, load order).
- What is deleted from `Directory` / `File` / `SymbolicLink` /
  `Other` / `List`.
- How `GelMenus`, `GelText`, and `u` change.
- A first vertical slice suggestion (what gel-presentations 000
  could be), without writing the checkpoint file.
- Explicit non-goals from §6.

When the spec is written, stop.
