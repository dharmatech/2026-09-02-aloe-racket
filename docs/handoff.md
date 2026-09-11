# Aloe handoff

Read first, in order: `SPEC.md`, `docs/philosophy.md`, `docs/decisions.md`,
`AGENTS.md`, `CHECKPOINTS.md`, this file. If the work touches Gel, also read
`docs/gel.md`. Spec is law. Decisions record accepted and rejected directions;
do not replay rejected designs.

## `experiment/gel-directory-surface`

Stacked on `experiment/filesystem`. Working design:
[`docs/gel-directory-surface.md`](gel-directory-surface.md).

First Gel experiment after the OO disk library: a focused directory
browser on Gel's stack. Not a workspace and not a GelFS framework.
Checkpoints 108–117 complete the first focused live Directory slice, its
path-focused TOS presentation, hidden-name control, and bounded paging. The
Term-only runner still launches ordinary Aloe applications. The separate
filesystem-capable runner starts `examples/gel-directory.aloe` at the
process's live current directory:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

A Directory TOS hides leading-dot names before showing one 22-item page of
immediate children with filesystem labels. Idle `n` / `p` move through
bounded pages; idle `.` persistently toggles visibility. Selection pushes the
nested live object, `u` pushes its live parent, and Escape pops history. Page
resets on those navigation and visibility changes, while hidden visibility
persists. `q` still quits, and pending `.` / `n` / `p` are no-ops.
Live `Directory`, `File`, `SymbolicLink`, and `Other` TOS lines show the class
and escaped absolute path while their structural `Mirror.raw` values remain
unchanged.
The Gel-owned presentation lives under `gel/`; `lib/disk.aloe` remains
Gel-ignorant, and loading Gel does not change disk method tables.
Do not implement later steps from the design file without another checkpoint.

Gel presentations (TOS stays the specimen) is specified in
[`docs/gel-presentations/`](gel-presentations/README.md). Its slices are a
**local** series (`gel-presentations 000`, tests under
`tests/gel-presentations/`), not global checkpoint 118. Do not write
`docs/checkpoints/0118-….md` for that work.
On `experiment/2026-09-11-gel-presentations`, **gel-presentations 000 and 002
are green**. **001 stays blocked; do not implement it.** List values come from
`gel-presentations list-values`. Directory listing, `u`, and TOS path text come
from `GelDirectoryPresentations`, which holds `fs-host`. Disk types and `List`
carry no `gel-*` selectors. Frozen Directory UX from global checkpoints
112–117 is unchanged. This work remains the local `gel-presentations N`
series, not global checkpoint 118.

If the work is still filesystem vocabulary rather than Gel, stay on
`experiment/filesystem` and ignore this section.

## `experiment/filesystem`

Proposal B is implemented through checkpoint 95 and ratified into `SPEC.md`
by [checkpoint 96](checkpoints/0096-ratify-class-constructors.md). Checkpoint
97 merges the sealed typed host boundary from `main` onto that constructor
line. The [Proposal B document](class-constructors.md) remains as historical
design and implementation context; `SPEC.md` is law on this branch. Proposal A
on `codex/unified-nominal-adts` was rejected and is not authority. Constructors
have not been merged to `main`.

## What Aloe is

Aloe is an s-expression language implemented by a definitional interpreter and
type checker in Racket. A list is a **send**, not Scheme apply:

    (receiver selector argument ...)

The selector is a source symbol and is not evaluated. Functions are objects
that understand `call`. Types are static and inferred where the programmer did
not write them.

Slogan: `Scheme + Smalltalk + Types`.

Keep the kernel small. Grow the language from applications, and add host access
only through explicit typed capabilities.

## Current state (0.4 on `experiment/gel-directory-surface`)

- Interpreter and type checker in Racket; no compiler or macros.
- `define-class`, `define-methods`, `fn`/`call`, `let`, `if`/`cond`, `load`,
  and `check`.
- Classes use either the singleton `(fields ...)` / `new` form or an explicit
  declaration-ordered constructor set. Construction is a class-object send.
- Receiver-anchored `case` checks constructor coverage and binds the selected
  payload; generic construction uses payload constraints and expected types.
- Generics, homogeneous `List`, protocols with required methods, and
  C#-style method overloading. Exact argument types beat protocol matches.
- Primitive `Int`, `Float`, `Bool`, `String`, and interned `Symbol` values;
  String supplies kernel `len`/`take` and an Aloe-derived `starts-with?`.
- Boids in `examples/boids.aloe` and `examples/point.aloe`.
- Cohen-style symbolic algebra in `examples/mpl/`, including `Math`, `Sym`,
  `Num`, `Sum`, `Prod`, and `Pow`. `Math` is a protocol supertype and primitive
  `Int` is not implicitly lifted to it.
- Like-term addition, product merging, power merging, and identity unwrapping
  (`x+0`, `x*0`, `x*1`, `x^0`, and `x^1`) are current behavior; a zero
  combined coefficient becomes `Num 0`.
- `Math.show` drives default display; REPL `:raw` retains the structural
  `#<…>` printer.
- `Mirror` and `Signature` provide nominally owned reflection and exact-row
  invocation without adding `perform` to ordinary objects.
- Gel is an Aloe-written keystroke object environment with an immutable
  `GelStack`, reflected menus, typed one-argument pending sends,
  integer entry, and a thin Racket terminal runner. `GelMain.start` accepts
  any ordinary Aloe value, pushes it once from `gel-empty-stack`, and enters
  the existing loop. The runner loads one supplied Aloe application and
  launches its `gel-start-value`; `examples/gel-point.aloe` now owns the
  Point demo. A separate filesystem-capable runner injects `term` and
  `fs-host`, then launches `examples/gel-directory.aloe` at the process's
  current live `Directory`. `GelStack.pop` removes one history item above a
  one-item floor;
  idle Escape pops, pending Escape cancels without popping, and `q` quits from
  either state. `GelMenus` gives built-in List a Gel-owned value presentation
  through `gel-presentations list-values`: the first 22 elements render with
  position-bound letters from `a` through `z`, omitting `n`, `p`, `q`, and
  `u`; selecting one pushes its exact mirror, and Escape returns to the List.
  Lists remain unpaged. `GelDirectoryPresentations`, holding `fs-host`,
  supplies the same value-row shape with `name`, `name/`, and `name@` labels,
  preserving live `File`, `Directory`, `SymbolicLink`, and `Other` mirrors.
  Leading-dot names are omitted before the Directory-only 22-row page window
  by default; idle `.` persistently toggles them while idle `n` / `p` page the
  full filtered listing. Non-Directory and pending `n` / `p` remain no-ops.
  `u` asks only a Directory for its live parent and pushes it, so Escape and up
  are observably different. Those four live disk classes render on TOS with their
  class and existing escaped absolute path through `tos-text` on that
  Gel-owned presentation; other values and `Mirror.raw` retain their
  structural text. Disk types and `List` carry no `gel-*` selectors. Reflected
  menus and pending input retain their digit behavior.
- Typed host capabilities use descriptor-defined interfaces shared by runtime
  dispatch, static checking, driver injection, and reflection.
- Generic fields retain exact injected host-interface types, allowing wrappers
  around capabilities without source-written host type names.
- Tests through checkpoint 117 are green on
  `experiment/gel-directory-surface`. `Option` is loadable from
  `lib/option.aloe` and is not a default-driver binding.
  `lib/fs.aloe` defines `Path`, the four-constructor `Entry`, and generic `Fs`
  with `current`, `path`, `child`, `parent`, `name`, `inspect`, and `entries`;
  it remains unchanged. `lib/disk.aloe` defines generic `Disk`
  and `Location`, `Location.inspect`, generic `Item`, and nested live `File`,
  `Directory`, `SymbolicLink`, and `Other` classes. Live `Directory.entries`
  returns mixed `(List Item)` values; `Location.entries` does not exist.
  The optional production `fs-host` receiver and its test double remain
  explicitly injected. Default drivers still receive neither filesystem nor
  terminal authority. Tag `v0.1.0-boids` records the earlier 0.1 milestone.

## Typed host boundary

A host capability is a Racket-created receiver explicitly injected into a
driver with `driver-inject-host!`. One opaque nominal `host-interface`
descriptor owns ordered, uniquely selected `host-method` declarations. Each
declaration supplies its selector, fixed parameter types, return type, and
Racket implementation.

The current crossing vocabulary is deliberately limited to `Int`, `Bool`,
`String`, and homogeneous `(List String)`. Nested lists and every other
`(List T)` remain excluded. Arguments and results are validated; strings are
normalized to immutable values. Host failures retain their Racket cause under
consistent Aloe context, and breaks pass through.

The same exact interface identity drives the checker, evaluator, and reflected
signature ownership. Interface names appear in diagnostics but cannot be
written as Aloe type annotations. Default environments contain no optional
capability. Term is the first production capability and is injected only by
the optional checked terminal runners.

Do not add handwritten checker facades, capability-specific evaluator paths,
ambient host bindings, or arbitrary Racket calls. If an application cannot be
expressed through the current boundary, specify the blocked golden first and
make any generic boundary extension a separate reviewed checkpoint before the
application feature that consumes it.

## How to work

- Work one small checkpoint at a time.
- Add tests in the same change and run the full suite before finishing an arc.
- Run one required expression or interaction by hand when the checkpoint calls
  for it.
- Do not weaken the type checker to make a golden pass.
- Do not add a second meaning for a list or a second dispatch rule.
- Do not patch `Int.+` for algebra. CAS lives on `Sym`, `Sum`, `Prod`, and
  `Num`; write math objects first (`x + 2`), because `(2 + x)` remains machine
  `Int` arithmetic.
- `Math` is a supertype. Do not erase the class type of a result that will
  receive another send; `(x + 2)` remains `(Sum Sym Int)` as well as `Math`.
- Protocols are types, not method tables. Runtime lookup remains on the class.
- Overloading uses receiver class and argument types; exact class matches beat
  protocol matches, and a remaining tie is an ambiguity error.
- There is no implicit `Int` to `Math` lift. Add `define-methods` only after
  the participating classes exist; there are no forward declarations.
- Preserve exact `Int`/`Float` separation and explicit `(n float)` conversion.
- Keep host facts and effects in Racket; keep domain objects, policy, and
  composition in Aloe.
- Keep Gel application code out of reusable domain vocabularies.

## Current application pressures

Boids originally drove the core object and collection model. MPL drove
protocols, overloading, strings, symbols, and richer display. Gel drove
reflection, exact signature invocation, terminal input, and the typed host
boundary.

The filesystem libraries now provide loadable `Option`, thin `Path`, the
closed four-constructor `Entry`, generic `Fs`, and the second library's generic
`Disk` and `Location` on `experiment/filesystem`. Thin `lib/fs.aloe` remains
unchanged and provides path algebra, `inspect`, and mixed `(List Entry)`
listings. `lib/disk.aloe` now provides `Location.inspect`, `Item`, and nested
live `File`, `Directory`, `SymbolicLink`, and `Other` objects with live
directory-only parents and mixed `Directory.entries` listings. Both filesystem
libraries are complete through listing; `(here entries)` does not exist.
Both libraries compose over an explicitly injected production `fs-host` or
controlled test double. The host crossing vocabulary remains `Int`, `Bool`,
`String`, and homogeneous `(List String)`; `(List Entry)` is built in Aloe,
not crossed, and `(List Item)` is likewise built in Aloe. There is no file-text
reading or Gel filesystem UI. Option remains loadable rather than bootstrapped,
default drivers still have no `fs-host`, and constructors are not merged to
`main`.

The first live Directory presentation is complete. Its TOS line now shows the
live object's class and escaped absolute path without changing structural
reflection. The current screen observes the host when it constructs a menu,
filters hidden names according to the persistent idle `.` toggle, and windows
the resulting full listing into 22-child pages. Idle `n` / `p` move between
pages without wrapping. Remaining pressure is search, a persistent per-TOS
listing snapshot with explicit refresh, and additional stack rendering that
makes history visible. No search, persistent snapshot, refresh key, or extra
stack-level display has been added.

Other open directions include broader Gel object interaction, authored Gel
surfaces, stack navigation, multi-argument builders, processes, repository
work, structured presentations, and alternate terminal renderers. None is an
instruction to implement ahead of an approved checkpoint.

## Designer and implementer roles

If you are the designer: inspect the current implementation, identify a
concrete application pressure, propose or amend governing documentation, and
write a small checkpoint specification. Wait for human approval before
implementation.

If you are the implementer: implement only the approved checkpoint, add its
tests, run the required verification, and stop when green. Do not silently add
adjacent features or continue into the next checkpoint.
