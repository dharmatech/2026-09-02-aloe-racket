# U1 resolution: invocation that returns a Mirror

> **USER-APPROVED DESIGN — NON-NORMATIVE AND UNIMPLEMENTED**
>
> The user approved this resolution of [audit finding U1][u1] in the design
> conversation after reviewing its before-and-after examples and generic
> invocation rule. This record does not itself amend the specification
> candidate or close checkpoint 89F. `SPEC.md` remains law.
> Code below compares current Gel method fragments with approved replacements;
> the replacements are not runnable in the checkpoint-88 implementation.

The approval covers the complete design below: the fixed `(List Mirror)`
argument, existing-Mirror result reuse, and complete pre-execution generic
resolution from sealed input type evidence. The historical `proposal` filename
is retained so existing links remain valid. Resume documentation-only 89F
using the [updated checkpoint instructions][cp89f].

## Approved decision

Add one ordinary operation on `Mirror`:

```aloe
(receiver invoke-mirrored signature arguments)
```

Its receiver is a `Mirror`, `signature` is a `Signature`, `arguments` is a
`(List Mirror)`, and its result is always a `Mirror`. It invokes the exact
selected row on the receiver's subject, using each argument mirror's subject.

Keep the existing ordinary-result `invoke` and contextually typed `subject`.
Gel uses the new operation when it needs to put a result back on its mirrored
stack without exposing an intermediate ordinary type to source checking.

The substantive additional rule is that this operation may instantiate the
opaque selected row using sealed, already resolved type evidence for its
mirrored arguments. All required row parameters must resolve before execution.
An unconstrained nullary generic constructor still fails.

This is an approved amendment to the reflection and checked-execution contract,
not an editorial interpretation of the current candidate.

## What the code costs

These are the three method rows from [GelStack][stack]. The surrounding nominal
declaration and the separate class-to-family migration are omitted so the
comparison isolates the reflection change.

### Before: current Gel helpers

```aloe
(invoke-zero
  (row GelRow)
  GelStack
  (self push
    ((self tos) invoke (row signature))))

(invoke-one
  (row GelRow)
  (arg Mirror)
  GelStack
  (self push
    ((self tos) invoke
      (row signature)
      (arg subject))))

(invoke-one (type T)
  (row GelRow)
  (arg T)
  GelStack
  (self push
    ((self tos) invoke
      (row signature)
      arg)))
```

### After: approved Gel helpers

```aloe
(invoke-zero
  (row GelRow)
  GelStack
  (self push
    ((self tos) invoke-mirrored
      (row signature)
      (List empty))))

(invoke-one
  (row GelRow)
  (arg Mirror)
  GelStack
  (self push
    ((self tos) invoke-mirrored
      (row signature)
      (List of arg))))

(invoke-one (type T)
  (row GelRow)
  (arg T)
  GelStack
  (self invoke-one row (Mirror of arg)))
```

The zero-argument helper adds an empty argument list. The mirrored-argument
helper replaces `(arg subject)` with `(List of arg)`. The ordinary-argument
helper becomes shorter by delegating to the exact `Mirror` overload.

The new operation supplies an expected `(List Mirror)` for `(List empty)`,
so its element type closes normally. Its result selects `push`'s exact
`Mirror` overload. The generic helper's `T` is already a declared bound
parameter; neither an unknown subject type nor an unknown invocation-result
type is introduced into these bodies.

Call sites stay identical before and after:

```aloe
(stack invoke-zero row)
(stack invoke-one row 2)
(stack invoke-one row picked-mirror)
```

Here `stack : GelStack`, `row : GelRow`, and `picked-mirror : Mirror` are
existing values. The chosen row must still have the appropriate owner, arity,
and parameter types. Gel's menu selection and ordinary key handling need no
additional type annotation, type picker, or wrapper at these call sites.

For the audit's small integer example, with `receiver` mirroring `10`,
`signature` its exact `Int.+` row, and `argument` mirroring `2`:

Before:

```aloe
((Mirror of (receiver invoke signature (argument subject))) raw)
```

After:

```aloe
((receiver invoke-mirrored signature (List of argument)) raw)
```

Both intend the String `"12"`. The earlier review executed the current form;
the replacement form has only been reviewed as design text. This equivalence
uses an ordinary Int result; the general Mirror-result policy is below.

## Exact invocation and result handling

The new operation evaluates its receiver and its two arguments under the
ordinary send rule. It checks the exact signature owner and row, the number
of mirrors in the argument list, and the selected row's instantiated argument
types before running that row. It unwraps each argument exactly once inside
the sealed boundary. It does not search by selector or repeat overload
selection.

Validate the ordinary result against the fully instantiated row result
before adapting it for the caller:

- If the result is already a `Mirror`, return that same mirror.
- Otherwise return a mirror of the result, under the existing `Mirror of`
  contract.

This is exactly the adaptation already performed by Gel's two `push`
overloads. It preserves rows that themselves return a Mirror, rather than
adding an extra wrapper and changing what Gel displays next. It performs no
recursive unwrapping or flattening.

`Mirror of` itself keeps its existing meaning: `(Mirror of existing-mirror)`
explicitly reflects the Mirror object. To pass a Mirror object as an ordinary
argument to a selected row, place `(Mirror of existing-mirror)` in the
argument list; placing `existing-mirror` there passes its subject.

Wrong ownership, arity, argument type, or unresolved generic parameters prevent
the selected row from executing. A bad result is rejected after execution;
its effects are not rolled back. Host rows keep their exact interface,
crossing restrictions, target state, failure causes, and break behavior.
Multi-constructor local rows remain absent from reflection.

## The generic decision

The source checker sees concrete `Mirror`, `Signature`, and `(List Mirror)`
types throughout the new operation. A selected row may still have bound
generic parameters in its opaque descriptor. These are not unresolved source
inference variables escaping the checking unit.

Permit the guarded invocation to solve those row parameters from:

1. the exact receiver instantiation already fixed by the signature owner;
   and
2. the closed type evidence associated with each mirrored argument's subject.

Use the existing invariant/nominal constraint relation and require a complete,
consistent instantiation before the row runs. Keep each invocation's bindings
fresh. Do not infer missing parameters from the result, execute a factory or
callback to discover its type, guess a protocol, or scan payloads to invent a
family or collection instantiation.

The evidence is trusted internal metadata, not the descriptive symbols from
`Signature.params` or `Signature.return`. For example, a family value already
has resolved nominal arguments; an empty list needs its already determined
element type; and a function needs its checked arrow type with its bound
arguments resolved. How this evidence is represented is an implementation
choice. It must be available without executing user behavior, and malformed
foreign values must not be blessed merely by wrapping them in a Mirror.

Reflection continues to describe a concrete nominal subject rather than its
earlier protocol view. A list's invariant element type and a function's
checked arrow are not recomputed from their current contents or behavior.
No public type query, cast token, source `Any`, or source existential type is
introduced.

The new operation has no generic parameters of its own and no special
type-header forwarding rule. Its outer result is `Mirror`; that expectation
does not specify the selected row's ordinary result type. Cases requiring
additional type evidence use the existing contextually typed `invoke` or an
ordinary explicitly typed constructor send.

### Consequences for representative rows

In the following table, the target and exact signature belong to the named
family type object or instance. Arguments are already well-typed mirrors;
family declarations are the candidate's `Option` and `Result` examples.

| Selected row and arguments | Approved outcome |
| --- | --- |
| `Int.+`, with a mirror of `2`, targeting mirrored `10` | Return a mirror of `12`. No row parameters remain to solve. |
| `(Option Int).map`, with a mirror of a function of type `(-> Int String)` | Resolve row-local `U = String` before calling the function; return a mirror of the resulting `(Option String)`. |
| `Option.Some`, with a mirror of `1` | Resolve `T = Int` from the sealed input type before construction; return a mirror of `(Option Int)` Some. |
| `Option.None`, with an empty argument list | Reject before construction: nothing determines `T`. A result type of `Mirror` supplies no missing family argument. |
| `Result.Ok`, with a mirror of `1` | Reject before construction: `T = Int` is determined but `E` is not. A successful `accepts?` query on this input does not change that. |
| An `(Option Int)` instance's nongeneric family row | Keep the exact owner's fixed `Int`; do not mint or infer another receiver instantiation. |
| A factory with a generic parameter determined only by its result | Reject before running its body. Do not use its returned value to finish inference. |

For an ordinary explicitly typed construction, the established route remains:

```aloe
(Mirror of (Option None (type Int)))
```

That expression fixes `T` at source checking and then mirrors the constructed
value. The new operation does not need an extra generic type-picker UI in Gel.
It also does not promise that every reflected generic row is invocable from
Gel without further context.

Permission to use sealed argument type evidence is the principal approved
design amendment. Limiting the operation to rows with no fresh parameters
after receiver substitution would suffice for many existing Gel examples,
but would exclude `Some` and generic `map` even when their mirrored inputs
determine every required type. The approved rule retains those useful calls
within the sealed reflection boundary.

## Why use a list of mirrors

The fixed argument list gives the operation an ordinary, fully describable
callable row:

```text
params:      (Signature (List Mirror))
return:      Mirror
type-params: ()
role:        operation
```

It needs no new variadic signature-description convention or source syntax.
The list length is the selected target row's arity; the new Mirror operation
itself always has two arguments. This is invocation, not a generalization of
`Signature.accepts?`, which remains a one-parameter query.

A variadic spelling would save `(List of ...)` at direct calls, but its
reflective signature would require an additional convention. The fixed list
keeps that issue out of U1. In Gel, the list construction stays inside the
existing helpers shown above.

Append the new row after the existing Mirror API rows, preserving their
relative order. Ordinary subjects do not acquire this message. Explicitly
browsing the Mirror object's own API will show the additional operation;
that menu's text necessarily changes. Thus preservation covers existing Gel
flows and results for valid rows, not a claim that an intentionally extended
reflection API has identical introspection output.

## Approved scope and next documentation work

The approved decision is to add this fixed-arity operation, with Gel's existing
result adaptation and complete pre-execution generic resolution from sealed
input type evidence. Approval authorizes its documentation reconciliation in
89F, not runtime implementation.

Resume 89F by reconciling the candidate's checked-execution, reflection,
examples, diagnostics, exclusions, validation, and client-preservation prose
together. In particular, qualify the blanket runtime-inference wording:
ordinary constructor sends still carry their resolved checked arguments;
only the explicit opaque reflection boundary may instantiate its selected
row from sealed argument type evidence before execution. This distinction
must be stated as an accepted rule, not hidden in an adapter or treated as an
accident of the current runtime.

Add future validation obligations for:

- all three Gel helper paths, unchanged application call sites, and both
  ordinary and already-Mirror results;
- contextual empty argument lists and homogeneous mirrored arguments;
- fixed-owner and input-determined generics, plus unresolved result-only
  parameters and failures that prevent the selected row from running;
- exact invariance and nominal ownership, empty-list and function type
  evidence, and no inference by executing a result or scanning payloads;
- one-level argument unwrapping and deliberately mirrored Mirror objects;
  and
- the new row's exact reflective metadata, preserved local exclusions,
  and unchanged guarded host crossings.

Keep existing uncontextualized `subject` and ordinary-result `invoke` subject
to inference closure. Do not silently allow them to produce an arbitrary
ordinary value just because that value will later be mirrored.

Then update U1 with the accepted decision and evidence, recheck the affected
audit conclusions, and finish 89F if no material issue remains. The roadmap,
durable handoff, ratification, code migration, and runtime implementation stay
later work. Recording approval alone does not close U1 in the audit; candidate
integration and the affected audit checks must still be completed.

[u1]: unified-nominal-adts-design-audit.md#u1-gel-reflection-and-inference-closure
[stack]: ../gel/stack.aloe
[cp89f]: checkpoints/0089f-audit-unified-family-design.md#resuming-89f-with-the-approved-u1-resolution
