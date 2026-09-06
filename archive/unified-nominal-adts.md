# Draft: unified nominal algebraic families

Status: **provisional and non-normative**

This working note records the design direction approved in conversation through
Decision 7. It is a working memory aid, not an amendment to `SPEC.md`, an
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

Still to decide:

8. Reflection
9. Concrete syntax
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

Tooling and later reflection should be able to distinguish a constructor row
from a factory row and report its parameters, result, and generic variables.
The precise reflective API remains Decision 8.

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

The spelling and complete grammar remain for Decision 9.

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

The exact punctuation belongs to Decision 9. For a one-constructor family, the
renderer may omit the redundant constructor label, preserving the familiar
product-like appearance. For a multi-constructor family, it must show the
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

The precise reflection surface remains for Decision 8. The exact printed
spelling remains for Decision 9.

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
- Reflection may observe the model but must not become an alternate,
  non-exhaustive discrimination mechanism.
- Runtime closure representation remains unobservable.
- Built-ins need not be rewritten immediately to validate the user-facing
  semantic model.
- Source compatibility with the current prototype is not a design constraint.

## Questions reserved for the remaining decisions

Decision 8 must settle which family, constructor, payload, generic, refinement,
and method facts are observable through reflection without undermining nominal
identity or exhaustive elimination.

Decision 9 must settle concrete declaration, constructor, case, and annotation
syntax only after the semantics are stable.

Decision 10 must state the checker and evaluator consequences, compatibility
boundary, validation applications, and safe checkpoint sequence. It is the
earliest point at which an implementation plan should be proposed.
