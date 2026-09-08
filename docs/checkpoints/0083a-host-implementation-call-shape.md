# Checkpoint 0083A — Exact host implementation call shape

Status: Proposed addendum
Amends: Checkpoint 0083

## Reason

Review of the initial uncommitted checkpoint 0083 implementation found that
`make-host-method` rejects required keyword arguments but accepts optional
keyword arguments. Its positional arity is exact, but its complete Racket call
shape is therefore broader than the declared Aloe host method.

Checkpoint 0083 said to reject optional arguments but did not distinguish
optional positional arguments from optional keyword arguments. This addendum
records that review finding explicitly rather than silently rewriting the
original checkpoint.

## Clarification

A host implementation accepts exactly one state argument followed by one
positional argument per declared parameter. It accepts:

- no other positional arities;
- no required keyword arguments; and
- no optional keyword arguments.

The boundary will never supply Racket keyword arguments. Permitting hidden
keyword call shapes would add behavior that is absent from the host-method
declaration and unnecessary for Term.

## Required revision

Revise the uncommitted checkpoint 0083 implementation so declaration
validation rejects procedures with either required or optional keyword
arguments. Extend `tests/checkpoint-83.rkt` with both cases. Keep the existing
coverage for too few, too many, optional positional, and variadic positional
arguments.

Do not otherwise change checkpoint 0083 or begin descriptor-driven runtime
dispatch, Term migration, checker integration, injection, or reflection.

## Acceptance

- Required-keyword and optional-keyword implementations both fail during
  `make-host-method` construction with a Racket contract-style exception.
- A fixed positional implementation of the declared arity remains accepted.
- Checkpoint 83 and the full suite pass.
- The required hand expression from checkpoint 0083 remains unchanged.

Checkpoint 0083 remains under review until this addendum is satisfied. Stop
for review when the revised checkpoint is green.
