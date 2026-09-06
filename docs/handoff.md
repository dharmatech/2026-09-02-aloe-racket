# Aloe handoff

Read first, in order: `SPEC.md`, `docs/philosophy.md`, `docs/decisions.md`,
`AGENTS.md`, `CHECKPOINTS.md`, this file. If the work touches Gel, also read
`docs/gel.md`. Spec is law. Decisions record accepted and rejected directions;
do not replay rejected designs.

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

## Current state (main through checkpoint 88)

- Interpreter and type checker in Racket; no compiler or macros.
- `define-class`, `define-methods`, `fn`/`call`, `let`, `if`/`cond`, `load`,
  and `check`.
- Generics, homogeneous `List`, protocols with required methods, and
  C#-style method overloading. Exact argument types beat protocol matches.
- Primitive `Int`, `Float`, `Bool`, `String`, and interned `Symbol` values.
- Boids in `examples/boids.aloe` and `examples/point.aloe`.
- Cohen-style symbolic algebra in `examples/mpl/`, including `Math`, `Sym`,
  `Num`, `Sum`, `Prod`, and `Pow`.
- `Mirror` and `Signature` provide nominally owned reflection and exact-row
  invocation without adding `perform` to ordinary objects.
- Gel is an Aloe-written keystroke object environment with an immutable
  `(List Mirror)` stack, reflected menus, typed one-argument pending sends,
  integer entry, and a thin Racket terminal runner.
- Typed host capabilities use descriptor-defined interfaces shared by runtime
  dispatch, static checking, driver injection, and reflection.
- Checkpoints through 88 are present. The full suite passed after checkpoint
  88. Tag `v0.1.0-boids` records the earlier 0.1 milestone.

## Typed host boundary

A host capability is a Racket-created receiver explicitly injected into a
driver with `driver-inject-host!`. One opaque nominal `host-interface`
descriptor owns ordered, uniquely selected `host-method` declarations. Each
declaration supplies its selector, fixed parameter types, return type, and
Racket implementation.

The current crossing vocabulary is deliberately limited to `Int`, `Bool`, and
`String`. Arguments and results are validated; strings are normalized to
immutable values. Host failures retain their Racket cause under consistent
Aloe context, and breaks pass through.

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
- Protocols are types, not method tables. Runtime lookup remains on the class.
- Preserve exact `Int`/`Float` separation and explicit `(n float)` conversion.
- Keep host facts and effects in Racket; keep domain objects, policy, and
  composition in Aloe.
- Keep Gel application code out of reusable domain vocabularies.

## Current application pressures

Boids originally drove the core object and collection model. MPL drove
protocols, overloading, strings, symbols, and richer display. Gel drove
reflection, exact signature invocation, terminal input, and the typed host
boundary.

A filesystem vocabulary is a candidate next application. Its types,
selectors, path representation, enumeration boundary, error policy, and Gel
presentation remain deliberately undecided. In particular, directory
enumeration must supply concrete pressure before admitting compound crossing
values or opaque host handles.

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
