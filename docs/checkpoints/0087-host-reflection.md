# Checkpoint 0087 — Descriptor-driven host reflection

Status: Proposed

Depends on checkpoint 0086.  It relies specifically on the validated runtime
boundary from checkpoint 0084 and nominal typed injection from checkpoint
0085.

## Goal

Make an explicitly injected host receiver participate in Aloe's existing
`Mirror` and `Signature` protocol.

The receiver's exact `host-interface` must be the only source for reflected
selectors, parameter types, return types, ordering, and invocable rows.  Do
not create a host-specific reflection API or expose Racket state and
procedures.

Term is the production control case.  Reflection must not change direct Term
sends, terminal behavior, or capability injection.

## Reflected shape

For a mirror whose subject is a host receiver:

- `(mirror messages)` returns the interface selectors as the existing
  `(List Symbol)` representation;
- selectors appear once and in interface declaration order;
- `(mirror signatures)` returns one existing `Signature` value per
  `host-method`, in the same order;
- `(signature selector)` returns the declared selector;
- `(signature params)` reifies the declared parameter types in order; and
- `(signature return)` reifies the declared return type.

The existing type-data representation is sufficient.  Each crossing type is
a simple Aloe `Symbol` value named `Int`, `Bool`, or `String`; no new type-data
form is added.

Term therefore reflects exactly these rows:

| Row | Selector | Parameters | Return |
|---|---|---|---|
| 1 | `read-key` | none | `String` |
| 2 | `write-line` | `String` | `String` |

Producing messages, signatures, selectors, parameters, or return data must
not invoke a host implementation or inspect receiver state.

The reflected surface contains only declared host methods.  Do not add
interface names, constructors, state access, implementation access, or
synthetic host-management messages.

## Nominal signature ownership

A reflected host signature is owned by the exact `host-interface` identity
from which its row came.

- A signature may be invoked against another receiver constructed with that
  same interface object.
- It must be rejected against a receiver whose independently constructed
  interface merely has the same name and method shape.
- It must be rejected against ordinary Aloe values and other host interfaces.

Ownership is by interface identity, not receiver identity: a signature selects
a capability type's method row, while the target mirror supplies the receiver
state used by that invocation.

The owner token remains kernel metadata.  Aloe can use the existing ownership
checks but cannot inspect or construct it.

## Exact-row invocation

`(mirror invoke signature argument ...)` must retain the existing reflection
semantics: it invokes the selected table row without performing selector
dispatch or overload resolution again.

Refactor the host boundary only as much as needed to share one guarded
exact-method invocation operation:

1. an ordinary host send finds its declared method by selector once;
2. reflected invocation obtains the exact method at the signature's row;
3. both paths pass that exact method to the same argument validation,
   implementation call, result validation, and failure-wrapping logic.

Any internal exact-method hook must verify that the method belongs by identity
to the receiver's exact interface.  It must not become a way for Racket code
to invoke an unrelated validated method through a receiver or bypass crossing
checks.  Keep this evaluator-facing seam private or otherwise narrowly
scoped.

The existing `Mirror.invoke` owner, arity, and runtime type checks occur before
the host implementation.  The shared host invocation core remains the final
crossing guard.  This deliberate layering does not create another Aloe
dispatch rule.

Successful reflected invocation returns the ordinary Aloe value produced by
the guarded host method.  For Term, invoking the reflected `read-key` and
`write-line` rows must have exactly the same results and transcript as direct
sends.

## Errors and control flow

Retain the existing Mirror errors for:

- a signature owned by another subject type;
- the wrong reflected invocation arity; and
- an argument that does not match the signature's reified parameter type.

Those failures occur before the host implementation and therefore perform no
host effect.

Once exact-row invocation enters the host boundary, retain all checkpoint
0084 behavior:

- argument and result crossing validation;
- immutable String normalization;
- Aloe-facing host failure context with the original Racket cause;
- no wrapping of boundary lookup/validation errors as implementation
  failures; and
- break propagation.

Do not introduce reflection-specific host exception classes or translate a
host failure into a generic Mirror failure.

## Static behavior

No new checker rule is required.  The existing types remain:

- `(Mirror of term)` is `Mirror`;
- `(mirror messages)` is `(List Symbol)`;
- `(mirror signatures)` is `(List Signature)`; and
- `Mirror.invoke` uses its existing expected result type or fresh type
  variable because a signature value does not carry a statically selected
  row.

Do not make reflection dependent, add a per-signature checker type, or infer a
host result type from the runtime `Signature` value.

The nominal host type introduced in checkpoint 0085 remains internal.  Host
interface names are still unavailable in source annotation position.

## Other Mirror behavior

`(mirror subject)` continues to return the exact receiver object.  `(mirror
raw)` continues to return its state-free structural form such as `#<Term>`.
Neither operation exposes host state or a Racket implementation.

Reflection does not inject or acquire a capability.  A program can reflect a
host receiver only after that receiver has already crossed an explicit driver
injection point and become reachable as an Aloe value.

## Tests

Add `tests/checkpoint-87.rkt`.

Cover at least:

- Term messages are exactly `read-key` then `write-line`;
- Term signatures have that same order and exactly the declared parameter and
  return type data;
- all `Int`, `Bool`, and `String` declaration tokens reify through a small
  test-only interface without a parallel reflection table;
- inspecting a receiver's messages and signatures performs no read, write, or
  custom host implementation call;
- invoking Term's reflected `read-key` and `write-line` rows preserves direct
  send results and transcript bytes;
- a wrong reflected arity or argument type is rejected before the host method
  can perform an effect;
- a host result crossing failure is still detected during reflected
  invocation;
- an implementation failure invoked through a mirror remains an
  `exn:fail:aloe-host?` with its original cause;
- a break raised by a reflected host implementation is not wrapped;
- a signature from one receiver works against another receiver sharing the
  exact interface and uses the target receiver's state;
- a signature from an independently constructed same-name, same-shape
  interface is rejected before either implementation runs;
- host signatures cannot be invoked against ordinary Aloe values, nor can an
  ordinary signature be invoked against a host receiver;
- `mirror subject` preserves receiver identity and `mirror raw` exposes only
  `#<InterfaceName>`;
- direct Term sends, checked injection, runners, and Gel transcripts remain
  unchanged; and
- default drivers remain free of Term.

Use the production `term-interface` for Term assertions and small test-local
interfaces for identity, state targeting, failure, and the full scalar
vocabulary.  Do not duplicate Term's descriptor in the test.

## Hand check

This checked driver sequence should succeed without a physical TTY:

```racket
(require "aloe/driver.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define state (make-driver))
(driver-inject-host!
 state 'term (make-term-receiver output (lambda () "q")))

(driver-eval! state '(define tm (Mirror of term)))
(driver-eval! state '(define rows (tm signatures)))
(driver-eval! state '(define read-row (rows first)))
(driver-eval! state '(define write-row ((rows rest) first)))

(list
 (driver-eval! state '((read-row selector) name))
 (driver-eval! state '((write-row selector) name))
 (driver-eval! state '(tm invoke read-row))
 (driver-eval! state '(tm invoke write-row "hi"))
 (get-output-string output))
```

Expected result:

```racket
'("read-key" "write-line" "q" "hi" "hi\r\n")
```

## Acceptance

This checkpoint is complete when injected host receivers obey the existing
Mirror/Signature contract using only their validated descriptors, including
safe exact-row invocation with nominal interface ownership.

The implementation should remain concentrated in the existing reflection and
host-boundary modules.  There must be no host-specific Mirror class, duplicate
signature declaration, selector re-dispatch during reflected invocation, or
exposure of receiver state and Racket procedures.

Run the checkpoint test, the full suite, the hand check, and
`git diff --check`.  All must pass.  Stop for review without committing.

## Explicit non-goals

- Do not add new Mirror or Signature messages.
- Do not expose host receiver state, interface objects, method objects, or
  implementation procedures to Aloe.
- Do not make signatures user-constructible in Aloe.
- Do not add `perform`, dynamic selectors, or a second dispatch path.
- Do not change the crossing vocabulary or admit host receivers as crossing
  arguments or results.
- Do not add source-written host types or a host type registry.
- Do not change Term's descriptor, effects, injection, runners, or TTY logic.
- Do not design or implement filesystem capabilities.
- Do not change Gel, Boids, MPL, or ordinary `bin/aloe`.

## Deferred questions

- Whether a later opaque host handle should itself be reflectable, and what
  interface would own its nominal identity.
- Whether source annotations should ever resolve host interface names.
- Whether future capability descriptors need metadata beyond the existing
  selector and fixed scalar signature.  No such metadata is justified by Term
  or this checkpoint.
