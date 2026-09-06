# Draft: unified nominal algebraic families

Status: **provisional and non-normative**

This working note records the design direction approved in conversation through
Decision 9. It is a working memory aid, not an amendment to `SPEC.md`, an
implementation plan, or authorization to change the language. The design can
still be revised as the remaining decisions are made and as applications expose
its strengths and weaknesses.

The eventual accepted design should be rewritten as normative specification
text. This draft may then be replaced or removed.

## Purpose

Aloe currently has nominal product-like classes. This design explores one
unified nominal algebraic model in which:

- a current class is a family with one representation constructor;
- a closed variant has multiple representation constructors;
- sends remain receiver-first;
- protocols remain the open axis of the language;
- families remain the closed data axis;
- the language stays small enough to understand as a whole.

The design is intended to support present applications such as Boids, MPL, the
filesystem interface, and Gel, while making types such as `Option`, `Result`,
and recursive `Tree` natural.

## Current decision status

Approved as a provisional direction:

1. Ontology
2. Construction and type objects
3. Messages and refinement
4. Elimination and exhaustiveness
5. Generics and recursion
6. Open protocols and closed data
7. Runtime behavior
8. Reflection
9. Concrete syntax

Still to decide:

10. Static and implementation consequences

No exact implementation checkpoints should be planned until the semantic
design has been reviewed through Decision 10.

## Decision 1: ontology

### Recommendation

One declaration introduces:

- one nominal family type;
- one ordinary type object associated with that family;
- a finite, nonempty set of representation constructors.

A product-like class is not a separate kind of entity. It is the one-constructor
case of the same family model.

A runtime data value contains:

- the identity of its family;
- its resolved generic arguments;
- the identity of the representation constructor that built it;
- that constructor's immutable payload.

Constructor identity is an opaque identity owned by the family. A constructor
name is a source and presentation label, not the identity itself. Constructors
with the same spelling in different families are unrelated.

### Types and refinements

Representation constructors do not introduce separate nominal types and are
not subtypes of the family. The source-level type is the family, such as
`Option Int`.

The checker may additionally track an internal constructor-set refinement,
written schematically in this draft as:

```text
F A... @ {C1, C2, ...}
```

This notation is explanatory, not proposed source syntax.

- A direct representation-constructor send produces a singleton refinement.
- An ordinary family type permits all of the family's constructors.
- Control flow can intersect, subtract, union, or forget constructor knowledge.
- A refinement can always widen to its unrefined family.

Refinements express facts known by the checker. They do not create new nominal
identities.

### Operations

There are two distinct operation surfaces:

- whole-family messages, available on every value of the family;
- case-local messages, available only when the receiver is known to have one
  particular constructor.

For a one-constructor family, the sole case is always known, so its local
surface has the familiar behavior of a current Aloe class.

Protocol conformance belongs to the whole family, never to an individual
constructor.

### Boundaries

The type object and its instances are distinct kinds of value. Calling a
constructor is a send to the type object, not an alternative expression model.

This semantic unification does not require all primitive and host-provided
values to be immediately reimplemented in Aloe using family declarations.
They can first obey the same observable model through built-in descriptors.

## Decision 2: construction and type objects

### One type object per declaration

A generic family has one declaration-level type object, not one runtime type
object for every instantiation. Generic arguments for a construction are
resolved at the send site.

The type object receives two kinds of ordinary receiver-first message:

- representation-constructor messages;
- factory messages.

There is no separate constructor-call expression.

### Representation constructors

A representation constructor is declared by a distinguished, bodyless type-
object method row. It has:

- a selector reserved within that family from factory use;
- a stable constructor identity;
- an ordered, typed payload;
- a result in its owning family.

Sending a constructor message is freshly polymorphic at each send. Its result
is the family refined to that constructor.

The initial model makes all representation constructors public. Visibility can
be reconsidered later if an application demonstrates the need.

Representation constructors are not first-class values. A program that needs
one as a value can explicitly wrap the send in an `fn` object.

### Factories

Factories are ordinary type-object methods with bodies. They may be overloaded,
may compute before constructing, and may return any constructor of their
declared family result. They do not add cases and do not participate in
exhaustiveness.

A factory's static result is only its declared result type. Calling a factory
does not reveal which constructor its implementation happened to choose.

### Generic argument inference

Constructor type arguments are constrained by:

- explicit static instantiation, when present;
- an expected exact family type;
- payload argument types;
- constraints from the surrounding expression.

An expected protocol type does not identify a family and therefore cannot by
itself infer that family's generic arguments.

Unresolved arguments may remain temporarily while the enclosing expression is
checked, but may not escape the checking unit. There is no constructor-specific
`let` polymorphism. Thus a bare parameterless `None`, or a partially determined
`Ok 1`, is an error when neither context nor explicit instantiation determines
all parameters.

The evaluator receives the checked, resolved type arguments. It must not infer
them solely from runtime payload values.

Tooling and reflection can distinguish a constructor row from a factory row and
report its parameters, result, and generic variables, as specified further in
Decision 8.

## Decision 3: messages and refinement

### Explicit whole-family surface

Every whole-family message is declared explicitly. Aloe does not infer a
family message merely because all constructors happen to define a local message
with the same selector.

A selector is classified within a family as either whole-family or case-local,
never both. Representation payload selectors are reserved from collision with
that classification.

The same local selector may appear on several constructors, but that repetition
does not promote it to the family surface.

Static availability is therefore simple:

- an unrefined family receiver has only whole-family messages;
- a singleton-refined receiver has whole-family messages plus that case's local
  messages;
- a protocol-typed receiver has only the protocol surface.

### Implementing a whole-family message

Each overload of a whole-family message chooses exactly one of two modes:

1. one uniform body, checked with an unrefined `self`; or
2. one body per constructor, with every body checked using the corresponding
   singleton-refined `self`.

There is no default body followed by constructor overrides.

For a one-constructor family, a uniform body's `self` is inherently singleton-
refined, so product fields and local operations remain directly usable.

Adding a constructor makes every exhaustive per-constructor implementation
incomplete until a body for the new constructor is supplied.

### Runtime dispatch

After overload selection, runtime lookup uses the selector's classification:

- a whole-family selector selects the family row, then either its uniform body
  or the body indexed by the value's actual constructor;
- a local selector selects the table belonging to the actual constructor.

Because the selector partitions are disjoint, there is no precedence rule
between a case method and a family method.

Aloe keeps its existing useful dynamic-overload behavior: a statically broader
protocol call may select a more-specific concrete overload at runtime. To keep
that sound, any overlapping more-specific row must return a value usable as the
broader row's declared result. This is the return-coherence requirement.

### Sources of refinement

Authoritative constructor refinements initially come only from:

- direct representation-constructor sends;
- exhaustive case branches;
- per-constructor implementations of family messages;
- immutable local aliases that preserve an already-known receiver occurrence.

Arbitrary predicates, reflection, equality tests, and user-defined messages do
not refine a value.

External consumers use exhaustive elimination. Family-owned operations may use
per-constructor bodies when that gives the clearest encapsulation.

## Decision 4: elimination and exhaustiveness

### One receiver-anchored special form

Aloe should have one receiver-shaped exhaustive case form, schematically:

```text
(value case
  ...clauses...)
```

The spelling and complete grammar are specified in Decision 9.

This is a genuine special form because:

- constructor labels must be literal;
- branch bindings introduce lexical scope;
- branches are lazy;
- each branch receives a different static refinement.

It reserves a second-position marker in the same syntactic position normally
occupied by a selector. Before implementation, this addition must be accepted
into the normative specification.

The scrutinee is evaluated exactly once. Runtime dispatch examines its opaque
constructor identity and evaluates exactly one branch.

### Eligible scrutinees

Exhaustive case analysis applies only to a concrete nominal family whose finite
constructor set is known. It does not apply directly to:

- a protocol value;
- an unconstrained type variable;
- a type object;
- a `Mirror` or other reflective description.

### Coverage

Let `S` be the constructors still possible under the scrutinee's current
refinement. With no default clause, the explicitly named constructor set `E`
must equal `S` exactly.

Each explicit clause may bind:

- the whole value, refined to that constructor;
- that constructor's payload positions, in declaration order.

Payload binding has exact arity. The refined whole-value binding gives access
to case-local messages as well as to the payload bindings.

Required diagnostics include:

- missing constructors, reported in declaration order;
- duplicate constructors;
- names that are not constructors of the scrutinee family;
- constructors impossible under the current refinement;
- wrong payload arity;
- an unreachable default;
- incompatible branch results.

### Default clause

A final default clause is permitted only when the residual set `S - E` is
nonempty. It covers that entire residual set and binds, at most, the whole
residual-refined value. It does not receive constructor-specific payload
bindings.

Using a default is an explicit opt-out from future missing-case diagnostics.
An application-domain case named `Other`, such as in a filesystem family, is
still an ordinary explicit representation constructor and is not synonymous
with the language default.

There is no silently partial case form.

### Initial pattern and result model

Patterns are flat. The first design has no nested patterns, guards, alternatives,
or fallthrough. Programs perform nested decomposition with nested case forms.

Branch results are checked bidirectionally:

- with an expected result type `R`, every reachable branch is checked against
  `R`;
- without one, the checker gathers constraints from every reachable branch in
  a branch-order-independent way.

Branches returning the same nominal family must unify invariant generic
arguments; their outer constructor refinements are unioned. Aloe does not
invent a shared protocol result as a least upper bound. If the desired result
is a protocol, the context must state that expectation.

Both explicit and default branches participate in result checking.

### Considered alternatives

The following were rejected or deferred in favor of one small, exhaustive,
receiver-shaped form:

- an ordinary `case` message taking handler thunks;
- a top-level, non-receiver-shaped eliminator;
- encoding all elimination as per-constructor methods or visitors;
- beginning with a full pattern language.

## Decision 5: generics and recursion

### Invariant family parameters

Nominal family parameters are invariant. `Option Sym` is not an `Option Math`
merely because `Sym` conforms to `Math`.

Expected types can nevertheless instantiate a constructor exactly. For example,
under an expected `Option Math`, constructing `Some` with a `Sym` payload may
choose `T = Math`; that constructs an `Option Math` from the outset. It is not a
covariant conversion from an already-constructed `Option Sym`.

Constraints are solved across the enclosing expression rather than greedily
per constructor. Schematically:

```text
None together with Some 1       => Option Int
Ok 1 together with Error "x"    => Result Int String
```

A constructor result with unresolved parameters is rejected when it reaches
the checking-unit boundary.

### Refinement propagation

The constructor-set component is flow knowledge, not part of nominal type
identity and not a source-level subtype declaration.

It is introduced, changed, and forgotten as follows:

- direct construction produces a singleton set;
- a case branch intersects with its named constructor;
- a default branch subtracts explicitly handled constructors;
- branch joins union possible constructors;
- ordinary widening forgets the set and yields the complete family;
- conversion to a protocol forgets it.

Refinements are shallow initially. Generic storage types do not encode nested
refinement components such as `List (Option T @ Some)`. Payload declarations
and generic containers carry the base family type. This lets, for example, one
`List Entry` contain values built by different `Entry` constructors.

An immutable, direct local alias may preserve an outer occurrence refinement.
Source annotations, method and factory result types, protocol conversion, and
ordinary generic storage generally expose the unrefined family.

### Recursive families

The semantic model supports recursive nominal algebraic families, while making
no claim to a full inductive type theory.

The initial recursion rule is direct, regular self-recursion:

- a declaration's family and constructor identities are registered while its
  payloads and methods are checked;
- a payload may refer to the family currently being declared;
- the recursive occurrence must use the same parameters, at full arity and in
  the same order;
- recursive occurrences may appear beneath ordinary types such as `List` or
  function types;
- nonregular or polymorphic recursion, such as `Tree (List T)`, is rejected;
- parameter permutation is rejected;
- references to previously declared families remain allowed;
- mutually recursive and general forward declaration groups are deferred.

There is initially no positivity restriction. Aloe is not claiming proof-theory
induction principles or totality, and method recursion is already permitted
without termination checking. Values remain finite at runtime under the
ordinary immutable construction rules.

The preferred term is therefore **recursive nominal algebraic family**, not
"inductive type."

Recursion is part of the semantic destination but not the first implementation
slice. Nonrecursive `Option` and `Result` should establish the model before a
recursive `Tree`. The exact staging remains for Decision 10.

## Decision 6: open protocols and closed data

### The two axes

A family's representation is closed: only its declaration fixes its finite set
of constructors and payloads.

Protocols are open in the implementation direction: downstream code may define
new nominal families that explicitly conform to an existing protocol.

These are deliberately independent axes. A multi-constructor family can conform
to protocols just as a one-constructor family can.

### Conformance

Every user-defined nominal family may explicitly conform to zero or more
protocols. Conformance is:

- nominal and explicit, never inferred structurally;
- attached to the whole family, never to a constructor;
- uniform across all generic instantiations of the family in the initial model.

Supporting more than one direct protocol removes the current one-protocol
restriction. Initially there is still no protocol inheritance, protocol
intersection type, protocol default method, protocol parameter, or conditional
conformance.

Because generic constraints are not yet part of the type system, a declaration
cannot say that `F T` conforms only when `T` conforms. Conditional conformance is
deferred until such constraints have a principled design.

Protocol-required selectors must be whole-family messages. A representation
constructor, factory, payload accessor, case-local message, or reflective
operation cannot satisfy a protocol requirement.

### Signature compatibility

For a family row to implement a protocol row:

- its parameters must accept every argument accepted by the protocol row;
- its result may be more specific, provided it is usable as the protocol row's
  declared result.

This is contravariant parameter compatibility and covariant result
compatibility within Aloe's small nominal and family-to-protocol type relation.

A family may have additional overloads. At least one row must cover the full
protocol domain. Any more-specific rows that runtime dispatch might choose must
also obey the return-coherence rule from Decision 3.

One compatible family row may satisfy identically shaped requirements from
multiple protocols. Requirements with differing parameter types may be served
by overloads. Requirements with the same parameter shape but incompatible
result obligations are rejected.

### Using a conformance

A singleton-refined family value can convert to any protocol its whole family
declares. The conversion forgets constructor refinement. Protocol-typed code
sees only the protocol's messages and cannot exhaustively case-analyze the
underlying family.

At runtime, a protocol send is checked against the static protocol signature,
then dispatched through the actual family's whole-family table, including
normal concrete overload selection. Protocols do not acquire separate runtime
method tables.

Adding a constructor requires rechecking:

- per-constructor family-message bodies;
- exhaustive case forms that did not opt into a default;
- the family's protocol conformance.

The operation set of a particular protocol version is closed. Adding a required
protocol operation is intentionally a breaking change that rechecks conforming
families. Defining a new family that conforms to the existing protocol remains
open.

### Additive receiver extensions

The design retains Aloe's receiver-anchored, additive method extensions because
they are essential to MPL's cross-referenced organization.

An extension may add:

- a whole-family message with a uniform body;
- additional compatible overload rows;
- an ordinary type-object method or factory.

An extension may not:

- add a representation constructor;
- add or change payload;
- add a case-local message;
- add a per-constructor body table;
- claim a new conformance for an existing family;
- replace an existing exact method row.

Constructor-local and per-constructor behavior stays with the representation
declaration. An external whole-family method that needs to distinguish cases can
use the ordinary exhaustive case form internally.

All exact rows participate in one global coherence check. Distinct overloads
are allowed subject to ordinary ambiguity checks and return coherence, but rows
may not collide with constructor or case-local selectors.

The family declaration owns its explicit conformance claims. Methods needed to
satisfy those claims may be supplied by additive extensions before the
surrounding program is finalized and conformance is checked. This preserves the
organization used by MPL without permitting retroactive orphan conformance.

The first implementation may continue to use a single program image with global
coherence and additive, non-replacing definitions. Module ownership rules are a
future design problem.

### Authority summary

| Change | Authority |
| --- | --- |
| Add constructor, payload, or local operation | Edit the family declaration |
| Add whole-family operation or factory | Declaration or additive receiver extension |
| Define a new family conforming to an existing protocol | Downstream code |
| Add conformance to an existing family | Amend the family declaration |
| Add a protocol requirement | Amend the protocol and recheck conformers |
| Define a new protocol | Downstream code; families explicitly opt in |
| Replace an existing method row | Not allowed |

### Expression-problem boundary

This model makes the tradeoff explicit:

- a closed family is easy to extend with external exhaustive operations;
- an open protocol is easy to extend with new implementing families;
- adding an operation across every arbitrary implementation of an existing
  protocol requires amending that protocol, defining a new opt-in protocol, or
  writing an external service.

There is no hidden mechanism that makes both axes open at once.

MPL can remain an open `Math` protocol while individual symbolic forms may be
single- or multi-constructor families. A filesystem family should not use
constructor-specific protocol conformance; case-specific capability belongs in
local messages or payload values, while uniformly available behavior belongs in
whole-family protocols.

Protocols remain types and contracts, not runtime objects that own behavior.

### Deferred or rejected alternatives

The initial design does not adopt:

- the present one-protocol-per-class limitation;
- structural protocol conformance;
- per-constructor conformance;
- retroactive orphan conformance claims;
- protocol default implementations;
- protocol inheritance or intersections;
- declaration-only methods that would remove MPL's additive organization.

## Decision 7: runtime behavior

### Semantic representation

A nominal algebraic family instance is an immutable structural value whose
nominal identity is carried by opaque runtime identities, not by names.

Conceptually, every family value contains:

```text
<family-id, resolved-type-arguments, constructor-id, payload-values>
```

This is the semantic model, not a required physical representation. The
implementation may optimize it freely as long as those optimizations are not
observable.

### Family and constructor identity

Each family declaration creates one opaque family identity. Each representation
constructor creates one opaque constructor identity owned by that family. A
constructor identity uniquely determines its owning family.

Names do not participate in identity:

- two families with the same name are distinct when introduced by distinct
  declarations;
- same-spelled constructors in different families are distinct;
- constructor identity cannot be forged with a corresponding `Symbol` or
  `String`;
- comparing printed names is not a runtime type test.

Names remain source and presentation labels used for lookup, diagnostics,
printing, and appropriately constrained reflection. Runtime checks use the
resolved opaque identities.

Identity is guaranteed within one linked Aloe program image. This design does
not yet promise stable opaque identities across separate executions,
recompilation, serialization, or a future module-reloading system.

### Instantiated generic identity

The runtime type of a generic family value includes its resolved type
arguments. For example, `Option Int` and `Option String` are different runtime
instantiations of the same family.

Parameterless constructors retain the instantiation chosen by the checker. A
`None` at `Option Int` and a `None` at `Option String` therefore have the same
family declaration and representation constructor but different runtime types.

Generic arguments remain invariant at runtime. The evaluator receives them from
checked construction and never attempts to reconstruct them from the payload.

### Values contain data, not behavior

A family value contains its constructor and payload but no per-instance method
dictionary or method closures. Behavior belongs to declaration-level metadata,
including:

- constructor descriptions;
- whole-family method rows;
- constructor-local method rows;
- explicit protocol conformances.

A send uses the receiver's family identity, its constructor identity when the
selector is case-local or the family body is constructor-indexed, and the
established overload rules.

Consequently:

- converting a family value to a protocol does not wrap or copy it;
- widening or forgetting a constructor refinement does not alter it;
- a factory leaves no provenance in its result beyond the representation
  constructor and payload it ultimately produced;
- adding protocol conformance does not change a family's value representation;
- one-constructor products and multi-constructor variants use the same runtime
  model.

### Immutability and allocation identity

A family value's constructor, resolved type arguments, and payload positions are
fixed when it is created. There are no setters, constructor changes, or payload
replacement.

This is shallow semantic immutability. A payload may contain a function or an
identity-bearing host capability whose external state changes. The enclosing
family value cannot replace that payload, but it does not deep-freeze the
referenced capability.

Ordinary family instances do not expose allocation identity. Two separately
allocated values with the same nominal structure are observationally the same
data value. A runtime may share, copy, intern, or allocate them independently.

This makes a constructor refinement permanently stable: a value known to be
`Some` cannot later become `None`.

Under normal Aloe construction, recursive algebraic data is finite and acyclic.
Constructing an immutable recursive node requires its payload values to exist
already. Opaque host values and function closures remain leaves from the
algebraic structural perspective.

### Kernel structural equality

Aloe retains a small, non-overridable kernel equality used by `check` and other
trusted runtime machinery.

Two family values are structurally equal exactly when:

1. their opaque family identities are the same;
2. their resolved runtime type arguments are the same;
3. their opaque constructor identities are the same;
4. corresponding payload values are recursively kernel-equal.

Thus separately allocated `Point` values with equal coordinates compare equal,
as do separately allocated `Some` values with equal payloads. `Some 1` and
`None` do not compare equal. Structurally identical instances introduced by
distinct nominal family declarations do not compare equal.

A `None` at `Option Int` and a `None` at `Option String` are unequal at the
kernel level because their runtime instantiations differ.

At payload leaves:

- ordinary scalar and algebraic values use their established value equality;
- functions, type objects, host capabilities, and other explicitly
  identity-bearing opaque values use their own opaque identity unless that
  built-in kind already defines value semantics.

This gives equality a total runtime answer without first requiring generic
constraints or an `Eq` protocol.

Kernel equality does not inject a user-visible `=` message into every family.
If a family or protocol declares `=`, it is an ordinary operation and may
express domain-specific equality. It does not redefine the kernel comparison
used by `check`. This separation prevents trusted testing behavior from
depending on arbitrary user computation, normalization, or host effects.

A future explicit equality protocol remains possible but is not required by the
family model.

### Raw printing and user display

Aloe retains distinct raw and user-facing display paths.

The raw structural renderer:

- never invokes Aloe methods;
- identifies the nominal family;
- identifies the actual constructor when that information is not redundant;
- renders payloads in declaration order;
- uses family and constructor names only as presentation labels;
- does not claim to produce parseable source or a serialization format.

Its information content would resemble:

```text
#<Point 1 2>
#<Option.Some 1>
#<Option.None>
```

The exact punctuation is specified in Decision 9. For a one-constructor family,
the renderer omits the redundant constructor label, preserving the familiar
product-like appearance. For a multi-constructor family, it shows the
constructor.

For generic values whose payload does not reveal their instantiation, detailed
raw output must be capable of showing the resolved type arguments. Whether
generic arguments appear always or only in a detailed diagnostic rendering is
reserved with the concrete printing design.

Raw rendering is diagnostic presentation. Its text is never used to establish
identity, equality, or type compatibility.

Normal interactive display may continue to use an applicable whole-family,
zero-argument `show` message returning `String`. A multi-constructor family can
implement `show` with exhaustive per-constructor bodies. If no suitable `show`
exists, display falls back to structural rendering.

The raw path remains independently available and never invokes `show`, giving
debugging and reflection a dependable representation even when display code
fails, recurses, or deliberately hides structure.

An implementation may impose clearly marked depth or collection limits for
interactive output. Such elision affects presentation only, never equality or
program behavior.

### Runtime type checks

All runtime boundaries use one consistent nominal relation.

For an expected concrete family type `F A...`, a value passes when:

- its family identity is exactly `F`;
- its resolved generic arguments exactly match `A...` invariantly.

When an internal constructor-set refinement is relevant, the actual constructor
must additionally belong to the permitted set.

For an expected protocol `P`, a family value passes when its exact family
declaration explicitly conforms to the opaque identity of `P`. The actual
constructor is irrelevant because conformance belongs to the family.

No runtime type check succeeds merely because:

- family or constructor names match;
- payload layouts match;
- similarly named messages happen to exist.

Protocol conversion changes the static view of a value but does not allocate a
runtime wrapper.

The same type relation applies at all dynamic boundaries, including:

- constructor payload validation;
- factory results;
- dynamically selected overload arguments and results;
- reflective invocation;
- host-to-Aloe and Aloe-to-host calls.

Trusted statically checked code may optimize redundant checks away, but its
behavior must be equivalent to performing them.

### Defensive constructor integrity

Ordinary Aloe code cannot forge a constructor identity. The runtime must still
preserve these invariants at any boundary that constructs or injects a value:

- the constructor belongs to the recorded family;
- payload arity matches the constructor declaration;
- each payload passes its substituted declared type;
- every generic argument is resolved.

A malformed value is rejected at the boundary that attempted to create or
inject it. It does not survive until a later case expression or send.

Exhaustive case analysis may consequently rely on the family's closed
constructor set. The runtime may defensively reject an impossible malformed
value rather than route it through a default branch.

### Built-ins and host values

The runtime model does not require an immediate rewrite of built-ins. Types such
as `Bool` and `List` may eventually expose equivalent family-and-constructor
descriptions while retaining specialized internal representations initially.

Host interfaces and capabilities remain opaque nominal values. They may have
meaningful identity or external state and are not forced into algebraic payload
representation merely for uniformity. Placing one inside an algebraic family
does not make it structurally inspectable or deeply immutable.

### Rejected runtime alternatives

The design rejects:

- constructor names as runtime tags, because they are forgeable,
  collision-prone, and make spelling affect type identity;
- treating each constructor as an independent class, because that recreates the
  split ontology;
- erasing generic arguments, because parameterless generic constructors and
  dynamic boundary checks would become ambiguous;
- reference equality for ordinary family values, because allocation is not
  meaningful for immutable data;
- user-overridable equality for `check`, because trusted comparison should not
  invoke arbitrary behavior;
- protocol wrapper objects, because a change of static view should not change
  allocation or identity;
- deep-freezing every payload, because host capabilities and functions are
  intentionally opaque;
- retaining factory provenance in values, because construction history is not
  part of a value's meaning;
- allowing raw rendering to invoke `show`, because that would remove the
  dependable diagnostic path.

### Semantic nucleus

An Aloe algebraic value is an immutable, nominally identified family
instantiation containing one opaque constructor and its payload. Nominal
identities govern runtime type checks; structure governs kernel equality; names
govern source presentation and diagnostics.

The precise reflection surface is specified in Decision 8. Its exact printed
spelling is specified in Decision 9.

## Decision 8: reflection

### Reflection boundary

`Mirror` remains a sealed, capability-bearing view of a value's callable
surface. It may describe a family's public schema, but it does not open an
instance's representation or become a second case-analysis mechanism.

The existing reflection architecture remains:

- `(Mirror of value)` creates an explicit reflective boundary;
- `(mirror messages)` returns unique callable selectors;
- `(mirror signatures)` returns one opaque `Signature` per overload row;
- `(mirror invoke signature ...)` invokes that exact row;
- `(signature accepts? candidate)` checks argument compatibility without
  invocation;
- `(mirror subject)` returns the original value under an expected,
  runtime-checked type;
- `(mirror raw)` returns structural diagnostic text.

Reflection messages remain on `Mirror`, not on every Aloe value. There is no
`perform`, dynamic send from a `Symbol`, user construction of signatures, or
second overload search during reflective invocation.

A selector symbol describes a row but grants no authority to invoke it. The
opaque `Signature` is the authority.

### Dynamic nominal receiver

When a value enters `Mirror`, its original static view is not retained. If a
family value was statically known only as a protocol, its mirror still describes
the actual runtime family's public reflective surface. This explicit dynamic
hatch is necessary for tools such as Gel.

The mirror does not retain or manufacture constructor-set refinement. Protocol
conversion does not create a runtime wrapper, and reflection does not reveal a
hidden wrapper.

### Callable surfaces by receiver kind

| Mirrored subject | Reflected callable rows |
| --- | --- |
| Multi-constructor family instance | Whole-family messages only |
| One-constructor family instance | Whole-family messages plus the sole constructor's local messages and payload accessors |
| Family type object | Representation constructors and factories |
| Primitive value or type object | Its existing public primitive rows |
| Host capability | Rows declared by its exact host interface |
| A `Mirror` itself | The reflection API of `Mirror` |

As in the current Gel design, asking an existing mirror for its signatures
describes its stored subject. Explicitly constructing `Mirror of mirror`
reflects the `Mirror` value itself.

#### Multi-constructor local messages

Exposing the actual constructor's local rows from an unrefined mirror would make
method presence an implicit case predicate. Reflective invocation could then
call case-local operations without exhaustive elimination.

For a multi-constructor family:

- actual-constructor local messages do not appear in `messages`;
- their rows do not appear in `signatures`;
- payload accessors do not appear;
- creating a mirror inside a singleton-refined branch does not capture an
  escaping refinement certificate.

A one-constructor family is different because every value necessarily has its
sole constructor. Reflecting its local surface cannot discriminate among cases
and preserves current `Point`-style behavior.

### Family schema through the type object

A family's type object exposes its public construction surface:

- every representation constructor appears as an exact signature row;
- every factory appears as an exact signature row;
- constructor rows occur in constructor declaration order;
- overloaded factories retain one row per overload.

This lets tooling discover the complete public constructor inventory without
asking which constructor an arbitrary instance contains.

Constructor signatures reveal:

- the constructor selector;
- ordered payload types through the parameter description;
- the family result type;
- declared generic parameters;
- that the row is a representation constructor rather than a factory.

Payload position names do not initially become reflective data. Payload order
and arity are semantic; source parameter names are not required to invoke or
exhaustively bind a constructor.

There is no separate first-class `Constructor` token in Aloe source. The opaque
signature row provides checked invocation authority, while its selector and
type data provide presentation metadata.

### Signature role and generic metadata

Each signature reports a semantic role from a small kernel-defined vocabulary:

- `constructor`;
- `factory`;
- `family`;
- `local`;
- `operation`.

`operation` covers callable rows belonging to primitives, `Mirror`, and host
capabilities that are not algebraic family or type-object rows.

A whole-family message with constructor-indexed bodies still appears as one
`family` signature. Reflection describes the public operation rather than the
hidden set of implementation bodies.

A signature also reports its declared row-level generic parameters as
presentation symbols. Existing parameter and return descriptions continue to
use reified `Symbol` and `List` type grammar.

Decision 9 names the additional metadata queries `role` and `type-params`.
Semantically, tooling can obtain:

```text
selector
role
generic parameters
parameter types
return type
```

Family type arguments fixed by an instance are substituted into its reflected
method types. Fresh row-level generic parameters remain visible as variables.

### Reified type data is descriptive

The existing `Symbol` and `List` representation of types remains presentation
data. A signature may describe types with data resembling:

```text
Option
(Option Int)
(Result T Error)
```

This data is useful for menus, documentation, diagnostics, and display. It is
not:

- a first-class type object;
- an opaque nominal identity;
- a cast token;
- a runtime substitute for a source type annotation;
- sufficient to prove that same-spelled nominal families are identical.

Distinct same-named declarations may have identical descriptive spelling.
Exact runtime checks continue to use hidden nominal identities retained by
mirrors and signatures.

The initial design does not add a general first-class `Type` descriptor or a
direct operation for comparing arbitrary runtime types. Gel's actual matching
requirement remains more safely served by `Signature.accepts?`.

### Instance representation remains closed

A mirror of a multi-constructor family instance does not programmatically
expose:

- the current constructor identity;
- the current constructor name as an authoritative tag;
- a constructor predicate;
- payload values or indexed payload access;
- constructor-local signatures;
- the checker's constructor-set refinement;
- an opaque family or constructor identity token;
- the family's conformance list;
- method bodies, dispatch tables, source locations, or closure representation.

In particular, the model has no reflection operations equivalent to:

```text
(mirror constructor)
(mirror payload)
(mirror is-constructor? Some)
```

Those operations would recreate partial pattern matching through reflection and
evade missing-case diagnostics.

To consume an instance's representation, code uses the exhaustive case form,
calls a whole-family operation, or uses an explicitly declared protocol
implemented exhaustively by the family.

A generic inspector that genuinely needs semantic decomposition can request an
`inspect`, `fold`, serialization, or visitor-like protocol. The family then
implements that operation with explicit exhaustive knowledge.

### Refinements are not reflected

Constructor-set refinements are checker facts about an occurrence, not runtime
fields. Therefore:

- `Mirror of` does not preserve an expression's refinement;
- a mirror made from direct `Some` construction has the same reflective kind as
  one made from an unrefined `Option`;
- `(mirror subject)` returns the original value, but its usable static type
  comes from the expected context;
- unwrapping cannot recover an earlier branch refinement.

If `subject` is expected as a concrete family, the returned value may then be
handled with the ordinary exhaustive case form. That is normal checked
elimination, not reflective discrimination.

### Signature identity and ownership

A `Signature` remains an unforgeable capability identifying one exact dispatch
row. Its hidden ownership includes enough information to validate:

- the exact family instantiation for instance rows;
- the exact family type object for constructor and factory rows;
- the appropriate constructor identity for reflectable local rows;
- the exact primitive or host-interface identity;
- the exact overload row.

Consequently:

- a signature from `Option Int` cannot be applied to `Option String`;
- a same-spelled row from an unrelated family is not interchangeable;
- a host row cannot move to a same-named but distinct host interface;
- a family-message row works for every constructor of its owning family;
- a constructor signature works only with the owning family's type-object
  mirror.

Ownership is checked by opaque identity, never by exposed selector or type
description data.

Signature values may be stored and copied. Aloe does not promise meaningful
user-visible equality, ordering, hashing, or stable serialization for them.
Repeated reflection may produce functionally equivalent capabilities without
exposing whether they are the same allocated object.

### Reflective invocation

`Mirror.invoke` invokes the selected row directly. It does not turn the
signature's selector back into a dynamic send or rerun overload resolution.

Invocation checks:

1. signature ownership against the target mirror;
2. argument count;
3. each argument against the exact instantiated parameter type;
4. complete resolution of generic arguments;
5. the result against the instantiated return type.

For an instance method, the receiver family's generic arguments are already
fixed.

For a generic constructor or factory on a family type object, row variables are
freshly instantiated for each invocation using the same constraints as a direct
send: explicit static information, expected result type, arguments, and the
enclosing expression.

Reflection does not make an otherwise ambiguous parameterless `None`
constructible. Unresolved generic arguments still cannot escape the checking
unit.

When a signature variable hides the selected row from the checker, invocation
may continue to use an expected result type. Runtime validation checks the
ordinary result against the opaque selected row.

### `Signature.accepts?`

The existing deliberately narrow operation remains:

- it applies to one-parameter rows;
- it checks the candidate mirror's subject using the invocation type relation;
- it does not invoke or select among overloads;
- it returns `#f` for other arities.

For a generic one-parameter row, input variables may be solved freshly from the
candidate. A `#t` result means the candidate can satisfy that parameter
position. It does not promise that unrelated result-only variables are resolved
or that invocation would type-check without additional context.

There is no initial generalization to arbitrary-arity argument-list reflection.

### Ordering and overload visibility

Reflection order is deterministic within a finalized program image:

- constructor rows follow constructor declaration order;
- declaration-owned method and factory rows follow textual order;
- additive extension rows follow finalized program-definition order;
- overloads remain separate signature rows;
- `messages` removes duplicate selectors while preserving the first signature
  occurrence.

A whole-family message with constructor-specific bodies contributes one
overload row, not one row per body.

Adding a constructor, factory, method, or overload may intentionally change
later menu positions. A future module system may need a stronger ordering rule.

### Raw output is not a discriminator contract

Decision 7 established that raw output identifies the constructor of a
multi-constructor value for human diagnostics. Programs can compare arbitrary
strings, so textual branching cannot be made physically impossible.

The semantic boundary is that raw text:

- provides no constructor identity;
- supplies no payload values;
- grants no signature authority;
- produces no static refinement;
- is not an exhaustive or parseable representation contract.

Code that parses `raw` or branches on `show` is branching on presentation text.
Aloe does not treat that as correct case analysis and cannot provide missing-
case diagnostics for it. The supported semantic discriminator remains the
exhaustive case form.

### Application consequences

Gel retains its required reflection behavior:

- heterogeneous stack slots remain `Mirror` values;
- menus enumerate exact overload rows;
- `Signature.accepts?` filters one-argument rows;
- `Mirror.invoke` invokes the selected row;
- `subject` and `raw` retain their roles.

A mirrored `Point` continues to expose `x` and `y` because `Point` has one
constructor.

A mirrored `Option Int` instance exposes whole-family operations but not a
`Some` payload or `None`/`Some` tag. Mirroring the `Option` type object exposes
the public `None` and `Some` constructor signatures and identifies them as
constructors.

MPL retains dynamic concrete reflection: a protocol-typed `Math` value can
reveal its concrete family's whole-family overloads. Constructor-local details
remain hidden.

Host capability reflection remains derived from its exact host-interface
declaration. The family model does not weaken that ownership boundary.

The receiver-shaped case form is syntax rather than a message, so it never
appears in `messages` or `signatures`.

### Rejected reflection alternatives

The design rejects:

- reflection methods on every value, because they pollute every receiver
  surface;
- dynamic `perform` from selector symbols, because it discards exact-row
  ownership and duplicates send;
- exposing current constructor tokens or arbitrary payload values, because that
  bypasses exhaustive elimination;
- reflecting multi-constructor local rows, because method presence becomes case
  discovery;
- capturing branch refinement inside an escaping mirror, because `Mirror`
  becomes a hidden proof object;
- user-created signatures, because handwritten selectors and type descriptions
  become forgeable authority;
- ownership checks by name, because they break nominal isolation;
- reflecting each constructor-specific family body separately, because that
  exposes implementation layout rather than the public row;
- a general first-class `Type` universe without application pressure;
- hiding the constructor/factory distinction, because tooling must understand
  the construction model from Decision 2.

### Reflection nucleus

A `Mirror` may tell a program which public operation it holds authority to
invoke. It may describe a family's public constructors through the family type
object. It may not tell a program which constructor an arbitrary
multi-constructor instance currently contains or extract that instance's
representation.

## Decision 9: concrete syntax

### One nominal declaration form

`define-family` is the single nominal data declaration. Products and variants
differ only in the number of explicitly declared constructors.

Construction remains an ordinary send:

```aloe
(Point new 1 2)
(Option Some 1)
(Option None (type Int))
```

The only new expression form is the receiver-anchored exhaustive `case`.

### Family declaration grammar

The declaration shape is:

```text
FamilyDeclaration ::=
  (define-family FamilyHeader
    ConformanceSection?
    ConstructorSection
    FactorySection?
    FamilyMethodSection?)

FamilyHeader ::=
    Name
  | (Name TypeVariable ...)

ConformanceSection ::=
  (conforms ProtocolName ...)

ConstructorSection ::=
  (constructors Constructor ...)

Constructor ::=
  (ConstructorSelector
    (fields Field ...)
    LocalMethodSection?)

Field ::=
  (name Type)

FactorySection ::=
  (factories Method ...)

FamilyMethodSection ::=
  (methods FamilyMethod ...)

LocalMethodSection ::=
  (methods Method ...)
```

Sections have a fixed order:

1. optional `conforms`;
2. required `constructors`;
3. optional `factories`;
4. optional whole-family `methods`.

Every family has at least one constructor. Empty optional sections are normally
omitted. Each constructor always has an explicit `fields` section, including a
zero-payload constructor.

This keeps the representation visually explicit without requiring a second
`class` construct.

### One-constructor product example

The current generic `Point` becomes:

```aloe
(define-family (Point T)
  (constructors
    (new
      (fields
        (x T)
        (y T))))
  (methods
    (+ (other (Point T)) (Point T)
      (Point new
        ((self x) + (other x))
        ((self y) + (other y))))

    (dot (other (Point T)) T
      (((self x) * (other x)) +
       ((self y) * (other y))))))
```

Construction remains:

```aloe
(Point new 10 20)
```

There is no automatically generated `new`. It is an explicitly declared
representation constructor named `new`. The same declaration form works for
every nominal family.

### Multi-constructor family example

`Option` is:

```aloe
(define-family (Option T)
  (constructors
    (None
      (fields))
    (Some
      (fields
        (value T))))
  (methods
    (present? () Bool
      (per-constructor
        (None #f)
        (Some #t)))))
```

Its construction sends are:

```aloe
(Option Some 10)
(Option None (type Int))
```

Constructor selectors are ordinary selector symbols. Capitalization is
conventional rather than enforced, so `None`, `Some`, and `Branch` coexist with
a product constructor named `new`.

Constructors are not environment bindings. Writing `Some` as an expression does
not produce a constructor value. A first-class constructor-like function is
explicit:

```aloe
(fn (value) (Option Some value))
```

### Constructor declarations

A constructor declaration contains its selector, one required `fields` section,
and an optional local `methods` section. It has no body or explicit result type.
Its result is its owning family instantiated with the family parameters.

For example:

```aloe
(define-family (Tree T)
  (constructors
    (Leaf
      (fields
        (value T)))
    (Branch
      (fields
        (left (Tree T))
        (right (Tree T))))))
```

Construction is:

```aloe
(Tree Leaf 10)
(Tree Branch left-tree right-tree)
```

Constructor-specific type parameters, existential fields, GADT result
equations, and explicit constructor result annotations are absent. Payload
declarations use family parameters under Decision 5's regular-recursion rules.

Constructor selectors are unique and cannot be overloaded. A constructor
selector is reserved throughout its owning family from factories, family
messages, local messages, and additive extensions. Although the type-object and
instance surfaces are operationally distinct, this reservation keeps every
constructor label unambiguous in sends, reflection, and case clauses.

### Payload fields and local methods

Each payload field generates a zero-argument local accessor, as current class
fields do. A constructor may also declare local methods:

```aloe
(define-family Entry
  (constructors
    (Directory
      (fields
        (path String))
      (methods
        (child-path (name String) String
          (((self path) append "/") append name))))

    (Regular
      (fields
        (path String)
        (size Int))
      (methods
        (empty? () Bool
          ((self size) = 0))))

    (Other
      (fields
        (path String)))))
```

Inside a local method, `self` is singleton-refined to the owning constructor.

Payload and local selectors:

- are unique within a constructor except for valid local overloads;
- may repeat on other constructors;
- do not become whole-family messages through repetition;
- cannot collide with a whole-family selector.

There is initially no visibility syntax because all representation constructors
are public.

### Factories

Factories are declared on the family type object:

```aloe
(define-family (Option T)
  (constructors
    (None
      (fields))
    (Some
      (fields
        (value T))))
  (factories
    (when (condition Bool) (value T) (Option T)
      (if condition
          (self Some value)
          (self None)))))
```

Within a factory body, `self` is the family's type object. It can send
constructor and other factory messages normally.

Factories use the existing method grammar, have explicit return types, and may
overload one another. Their selectors cannot collide with representation
constructors.

A factory call is an ordinary send:

```aloe
(Option when ready? value)
```

No surface punctuation distinguishes a factory from construction. Reflection's
signature role describes the selected type-object row.

### Method syntax

The existing method-row syntax remains:

```text
(selector (parameter Type) ... ReturnType body)

(selector () ReturnType body)

(selector
  (type U ...)
  (parameter Type) ...
  ReturnType
  body)
```

For example:

```aloe
(map
  (type U)
  (f (-> T U))
  (Option U)
  body)
```

Protocol signatures retain the same shape without a body:

```aloe
(define-protocol Show
  (show () String))
```

Protocols themselves remain non-generic initially.

### Whole-family implementation modes

A whole-family method has either an ordinary uniform body or a declaration-only
`per-constructor` body table.

An ordinary uniform body is written exactly like an existing method:

```aloe
(methods
  (keep (fallback T) T
    fallback))
```

Here, `self` is unrefined unless the family has one constructor. A uniform body
may explicitly eliminate `self` with an ordinary case expression.

A per-constructor table is:

```aloe
(methods
  (present? () Bool
    (per-constructor
      (None #f)
      (Some #t)))

  (show () String
    (per-constructor
      (None "none")
      (Some ((self value) text)))))
```

`per-constructor` is recognized only as the body mode of a whole-family method
declaration. It is not a general expression.

Each branch contains:

```text
(ConstructorSelector body)
```

There are no binders because ordinary method parameters are already in scope,
`self` is singleton-refined in each body, and payload values are available
through that constructor's local accessors.

The table contains every constructor exactly once and has no `else`. Branch
order is semantically irrelevant, although declaration order is the canonical
style.

Local methods and factories always have ordinary bodies. They cannot use this
declaration mode.

### Exhaustive case grammar

The expression grammar is:

```text
CaseExpression ::=
  (scrutinee case CaseClause ... DefaultClause?)

CaseClause ::=
    (ConstructorSelector (payload-name ...) body)
  | (ConstructorSelector whole-name (payload-name ...) body)

DefaultClause ::=
    (else body)
  | (else whole-name body)
```

The form contains at least one explicit or default clause.

A basic `Option` elimination is:

```aloe
(option case
  (None () fallback)
  (Some (value) value))
```

A clause with an optional refined whole-value binder is:

```aloe
(option case
  (None () fallback)
  (Some some (value)
    (some value)))
```

Within the `Some` branch, `some` has `Option T` refined to `Some`, while `value`
has type `T`.

A zero-payload constructor still has an explicit empty payload-binder list:

```aloe
(None () body)
```

If its refined whole value is needed:

```aloe
(None none () body)
```

This makes payload arity visible even for nullary constructors.

### Default clause syntax

A final default uses `else`, matching `cond`:

```aloe
(value case
  (Known (payload) known-body)
  (else other fallback-body))
```

Without a whole-value binding:

```aloe
(value case
  (Known (payload) known-body)
  (else fallback-body))
```

The default clause:

- is final;
- is legal only when it covers at least one possible constructor;
- has no payload binders;
- may bind the entire residual-refined value;
- explicitly opts out of future missing-constructor diagnostics.

A representation constructor named `Other` remains an ordinary explicit case:

```aloe
(entry case
  (Directory (path) ...)
  (Regular (path size) ...)
  (Other (path) ...))
```

It is unrelated to `else`.

### Case form properties

Constructor labels in clauses are unqualified because the scrutinee's nominal
family supplies their namespace:

```aloe
(option case
  (Some (value) ...)
  (None () ...))
```

There is no `Option.Some` expression or global `Some` binding.

Clauses may be written in any order; declaration order is preferred. Missing-
case diagnostics report constructors in declaration order.

Each branch has exactly one expression. Nested elimination uses another
receiver-anchored case:

```aloe
(outer case
  (Some (inner)
    (inner case
      (None () ...)
      (Some (value) ...)))
  (None () ...))
```

There are initially no guards, nested patterns, alternatives, fallthrough, or
wildcard payload patterns. An unwanted payload receives an ordinary lexical
name.

### Reserved case markers

`case` is a reserved second-position marker:

```aloe
(receiver case ...)
```

Such a list is always an exhaustive case form, never an ordinary send. No
message or constructor can therefore use `case` as its selector.

`else` is reserved only as the head of a `case` or `cond` clause and cannot be a
representation-constructor selector.

`per-constructor` is reserved only in the body-mode position of a whole-family
method declaration.

Other section words such as `constructors`, `fields`, `factories`, `conforms`,
and `methods` are special only in their declaration positions. They do not
become globally reserved message selectors.

### Explicit static type arguments

A send may contain one optional type-argument header immediately after its
selector:

```text
(receiver selector (type Type ...) argument ...)
```

The header is static syntax. Its contents are type expressions and are not
evaluated as argument expressions.

Examples:

```aloe
(Option None (type Int))
(Option Some (type Math) x)
(Result Error (type Int String) "failed")
(Point new (type Float) 0.0 1.0)
```

Omitting the header requests inference:

```aloe
(Option Some 10)
(Point new 0.0 1.0)
```

The first item remains the receiver, the second remains the literal selector,
and runtime arguments follow. The `type` list is static metadata inside the
send.

For a send to a family type object, explicit arguments correspond in order to
the family declaration parameters followed by any row-local factory type
parameters. For an instance send, family arguments are fixed by the receiver,
so the header supplies only row-local method parameters.

When present, the header supplies every applicable type parameter. There is no
partial `_` syntax. A program either provides the complete ordered list or omits
the header and uses inference.

The header works consistently for constructors, factories, and polymorphic
methods. Overload candidates whose generic arity does not match are
inapplicable.

A `(type ...)` form immediately after a selector is therefore reserved as
static send metadata and cannot simultaneously be a runtime first argument.

### Source type grammar

The existing nominal type grammar remains:

```aloe
Point
(Point Float)
(Option Int)
(Result Int String)
(Tree Math)
(List (Option Int))
```

A constructor name never appears as a type. Forms such as `Some Int` and
`(Option.Some Int)` are not types.

Constructor-set refinements remain internal checker knowledge. There is no
source annotation for a singleton or constructor set.

Expected types continue to come from method and function parameter annotations,
declared results, protocol positions, and enclosing expression constraints. The
explicit send type header handles context-free constructions such as `None`
without introducing a general cast or ascription expression.

### Additive extension syntax

`define-methods` remains the extension form used by MPL. It gains an optional
`factories` section while retaining the existing `methods` section:

```text
(define-methods FamilyName
  FactorySection?
  FamilyMethodSection?)
```

At least one section is present, in factories-then-methods order.

An existing-style family extension remains recognizable:

```aloe
(define-methods Sym
  (methods
    (+ (other Math) Math
      body)))
```

A type-object extension is:

```aloe
(define-methods Point
  (factories
    (diagonal (value T) (Point T)
      (self new value value))))
```

One form may add both sections.

The target family's generic parameters are in scope, as `T` is for the current
`define-methods List`.

Extensions may add factories, uniform whole-family methods, and compatible
overload rows. They may not add constructors, fields, local methods,
`per-constructor` body tables, conformance claims, or replacement rows.

An external family method requiring constructor knowledge uses an ordinary
exhaustive case expression on `self`.

### Protocol conformance syntax

The current positional protocol after a class name is replaced by an explicit
optional section that supports multiple protocols:

```aloe
(define-family Sym
  (conforms Math Show)
  (constructors
    (new
      (fields
        (name String))))
  (methods
    ...))
```

An absent `conforms` section means no protocols. An empty section is rejected
rather than retained as noise.

Conformance remains declaration-owned. There is no external
`define-conformance` form. Methods required by a declared conformance may still
be supplied by additive `define-methods` forms before whole-program conformance
validation.

### Reflection selector spellings

Decision 8's additional `Signature` selectors are:

```aloe
(signature role)
(signature type-params)
```

Their result types are:

```text
role        : Symbol
type-params : (List Symbol)
```

`role` returns an interned symbol whose name is one of:

```text
constructor
factory
family
local
operation
```

The existing reflection vocabulary remains:

```aloe
(signature selector)
(signature params)
(signature return)
(signature accepts? candidate-mirror)

(mirror messages)
(mirror signatures)
(mirror invoke signature argument ...)
(mirror subject)
(mirror raw)
```

There is no `mirror constructor`, `mirror payload`, `mirror type`, or general
dynamic cast syntax. The exhaustive case form is syntax and never appears in
reflected messages.

### Raw rendering syntax

The concise raw spelling is:

```text
#<Point 1 2>
#<Option.None>
#<Option.Some 1>
#<Tree.Branch #<Tree.Leaf 1> #<Tree.Leaf 2>>
```

A one-constructor family prints its family label and payloads, omitting the
redundant constructor label. A multi-constructor family prints
`Family.Constructor`. Payloads follow declaration order, and a zero-payload
constructor ends after its qualified label.

Names remain presentation labels. Raw output is not parseable source or a
serialization format. Normal display may use `show`; `:raw` and `(mirror raw)`
use this structural form.

When exact generic instantiation matters, type-aware diagnostics display it
separately with ordinary type grammar:

```text
value: #<Option.None>
type:  (Option Int)
```

This keeps ordinary values readable while allowing runtime type mismatches to
distinguish otherwise identical parameterless constructions.

### Complete `Result` example

```aloe
(define-family (Result T E)
  (constructors
    (Ok
      (fields
        (value T)))
    (Error
      (fields
        (error E))))
  (methods
    (successful? () Bool
      (per-constructor
        (Ok #t)
        (Error #f)))))
```

Construction:

```aloe
(Result Ok 10)
(Result Error (type Int String) "not found")
```

Elimination:

```aloe
;; result : (Result String String)
(result case
  (Ok (value)
    value)
  (Error failed (message)
    ("error: " append (failed error))))
```

### Complete recursive `Tree` example

```aloe
(define-family (Tree T)
  (constructors
    (Leaf
      (fields
        (value T)))
    (Branch
      (fields
        (left (Tree T))
        (right (Tree T)))))
  (methods
    (size () Int
      (per-constructor
        (Leaf 1)
        (Branch
          (((self left) size) + ((self right) size)))))))
```

External elimination:

```aloe
(tree case
  (Leaf (value)
    value)
  (Branch node (left right)
    ((left size) + (right size))))
```

### Source-language transition

The unified language removes `define-class` rather than retaining it as a
permanent alias.

A current class:

```aloe
(define-class (Point T)
  (fields
    (x T)
    (y T))
  (methods
    ...))
```

becomes:

```aloe
(define-family (Point T)
  (constructors
    (new
      (fields
        (x T)
        (y T))))
  (methods
    ...))
```

Existing construction remains `(Point new ...)` because `new` is now the
explicit sole constructor. Positional protocol syntax moves to `(conforms ...)`,
while existing `define-methods` extensions largely retain their shape.

Keeping both `define-class` and `define-family` in the normative language would
preserve two apparent ontologies after choosing one. A temporary migration tool
or implementation compatibility window can be considered in Decision 10, but
it is not part of the language semantics.

### Rejected syntax alternatives

The design rejects:

- separate `define-class` and `define-variant` forms, because they preserve the
  ontology split;
- constructor application such as `(Some value)`, because it violates
  receiver-first send semantics;
- globally bound constructor functions, because they introduce a second
  construction mechanism and name collisions;
- implicitly generated `new`, because it hides the one-constructor family's
  representation constructor;
- top-level `match value` syntax, because it loses the receiver-first shape;
- qualified case labels such as `Option.Some`, because the scrutinee already
  anchors the family;
- handlers or visitors as the primary eliminator, because they add ceremony and
  weaken missing-case diagnostics;
- a full nested-pattern grammar before applications require it;
- constructor-specific result annotations, because they imply GADT machinery;
- a permanent `define-class` compatibility alias, because it leaves two mental
  models in the language;
- a positional conformance list after the family header, because it becomes
  ambiguous as protocols multiply;
- a general cast or type-ascription form solely for parameterless constructors,
  because the send type header solves the local problem;
- a separate factory-extension construct, because a labeled section on
  `define-methods` is smaller;
- reflective instance constructor tags, because they contradict Decision 8.

### Syntax nucleus

```aloe
(define-family (Option T)
  (constructors
    (None
      (fields))
    (Some
      (fields
        (value T))))
  (methods
    (present? () Bool
      (per-constructor
        (None #f)
        (Some #t)))))

(define maybe
  (Option None (type Int)))

(maybe case
  (None () 0)
  (Some (value) value))
```

Definitions remain explicit s-expressions, construction remains a send,
selectors remain literal, type syntax remains in annotation positions, methods
remain receiver-owned, exhaustive elimination remains receiver-anchored, and
one or many constructors use one nominal declaration model.

## Cross-decision guardrails

The approved direction so far preserves these constraints:

- Sends remain receiver-first; list heads are receivers and second positions
  remain literal selectors except for an explicitly specified future case form.
- Functions still execute only through the `call` message.
- Families are nominal, constructor sets are closed, and protocols provide the
  explicitly open implementation axis.
- Constructor-set refinements are checker knowledge, not user-forgeable tags or
  new nominal types.
- Family and constructor names are presentation labels, not nominal identities.
- Ordinary family values are immutable structural data without observable
  allocation identity.
- Kernel structural equality remains separate from user-defined `=` messages.
- Protocol widening and constructor-refinement widening do not wrap, copy, or
  otherwise alter runtime values.
- Reflection exposes exact callable rows as opaque capabilities, not dynamic
  selector sends.
- A multi-constructor instance mirror exposes whole-family operations but no
  current constructor, payload, local rows, or refinement certificate.
- Constructor schema is observable through the family type object's constructor
  signatures rather than through an instance discriminator.
- `define-family` is the sole source form for user-defined nominal data;
  one-constructor products explicitly declare their constructor.
- Construction and factories remain sends to the family type object, with an
  optional static `(type ...)` header after the selector.
- `(receiver case ...)` is the sole exhaustive elimination form and the sole new
  expression form introduced by this design.
- Source annotations contain nominal family types but never constructor-set
  refinements or constructor types.
- Runtime closure representation remains unobservable.
- Built-ins need not be rewritten immediately to validate the user-facing
  semantic model.
- Source compatibility with the current prototype is not a design constraint.

## Questions reserved for the remaining decisions

Decision 10 must state the checker and evaluator consequences, compatibility
boundary, validation applications, and safe checkpoint sequence. It is the
earliest point at which an implementation plan should be proposed.
