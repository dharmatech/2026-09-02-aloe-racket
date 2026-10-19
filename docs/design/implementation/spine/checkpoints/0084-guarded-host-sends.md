# Checkpoint 0084 — Guarded descriptor-driven host sends

Status: Proposed
Depends on: Checkpoint 0083 and addendum 0083A

## Goal

Make the existing host-receiver send path consume validated host-interface
declarations, and migrate Term as the first control case. One interface must
now supply Term's runtime selectors, parameter types, return types,
implementations, and dispatch order.

This checkpoint is runtime-only. Preserve Aloe's ordinary send evaluation and
leave the separate synthetic `HostTerm` checker facade in place until the next
checkpoint.

## Host receiver

A host receiver contains:

- one validated `host-interface`; and
- arbitrary opaque Racket state used only by its host implementations.

Expose a validated `make-host-receiver` constructor, the receiver predicate,
an interface accessor, and `host-receiver-name`, which derives the nominal
name from the interface. The raw receiver constructor and its state are not
public. Construction rejects a value that is not a validated host interface.

Remove `host-message` and the legacy receiver constructor and message-table
accessors. Do not retain a compatibility path that can dispatch around the
validated declarations.

Host receivers have identity semantics. Two references to the same receiver
are equal; two separately constructed receivers are unequal even when they
share an interface and equal state. Structural output is exactly
`#<InterfaceName>` and never includes state.

## Runtime send contract

`host-receiver-send` uses the receiver's interface methods as its only method
table:

1. Find the unique declaration with the literal selector.
2. Reject an unknown selector with Aloe's existing `unknown message` error.
3. Require the declared fixed arity.
4. Validate and normalize every argument before calling the implementation.
5. Call the declared implementation with receiver state followed by the
   normalized positional arguments.
6. Validate and normalize the result before returning it to Aloe.

This remains the host-receiver branch of Aloe's ordinary evaluated-send path.
Do not add syntax, a special form, a second evaluator, overload selection, or
another dispatch rule.

### Crossing validation

Use the complete crossing vocabulary established by checkpoint 0083:

| Declared type | Accepted runtime value |
|---|---|
| `Int` | an exact Racket integer |
| `Bool` | `#t` or `#f` |
| `String` | a Racket string |

`Int` and `Bool` pass through unchanged. A `String` is normalized with an
immutable copy before entering a host implementation and again before a host
result enters Aloe. The implementation must not receive an Aloe-owned mutable
string or retain a mutable string later returned to Aloe.

Any other value fails the crossing check. Do not admit `Float`, lists, Aloe
instances, functions, mirrors, signatures, classes, ports, arbitrary Racket
values, or nominal host receiver values as method arguments or results.

Argument validation finishes before the implementation runs. Result
validation happens after the implementation returns; it cannot roll back an
effect that has already occurred.

### Runtime errors

Unknown-message and arity errors retain Aloe's established runtime forms. An
arity error names both the interface and selector.

A crossing error is an `eval-aloe` runtime error and identifies:

- the interface and selector;
- `argument N` or `result`; and
- the expected crossing type.

For example, a bad call to `write-line` identifies `Term`, `write-line`,
argument 1, and `String`. Tests should match these stable facts rather than an
entire punctuation-sensitive message.

If the Racket implementation raises `exn:fail?`, raise one Aloe-facing host
failure that identifies the interface and selector and includes the original
message. Preserve the original exception as an inspectable cause for Racket
debugging. Expose only the predicate and accessors needed to recognize that
host-failure exception and inspect its cause; keep its raw constructor
private. Do not convert breaks or other non-failure control events.

Boundary lookup, arity, argument, and result failures are not implementation
failures and must not be wrapped as such.

## Term migration

`host/racket/term.rkt` defines and exports one `term-interface` with these
ordered methods:

| Selector | Parameters | Return |
|---|---|---|
| `read-key` | none | `String` |
| `write-line` | `String` | `String` |

The declared implementation procedures contain no manual Aloe crossing
checks. `read-key` obtains the next key from Term's state. `write-line` writes
the supplied string with `display`, writes `"\r\n"`, flushes, and returns that
string.

Keep `make-term-receiver` compatible with its existing optional output-port
argument. Add one optional Racket-side reader procedure used as the source of
the next Aloe key, defaulting to the existing `read-next-key` behavior. This
is a state dependency for scripted tests, not another host-method declaration
or a caller-selectable Aloe capability.

Production TTY behavior remains unchanged:

- printable characters become one-character `String` values;
- return, escape, and named keys retain their current `String` mappings;
- mouse, resize, and unrelated events remain ignored;
- unsupported keys and closed input still fail; and
- `with-term` still owns terminal restoration.

Migrate scripted Gel tests to construct Term receivers through
`make-term-receiver` with controlled reader state and output. They must use
the exported production `term-interface`; do not recreate selectors, types,
implementations, interfaces, or legacy message tables in tests.

## Compatibility and exclusions

The synthetic `make-term-type-environment` facade remains unchanged in this
checkpoint. The optional runners retain their current injection and loading
paths. Their checked migration belongs to later checkpoints.

Apart from adapting host receiver structural printing and equality to the new
representation, do not change evaluator dispatch or runtime type relations.
Do not change:

- Aloe parsing or type checking;
- driver or environment injection;
- `Mirror` messages, signatures, ownership, or invocation;
- the crossing-type vocabulary;
- Gel application behavior or terminal transcript bytes;
- ordinary `bin/aloe`, Boids, MPL, or the default environment; or
- the optional `tui-term` dependency boundary.

## Tests

Add `tests/checkpoint-84.rkt` and update existing host/terminal tests only as
required to remove their use of the legacy receiver/message-table API.

Cover at least:

- receiver construction requires a validated interface and preserves its
  nominal identity;
- selector lookup and arity come from the interface declaration;
- exact successful `Int`, `Bool`, and `String` crossings;
- every wrong scalar crossing in argument and result positions;
- a non-crossing Aloe value in argument and result positions;
- no implementation call or output occurs after an argument failure;
- mutable input and result strings are not exposed across the boundary as
  mutable values;
- an implementation failure has the stable Aloe-facing context and retains
  the original exception as its cause;
- a break is not converted into a host failure;
- same-receiver equality, distinct-receiver inequality, and structural output
  that cannot reveal string or other state;
- the exported Term interface has exactly the two ordered declarations above;
- Term rejects a bad `write-line` argument through the generic boundary, not
  a manual Term guard;
- a scripted non-String `read-key` result is rejected by result validation;
- scripted Gel behavior uses the production Term declaration; and
- existing key mapping, CRLF, flush, return value, Gel transcripts, and
  default-environment isolation remain unchanged.

All pre-existing checkpoint tests must remain green after their mechanical
migration away from `host-message`.

## Acceptance

- Runtime host dispatch has one declaration source and no legacy bypass.
- Every host argument is guarded before an implementation can perform an
  effect, and every returned value is guarded before Aloe receives it.
- Host failures have consistent Aloe-facing context and retain their Racket
  cause.
- Term uses one production interface for both real and scripted receivers.
- Term's observable behavior and Gel's transcript are unchanged.
- The checker facade, injection model, runners, and reflection have not been
  redesigned or migrated.
- Ordinary Aloe applications remain capability-independent.
- All checkpoint tests pass.
- By hand, the final expression evaluates to
  `("q" "hi" "hi\r\n")`:

  ```racket
  (require "aloe/host.rkt"
           "host/racket/term.rkt")

  (define output (open-output-string))
  (define term
    (make-term-receiver output (lambda () "q")))

  (list (host-receiver-send term 'read-key '())
        (host-receiver-send term 'write-line '("hi"))
        (get-output-string output))
  ```

Stop for review when this checkpoint is green. Do not begin checker-visible
host types, paired driver injection, runner migration, or host reflection in
the same change.
