# Checkpoint 0085 — Typed atomic host injection

Status: Proposed

Depends on:

- checkpoint 0083, validated host declarations;
- checkpoint 0083A, rejection of keyword implementations;
- checkpoint 0084, guarded descriptor-driven host sends.

## Goal

Make a host interface the checker-visible source of truth as well as the
runtime source of truth.

A driver must be able to inject one named host receiver atomically into its
runtime and type environments.  After injection, ordinary Aloe sends through
that binding are checked from the receiver's `host-interface`; no handwritten
Aloe class facade describes the same messages a second time.

Term is the control case.  Its behavior and transcript must remain unchanged.

This checkpoint completes static/runtime agreement for an already injected
capability.  It does not make Term ambient, change runner policy, or introduce
a general FFI.

## Public driver operation

Add one canonical driver operation with this shape:

```racket
(driver-inject-host! a-driver binding-name a-host-receiver)
```

The operation:

- accepts a driver, a symbol naming the Aloe binding, and a validated host
  receiver;
- returns `void` after a successful injection;
- installs the receiver in the driver's runtime environment;
- installs its checker type in the same driver's type environment;
- rejects a name already bound in either environment rather than overwriting
  it; and
- makes no change to either environment if validation or collision checking
  fails.

The implementation may add the smallest environment binding-presence queries
needed to preflight both environments.  Those queries must not expose the
underlying mutable tables.

Bad Racket-side arguments and binding collisions are host integration errors,
so they should use consistent Racket contract-style failures.  They are not
Aloe program type errors.

Different names may intentionally refer to receivers with the same interface.
Reinjecting an occupied name is still an error, even if the new receiver or
interface is identical to the existing one.

## Checker representation

Give the checker a small internal host-receiver type containing the exact
`host-interface` object.

The raw constructor must not become a public way to forge host types.  Normal
creation occurs only while the driver injects a validated host receiver.

Host-receiver types are nominal:

- two types agree when they contain the same interface object by identity;
- two independently constructed interfaces do not agree merely because their
  names and method declarations are equal; and
- ordinary type variables may infer and retain a host-receiver type, so Aloe
  aliases and functions do not lose the capability's type.

`type->datum` should render a host-receiver type as its interface name, such as
`Term`.  This is diagnostic presentation only; the printed name does not
determine type identity.

## Static send contract

When the receiver of an Aloe send has a host-receiver type, the checker must:

1. look up the literal selector in that type's exact host interface;
2. reject an unknown selector;
3. require the declared positional arity;
4. check each argument against the corresponding declared crossing type; and
5. assign the send the method's declared result type.

The crossing vocabulary remains exactly:

- `Int`
- `Bool`
- `String`

The checker maps those declaration tokens directly to its existing scalar
types.  It must not reinterpret them through Aloe source syntax or add a
parallel method signature table.

Static failures use the existing `exn:fail:aloe-type?` path and the existing
style of selector, arity, and type-mismatch diagnostics.  Static checking must
never invoke the Racket implementation or otherwise perform the host effect.

No new dispatch or evaluation rule is added.  Evaluation continues to use the
checkpoint 0084 host-receiver send path.

## Source annotations

The interface name is not introduced as an Aloe source type name in this
checkpoint.

Thus an injected binding may infer and display the internal nominal type
`Term`, and an alias such as `(define console term)` retains that type, but a
program-written annotation naming `Term` remains unbound and is rejected.

Making host types writable in annotations would require a deliberate policy
for resolving names to interface identities.  It would also raise questions
about host handles in fields, method signatures, and reflection.  Those issues
are deferred until a concrete consumer requires them.

## Term migration

Use the production `term-interface` and `make-term-receiver` through
`driver-inject-host!` in checker-aware Term tests.

Remove the synthetic `HostTerm` Aloe declaration and
`make-term-type-environment`.  `host/racket/term.rkt` should no longer depend
on the general Aloe convenience API solely to typecheck that facade.

There must be one declaration of the Term message shape:

- `read-key : () -> String`
- `write-line : (String) -> String`

The implementations, runtime guards, and checker signatures all originate in
`term-interface`.

The default driver and default Aloe type environment remain free of `term`.
Only explicit injection introduces the binding.

The optional capability runners are not migrated in this checkpoint.  Their
current explicit runtime injection remains valid and will be addressed in the
next checkpoint.

## Tests

Add `tests/checkpoint-85.rkt` and migrate existing tests that construct the
synthetic Term type environment.

Cover at least:

- a Term receiver injected through a driver supports checked `read-key` and
  `write-line` sends with the existing results and transcript;
- the checker reports `String` for each Term send from the descriptor;
- an alias of the injected binding retains the Term host type and can receive
  its messages;
- an unknown selector is rejected statically;
- too few and too many arguments are rejected statically;
- a non-String `write-line` argument is rejected statically;
- rejected sends do not call the scripted reader or write output;
- checking a valid send without evaluating it does not call its host
  implementation;
- whole-file driver checking still prevents all effects when a later
  expression in the file is ill typed;
- two bindings with the same exact interface identity can be used at the same
  inferred host type;
- two independently declared interfaces with the same name and shape do not
  unify;
- injection rejects an occupied binding and preserves the prior runtime and
  checker bindings;
- failure discovered on either side of the preflight cannot leave a partial
  injection;
- a default driver still rejects an unprovided `term` binding;
- `Term` remains unavailable in source annotation position; and
- `make-term-type-environment` and the synthetic `HostTerm` facade are gone.

Use custom test interfaces where necessary to observe implementation calls or
prove nominal identity.  Keep those interfaces within the checkpoint test;
they are not new production capabilities.

Retain all checkpoint 0084 boundary tests.  Runtime argument validation,
result validation, immutable String normalization, host-failure wrapping,
break propagation, receiver equality, and receiver printing must not regress.

## Hand check

The following shape should work through the checked driver path:

```racket
(require "aloe/driver.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define state (make-driver))

(driver-inject-host!
 state
 'term
 (make-term-receiver output (lambda () "q")))

(list (driver-eval! state '(term read-key))
      (driver-eval! state '(term write-line "hi"))
      (get-output-string output))
```

Expected result:

```racket
'("q" "hi" "hi\r\n")
```

## Acceptance

This checkpoint is complete when a host interface alone determines the static
and runtime shape of an explicitly injected Term receiver, and the checked
driver path preserves Term's behavior.

The implementation must be small enough that the nominal checker type, static
send branch, and atomic injection can each be read directly.  There should be
no generated Aloe facade, hidden duplicate signature table, or special Term
case in the checker.

Run the checkpoint test, the full suite, the hand check, and
`git diff --check`.  All must pass.  Stop for review without committing.

## Explicit non-goals

- Do not add `racket-call`, evaluation, dynamic loading, or namespace access.
- Do not inject Term into default environments.
- Do not weaken static checking or fall back to dynamic typing for hosts.
- Do not add a second evaluator or dispatch path.
- Do not make host interface names available as source-written types yet.
- Do not design filesystem selectors, paths, handles, or policies.
- Do not expand the crossing vocabulary beyond `Int`, `Bool`, and `String`.
- Do not add optional arguments, keywords, variadics, overloads, generics, or
  protocol conformance to host methods.
- Do not expose the Racket implementation to Aloe or call it while checking.
- Do not migrate `gel-run.rkt` or `term-run.rkt` yet.
- Do not add host-specific reflection metadata yet.
- Do not change ordinary class dispatch, Boids, MPL, or default `bin/aloe`.

## Deferred questions

- When should a host interface name become available in Aloe annotations, and
  how should source names resolve to exact nominal identities?
- Which host values, if any, may later cross as opaque handles rather than the
  three scalar crossing types?
- What host method information should mirrors expose, and in what order?
- Should a later filesystem capability use one interface or several narrowly
  scoped interfaces?  Let its first concrete operations answer that question.
