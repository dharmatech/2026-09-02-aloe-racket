# Aloe decisions

Spec is law: `SPEC.md`. This file is what we considered and rejected, so a
new conversation does not replay them.

## Evaluation (2026-09-02)

Decided: send, not Scheme apply. Selector is a source symbol.

Rejected: `(step demo-flock)` as function application.

## let (2026-09-02)

Decided: `(let ((n e1) (bs e2)) body)` → `((fn (n bs) body) call e1 e2)`.
Parallel bindings.

Rejected: Scheme’s `((lambda (n bs) body) e1 e2)` (treats `e1` as selector).

## if / Bool (2026-09-02)

Decided: `#t` / `#f` understand `(b if then-fn else-fn)`; only one zero-arg
thunk is sent `call`. Sugar: `(if test then else)` desugars to that send.

Rejected:

- `if` as a special form that secretly evaluates one arm (two conditionals)
- `[10]` or `T[10]` as thunk literals (keep `[]` / custom reader for later)
- requiring programs to write only the send spelling (too noisy for Boids)

## Sim and numerics (2026-09-02)

Decided: `Point` and `Boid` are generic. `Sim` is not. Flock is
`(List (Boid Float))`. No implicit `Int`/`Float` mix; `(n float)` converts.

Rejected: `Sim[T]` whose `step` body hard-codes `0.0` / `0.01` and pretends
to be parametric.

## Implementation host (2026-09-02)

Decided: definitional interpreter + checker in `racket/base`. `#lang aloe`
later as a wrapper around that pipeline, not a rewrite.

Rejected for 0.1: Turnstile, PLAI student languages, expanding sends into
Racket apply.

## Host terminal input (2026-09-04)

Decided: host key input uses the `tui-term` package, not `#%terminal` directly
and not a project C FFI. Term is Aloe's first optional typed host capability:
`(term read-key)` returns a `String`, and `(term write-line string)` uses
Racket `display`, writes `"\r\n"`, flushes, and returns the string.

Both terminal runners create a checked driver and explicitly inject the
production Term receiver into its runtime and checker environments before
loading Aloe source. `raco pkg install tui-term` is required only for these
optional terminal paths; ordinary `bin/aloe`, Boids, and MPL do not load it.

Term is an injected receiver, not a `tui-term` API exposed to Aloe or a new
kernel printing primitive.

## Collections (2026-09-02)

Decided: the host provides `of`, `empty`, `empty?`, `first`, `rest`, `cons`,
and `len`. `fold`, `reverse`, and `map` are Aloe methods in `lib/list.aloe`,
installed with `define-methods List` before user programs run.

Method-local type parameters such as fold's accumulator `A` are rigid while
the method body is checked and freshly inferred at each send.

## Message chains (2026-09-02)

Deferred: (-> recv (sel args ...) ...) desugars to nested sends.
Not now — one force-sum in Boids is not enough pressure.

## Math protocol (2026-09-03)

Decided: empty protocol `Math`; `(define-protocol Math)`;
`(define-class Sym Math ...)`; a method may return `Math` so `(x + 2)`
and `(x + y)` share a type. Lookup stays on the class.

Rejected for this experiment: C# implementation inheritance, closed ADT
`Expr`, `Any`, required protocol methods, `super`.

Deferred: `simplify` as a required protocol method; multiple protocols
per class; ADT control experiment on a separate branch.

## Symbol values (2026-09-05)

Decided: `Symbol` is a primitive interned name, separate from Racket symbols
and constructed explicitly with `(Symbol intern String)`.

Rejected for this slice: reader literals for symbols, treating Racket symbols
as Aloe values, and `perform`.

## Reflection mirrors (2026-09-05)

Decided: reflection lives on a separate primitive `Mirror`, rather than adding
`perform` or reflection messages to every object.

Signatures are kernel-created dispatch-table rows, not user-built objects.
Their parameter and return types are reified directly as grammar data: simple
names are `Symbol` values and compound types are `List` values.

`Mirror.invoke` consumes one of those owned rows and dispatches it directly;
it does not turn the row's selector into `perform` and does not run overload
resolution a second time.

Mirror unwrapping is the kernel message `(mirror subject)`. It returns the
stored value directly; there is no `Object` cast syntax, and `List` remains
homogeneous rather than becoming a heterogeneous container.

Rejected for this slice: `#%` reflection sigils and `perform`.

## Typed host capabilities (2026-09-06)

Decided: one opaque nominal host-interface descriptor is the source of truth
for checking, runtime dispatch, and reflection. This prevents handwritten
checker facades or reflection tables from drifting away from the code that
actually performs an effect.

Capabilities are explicitly and atomically injected through a driver so the
runtime binding and checker type agree, and so possessing a capability is a
visible authority rather than ambient access. The initial crossing vocabulary
is only `Int`, `Bool`, and `String`: they are sufficient for Term and keep the
boundary concrete, validated, and free of premature object-marshalling rules.

Reflected host signatures retain the exact interface identity as their owner
and use the same guarded invocation core as direct sends. This permits a row
to operate on another receiver of the same capability type without selector
redispatch, while rejecting merely same-named interfaces.

Deferred: source-written host types, opaque host handles, and a comprehensive
FFI. Each would require concrete application pressure and additional authority
and lifetime decisions that Term does not justify.

## Class constructors (2026-09-07)

Decided: Proposal B. A class has one nominal type and a finite constructor
set. Construction remains a send to the class object, using the constructor
selector; `(fields ...)` is the singleton `new` case. Methods belong to the
whole class, and receiver-anchored `case` selects and binds one constructor's
payload.

Rejected on `experiment/class-constructors`: Proposal A's `define-family`,
factories, constructor-local methods, `per-constructor` bodies, send-site
`(type ...)` headers, constructor names as types, nested patterns, and an
elaboration IR.

## `(List String)` host crossing (2026-09-08)

Decided: admit homogeneous `(List String)` under concrete filesystem-listing
pressure. Host implementations exchange proper Racket lists of frozen strings,
while Aloe receives its ordinary homogeneous list values.

This is not a general list FFI. Nested lists and every other `(List T)` remain
outside the crossing vocabulary; opaque handles and `Result` remain deferred.

## Option library (2026-09-08)

Decided: under filesystem pressure, `Option` is an ordinary loadable Aloe
library at `lib/option.aloe`. Programs opt in with `load`; `make-driver` does
not bootstrap it, and `Option` is not a host crossing type.

## Filesystem host test double (2026-09-08)

Decided: filesystem facts begin as a second optional host capability, using
one nominal `FsHost` interface and a controlled test double before production
disk I/O. The capability crosses values only and is not installed in default
drivers.

The parent of the normalized POSIX root is `"/"`, and the kind of a missing
path is `"missing"`. Asking `names` of a missing or non-directory path is a
host failure.
