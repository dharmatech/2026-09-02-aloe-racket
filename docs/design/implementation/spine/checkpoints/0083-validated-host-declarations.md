# Checkpoint 0083 — Validated host declarations

Status: Proposed
Depends on: Checkpoint 0082

## Goal

Introduce one validated, nominal Racket-side description for an explicitly
injected host capability and its typed methods. This checkpoint establishes
declaration data only; it does not connect that data to runtime sends, the Aloe
checker, injection, Term, or reflection.

This is the first slice of the typed host-capability boundary. Later
checkpoints will make the evaluator, checker, and `Mirror` consume these same
declarations rather than maintaining parallel shapes.

## Contract

`aloe/host.rkt` exposes validated constructors, predicates, and accessors for
two opaque values:

- A **host interface** has a nominal name and an ordered list of host methods.
- A **host method** has a selector, ordered parameter crossing types, one
  return crossing type, and a Racket implementation procedure.

The public construction operations are:

```racket
(make-host-method selector parameter-types return-type implementation)
(make-host-interface name methods)
```

The corresponding predicates and field accessors are public. Raw struct
constructors are not public, so callers cannot bypass declaration validation.

### Crossing types in this checkpoint

The complete permitted method type vocabulary is:

```text
Int
Bool
String
```

They are represented by those exact symbols in `parameter-types` and
`return-type`. A parameter list must be a proper Racket list, and every member
must be one of those symbols.

Do not accept `Float`, `Symbol`, `Mirror`, `Signature`, `List`, function types,
type variables, Aloe class names, arbitrary type datums, or nominal host
receiver references in this checkpoint. The Term control case needs only
`String`; `Int` and `Bool` are the only anticipated scalar host facts admitted
in advance. Any additional crossing form requires later application pressure
and its own checkpoint.

### Host-method validation

`make-host-method` requires:

- `selector` is a symbol;
- `parameter-types` is a proper list of permitted crossing types;
- `return-type` is a permitted crossing type;
- `implementation` is a Racket procedure; and
- the procedure accepts exactly one state argument followed by one positional
  argument per declared parameter, and accepts no other arities.

For example, a zero-parameter host method has a one-argument Racket
implementation, while a one-parameter host method has a two-argument Racket
implementation. Implementations are not called while declarations are
validated.

### Host-interface validation

`make-host-interface` requires:

- `name` is a symbol;
- `methods` is a proper list containing only validated host methods; and
- no two methods have the same selector.

Method order is retained exactly. It will become reflection row order in a
later checkpoint. Duplicate selectors are rejected rather than overwritten;
host overloading is not part of this boundary.

An interface is a nominal token. Two separately constructed interfaces remain
different interface identities even when their names and methods have equal
contents. The name is for Aloe type presentation and diagnostics; it is not
the runtime identity.

Invalid declarations raise Racket contract-style exceptions at construction
time and identify the rejected field or invariant. They are host integration
errors, not Aloe type or evaluation errors.

## Compatibility

Keep the current `host-message`, `host-receiver`, and `host-receiver-send`
behavior and exports unchanged. Keep `host/racket/term.rkt`, both optional
runners, and all existing fake terminal receivers unchanged. This checkpoint
does not migrate Term or create a production host-interface value.

Do not change:

- Aloe syntax, parsing, evaluation, dispatch, or type checking;
- runtime argument or result validation;
- capability injection;
- `Mirror` messages, signatures, ownership, or invocation;
- host receiver printing or equality;
- the default environment or optional `tui-term` dependency boundary; or
- Gel, Boids, MPL, or their behavior.

## Tests

Add `tests/checkpoint-83.rkt`. It must cover:

- a valid Term-shaped interface with `read-key : () -> String` followed by
  `write-line : (String) -> String`;
- preservation of that declaration order through the public accessors;
- distinct nominal identity for two separately constructed interfaces with
  equal names and method contents;
- rejection of a non-symbol selector;
- rejection of an improper parameter list;
- rejection of every unsupported parameter and return type;
- rejection of a non-procedure implementation;
- rejection when the implementation accepts too few, too many, optional, or
  variadic arguments;
- rejection of a non-symbol interface name;
- rejection of a non-method member in the interface method list;
- rejection of duplicate selectors; and
- confirmation that declaration validation never calls an implementation.

Existing host and terminal tests must remain unchanged and green.

## Acceptance

- One immutable declaration shape contains the future selector, parameter
  types, return type, implementation, nominal owner, and reflection order.
- All declaration invariants are enforced before a host interface can be used.
- The declaration API admits only `Int`, `Bool`, and `String` method crossings.
- Interface identity is nominal rather than name- or structure-based.
- Existing runtime host sends and Term behavior are byte-for-byte unchanged.
- Ordinary `bin/aloe`, Boids, MPL, and the default environment remain
  capability-free and independent of `tui-term`.
- All checkpoint tests pass.
- By hand, the final expression evaluates to `(read-key write-line)`:

  ```racket
  (require "aloe/host.rkt")

  (define interface
    (make-host-interface
     'Term
     (list
      (make-host-method
       'read-key '() 'String
       (lambda (_state) "x"))
      (make-host-method
       'write-line '(String) 'String
       (lambda (_state value) value)))))

  (map host-method-selector
       (host-interface-methods interface))
  ```

Stop for review when this checkpoint is green. Do not begin descriptor-driven
runtime dispatch or migrate Term in the same change.
