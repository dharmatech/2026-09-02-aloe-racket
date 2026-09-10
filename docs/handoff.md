# Aloe handoff

Read first, in order: `SPEC.md`, `docs/philosophy.md`, `docs/decisions.md`,
`AGENTS.md`, `CHECKPOINTS.md`, this file. If the work touches Gel, also read
`docs/gel.md`. Spec is law. Decisions record accepted and rejected directions;
do not replay rejected designs.

## `experiment/gel-directory-surface`

Stacked on `experiment/filesystem`. Working design:
[`docs/gel-directory-surface.md`](gel-directory-surface.md).

First Gel experiment after the OO disk library: a focused directory
browser on Gel's stack. Not a workspace, not a GelFS framework, not
checkpoints yet. Do not implement from the design file. Do not grow
`lib/disk.aloe` unless that surface blocks. Checkpoint 107 remains the
last required OO-filesystem slice.

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

## Current state (0.4 on `experiment/filesystem`)

- Interpreter and type checker in Racket; no compiler or macros.
- `define-class`, `define-methods`, `fn`/`call`, `let`, `if`/`cond`, `load`,
  and `check`.
- Classes use either the singleton `(fields ...)` / `new` form or an explicit
  declaration-ordered constructor set. Construction is a class-object send.
- Receiver-anchored `case` checks constructor coverage and binds the selected
  payload; generic construction uses payload constraints and expected types.
- Generics, homogeneous `List`, protocols with required methods, and
  C#-style method overloading. Exact argument types beat protocol matches.
- Primitive `Int`, `Float`, `Bool`, `String`, and interned `Symbol` values.
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
  integer entry, and a thin Racket terminal runner.
- Typed host capabilities use descriptor-defined interfaces shared by runtime
  dispatch, static checking, driver injection, and reflection.
- Generic fields retain exact injected host-interface types, allowing wrappers
  around capabilities without source-written host type names.
- Tests through checkpoint 107 are green on `experiment/filesystem`. `Option`
  is loadable from `lib/option.aloe` and is not a default-driver binding.
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
