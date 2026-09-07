# Unified nominal algebraic families: specification candidate

> **HISTORICAL CANDIDATE — NON-NORMATIVE — PROMOTED IN THE 89I REVIEW CHANGE**
>
> [SPEC.md](../SPEC.md) now contains the complete normative target in the
> ratification change submitted for review. This file preserves the accepted
> pre-ratification design; it is not a second evolving specification. The
> [promotion map](#promotion-map) records every section's normative home.
> Runtime behavior remains complete through checkpoint 88.

The [89F audit](unified-nominal-adts-design-audit.md), including approved and
rechecked [U1](unified-nominal-adts-reflection-resolution-proposal.md), is complete.
The corrected [89G roadmap](unified-nominal-adts-implementation-roadmap.md) and
[89H handoff](unified-nominal-adts-implementation-handoff.md) are accepted with
no findings, as recorded by [89I](checkpoints/0089i-ratify-unified-family-design.md).
Acceptance of 89I completes checkpoint 89's design/documentation arc; 90A
requires its own checkpoint document and authorization.

Sections 1–22 below are preserved verbatim from revision
`616c0ceecd7d52d7f9c3e2c4df89e9037ed57aaa`, including examples and validation
catalogues. Their “candidate,” “later ratification,” and review-stage wording
is historical. Current language-law references belong to `SPEC.md`, and
[CHECKPOINTS.md](../CHECKPOINTS.md) governs the promoted implementation order.

## 1. Preserved expression model

The candidate preserves Aloe's existing atoms and lexical lookup. Integers,
floats, strings, and booleans evaluate to values of their primitive types. A
symbol in expression position is looked up in the lexical environment; an
unbound symbol is an error.

Every ordinary combination of at least two elements remains a receiver-first
send:

```text
(receiver-expr selector argument-expr ...)
```

The receiver expression is evaluated first. The selector is a literal source
symbol and is never evaluated. Argument expressions are evaluated from left to
right. Dispatch remains anchored on the receiver and the selected overload.
There is no Scheme-style application interpretation for a list.
The empty list and a one-element list remain invalid expressions because they
cannot supply both a receiver and a selector.

Function objects still run only through their `call` message:

```aloe
(f call x)
```

In particular, `(f x)` sends the literal selector `x` to `f`; it does not call
`f`. The candidate adds no constructor-call form, computed selector, implicit
application, or second send rule.

The existing `define`, `fn`, parallel `let`, `if`, `cond`, `load`, and `check`
forms retain their specified behavior. Runtime `let` remains exactly the
existing `fn`/`call` behavior:

```text
(let ((n e1) (bs e2)) body)
=> ((fn (n bs) body) call e1 e2)
```

The bindings are parallel. The right-hand side of one binding cannot see a
name introduced by another binding in the same `let`. `if` retains lazy branch
selection through zero-argument function objects, and `cond` retains its
required final `else`. `check` retains same-typed value comparison. `load`
retains the current shared-environment and relative-path behavior.
`define-protocol` retains its current role as the non-generic, nominal protocol
declaration; this candidate changes how a family declares conformance, not how
a protocol is introduced.

Numeric types remain distinct. There is no implicit `Int`/`Float`
conversion; `Int` to `Float` remains the ordinary message:

```aloe
(n float)
```

The candidate introduces only two expression-level syntactic distinctions:

- `(receiver case ...)` is exhaustive case syntax rather than an ordinary
  send; and
- a `(type Type ...)` list immediately after a send selector is static type
  metadata rather than a runtime argument.

Their full grammar appears below.

### Reserved-word scopes

The four new contextual markers have deliberately narrow scopes:

- `case` is reserved in the second position of a list. Every
  `(receiver case ...)` form is a case expression, never a send. Consequently
  no constructor, payload accessor, factory, local method, or whole-family
  method can use `case` as its selector.
- `else` is reserved only as the head of a `case` or `cond` clause. It cannot
  be a representation-constructor selector. Outside those clause-head
  positions it is not a new general expression marker.
- `per-constructor` is reserved only where the body of a whole-family method
  declaration selects its implementation mode. It is not a general
  expression or a case clause.
- In expressions, `type` is special only as the head of a list immediately
  following a send's selector. That complete list is static metadata and
  cannot simultaneously be the send's first runtime argument. `type` is not
  otherwise made a global special form or a globally reserved selector.

The existing method-declaration `(type U ...)` header remains a binder of
row-local variables, as specified in section 3. It is distinct from a send
header, which supplies types rather than declaring variables.

Section labels such as `conforms`, `constructors`, `fields`, `factories`, and
`methods` are special only in the declaration positions shown by their
grammars. They are not globally reserved selectors.

## 2. One nominal family ontology

One `define-family` declaration introduces all of the following as a single
nominal unit:

- one opaque family identity;
- one ordinary family type object, bound to the declared family name; and
- a finite, nonempty, declaration-ordered set of opaque representation
  constructors owned by that family.

A product with one constructor and a variant with several constructors are the
same kind of entity. There is no parallel class or variant ontology.

A family value records its family, its fully resolved invariant generic
arguments, its actual representation constructor, and that constructor's
ordered immutable payload. Family identity and constructor identity are
opaque. Source names are lookup, diagnostic, and presentation labels; spelling
does not constitute nominal identity.

Representation constructors are not source types, subtypes, global bindings,
or first-class function values. A constructor selector is meaningful only on
its owning family type object and as a literal label resolved within an
exhaustive case. Code that needs constructor-like behavior as a value wraps the
send explicitly. For example, under an expected `(-> Int (Option Int))`
function type, using section 16's `Option` declaration:

```aloe
(fn (value) (Option Some value))
```

The candidate distinguishes three declaration-owned callable surfaces:

- constructors and factories are messages of the family type object;
- whole-family methods are explicitly available on every instance of the
  family; and
- payload accessors and constructor-local methods are available only when the
  receiver is statically known to have their constructor.

Repeating the same local selector on several constructors does not infer or
create a whole-family message. Protocol conformance belongs to the whole
family, never to an individual constructor. A constructor-set refinement is
checker knowledge about an occurrence; it is neither source syntax nor a new
nominal identity.

## 3. Family declarations and callable surfaces

### Declaration grammar

`define-family` and `define-protocol` are top-level declaration forms, as
their current nominal and protocol counterparts are. Method, factory,
function, `let`, and case-clause bodies each contain one expression.
Capitalization of family names and constructor selectors is conventional,
not enforced.

The complete section order is fixed:

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
  (conforms ProtocolName ProtocolName ...)

ConstructorSection ::=
  (constructors Constructor Constructor ...)

Constructor ::=
  (ConstructorSelector
    FieldSection
    LocalMethodSection?)

FieldSection ::=
  (fields Field ...)

Field ::=
  (name Type)

FactorySection ::=
  (factories Method ...)

FamilyMethodSection ::=
  (methods FamilyMethod ...)

LocalMethodSection ::=
  (methods Method ...)
```

The parenthesized family header introduces its type variables. Type-variable
names within a header are unique. A `conforms` section, when present, names one
or more existing protocols. The `constructors` section is required and
contains one or more constructors. Every constructor has exactly one explicit
`fields` section; a nullary constructor writes `(fields)`. Optional empty
sections carry no information and are omitted by convention.

Factories and methods preserve the current typed method-row grammar. In the
following grammar, `ParameterRow+` means one or more `(name Type)` rows and
`TypeVariable+` means one or more fresh row-local type-variable names:

```text
Method ::=
    (Selector ParameterRow+ ReturnType body)
  | (Selector () ReturnType body)
  | (Selector (type TypeVariable+) ParameterRow+ ReturnType body)
  | (Selector (type TypeVariable+) () ReturnType body)

ParameterRow ::=
  (name Type)
```

The explicit `()` remains required for a zero-argument row. Row-local type
variables are unique, are scoped to that row, and are freshly instantiated at
each send. Protocol requirements retain the corresponding typed signature
shape without a body. Protocols themselves remain non-generic.

A `FamilyMethod` uses the same selector, optional row type header, parameter
rows, and declared result as `Method`, but its final position is one of two
body modes:

```text
FamilyBody ::=
    expression
  | (per-constructor ConstructorBody ConstructorBody ...)

ConstructorBody ::=
  (ConstructorSelector expression)
```

### Declaration invariants

A family declaration is accepted only when all of these invariants hold:

- it has a nonempty, finite constructor set;
- constructor selectors are unique, cannot be overloaded, and preserve their
  textual declaration order;
- a constructor selector is reserved throughout its family from factories,
  payload accessors, local methods, whole-family methods, and later additive
  extensions;
- payload names are unique within a constructor and generate zero-argument
  local accessors in declaration order;
- a payload accessor cannot collide with a local method in its constructor;
- whole-family selectors and all constructor-local selectors form disjoint
  partitions;
- a local selector may repeat in another constructor without becoming a
  whole-family selector;
- factories, local methods, and whole-family methods may overload a selector
  only when their method rows satisfy Aloe's ordinary exact-row uniqueness,
  ambiguity, and coherence rules; and
- every representation constructor is public. There is no visibility syntax.

These rules do not add precedence between local and whole-family lookup: the
partitions are disjoint instead.

### Constructors

A constructor declaration is a distinguished bodyless row on the family type
object. Its parameters are its ordered payload fields. Its result is its owning
family instantiated with the family parameters and singleton-refined to the
declared constructor. The family parameters are freshly instantiated at every
constructor send.

Constructors have no constructor-local type parameters, explicit result
annotations, existential fields, or GADT result equations. Constructor
selectors cannot be overloaded.

There is no generated `new`. A product declares its sole constructor
explicitly, conventionally with the selector `new` when that preserves the
familiar construction spelling:

```aloe
(Point new 1 2)
```

### Factories

Factories are ordinary, typed, possibly overloaded methods on the family type
object. A factory has a body and an explicit declared result. Within its body,
`self` is the family type object, so constructor and factory sends retain the
ordinary receiver-first shape. For example, in section 16's `Option.when`
factory, `value` has the bound family parameter type `T`:

```aloe
(self Some value)
```

A caller receives only the factory's declared, unrefined result type. The
constructor chosen by a factory body does not become call-site refinement or
construction provenance.

### Local and whole-family methods

Within a constructor-local method, `self` is singleton-refined to that
constructor. Its payload accessors and local method surface are therefore
available.

Every whole-family overload chooses exactly one implementation mode:

1. one uniform expression body; or
2. one complete `per-constructor` body table.

There is no default-plus-override mode. In a uniform body, `self` is unrefined,
except that the only possible constructor of a one-constructor family makes
such a receiver inherently singleton-refined. A uniform body that needs to
distinguish several constructors uses the ordinary exhaustive `case` form.

A `per-constructor` table contains every family constructor exactly once and
has no `else`. Its branch order has no semantic effect; declaration order is
the canonical written order. Each body has the method's ordinary parameters
in scope and receives `self` singleton-refined to the named constructor, so no
additional binders appear in the table.

Factories and constructor-local methods cannot use `per-constructor`.

## 4. Exhaustive receiver-anchored `case`

### Flat grammar

The candidate's only representation-elimination form is:

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

A case expression contains at least one explicit clause or a default clause.
An explicit clause may bind only the constructor's payload positions, or it
may first bind the whole value and then bind the payload positions. A nullary
constructor still writes the empty payload-binder list `()`. A default may
bind the whole residual-refined value, but it never has payload binders and is
always final.

For an unrefined `option` of type `(Option T)` and `fallback` of type `T`,
with `T` bound by the enclosing declaration:

```aloe
(option case
  (None () fallback)
  (Some some (value)
    (some value)))
```

The scrutinee is evaluated exactly once. Its opaque constructor identity
selects exactly one branch, and only that branch body is evaluated. Clause
labels are literal symbols resolved within the scrutinee family's constructor
namespace; they are not evaluated, global constructor names, or string tags.

Each explicit clause has exactly as many payload binders as its constructor
has fields. Those binders receive the substituted payload types in declaration
order. Its optional whole-value binder has the family type singleton-refined
to that constructor. A default whole-value binder has the family type refined
to the entire residual constructor set.

### Coverage and validity

Case requires a scrutinee with one concrete nominal family and a statically
known nonempty possible-constructor set `S`. A protocol value, unconstrained
type variable, family type object, `Mirror`, or other reflective description
cannot be case-analyzed directly.

Let `E` be the set of explicitly named constructors.

- Without `else`, `E` must equal `S` exactly.
- With `else`, the default covers exactly `S - E`, and that residual must be
  nonempty.

The checker rejects missing constructors, duplicate clauses, labels unknown to
the scrutinee family, constructors impossible under the current refinement,
incorrect clause or binder shapes, wrong payload-binder arity, a non-final
default, an empty-residual default, and incompatible branch results. Missing
constructors are reported in family declaration order.

A constructor named `Other` is an ordinary explicit constructor and has no
relationship to `else`. Choosing `else` explicitly opts that consumer out of
future missing-constructor diagnostics if the family declaration later grows.
There is no partial case analysis.

### Branch results

When the surrounding context supplies an expected result type, every reachable
explicit and default branch is checked against that type.

Without an expected result, the checker uses a symmetric,
branch-order-independent join:

- exact ordinary result types unify;
- results in the same nominal family unify their invariant generic arguments;
- only their outer constructor refinements are unioned; and
- results from unrelated families do not infer a shared protocol type merely
  because all those families conform to it.

If a protocol result is intended, its expected type must come from the
surrounding context. Branch visitation order cannot select or change the
inferred result.

Case patterns are deliberately flat. There are no nested patterns, guards,
alternatives, fallthrough, wildcard payload patterns, or non-exhaustive modes.
Nested decomposition uses another receiver-anchored case expression.

## 5. Types, generic inference, and constructor refinements

### Source types

The candidate generalizes the existing source type grammar without admitting
constructors or checker refinements as types:

```text
Type ::=
    PrimitiveType
  | (List Type)
  | (-> Type ... Type)
  | FamilyName
  | (FamilyName Type ...)
  | ProtocolName
  | BoundTypeVariable

PrimitiveType ::=
    Int | Float | Bool | String | Symbol | Mirror | Signature
```

Types occur only in annotation positions and in the new static send header.
A type-shaped list in ordinary expression position remains a receiver-first
send; this grammar creates no type application expression.

The bare nominal-family form is for a zero-parameter family. A generic family
application supplies its arguments at full declared arity. Arrow types contain
zero or more parameter types followed by one result type; `(-> U)` is a
zero-argument function type.

Constructor names and constructor sets are never source types. Host-interface
diagnostic names are also absent from source type grammar. Type names are
resolved to their nominal declarations rather than compared by spelling.

Family parameters are invariant. For example, `(Option Sym)` is not an
`(Option Math)` merely because `Sym` conforms to `Math`. An expected
`(Option Math)` may instead cause a new construction to choose `T = Math` from
the outset.

This design adds no generic-constraint syntax. Existing generic method
checking remains the starting point; family invariance does not introduce
conditional conformance or a new subtyping system.

### Explicit send type headers

Every ordinary send may have one optional static header immediately after its
selector:

```text
Send ::=
  (receiver selector TypeHeader? argument ...)

TypeHeader ::=
  (type Type ...)
```

Header types are checked as types and are not evaluated. On a send to a family
type object, the header supplies all family parameters first and then all
row-local factory parameters. Constructor rows have only the family
parameters. On an instance send, the receiver has already fixed the family
arguments, so the header supplies all row-local method parameters.

When present, the header is complete. There is no partial header, placeholder,
or `_` syntax. An overload candidate with a different applicable generic arity
does not match that header. Omitting the header requests inference.

Examples include:

```aloe
(Option None (type Int))
(Option Some (type Math) x)
(Result Error (type Int String) "failed")
(option map (type String) formatter)
```

These examples use section 16's families. For the `Some` send, assume `x`
has a nominal type explicitly conforming to `Math`. For `map`, assume
`option : (Option Int)` and `formatter : (-> Int String)`; its explicit
header supplies row-local `U`, yielding `(Option String)`.

### Construction inference

A constructor send may receive constraints from all of these sources:

- a complete explicit send type header;
- an expected exact family instantiation;
- its payload argument types; and
- its enclosing expression, including sibling branches whose results must
  agree.

Constraints are gathered across the enclosing expression rather than committed
greedily by the first constructor or first branch visited. An expected protocol
alone does not identify an exact family instantiation and therefore cannot, by
itself, determine that family's generic arguments.

Inference variables may remain temporarily while the enclosing unit is
checked, but no unresolved variable may escape its checking-unit boundary.
Consequently, a context-free generic nullary construction such as
`(Option None)` is rejected. It needs an explicit header or an exact expected
family type. A partially determined multi-parameter construction is rejected
under the same rule.

### Shallow constructor refinements

For a base family type `F A ...`, the checker may internally track the subset
of `F`'s constructors still possible for one expression occurrence. This set is
not written in Aloe and is not part of nominal type equality.

The checker applies these operations:

- direct construction introduces the selected singleton set;
- an explicit case branch intersects existing knowledge with its constructor;
- a default branch subtracts the explicitly handled constructors;
- control-flow joins union possible outer constructors;
- ordinary widening replaces a subset with the family's complete constructor
  set; and
- protocol conversion forgets constructor knowledge.

Refinement is shallow. Generic storage and payload declarations never encode
nested facts such as “a list of only `Some` values.” Family-typed payloads
carry the declared base family type.

The authoritative sources of outer refinement are direct construction,
explicit case branches, `per-constructor` bodies, and immutable direct aliases
of an already-refined occurrence. A direct `define` or source `let` alias may
therefore preserve that outer fact for checking. This does not change runtime
`let`: evaluation retains its established `fn`/`call` definition and does not
create general function-argument refinement.

Refinement is forgotten at protocol conversion, declared method and factory
results, general function boundaries, generic storage, family-typed payloads,
source type annotations, and reflective unwrapping. A factory call therefore
has its declared family result even when its body always happens to choose one
constructor.

## 6. Direct regular recursion

A family declaration registers the current family identity and all its ordered
constructor identities before resolving constructor payload types. This makes
direct self-reference available while the payload declarations are checked.
Previously declared families remain available normally.

In payload types, every recursive occurrence of the current generic family
must use that family's parameters at full arity, in the same order:

```aloe
(Tree T)
```

The occurrence may appear beneath an ordinary container or function type, for
example `(List (Tree T))` or `(-> (Tree T) (Tree T))`. A non-generic family
refers to itself by its bare family type name.

This restriction on recursive payloads does not prohibit ordinary generic
method results such as the `(Option U)` result of `Option.map` in section 16.

The checker rejects nonregular or polymorphic recursion such as
`(Tree (List T))`, reordered parameters, missing or additional parameters,
mutual recursion, and references to unresolved forward families.

This rule does not add positivity checking, termination checking, GADTs,
existentials, mutual declaration groups, or a claim that Aloe supplies a full
inductive type theory. It specifies only direct regular recursion for nominal
algebraic families.

## 7. Protocols and additive extensions

### Ordinary overload selection

An ordinary send considers rows on its receiver's available surface with the
literal selector, matching argument arity, and compatible parameter types.
Section 5's complete type header also filters applicable generic arity.
Among applicable rows, Aloe retains its existing specificity rule: exact
nominal matches beat matches through a declared protocol. A unique most
specific row is selected. A send with no applicable row or an unresolved tie
is rejected. Compatibility requires exact types or the declared nominal
protocol relation; there is no implicit numeric conversion. This is
receiver-anchored overloading, not an additional send rule. The
result-coherence obligations below also constrain rows that concrete runtime
dispatch may select.

### Family-wide protocol conformance

A family may declare zero or more conformances in its optional
`(conforms P ...)` section. Each conformance is nominal and belongs uniformly
to the entire family across all of its generic instantiations. Constructors do
not conform independently.

Only whole-family rows can satisfy protocol requirements. Constructor rows,
factories, payload accessors, constructor-local methods, and reflection rows
cannot do so.

For a whole-family row to satisfy a protocol requirement:

- its parameter types must cover every argument in the protocol row's domain;
  and
- its result may be more specific only when that result remains usable as the
  protocol row's declared result.

This is contravariant parameter compatibility and covariant result
compatibility within Aloe's nominal family-to-protocol relation. A family may
also have narrower overloads, but every narrower row that dynamic dispatch may
choose in place of a broader row must return a value usable as the broader
row's declared result.

One whole-family row may satisfy identically shaped requirements from several
declared protocols. Differently shaped requirements may be met by coherent
overloads. Requirements with the same parameter shape and incompatible result
obligations are rejected.

Rows supplied by allowed additive extensions in the same complete source unit
may satisfy declaration-owned conformance claims before that unit is
finalized. This does not permit an extension to make a retroactive conformance
claim.

Using a family value where one of its declared protocols is expected exposes
only the protocol rows and forgets constructor refinement. The conversion does
not allocate a wrapper. A protocol-typed value cannot use local methods or be
case-analyzed without first obtaining a separately justified concrete-family
view.

Protocols remain non-generic and have no inheritance, intersection types,
default implementations, conditional or structural conformance,
per-constructor conformance, or retroactive orphan claims.

A family declaration fixes its closed representation. Adding a constructor
means editing that declaration and rechecking exhaustive consumers,
per-constructor bodies, and conformance; it is not an additive extension.
Downstream code may declare a new family conforming to an existing protocol
without changing that protocol. A protocol's required operation set is closed
for that version: adding a requirement rechecks its conformers. The family
declaration owns its conformance claims; no mechanism opens both axes at once.

### Additive `define-methods`

The extension form becomes:

```text
FamilyExtension ::=
  (define-methods FamilyName
    FactorySection?
    ExtensionMethodSection?)

ExtensionMethodSection ::=
  (methods Method ...)
```

At least one section is present, and `factories` precedes `methods` when both
appear. The target family's parameters are in scope. An extension may add:

- ordinary factories;
- uniform whole-family methods; and
- new compatible overload rows on either permitted surface.

An extension cannot add constructors, payload fields or accessors,
constructor-local methods, `per-constructor` tables, conformances, or a
replacement for an existing exact row. It also cannot use a selector reserved
by the family's constructors or local/whole-family partition.

All rows proposed by one extension are staged together. Their signatures and
bodies are checked in a combined staging view, including calls among the new
rows. Exact-row uniqueness, overload ambiguity, return coherence, selector
classification, and combined row coherence are validated before any of the
rows commit. Declaration-owned protocol obligations are finalized over the
complete source unit as specified in section 9. A failed extension commits
none of its rows.

An external whole-family method that needs constructor knowledge uses the
ordinary exhaustive case expression on `self`; extensions cannot add
constructor-indexed body tables.

This family extension grammar does not remove the established
`(define-methods List (methods ...))` route. Section 15 specifies its preserved
element-parameter scope and built-in boundary. The family grammar's extension
rights do not automatically extend to specialized receivers.

## 8. Checked programs and elaboration

### Required pipeline

The candidate requires checking to resolve every static decision needed by
evaluation. The program pipeline is:

```text
source
  -> parsed source AST
  -> linked nominal declarations and opaque identities
  -> type checking and elaboration
  -> globally validated checked program
  -> evaluation
```

The parsed source AST retains source constructs that affect checking,
including family declarations, explicit send type headers, case clauses, and
direct-alias provenance. Linking resolves names to one program image's opaque
nominal identities. Type checking elaborates the linked source into a checked
program, and global validation establishes whole-unit obligations before
evaluation begins.

The checked program carries every runtime-relevant static decision, including:

- resolved family, constructor, protocol, and dispatch-row identities;
- resolved type arguments for sends whose runtime behavior depends on them;
- resolved constructor identities for explicit case clauses; and
- checked row and result obligations required at dynamic boundaries.

Constructor-set refinements that serve only static lookup, coverage, and flow
checking need not become fields of runtime values or annotations retained for
evaluation. Ordinary type presentation exposes the base family type, not its
internal possible-constructor set.

Only a successfully checked and globally finalized unit is evaluated.
Production evaluation does not accept unresolved construction semantics,
re-run nominal name resolution, or infer generic arguments from runtime
payloads. Ordinary constructor sends carry the type arguments resolved during
checking, including parameterless constructions resolved by context or an
explicit header. Section 14's `invoke-mirrored` is an explicit guarded
reflection operation: it may instantiate its opaque selected row from fixed
owner arguments and sealed, closed input type evidence before running that
row. This does not allow ordinary construction to defer its static decisions
or permit inference from payload contents or executed results.

Public source-checking and source-evaluation helpers may retain their broad
roles. A type-only caller may discard the elaborated program after successful
checking. Evaluation helpers and drivers evaluate the checked result rather
than an arbitrary unresolved parsed program.

### Inference closure and source aliases

Temporary inference variables may participate while an enclosing expression
is checked, as described in section 5, but no unresolved inference variable
survives any of these boundaries:

- a top-level expression or definition;
- a method or factory body;
- an explicitly typed function body; or
- a complete program transaction.

Declared family parameters and row-local parameters are bound variables, not
unresolved inference variables.

`invoke-mirrored` has a closed source signature over `Mirror`, `Signature`,
and `(List Mirror)`, returning `Mirror`. Its selected row's bound schema
parameters are instantiated inside the guarded boundary under section 14;
they are not unknown intermediate source types escaping this closure rule.
Checked execution must make the sealed type evidence for its mirrored inputs
available without executing user behavior. Ordinary-result `invoke` and
contextual `subject` still require their source result types to close, even
when an enclosing operation would immediately mirror the result.

Source `let`, or equivalent source provenance, remains visible through
checking so an immutable direct alias can preserve an outer constructor
refinement. This checker requirement does not create a new runtime form.
Runtime `let` retains the existing parallel `fn`/`call` definition from
section 1.

## 9. Shared descriptors, linking, and transactions

### One linked descriptor graph

Checking, evaluation, conformance validation, dynamic type validation, kernel
equality, structural printing, and family-aware reflection share one
linked program-image graph of nominal descriptors. Its significant opaque
identities are:

- protocol identity;
- family identity;
- constructor identity; and
- dispatch-row identity.

These descriptors are implementation metadata. They are not Aloe-visible
objects, source types, identity tokens, or an additional reflection surface.

A family descriptor owns its presentation name, ordered type parameters,
declared protocol conformances, ordered constructor descriptors, factory rows,
and whole-family rows. Its one family type object refers to that declaration,
not to a particular generic instantiation.

A constructor descriptor owns its exact family, selector label, ordered
payload declarations, constructor-local rows, and declaration position. A
constructor identity therefore determines exactly one owning family.

A dispatch-row descriptor owns its selector, row-local generic parameters,
parameter and result types, semantic role, body mode, and exact row identity.
Constructor, factory, whole-family, and local rows use this shared identity
model without becoming the same callable surface.

This candidate specifies the descriptors' semantic contents and shared opaque
identity, not public Racket structure names or physical memory layout. An
implementation may combine, split, index, cache, or otherwise optimize these
representations when no Aloe observation changes.

### Three family-linking phases

A family declaration is linked in three ordered phases.

1. **Header and identities.** Bind the family name, mint its opaque family
   identity and its family type object, bind its type parameters, and register
   every constructor label and opaque constructor identity. This phase makes
   the current family available for the direct regular self-reference allowed
   by section 6.
2. **Representation and signatures.** Resolve constructor payload types,
   generated accessor rows, constructor-local signatures, factory signatures,
   whole-family signatures, and conformance names. Enforce the declaration,
   selector, and exact-row invariants from section 3 in this linked view.
3. **Bodies.** Install all declaration signatures before checking any body, so
   rows in one declaration may call one another. Then check local bodies with
   singleton-refined `self`, uniform whole-family bodies with their specified
   family view, each `per-constructor` body with its corresponding singleton
   view, and factory bodies with the family type object as `self`.

Previously declared families remain available in every phase. The first phase
does not create forward declarations for unrelated later families or mutual
recursion groups.

### Whole-unit finalization

After a complete source unit and its transitive loads have been linked and
checked, finalization validates the combined program image. It verifies:

- every declared protocol conformance;
- every complete `per-constructor` table;
- every overload set and ambiguity condition;
- every dynamic-overload return-coherence obligation;
- every constructor, local, and whole-family selector partition;
- every additive extension owner and exact-row nonreplacement rule; and
- the absence of escaped inference variables.

Rows supplied by later allowed `define-methods` forms in the same complete
source unit participate in this validation and may satisfy a declaration-owned
conformance. The atomic per-extension staging rule in section 7 remains
unchanged: this whole-unit phase neither duplicates nor weakens it.

### Transactional checking and evaluation

A loaded source unit and all of its transitive loads form one staging
transaction:

1. link declarations and extensions;
2. check expressions and bodies and produce the elaborated program;
3. run whole-unit finalization;
4. commit the static descriptor graph; and
5. evaluate the checked program into the corresponding runtime environment.

A REPL datum is its own smaller transaction and must be coherent when that
transaction commits. A static failure commits no partial declaration,
extension row, conformance, or checker binding to the live environment, and it
does not begin evaluation. Runtime effects that occur after successful
checking and commit retain Aloe's ordinary behavior and are not rolled back.

## 10. Runtime family values and dispatch

### Semantic family value

The semantic content of a family instance is:

```text
<family identity, resolved type arguments, constructor identity, payloads>
```

The payloads are immutable values in constructor declaration order. The
constructor belongs to the recorded family, and the resolved type arguments
identify the exact invariant family instantiation.

There is one family type object per declaration, not one type object for every
generic instantiation. Generic arguments are resolved before construction and
stored in the constructed value: ordinary sends carry checked arguments;
`invoke-mirrored` may resolve its selected row under section 14's sealed input
evidence rule. A `None` at `(Option Int)` and a `None` at
`(Option String)` therefore share a family and constructor declaration but
have different runtime family types.

The semantic tuple is not a required physical representation. Its components
may be represented indirectly through the shared descriptors as long as all
specified observations remain the same.

### Data rather than behavior

A family value contains its family data, not per-instance method tables,
method closures, a protocol wrapper, or factory provenance. Callable behavior
and explicit conformances belong to the declaration-level descriptor graph.

Consequently:

- protocol conversion and constructor-refinement widening do not wrap, copy,
  or otherwise alter the value;
- a factory leaves no construction-history marker beyond the family,
  constructor, resolved arguments, and payload that it returned;
- adding an allowed method row does not alter the stored representation of
  existing values; and
- one-constructor products and multi-constructor variants use the same value
  model.

Family identity, resolved type arguments, constructor identity, and each
payload position are fixed at creation. There are no setters, constructor
changes, or payload replacements.

This immutability is shallow. A payload may contain a function or an
identity-bearing host capability whose opaque external state changes. The
family value cannot replace that leaf and does not claim to deep-freeze it.

Ordinary family values expose no allocation identity. A runtime may share,
copy, intern, or separately allocate equivalent family data. Constructor
refinement is therefore stable for the lifetime of a value: a `Some` value
cannot later become `None`.

Ordinary immutable construction produces finite, acyclic family data because
all payload values must already exist when a value is constructed. Opaque
functions and capabilities are leaves for this structural purpose.

### Scope of opaque identity

Opaque nominal identity is guaranteed within one linked Aloe program image.
The candidate promises no stable family, constructor, protocol, or row
identity across separate executions, recompilation, serialization, or a future
module-reloading system.

Names remain source and presentation labels. Same-spelled families introduced
by distinct declarations have distinct identities, and same-spelled
constructors in different families are unrelated. No `Symbol`, `String`, raw
text, or reified type spelling can forge or stand in for an opaque identity.

### Dispatch surfaces

After overload selection, evaluation follows the disjoint callable surfaces
specified in sections 2 and 3:

- a send to a family type object consults that family's constructor and
  factory rows;
- a whole-family send invokes the selected family row, then uses its one
  uniform body or the body indexed by the receiver's actual constructor; and
- a statically authorized local send consults the table belonging to the
  receiver's actual constructor.

The value itself supplies family and constructor identities for dispatch; it
does not carry method closures. Because local and whole-family selector
partitions are disjoint, evaluation needs no precedence rule between them.

A send checked against a broader protocol signature may retain Aloe's existing
concrete runtime overload selection on the actual family. Every narrower row
that might be selected remains subject to the return-coherence rule in section
7, so dynamic selection cannot invalidate the statically promised result.

## 11. Central runtime type relation and constructor integrity

### One dynamic relation

Every dynamic boundary uses one consistent nominal runtime type relation.

For an expected concrete family type `F A ...`, a value passes exactly when
its family identity is `F` and its resolved generic arguments exactly match
`A ...` invariantly. If the expected view also carries an internal
constructor-set refinement, the actual constructor must belong to that set.

For an expected protocol `P`, a family value passes exactly when its family
descriptor explicitly conforms to the opaque identity of `P`. Its constructor
is irrelevant because conformance belongs to the whole family.

No runtime type check succeeds merely because family or constructor names,
reified type data, printed output, payload layouts, or similarly named message
surfaces match. Compatibility follows opaque nominal identity and the
specified family-to-protocol relation, never presentation data or structural
coincidence.

The same relation governs constructor payloads, factory results, dynamically
selected overload arguments and results, the reflective boundaries in section
14, and the specialized-value and typed host integration in section 15. It
covers primitives, functions, lists, exact family instantiations, protocols,
and host-interface identities. Specialized cases within this one relation do
not create parallel compatibility rules or enlarge the admitted host crossing
vocabulary.

Trusted checked code may omit a redundant dynamic check only when its behavior
is equivalent to applying this relation.

### Defensive constructor integrity

Ordinary Aloe source cannot forge an opaque constructor identity. Every
boundary that constructs or injects a family value nevertheless rejects:

- a constructor that is not owned by the recorded family;
- a payload count different from the constructor declaration;
- a payload that fails its substituted declared type; or
- an unresolved generic argument.

The failure occurs at the boundary that attempted to introduce the malformed
value. Such a value does not survive until a later send or case expression.
Exhaustive case evaluation may therefore rely on the family's closed
constructor set. If malformed foreign data somehow reaches that boundary, it
is rejected rather than routed through an `else` clause.

## 12. Kernel equality

`check` and other trusted runtime machinery use a total, non-overridable kernel
equality. Two family values are kernel-equal exactly when all of the following
hold:

1. their opaque family identities are the same;
2. their resolved generic arguments are the same;
3. their opaque constructor identities are the same; and
4. their corresponding payload values are recursively kernel-equal.

Thus separately allocated `Point` values with equal coordinates compare equal,
as do separately allocated `Some` values with equal payloads. `Some` and
`None` do not compare equal. Same-shaped values from distinct nominal family
declarations do not compare equal. A `None` at `(Option Int)` and a `None` at
`(Option String)` do not compare equal even though neither has a payload.

At leaves, scalar and algebraic values retain their established value
equality. Functions, type objects, host capabilities, and other explicitly
identity-bearing opaque values use their established opaque identity unless
that built-in kind already defines value semantics.

Kernel equality does not invoke Aloe methods and does not inject a universal
user-visible `=` message. A family or protocol row named `=` is an ordinary
domain operation. It may define a different notion of equality, but it cannot
replace the comparison used by `check` or other trusted runtime operations.

## 13. Raw and user-facing display

### Structural raw form

The concise raw forms are exactly:

```text
#<Point 1 2>
#<Option.None>
#<Option.Some 1>
#<Tree.Branch #<Tree.Leaf 1> #<Tree.Leaf 2>>
```

A one-constructor family prints its family label followed by its payloads and
omits the redundant constructor label. A multi-constructor family prints
`Family.Constructor` followed by payloads in declaration order. A nullary
constructor ends after its label. Nested values use the same structural rule.

Family and constructor names in this output are presentation labels only. Raw
text grants no opaque identity, proves no type compatibility, and creates no
constructor refinement.

Raw rendering never invokes Aloe methods. It is diagnostic text, not parseable
source, an equality definition, or a serialization format. Clearly marked
depth or collection limits may elide interactive presentation only; they do
not change equality or any program behavior.

When the exact generic instantiation matters, especially for a parameterless
constructor, a type-aware diagnostic presents it separately with ordinary
source type grammar:

```text
value: #<Option.None>
type:  (Option Int)
```

This additional diagnostic context does not alter the concise value form.

### Normal display

Normal interactive display may use an applicable whole-family,
zero-argument `show` row returning `String`. If no such row is available, it
falls back to structural display. The raw path remains independently available
and never invokes `show`, including when user display code fails, recurses, or
deliberately hides structure.

## 14. Family-aware reflection

### Mirror boundary and receiver view

`Mirror` is the explicit, sealed boundary for describing a value's public
callable surface. Reflection operations belong to `Mirror` and `Signature`,
not to every ordinary value. The vocabulary preserves existing operations and
adds the fixed `invoke-mirrored` row:

| Operation | Result and role |
| --- | --- |
| `(Mirror of value)` | A `Mirror` of any Aloe value. |
| `(mirror messages)` | The unique callable selectors as a `(List Symbol)`. |
| `(mirror signatures)` | One opaque `Signature` per public overload row, as a `(List Signature)`. |
| `(mirror invoke signature argument ...)` | The ordinary result of invoking that exact owned row, with the checks below. |
| `(mirror subject)` | The original ordinary value, under contextual typing and runtime validation. |
| `(mirror raw)` | A `String` from the structural renderer in section 13. |
| `(mirror invoke-mirrored signature arguments)` | Invoke the exact owned row with a `(List Mirror)` of arguments and return a `Mirror`, under the guarded contract below. |
| `(signature selector)` | The row's literal selector description as a `Symbol`. |
| `(signature params)` | A `List` of ordered parameter-type descriptions. |
| `(signature return)` | The result-type description. |
| `(signature accepts? candidate-mirror)` | A `Bool` answering the one-parameter compatibility question below. |

A mirror describes the actual runtime nominal receiver. It does not retain
the expression's original static view: a value seen through a protocol still
reflects its concrete family's public surface. Protocol widening creates no
wrapper for reflection to reveal. Nor does the mirror retain or manufacture a
constructor-set refinement, including when it is made from direct
construction or inside a singleton-refined branch.

Asking an existing mirror for signatures describes its stored subject.
`(Mirror of mirror)` explicitly reflects the `Mirror` value itself instead.
Selector symbols and reified type descriptions describe operations; only the
opaque signature grants authority to invoke its exact row.

`subject` returns the value originally passed to `Mirror of`, not another
mirror. Its checker result is the expected type when available and otherwise
a fresh inference variable. Section 8's inference closure still applies: that
variable must be resolved within the enclosing checking unit. The checked
contextual obligation is enforced at the runtime boundary with section 11's
relation, so an incompatible subject is rejected rather than treated as a
successful cast.

Unwrapping forgets earlier constructor refinement under section 5. An expected
concrete family permits subsequent ordinary exhaustive case analysis; it does
not recover a prior branch's singleton fact. Source annotations still cannot
request a constructor refinement. A one-constructor family retains local
access because its ordinary family type already has only one possible
constructor.

### Callable surfaces and closed instance representation

The subject determines the entire public reflected surface:

| Mirrored subject | Callable rows |
| --- | --- |
| Multi-constructor family instance | Whole-family rows only. |
| One-constructor family instance | Whole-family rows, sole-constructor local rows, and payload accessors. |
| Family type object | Representation constructors and factories. |
| Primitive value or type object | Its existing public primitive rows. |
| Host capability | Rows declared by its exact host interface. |
| A `Mirror` value | The reflection API of `Mirror`. |

For a multi-constructor instance, both `messages` and `signatures` exclude
constructor-local rows and payload accessors when forming their results.
They are not exposed and merely rejected at invocation time. Repeated local
selectors on several constructors do not become reflective family rows.
Creating the mirror inside a refined branch changes neither list and grants
no escaping refinement certificate.

A multi-constructor instance mirror supplies no reflective query for its
current constructor identity or authoritative tag, constructor predicates,
payload values or indexed payload access, constructor refinements, opaque
nominal identity tokens, conformance lists, method bodies, dispatch tables,
source locations, or closure representation. In particular, there is no
`mirror constructor`, `mirror payload`, or `mirror is-constructor?`
operation. A multi-constructor family's representation is consumed through
ordinary exhaustive `case` or through explicitly declared whole-family
operations and protocols. A whole-family operation may itself use exhaustive
knowledge; its ordinary result is not reflective refinement authority.

The family type object exposes the complete public construction schema. Each
constructor row describes its selector, ordered payload types, family result,
generics, and constructor role; each factory overload has its own row and
factory role. Payload position names do not become separate reflective data.
There is no first-class `Constructor` token: a constructor signature is an
exact-row capability with descriptive metadata, not a new constructor value
or source type.

A whole-family overload with `per-constructor` bodies contributes one
signature, irrespective of the number of implementation bodies. The `case`
form is syntax and never appears in `messages` or `signatures`.

### Signature metadata and descriptive types

The candidate adds exactly these metadata queries:

```text
(signature role)        : Symbol
(signature type-params) : (List Symbol)
```

`role` returns an interned symbol with one of these names:

| Role | Meaning |
| --- | --- |
| `constructor` | A bodyless representation-constructor row on its family type object. |
| `factory` | An ordinary factory row on its family type object, including an allowed extension. |
| `family` | A whole-family overload, whether uniform or implemented with `per-constructor` bodies. |
| `local` | A reflectable sole-constructor local method or payload accessor. |
| `operation` | A primitive, reflection, or host row outside the algebraic family and type-object surfaces. |

`type-params` describes the row's applicable generic parameters as ordered
presentation symbols. A constructor has the family declaration's parameters
and no additional constructor-local parameters. A type-object factory has
family parameters followed by its fresh row-local parameters. This is the
same family-then-row order used for instantiation in section 5, not a second
type-argument syntax. A non-generic row returns an empty list.

For an instance row, the receiver's fixed family arguments are substituted
into its parameter and result descriptions. They are not fresh parameters of
that row. Only fresh row-local method parameters remain in `type-params` and
appear as variables in the descriptions. For example, the `map` row of an
`(Option Int)` instance has parameter description `(-> Int U)`, result
description `(Option U)`, and the one type-parameter symbol `U`.

`selector`, `params`, and `return` retain their existing meanings. A simple
type description is a `Symbol`; compound type grammar is nested `List` and
`Symbol` data. Thus the description `(Option Int)` is a list containing the
symbols named `Option` and `Int`, not an evaluated send. The outer list from
`params` records parameter order and may contain both simple and compound
descriptions. Constructor results describe the base family type without their
internal singleton set; constructor-set refinements never appear in ordinary
reflected type data.

These descriptions are presentation data, not first-class types, cast tokens,
source annotations, runtime type tokens, or proof of nominal identity.
Unrelated same-spelled declarations may have identical descriptions. Matching
those descriptions cannot establish ownership or compatibility. There is no
general `mirror type` query, first-class type universe, or operation for
comparing arbitrary runtime types.

All metadata and hidden authority derive from the shared descriptors in
section 9. This specifies their semantic contents, not public Racket
structures, copied method tables, or a physical storage layout.

### Exact ownership and row authority

A signature is an unforgeable capability for one exact dispatch row. Its
hidden ownership records the row identity together with the relevant owner:

- the exact family instantiation for an instance row;
- the exact family type object for a constructor or factory row;
- the appropriate constructor identity as well for a reflectable local row;
  or
- the exact primitive or host-interface identity for those receiver kinds.

A whole-family signature is usable on every constructor of its owning family
at the same generic instantiation. It cannot transfer from `(Option Int)` to
`(Option String)` or to an unrelated declaration also named `Option`. A
constructor signature belongs to the owning family type object's mirror, not
to a mirror of one of its instances. Fresh generic construction does not mint
a new family type object or transfer the row to another owner.

Host ownership follows the exact interface, not its diagnostic name or one
receiver's allocation identity. A row may be used on another receiver of that
same interface, with the target receiver supplying its state. A same-named but
distinct interface is rejected.

Signatures retain opaque row descriptors; a flattened menu index is not
authority. Source code cannot construct a signature from a selector, role, or
type description. Signatures may be stored and copied, but the candidate
promises no user-visible signature equality, ordering, hashing, allocation
identity, or stable serialization. Repeated reflection need not reveal
whether equivalent capabilities share an allocation. This does not alter
section 12's total internal kernel equality or add a signature comparison
message.

### Checked exact-row invocation and generics

`Mirror.invoke` invokes the selected descriptor directly. It neither converts
the selector description into `perform` nor repeats overload resolution. For
a whole-family row with `per-constructor` bodies, choosing the body for the
actual constructor is execution of that one row, not selection of another
overload.

The checker requires the first runtime argument to be `Signature` and checks
the remaining argument expressions normally. Invocation must validate:

1. the signature's exact owner and row authority against the target subject;
2. the argument count against that row;
3. each argument against the instantiated parameter type;
4. complete resolution of applicable generic parameters before running the
   row or constructing a value; and
5. the ordinary result against the instantiated return type and any checked
   contextual result obligation before returning it to Aloe.

All compatibility checks use section 11's central relation. A wrong owner,
wrong arity, incompatible argument, conflicting or insufficient generic
information, or incompatible result is rejected. Rejection does not fall back
to a similarly named row or a more convenient overload. Constructor integrity
is enforced at the construction boundary under section 11. Static failures
prevent evaluation under section 9; obligations that depend on an opaque
signature are enforced by the guarded runtime invocation.

An instance's family arguments are already fixed by its exact owner. Its
row-local generic parameters are fresh for every invocation. A constructor
or factory on a family type object is freshly instantiated on each invocation
using the same constraints as a direct send: explicit static information,
the expected result, argument types, and the enclosing expression. Applicable
parameters follow the family-then-row order above. Reflection adds neither
partial instantiation nor a second send form or signature-specialization API.

When a signature variable hides the selected row from the checker, the
invocation's result type remains its expected type, or a fresh inference
variable when there is no expectation. The latter must be resolved under
section 8's closure rule. The checked invocation carries its resolved static
information and contextual result obligation; runtime validation checks them
against the opaque selected descriptor. Bound generic variables in a stored
row schema are not escaped source inference variables.

Hiding the row does not permit unresolved construction semantics. The checked
information must suffice, when validated against the selected descriptor, to
determine all required instantiations before that row executes. If it does
not, invocation is rejected. In particular, a contextual exact family may
supply a generic constructor's result arguments; an expected protocol alone
cannot determine them. The evaluator does not recover a constructed family's
arguments from runtime payloads or infer them from the returned value. Result
validation checks an already instantiated obligation; it cannot finish
construction inference after the fact.

Consequently, reflecting `Option` does not make a context-free nullary `None`
constructible. Nor can a successful result check recover singleton refinement
for the caller: the ordinary contextual result route observes section 5's
refinement-erasure rules. No reflected spelling can replace the checked
nominal information required by this boundary.

### Invocation with mirrored arguments and result

`invoke-mirrored` is an ordinary operation on `Mirror`:

```aloe
(receiver invoke-mirrored signature arguments)
```

The receiver has type `Mirror`. The operation has exactly two arguments,
`Signature` and `(List Mirror)`, and result type `Mirror`. It has no
operation-local type parameters. Its exact reflected metadata is:

```text
selector:    invoke-mirrored
params:      (Signature (List Mirror))
return:      Mirror
type-params: ()
role:        operation
```

The type spellings above describe the same `Symbol`/`List` data as other
signature metadata. This fixed row needs no variadic description convention.
The list length is the selected target row's arity, not the arity of
`invoke-mirrored` itself. The operation has no special forwarding of a send
type header to the selected row: its own generic arity is zero. An outer
expected result of `Mirror` supplies no type argument or ordinary result
expectation for that selected row.

The receiver, signature argument, and argument-list expression are evaluated
in ordinary receiver-first, left-to-right send order. Within the sealed
boundary, each argument mirror is unwrapped exactly once. The signature
retains exactly the owner and row authority specified above. Before the
selected row runs, the boundary validates ownership, the number of argument
mirrors, complete consistent instantiation, and each ordinary argument
against the instantiated parameter type using section 11's relation. It
invokes that exact row on the receiver mirror's subject without a selector
search or another overload selection.

The selected row may be instantiated from exactly these sources:

- the receiver instantiation already fixed by its exact owner; and
- sealed, closed type evidence associated with each mirrored input subject.

Each invocation uses fresh bindings for any remaining row parameters and
retains invariance and nominal compatibility. All required parameters must
resolve before execution, including parameters used only in the row's
result. Insufficient or conflicting evidence is a guarded failure; the row
does not run. A successful one-argument `accepts?` query does not fill a
result-only parameter or specialize the stored signature.

Input evidence is trusted internal metadata about an already checked value,
not the symbols returned by `params`, `return`, or `type-params`. A family
subject already has its exact nominal instantiation. An empty list needs its
already resolved invariant element type; a function needs its checked arrow
type with bound arguments resolved. Reflection still describes the actual
nominal subject rather than retaining an earlier protocol view. Collection
and function types are not recomputed from contents or behavior.

The representation of this evidence is internal, but it must be available
without running a callback, factory, or other user behavior. No payload scan,
descriptive name comparison, guessed protocol, or returned value can invent
missing type information. Wrapping malformed foreign data in a mirror cannot
validate it; the integrity obligations of section 11 still apply. There is
no new source `Any`, existential type, cast token, or public type query.

After executing the selected row, validate its ordinary result against the
fully instantiated row result before adapting it for the caller:

- If the result is already a `Mirror`, return that same mirror.
- Otherwise return a mirror of the ordinary result under `Mirror of`'s
  existing contract.

This performs no recursive unwrapping or flattening. `Mirror of` itself is
unchanged: `(Mirror of existing-mirror)` explicitly reflects the Mirror
object. As an element of the argument list, `existing-mirror` supplies its
subject; `(Mirror of existing-mirror)` supplies that Mirror object after the
one permitted unwrap. Mirroring and result adaptation neither capture nor
recover constructor refinement.

Owner, arity, argument, and generic-resolution failures prevent the selected
row from executing. A bad result is rejected after execution and its effects
are not rolled back. Host targets use the same exact interface, target state,
crossing restrictions, failure causes, and break behavior as other guarded
invocation. Multi-constructor local rows remain absent from reflection.

This permission to instantiate an opaque row from sealed input evidence is
specific to `invoke-mirrored`. Ordinary constructor elaboration, contextual
`subject`, and ordinary-result `invoke` retain their closure requirements.
The new operation cannot construct a context-free `Option.None` or a
`Result.Ok` whose `E` is unknown, but can use inputs that fully determine
`Option.Some` or an instance's generic `map`. Cases needing more evidence use
the existing contextual `invoke` or an ordinary explicit constructor send.

### Argument acceptance and enumeration

`(signature accepts? candidate-mirror)` requires a `Mirror` argument and
returns `#f` for any row whose parameter count is not one. For a one-parameter
row it checks the candidate mirror's subject against that parameter with the
invocation type relation. It performs neither invocation nor overload search
and supplies no constructor refinement.

For a generic one-parameter row, input variables may be solved freshly from
the candidate, while any receiver family arguments remain fixed. Success
proves only parameter compatibility. It does not resolve unrelated
result-only variables or guarantee that invocation can proceed without
further context. The query does not specialize or change the stored
signature. There is no arbitrary-arity argument-list version of `accepts?`.

Enumeration is deterministic within a finalized program image:

- constructor rows follow constructor declaration order;
- declaration-owned method and factory rows follow textual order, with
  generated payload accessors following payload declaration order;
- additive extension rows follow finalized program-definition order; and
- overloads remain separate signatures, while `messages` removes duplicate
  selectors and preserves their first signature occurrence.

Adding a constructor, factory, method, or overload may change later menu
positions. Indices are presentation positions, not stable row identities;
their ordering does not imply a user-visible ordering relation on signatures.

For Mirror's own API, append `invoke-mirrored` after the existing instance
rows `messages`, `signatures`, `invoke`, `subject`, and `raw`, preserving their
relative order. Ordinary subjects acquire no new operation. Asking a mirror
for its subject's rows is unchanged; explicitly reflecting a Mirror object
exposes the additional row with the fixed metadata above.

### Presentation and existing clients

`raw` uses exactly section 13's structural renderer, including
`Family.Constructor` in multi-constructor diagnostics and the established
one-constructor spelling. It does not invoke `show`. Diagnostic text grants
no constructor identity, payload value, signature authority, refinement, or
exhaustive-discrimination contract. Text depicting a payload is not access to
the original Aloe payload value.

Programs can inspect and compare strings. Parsing `raw` or branching on
`show` is presentation-text processing, not semantic case analysis, and
receives no missing-case diagnostics. This boundary does not claim textual
discrimination is physically impossible or change the raw spelling to hide
it. Ordinary exhaustive `case` remains the supported representation
discriminator.

Existing clients impose preservation obligations. Gel retains its `Mirror`
stack, menus of exact overload rows, one-argument filtering through
`accepts?`, and structural `raw`. Its invocation helpers use `invoke-mirrored`
to keep intermediate arguments and results behind the sealed boundary, as
illustrated in section 16. Ordinary-result `invoke` and contextual `subject`
remain available for source contexts that determine their types.
Reflecting an existing mirror's subject and explicitly reflecting a mirror
itself remain distinct. Existing valid Gel flows, results, keys, and emitted
text are preserved, except that explicitly browsing Mirror's extended API
shows its additional operation. That intentional menu addition is not a
promise of identical introspection text for the extended API.
MPL retains reflection of the concrete family's public surface through a
protocol view, subject to the multi-constructor
local exclusion. Host reflection retains exact interface ownership and the
ordinary guarded invocation boundary with the target receiver's state.

Primitive and host rows here are preservation constraints only. Section 15
specifies their integration with checked execution and the guarded host
boundary. Neither section specifies adapter internals, a new built-in schema,
additional crossing types, or a Gel redesign.

## 15. Specialized built-ins and typed host integration

### Specialized values in one language

`define-family` is the one ontology for user-defined nominal data. Existing
primitives, functions, collections, reflection values, and host capabilities
may retain specialized implementations. Internal adapters connect those kinds
to the common type and reflection relations where necessary. Specialization
does not introduce a second meaning for a list, another send rule, or an
alternative nominal declaration form.

| Value kind | Preserved boundary |
| --- | --- |
| `Int`, `Float`, and `String` | Existing scalar values and messages; numeric types remain distinct. |
| `Bool` | Existing Boolean values and lazy `if` behavior through function objects. |
| Functions | Arrow types and execution through `call`; closure representation remains opaque. |
| `List` | Homogeneous invariant element typing, immutable collection operations, and existing Aloe-defined methods. |
| `Symbol` | Interned names with the existing `intern`, `name`, and `=` messages. |
| `Mirror` and `Signature` | The explicit reflection boundary in section 14. |
| Host capabilities | Explicitly injected opaque nominal receivers with guarded declared operations. |

This integration assigns no representation constructors or payload schemas to
these kinds. Possible future algebraic descriptions for `Bool` or `List`
remain optional; they are not unfinished prerequisites of the family model.
An adapter alone neither makes its value eligible for family `case` nor
creates constructor refinement or publishes a constructor inventory. Case
eligibility still follows section 4.

Existing expression receivers such as `List`, `Symbol`, and `Mirror` remain
available. Being a primitive type name in an annotation does not imply a bound
type-object value in expression position. This candidate creates no new such
bindings, generated built-in `new`, or user constructor for `Signature`.
It adds no built-in protocol conformance claims and grants no general right
to extend every specialized receiver. `Option` and `Result` remain ordinary
user families, not privileged built-ins.

### Operations and library composition

Numeric sends retain their existing parameter and result types. Arithmetic
requires the same numeric kind on both sides, comparisons retain `Bool`
results, and `(n float)` remains the explicit `Int` to `Float` conversion.
Existing string values and their public messages are preserved.

`Bool.if` receives two zero-argument function objects with a common result
type and invokes exactly one through `call`. Functions retain arrow typing,
their established annotation and inference rules, and execution exclusively
through `call`. The `if` and `cond` forms, including `cond`'s required final
`else`, and parallel `let` retain the behavior in section 1. Specialized
function representation creates no direct application form or closure
inspection operation.

`(List of ...)` retains variadic construction with homogeneous element typing.
`(List empty)` constructs an empty list. The existing `empty?`, `first`,
`rest`, `cons`, and `len` operations retain their meanings: `first` and
`rest` reject an empty receiver, `cons` returns a new list with a same-typed
element prepended, and `len` returns `Int`. These operations do not mutate
the receiver.

`fold`, `reverse`, and `map` remain Aloe methods in `lib/list.aloe`.
`fold` is the existing left fold; `map` and `fold` execute their callbacks
through `call`. The established declaration route remains:

```text
(define-methods List
  (methods
    ...))
```

Here `T` denotes the receiver's element type and remains in scope. Row-local
parameters, such as the accumulator parameter `A` of `fold` and result
parameter `U` of `map`, retain their ordinary method-local meaning and fresh
instantiation. Keeping this route requires neither a source-defined `List`
family nor new built-in factories, constructors, local tables, or conformance
declarations. Section 7's family extension grammar does not grant those
additional rights to `List` or to other specialized kinds.

`List` remains homogeneous and invariant. A list of family values stores the
base family element type, not nested constructor refinements. Removing that
checker knowledge does not erase an element's actual family, resolved generic
arguments, constructor, or payload. Reading an element recovers the declared
base element type; constructor knowledge is obtained by the ordinary rules
in sections 4 and 5.

An empty list receives its element type from an expected `(List T)` when
available. Otherwise its fresh element variable must be determined by
constraints within the enclosing checking unit. Section 8's inference
closure applies without an empty-list exception: no unresolved variable
escapes a boundary, and missing generic arguments are not reconstructed from
runtime elements. Checked execution retains the static information needed
even when the collection has no elements.

`(Symbol intern string)` preserves interned-name behavior, `(sym name)`
returns the name string, and `(sym = other)` compares symbols. Interning
changes neither lexical lookup of expression symbols nor literal selector
syntax. A symbol does not confer dynamic invocation authority.

The `Symbol`/`List` type-description data used by reflection remains the
descriptive boundary in section 14. Its nested grammar does not introduce a
general heterogeneous collection type or source-written `TypeData`, `Any`,
or `Object` type.

### Common checked and runtime obligations

Specialized kinds participate in the checked-program and shared-descriptor
model of sections 8 and 9. The checker, direct sends, reflected invocation,
`accepts?`, and boundary validation must agree on the relevant types and exact
owners under section 11's one relation. The existing function and collection
typing rules are preserved; integration introduces no new subtyping or
variance system. Descriptive symbols, equal layouts, and matching method names
cannot establish nominal compatibility.

Adapters retain the static information required by checked execution. They
make sealed, already closed collection, function, and nominal type evidence
available for section 14's explicit `invoke-mirrored` boundary. That operation
may instantiate its selected row from this evidence before execution.
Adapters do not permit ordinary construction to reconstruct missing family
arguments at runtime, inference by scanning values or executing behavior,
evaluation of unchecked parsed source, or a second elaboration path with
weaker guarantees. Their algorithms and physical representation remain internal.

Reflection uses section 14's existing primitive and host surfaces, exact-row
ownership, and guarded invocation. Rows outside algebraic family and
type-object surfaces have role `operation`. Participation does not require
revealing a specialized value's physical representation or adding metadata
queries.

Kernel equality and display remain governed by sections 12 and 13. Scalars
and algebraic values retain their established value semantics. Functions,
type objects, host capabilities, and other identity-bearing opaque leaves
follow the identity rules already specified there. Host state is not compared
structurally or deep-frozen, no universal `=` message is added, and raw
printing never invokes Aloe methods. An adapter changes none of those
observations and does not expose private state through structural display.

### Host declarations and scalar crossings

A host capability is a Racket-created receiver holding an opaque nominal
`host-interface` and private state. One interface descriptor owns an ordered
list of `host-method` declarations with unique selectors. Each declaration
supplies the selector, fixed parameter types, result type, and Racket
implementation shared by checking, dispatch, and reflection.

The implementation accepts exactly one private state argument followed by the
declared positional arguments. Optional, variadic, or keyword call shapes are
rejected. Private state is not an extra Aloe argument or an exposed payload.
Host selectors remain unique; user-family overloading does not introduce host
overloads. A send to an unknown selector or with the wrong declared arity is
rejected through the existing boundary.

The complete method-argument and method-result crossing vocabulary is
`Int`, `Bool`, and `String`. All arguments are validated before the
implementation runs, and the result is validated before it enters Aloe.
Strings are normalized to immutable values in both directions. Invalid
declarations or crossing values are rejected rather than coerced. An
implementation failure receives consistent Aloe host-failure context while
retaining its original Racket cause; breaks pass through unchanged.

The common type relation can describe more types than this boundary admits.
It does not add `Float`, collections, family values, functions or callbacks,
reflection values, or opaque handles to host method arguments or results.
Explicit injection of a capability is distinct from returning one as a host
method result. There is no family marshalling or general FFI, arbitrary Racket
call or evaluation, namespace access, dynamic library surface, or ambient
capability.

### Injection, ownership, and opaque composition

An optional capability enters Aloe only through explicit driver injection.
Injection preflights both runtime and checker environments, then installs the
receiver and its nominal type as one logical operation. It never overwrites
an existing binding on either side. The checker and runtime refer to the same
exact interface identity, not independently manufactured descriptions with
the same name. Default environments contain no optional capability.

Interface names are diagnostic labels. They do not become source-written
host types in annotations or explicit send type headers. Possession of an
injected value permits its existing typed use; spelling its printed name
grants no authority. Internal inferred host types do not enlarge the source
type grammar in section 5.

Host messages, signatures, type descriptions, and ownership derive from that
same descriptor and use the ordinary guarded exact-row invocation boundary.
As specified in section 14, a signature may target another receiver of the
same exact interface and uses that receiver's private state. A same-named but
distinct interface is incompatible. Reflected invocation does not bypass
declaration, argument, result, or failure guards.

Where ordinary typing permits a family payload to contain a capability or
function, that leaf remains opaque. The family fixes the payload position;
it neither freezes external state nor reveals the leaf's representation.
Case analysis of the enclosing family can bind the leaf as an ordinary value,
but cannot inspect host state or a closure. Neither a mirror nor containment
in family data makes the leaf an algebraic constructor or enlarges the host
crossing vocabulary.

The guarded Racket-facing host declaration and driver-injection boundary
sealed at checkpoint 88 is preserved. Validated constructors, predicates,
safe declaration accessors, receiver sends, and retained-failure-cause
inspection keep their existing roles. Raw constructors and receiver state
access remain outside the ordinary public surface, as do the checker's
host-type machinery and the narrow internal injection and exact-method
invocation hooks. The implementation accessor remains Racket-facing
declaration data; it is never exposed as an Aloe procedure value.

Descriptors may be adapted internally to the linked program image without
bypassing these guards or publishing private state or arbitrary Racket
procedures to Aloe. This contract requires no new registry, loader,
capability declaration form, ownership or lifetime system, or Racket API
redesign.

Atomic injection and checking transactions are distinct guarantees. Injection
preflight prevents a binding conflict from installing only one side. Static
failures obey section 9's transaction rules and prevent evaluation. Host
effects after successful checking retain their ordinary behavior and are not
rolled back, including when a later result check fails.

### Term and application composition

Term is the existing production example with exactly these declared rows:

```text
read-key   : () -> String
write-line : (String) -> String
```

`write-line` writes the supplied string followed by CRLF, flushes output,
and returns the string. Both optional terminal runners explicitly inject
Term into a checked driver. Ordinary Aloe startup, Boids, and MPL remain free
of optional Term authority and terminal dependencies.

Racket supplies host facts and effects; Aloe owns domain policy and
composition, including Gel's key handling and state transitions. This is a
preservation example, not a new terminal specification: it changes no key
mapping, exposes no `tui-term` Aloe API, specifies no filesystem capability,
and migrates no Gel state.

## 16. Candidate examples

These examples illustrate the candidate syntax, reflection, and integration
contracts; they are not checkpoint-89A–89E goldens. Family declarations and
family-aware reflection remain unimplemented. Observations about established
built-in and host behavior are preservation examples.

### `Point`: a one-constructor product

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
        ((self y) + (other y))))))

(define p
  (Point new (type Float) (2 float) 3.0))
```

`new` is explicit. `(2 float)` is an ordinary send performing the required
numeric conversion; the type header is static and its two payloads are runtime
arguments.

### `Option`: constructors, a factory, `call`, and case

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
          (self None))))
  (methods
    (present? () Bool
      (per-constructor
        (None #f)
        (Some #t)))

    (map (type U)
      (f (-> T U))
      (Option U)
      (self case
        (None () (Option None (type U)))
        (Some (value) (Option Some (f call value)))))))

(define maybe-name
  (Option when #f "unused"))

(define none-name
  (Option None (type String)))

(maybe-name case
  (None () "unknown")
  (Some (name) name))
```

The function object in `map` runs only through `(f call value)`. The factory's
false branch is checked with its declared `(Option T)` result, but callers of
`when` do not learn whether it returned `None` or `Some`.

### `Result`: two invariant family parameters

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

(define failed
  (Result Error (type String String) "not found"))

;; result is an unrefined (Result String String)
(result case
  (Ok (value) value)
  (Error failure (message)
    ("error: " append (failure error))))
```

The explicit header on `failed` fixes both family arguments on a constructor
whose payload alone cannot determine `T`. The separate `result` value is
unrefined. In its `Error` branch, the whole-value binder `failure` is refined
to `Error`, so its local `error` accessor is available.

### `Tree`: direct regular recursion

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

;; tree is an unrefined (Tree Int)
(tree case
  (Leaf (value) value)
  (Branch node (left right)
    ((left size) + (right size))))
```

The recursive payloads reuse `T` at full arity and in the same order. All
method calls and construction sites remain receiver-first sends.

### Reflection observations

The following observations use the families above. Type descriptions in the
tables are schematic spellings of `Symbol`/`List` data, not source expressions
to evaluate or tokens to pass as types.

For a `(Point Float)` instance such as `p`, its mirror exposes `x` and `y`
as zero-argument `local` rows returning `Float`, together with the `family`
row `+`. This is valid because `Point` has one constructor. Mirroring `Point`
itself instead exposes its explicit `new` constructor row.

For both `None` and `Some` instances at `(Option Int)`, the whole-family
surface is the same:

| Selector | Role | Type parameters | Parameter descriptions | Result description |
| --- | --- | --- | --- | --- |
| `present?` | `family` | none | none | `Bool` |
| `map` | `family` | `U` | `(-> Int U)` | `(Option U)` |

There is no `value` accessor, `None`/`Some` tag query, or constructor-local
row in either instance menu, even for a mirror made inside the `Some` branch
of an exhaustive case. `present?` is one declared family operation with two
implementation bodies, so it contributes only one signature. Its Boolean
result supplies no checker refinement.

The `Option` type object's signatures instead describe construction:

| Selector | Role | Type parameters | Parameter descriptions | Result description |
| --- | --- | --- | --- | --- |
| `None` | `constructor` | `T` | none | `(Option T)` |
| `Some` | `constructor` | `T` | `T` | `(Option T)` |
| `when` | `factory` | `T` | `Bool`, `T` | `(Option T)` |

The constructors follow declaration order, followed by the declared factory.
`Some` reports its payload's type, not the payload position name `value`.
`None` remains generic even though it has no payload. A hidden `None`
signature invoked in a checked `(Option Int)` result context can use that
context to resolve `T`; absent sufficient checked information it is rejected.

A `present?` signature obtained from a mirror of an `(Option Int)` `None`
may be invoked on a mirror of an `(Option Int)` `Some`: it selects that same
family row, whose actual-constructor body returns `#t`. The row is rejected
on `(Option String)`, even though `present?` mentions no `T` in its parameter
or result types. It is also rejected on an unrelated same-named family with
identical descriptive metadata. Ownership is stronger than type spelling or
coincidence of row shape.

The `Result` type object's one-parameter `Ok` constructor row describes
generic parameters `T`, `E`, input `T`, and result `(Result T E)`. Its
`accepts?` query on a mirror of `1` returns `#t` by solving the input
variable as `T = Int`. That does not determine result-only `E`. Invocation
still needs sufficient checked context, such as an expected
`(Result Int String)`, to resolve both parameters before construction.

Finally, unwrapping a mirror of `Some` in an `(Option Int)` context yields
the ordinary unrefined family view. A direct `value` send on that view is
rejected. An exhaustive case covering `None` and `Some` can introduce a
`Some` whole-value binder and use its local `value` accessor normally. The
same rule holds if the mirror was originally made in a refined branch or
from a protocol view; unwrapping does not recover that source history.

### Gel invocation through mirrors

The following current and proposed method fragments isolate the reflection
change; their surrounding nominal declarations and the class-to-family
migration are omitted. The proposed fragments are future examples only and
do not change Gel source in this checkpoint.

Current Gel helpers use ordinary results and contextual unwrapping:

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

The candidate's replacements keep intermediate values behind the guarded
reflection operation:

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

The new row supplies an expected `(List Mirror)` to `(List empty)`, so the
empty argument list's element type closes normally. Its result is statically
`Mirror`, selecting `push`'s exact Mirror overload. The mirrored-argument
helper passes `(List of arg)` instead of introducing the unknown ordinary
type of `(arg subject)`. The shorter ordinary-argument helper delegates to
the exact Mirror overload; its `T` is a declared bound parameter. None of
these bodies exposes an unknown intermediate subject or invocation-result
type to source checking.

Application call sites remain the same before and after:

```aloe
(stack invoke-zero row)
(stack invoke-one row 2)
(stack invoke-one row picked-mirror)
```

Here `stack : GelStack`, `row : GelRow`, and `picked-mirror : Mirror` are
existing values, and the selected row must have the appropriate owner,
arity, and argument types. No type picker, additional annotation, or wrapper
is added at these call sites.

For `receiver` mirroring `10`, `signature` its exact `Int.+` row, and
`argument` mirroring `2`, the current expression is:

```aloe
((Mirror of (receiver invoke signature (argument subject))) raw)
```

Its candidate replacement is:

```aloe
((receiver invoke-mirrored signature (List of argument)) raw)
```

Both intend the String `"12"`. The current expression illustrates the old
client path; it does not waive the candidate's closure rule for ordinary
`subject` or `invoke`. The replacement uses a closed source signature and
guards its hidden row.

For a selected row returning a `Mirror`, `invoke-mirrored` returns that same
mirror and the exact `push` overload stores it unchanged. An ordinary result
is mirrored once. This preserves Gel's current adaptation for both kinds of
result; an unconditional extra `Mirror of` would change which object Gel
describes next. An explicitly double-mirrored argument still passes the
Mirror object itself after one unwrap; no recursive flattening occurs.

With the exact target/signature owners and already well-typed mirrored inputs,
the generic consequences are:

| Selected row and context | Required outcome |
| --- | --- |
| `Int.+` on mirrored `10`, with a mirror of `2` | Return a mirror of `12`. No generic parameter is missing. |
| `(Option Int).map`, with a mirrored function of checked type `(-> Int String)` | Resolve fresh `U = String` before any callback executes, then mirror the resulting `(Option String)`. |
| `Option.Some`, with a mirror of `1` | Resolve `T = Int` from sealed input evidence before construction; mirror the `(Option Int)` Some result. |
| `Option.None`, with an empty mirror list | Reject before construction: no evidence determines `T`. The outer `Mirror` result supplies none. |
| `Result.Ok`, with a mirror of `1` | Reject before construction: `T = Int` is known but `E` is not, even if `accepts?` returned `#t`. |
| An `(Option Int)` instance's nongeneric family row | Retain the exact owner's fixed `Int`; do not infer another receiver instantiation. |
| A factory with a parameter determined only by its result | Reject before running its body; its result cannot finish inference. |

When an explicit construction is needed, the existing route remains:

```aloe
(Mirror of (Option None (type Int)))
```

The family argument is fixed at source checking before mirroring. The new
operation supports input-determined generic rows without promising that
every reflected row can run in Gel without further context. Explicitly
browsing a Mirror object's own API includes the appended `invoke-mirrored`
row; ordinary subject menus and existing valid Gel key flows retain their
specified behavior, subject to that intentional API menu addition.

### Specialized-value and host observations

The established numeric sends remain:

```aloe
(1 + 2)                 ; 3, an Int
(1.0 + 2.0)             ; 3.0, a Float
((1 float) + 2.0)       ; 3.0, after explicit conversion
```

`(1 + 2.0)` is rejected. Common runtime integration supplies no implicit
conversion between the numeric kinds.

In the proposed family model, a `(List (Option Int))` can hold both `None`
and `Some` values. `reverse` preserves that element type; `map` with a
callback sending `present?` produces a `(List Bool)`, with the callback run
through `call`. Reading an element gives an unrefined `(Option Int)` even
when that element originally came from a directly constructed `Some`.
Ordinary exhaustive case analysis can recover the local surface. The stored
value still has its exact family, `Int` argument, actual constructor, and
payload; only the nested checker refinement was forgotten.

An empty list can obtain its element type from its enclosing function call:

```aloe
((fn (xs) ((xs cons 1) len)) call (List empty))
```

The list argument and `cons 1` together determine `xs` as `(List Int)` within
the call; the result is `1`. A parameter already expected as `(List Int)`
supplies that type directly. Under the candidate's closure rule, an empty
list whose element variable is still unresolved at its checking-unit boundary
is rejected. Runtime inspection of later elements does not supply the missing
static information, and the list head of the call above is still the function
receiver.

Two separately declared host interfaces can share a diagnostic name and
identical row descriptions without sharing signature authority. A signature
from one is rejected by a receiver of the other. Conversely, two receivers
of the same exact interface may use the same signature; invocation supplies
the target receiver's state, not the state of the receiver first reflected.
No source-written host annotation is needed or introduced by that fact.

For a declared host row accepting `String`, an `Int` argument is rejected
before the Racket implementation can run. If a declared `String` result
instead returns a Racket integer, the return boundary rejects it before it
enters Aloe; any effects the implementation already performed are not undone.
Direct and reflected invocations use the same guards.

If ordinary typing permits an injected receiver or a function in a family
payload, a case branch can bind that opaque value. It cannot decompose the
receiver's private state or the function's closure. Carrying either leaf in
Aloe data does not permit passing the enclosing family, a callback, or a
capability as a host method argument or result.

## 17. Reconciliation and compatibility boundary

This candidate deliberately changes only the proposed nominal family surface;
the current language remains governed by `SPEC.md` until an atomic later
ratification.

The proposed reconciliation is:

| Current normative surface | Candidate family surface |
| --- | --- |
| `define-class` | one `define-family` ontology |
| one class-level `fields` section | fields owned by each explicit constructor |
| generated class message `new` | no generated constructor; products explicitly declare `new` |
| one positional protocol after a class header | optional nonempty `(conforms P ...)` section supporting several protocols |
| generic `new` inference from fields | constraint-based constructor inference, with an optional complete send type header |
| nominal class applications in type grammar | nominal family applications at declared arity |

The completed candidate language rejects `define-class`, positional
conformance after a family header, family-level `fields`, generated `new`, and
permanent class/family aliases. All user-defined nominal source ultimately
uses `define-family`. Retaining both declaration forms permanently would retain
two apparent nominal ontologies.

A later implementation sequence may temporarily lower a legacy
`define-class` declaration to an internal one-constructor family whose explicit
constructor is `new`, solely to keep the historical suite green during
migration. Such a bridge is implementation sequencing, not candidate source
syntax or a compatibility promise, and it must have an explicit removal
checkpoint. Checkpoints 89A–89E add and authorize no bridge or implementation
scaffold.

The candidate preserves all unaffected expression behavior, including literal
selectors, `fn` through `call`, parallel `let`, lazy `if` and `cond`, `load`,
`check`, homogeneous invariant `List`, explicit numeric conversion, existing
primitive types, and the separation between protocol types and runtime method
tables. It does not carry forward contradictory rules for generated `new`,
class-level fields, one positional conformance, or constructors inferred from
class layout.

## 18. Diagnostics and detection boundaries

The catalogue in sections 19–22 organizes the preceding semantic rules. It
does not add language features or certify the complete design. A diagnostic
must identify the invalid condition and the relevant evidence, such as the
offending declaration, selector, type obligation, or missing constructor.
The boundaries below describe when the language must enforce an obligation;
they are not mandatory error-code names or public exception classes.

| Detection boundary | Required distinction | Governing rules |
| --- | --- | --- |
| Source grammar, name resolution, and static checking | Reject invalid source and unsatisfied static obligations before evaluation. Where only that timing is specified, no particular parser, linker, or checker phase is mandated. | Sections 1–8 |
| Combined declaration, extension, and whole-unit finalization | Validate the combined rows and conformance claims, including allowed extensions in the complete source unit and its transitive loads, before committing static state and evaluating. | Sections 7–9 |
| Racket host declaration and driver injection | Validate host declarations and implementation call shape; preflight both driver environments before installing a capability binding. These are not Aloe source declaration forms. | Section 15 |
| Guarded runtime validation and ordinary evaluation | Enforce obligations depending on actual values or hidden signatures, and report ordinary evaluation failures. A checked program does not remove its dynamic guards. | Sections 10–15 |

The candidate specifies no numeric codes, exact diagnostic wording,
source-span format, error aggregation, recovery behavior, or global precedence
between independent errors. Existing specific information requirements remain:

- Missing case constructors are reported in family declaration order
  (section 4).
- Ordinary type presentation uses the base family type, not a source-like
  constructor-set annotation. When exact instantiation matters, especially
  for a nullary constructor, type context is displayed separately from
  concise raw value text (sections 8, 11, and 13).
- Names and raw spellings are descriptions. A mismatch between same-named
  nominal owners remains a mismatch; identical text does not establish
  compatibility (sections 10, 11, 14, and 15).
- `check` retains its left-to-right evaluation and same-type requirement.
  When same-typed values are unequal, the failure reports both original
  source datums and both resulting values. Success returns the right-hand
  value. Trusted comparison is kernel equality, not a user `=` send
  (sections 1 and 12).
- Host implementation failures retain Aloe host-failure context and the
  original Racket cause; breaks pass through unchanged (section 15).

Static failure commits no partial live checker state and begins no evaluation
under section 9. A hidden reflective row or host crossing may require runtime
validation: owner, arity, argument, and required generic-resolution failures
prevent the selected row from running. Result validation occurs after the
row executes and does not undo its effects. For `invoke-mirrored`, the selected
row's generics must resolve from its exact owner and sealed closed input type
evidence before execution. Its ordinary result must pass the fully instantiated
result check before Mirror adaptation. This explicit guarded operation has
closed source types; it does not relax closure for ordinary-result `invoke`,
contextual `subject`, or ordinary construction. Atomic injection, checking
transactions, and the absence of runtime effect rollback remain distinct
guarantees.

## 19. Required rejection catalogue

Each entry names an invalid condition, its semantic detection boundary, and
the rule it enforces. “Static” below includes source grammar, resolution, and
checking without prescribing their internal allocation. “Finalization” includes
the combined declaration and extension obligations of section 9. A condition
listed at both static and runtime boundaries is checked statically when the
relevant information is available and guarded dynamically where required.

### Expressions, declarations, and source types

| Invalid condition | Detection boundary | Governing rules |
| --- | --- | --- |
| Empty or one-element ordinary combination; invalid nonliteral selector; malformed preserved expression form, binding, or body; unbound expression name. A name available only in another new parallel `let` binding is not in scope on a binding's right-hand side. | Static | Section 1 |
| Malformed or unresolved source type, unbound type variable, wrong nominal or container type arity, or arrow type lacking a result; a constructor, constructor set, host diagnostic label, or reflected type datum used as if it were an admitted source type. | Static | Sections 5 and 15 |
| Unsupported source form, including the completed language's legacy declaration forms. A type-shaped list in expression position is still a send, not type application. | Static | Sections 1, 5, and 17 |
| Missing required family or constructor section; wrong section order or cardinality; empty constructor set; present-but-empty `conforms`; unresolved conformance name. | Static, with combined declaration validation before commit | Sections 3, 7, and 9 |
| Malformed method or protocol row, missing required parameter/result/body structure, or duplicate bound type-variable names within a family or row header. | Static | Sections 3, 5, and 7 |
| Duplicate constructor selectors or payload names; constructor selector reused by a factory, accessor, local method, family method, or extension; family/local selector collision; payload/local collision within a constructor; duplicate exact overload. | Static and finalization | Sections 3, 7, and 9 |
| Misuse of contextual markers: `case` as a declared callable selector, `else` as a constructor selector, malformed reserved clause/body-mode grammar, or an immediately post-selector `type` header treated as a runtime argument. | Static | Sections 1, 3–5 |

The marker rules apply only in their specified scopes. `type` is not a
globally forbidden selector, `per-constructor` is only a body-mode marker,
and declaration labels are not global reserved words. Outside reserved
positions, ordinary symbol/selector use remains legal where the other rules
permit it. A nullary constructor requires an empty `(fields)` section; that is
different from an invalid empty constructor set. Optional empty sections stay
legal where section 3's grammar permits them. Section 7 requires an extension
section, not an invented minimum number of rows in that section.

### Construction, methods, case, and linked behavior

| Invalid condition | Detection boundary | Governing rules |
| --- | --- | --- |
| Wrong constructor payload arity or substituted payload type; inconsistent invariant family arguments. | Static; defensive construction validation at runtime | Sections 3, 5, and 11 |
| Malformed or partial explicit type header, unsupported placeholder, ill-formed type argument, or explicit evidence conflicting with parameter/result constraints; no applicable row after type-header and ordinary overload constraints are considered. | Static; checked reflective obligations at runtime when the row is hidden | Sections 5 and 14 |
| Unresolved nullary or partially determined construction, or inference variables escaping a top-level expression/definition, method/factory body, explicitly typed function body, or complete program transaction. | Static closure; guarded generic resolution for hidden reflective rows | Sections 5, 8, and 14 |
| Unknown message, wrong ordinary call arity/type, or local access without singleton knowledge; repeated local selectors treated as a family row; unavailable local access through a protocol or widened result/storage view. | Static; ordinary dispatch and dynamic boundary checks where applicable | Sections 2–5, 7, 10, and 11 |
| Missing, duplicate, unknown, or malformed `per-constructor` entries; a default or extra binders in that table; a body violating its declared type or `self` view; `per-constructor` on a factory or local method; default-plus-override body mode. | Static and complete-table finalization | Sections 3 and 9 |
| Case scrutinee with no eligible concrete family/constructor set, including a protocol-only view, unconstrained variable, type object, or mirror. A built-in adapter alone does not confer eligibility. | Static | Sections 4 and 15 |
| Missing, duplicate, unknown, or currently impossible case constructor; malformed clause or whole/payload binders; wrong payload arity; misplaced or empty-residual `else`; incompatible branch results or an unsupported pattern form. | Static | Sections 4 and 5 |
| Missing or incompatible protocol requirement; requirements supplied only by constructors, factories, accessors, locals, or reflection rows; insufficient parameter-domain coverage; incompatible result obligations at one parameter shape. | Static and whole-unit conformance finalization | Sections 7 and 9 |
| Unsupported conformance form, including per-constructor or nonuniform generic claims; ambiguous overloads or narrower dynamic rows with results unusable as the broader promised result. | Static and combined overload/conformance finalization | Sections 7, 9, and 10 |
| Invalid extension target, missing/misordered sections, exact row replacement, reserved-selector collision, or incoherent combined rows; attempted constructor/payload/local/per-constructor-table/conformance addition. | Static and atomic extension/whole-unit finalization | Sections 7, 9, and 15 |
| Recursive payload self occurrence with wrong arity or changed/reordered arguments; nonregular/polymorphic recursive payloads, mutual recursion, or unresolved forward family reference. | Static | Sections 6 and 9 |

An explicit header filters overload candidates by applicable generic arity.
Rejecting one candidate on that basis does not reject the send when another
valid row applies; ambiguity still follows the ordinary rules. The family
parameters precede row-local parameters on type-object sends, while an
instance has already fixed its family arguments (section 5).

An expected protocol alone cannot resolve a family instantiation. Ordinary
declared results, annotations, function boundaries, generic storage, payloads,
protocol conversion, and reflective unwrapping forget refinement as specified
in section 5; they do not change the stored constructor or nominal type.
One-constructor families remain inherently singleton-refined. The existing
`define-methods List` route and its element parameter remain legal under
section 15.

### Dynamic integrity, reflection, comparison, and integration

| Invalid condition | Detection boundary | Governing rules |
| --- | --- | --- |
| A constructor owned by another family, malformed payload count, payload failing its substituted type, or unresolved construction arguments in a value being introduced. | Defensive construction or injection boundary; reject malformed foreign data rather than treating it as a case default | Sections 10 and 11 |
| Exact family, invariant instantiation, protocol identity/conformance, or internally required constructor-membership mismatch at a dynamic boundary. | Guarded runtime validation | Section 11 |
| Malformed reflection call: wrong API argument count/type, including an `invoke` without a `Signature`, an `accepts?` without a `Mirror`, or an `invoke-mirrored` without exactly a `Signature` and a `(List Mirror)`. Its own generic arity is zero; a nonempty type header cannot supply selected-row parameters. | Static when known; guarded reflection boundary | Sections 5 and 14 |
| Wrong signature owner or exact row authority, wrong invocation argument count/type, conflicting or insufficient generic information, incompatible returned result, or incompatible contextual `subject`. | Static obligations and guarded runtime validation; result checking follows execution | Sections 8, 11, and 14 |
| For `invoke-mirrored`, wrong target-list length, a non-Mirror element, unavailable or inconsistent closed subject type evidence, or a once-unwrapped argument failing its instantiated parameter type. Malformed foreign subjects are not made valid by wrapping them. | Guarded boundary before the selected row executes; statically reject known API type mismatches | Sections 11, 14, and 15 |
| Selected-row parameters still unresolved after fixed-owner and sealed-input constraints, including `Option.None` without input evidence, `Result.Ok` with only `T` known, or a result-only factory parameter. Neither an outer expected `Mirror`, a successful `accepts?`, nor the operation's type header supplies the missing evidence. | `invoke-mirrored` guarded generic resolution before execution, without probing a body or result | Section 14 |
| Context-free ordinary-result `invoke` or contextual `subject` leaves source inference variables unresolved, including inside an enclosing `Mirror of`. | Static inference closure; the explicit `invoke-mirrored` rule does not rescue these ordinary operations | Sections 8 and 14 |
| Attempted invocation through a selector/type description or forged signature authority, or use of a nonexistent representation-query API on a multi-constructor instance mirror. | Unsupported source/API use is rejected; forged authority is a defensive runtime scenario. Valid enumeration succeeds with excluded local/accessor rows absent. | Sections 14 and 15 |
| `check` operands that cannot have the same type; unequal same-typed values. | Static for incompatible operands; evaluation for failed kernel equality | Sections 1, 12, and 18 |
| Wrong numeric operand kind or arity, invalid function/conditional arguments, mixed or invariantly mismatched list elements, or unresolved empty-list element type. | Static and applicable runtime boundaries; inference closure remains static | Sections 1, 5, 8, and 15 |
| `first` or `rest` of an empty list, or an ordinary numeric/collection evaluation failure under the established operation's rules. | Ordinary evaluation | Section 15 |
| Invalid host declaration: unsupported argument/result crossing type, duplicate/non-symbol selector, invalid descriptor inputs, or implementation not accepting exactly private state plus declared positional arguments without optional, variadic, or keyword shape. | Racket host declaration validation | Section 15 |
| Invalid driver-injection inputs or a binding conflict in either environment; separately manufactured same-name descriptors substituted for one exact interface. | Driver preflight and exact nominal boundary checks | Section 15 |
| Host argument/result failing the declared `Int`/`Bool`/`String` crossing, wrong host arity/selector, or reflected host row owned by a distinct same-named interface. | Static when known; guarded direct/reflected host invocation | Sections 14 and 15 |
| Use of an optional capability absent from the environment, or a host diagnostic name as a source type or type-header argument. | Name resolution and static checking | Sections 5 and 15 |
| Legacy `define-class`, positional conformance, family-level fields, an assumed generated `new`, or permanent dual nominal declaration syntax in the completed language. | Source acceptance and message checking in the completed language | Section 17 |

Malformed nominal values and forged signatures above are defensive boundary
validation scenarios, not constructible Aloe examples. They require no new
source syntax, published descriptor constructor, or public testing hook.
The completed-source exclusions do not deny section 17's possible later
temporary migration bridge, and this catalogue does not authorize that bridge.

Ordinary negative answers are not errors. With a valid mirror argument,
`Signature.accepts?` returns `#f` for a non-one-parameter row or an incompatible
candidate subject without invoking anything. Kernel inequality itself is a
comparison result; `check` fails because it requires equality. A final
nonempty-residual `else` is legal, and a constructor named `Other` is an
ordinary explicit case, unrelated to that default (sections 4, 12, and 14).

## 20. Consolidated exclusions and deferrals

The following are absent from the proposed language, not claims that they
can never be designed later. Required protocol signatures and multiple
family conformances are included in this candidate; their historical absence
from earlier Aloe versions is not a current design exclusion. Likewise,
today's unimplemented family features remain part of the proposed destination.

| Subject | Excluded proposed-language facilities | Governing rules |
| --- | --- | --- |
| Small expression language | Inheritance/`super`, Aloe mutation/setters, macros, implicit numeric coercion, computed selector sends, Scheme application, a second send/evaluation rule, `begin`, labeled `make`, modules beyond `load`, and native compilation remain outside the preserved language. Receiver-anchored overloading does not add full unanchored multimethods. | Section 1 and the preserved language boundary in section 17 |
| Family representation | Constructor types/subtypes, implicitly bound constructor functions, constructor-specific generics or result annotations, existential payloads, GADTs, visibility syntax, open constructor extension, and a permanent parallel class ontology. Constructors are not first-class values; an explicit `fn` wrapping a constructor send is allowed. | Sections 2, 3, 5, and 17 |
| Refinement and elimination | Source-written or deep stored constructor refinements; refinement from arbitrary predicates, equality, user messages, or reflection; partial case; nested patterns, guards, alternatives, fallthrough, or wildcard payload patterns. Nested case expressions and ordinary lexical payload binders remain legal. | Sections 4, 5, and 14 |
| Generic and recursive machinery | Partial type headers, constructor-specific `let` polymorphism, generic-constraint syntax, general subtyping expansion, mutual/forward declaration groups, nonregular recursion, positivity/termination checking, or claims of a full inductive type theory. Bound generic parameters are not escaped inference variables. | Sections 5, 6, 8, and 15 |
| Protocols and methods | Structural, conditional, per-constructor, or retroactive orphan conformance; generic protocols; protocol inheritance, intersections, or defaults; default-plus-override family bodies. Additive uniform family methods and ordinary factories remain allowed. | Sections 3, 7, and 9 |
| Runtime and reflection surface | Observable allocation identity for ordinary family data, user-overridable kernel equality, multi-constructor instance representation queries, captured refinement certificates, user-created signatures, a first-class type universe, or selector-based `perform`. | Sections 10–14 |
| Specialized values and host access | Invented built-in constructors or case eligibility, a general heterogeneous `List`, new primitive type-object bindings, generalized built-in extension rights, broader host crossings, source-written host types, opaque-handle/callback/family marshalling, ambient authority, arbitrary Racket access, or a general FFI. | Section 15 |

Some rejected choices are implementation strategies rather than source forms.
Name-based identity or case dispatch, independent name-based compatibility
relations, protocol wrappers, factory provenance in values, reference equality
for ordinary family data, raw rendering through `show`, runtime reconstruction
of missing family arguments for ordinary construction, and unchecked production
evaluation violate sections 8–15. The explicit `invoke-mirrored` boundary may
instantiate a selected row from its fixed owner and sealed, already closed
input type evidence before execution. This is not general runtime inference:
payload/collection scans, execution to discover types, and result-based
reconstruction remain excluded. No public type query, `Any`, existential,
cast, type token, or heterogeneous list is added. Exposing multi-constructor
local rows and rejecting their use only afterward also violates section 14.
These are not alternative ways to
implement the same observations. Permitted opaque stateful leaves do not
introduce Aloe setters or deep mutation of family data.

Other properties are deliberately unpromised: stable nominal identities across
executions, recompilation, serialization, or future reloading; source or
serialization round-tripping of raw text; stable menu indices; and user-visible
signature equality, ordering, hashing, allocation identity, or stable
serialization (sections 10, 13, and 14). This does not weaken total internal
kernel equality. Optional algebraic rewrites of built-ins remain future work,
not a required implementation strategy or an unfinished prerequisite
(section 15). No future syntax or mechanism for these subjects is specified
here.

## 21. Semantic validation obligations

These are future candidate validation scenarios, not executable checkpoint-89E
goldens or a test-harness design. They pair the rejection catalogue with
permitted behavior. Unless a row supplies another context, family examples
use section 16's `Point`, `Option`, `Result`, and `Tree` declarations. A
scrutinee described as unrefined permits all constructors of its stated
family. Existing runnable preservation examples in section 16 and the current
regression suite are distinct from these unimplemented family obligations.

### Construction and inference

| Scenario and context | Required observation | Governing rules |
| --- | --- | --- |
| Construct `Point` with ordered same-typed coordinates; inspect its fields and type-object surface. | The explicit `new` row constructs the one-constructor product; `x`/`y` preserve payload order and are usable without further case analysis. There is no generated constructor on a family that did not declare one. | Sections 2, 3, 14, and 16 |
| Construct both `Option` variants and call the declared `when` factory with each Boolean condition. | Public constructor sends work; factory `self` is the type object. The factory returns the chosen ordinary value under its declared unrefined result. Uniform methods and a complete `per-constructor` row execute their specified bodies; incomplete tables are rejected. | Sections 3, 5, 10, and 16 |
| Invoke `Option None` with an explicit `Int` header, or under an exact expected `(Option Int)`; separately try it with no header or constraining context. | The first two fix the nullary value's stored argument to `Int`; the unconstrained occurrence is rejected at closure. A protocol expectation alone does not fix that argument. | Sections 5, 8, and 11 |
| Use independent constructor sends at different fully resolved family arguments, and independent instance `map` sends whose callbacks determine different `U` types. | Family construction parameters and row-local method parameters are fresh per send. One invocation's substitution does not specialize the declaration or another invocation. | Sections 3 and 5 |
| In a case on an unrefined `Option Int`, one branch constructs `Result Ok 1` and the other `Result Error "x"`, with no unrelated enclosing result constraint; reverse the clause order. | Both arrangements infer `(Result Int String)` by gathering constraints across alternatives. A separate isolated `Ok 1` with no evidence for `E` is rejected. Branch order cannot commit a partial instantiation. | Sections 4, 5, 8, and 16 |
| Assume `Sym` explicitly conforms to `Math`. Construct `Some` from a `Sym` payload under expected `(Option Math)`; separately use an already constructed `(Option Sym)` where `(Option Math)` is expected. | The new construction may choose `T = Math`; the existing invariant instantiation does not convert covariantly and is rejected. | Sections 5, 7, and 11 |
| A valid overload set contains rows with different applicable generic arities; supply a complete type header matching one row and its ordinary constraints. | Inapplicable rows are filtered without rejecting a valid selected row. Partial/conflicting evidence, no applicable row, and genuine ambiguity are rejected. | Sections 3, 5, and 7 |

### Refinement and exhaustive control flow

| Scenario and context | Required observation | Governing rules |
| --- | --- | --- |
| Directly construct `Some 1`, then take immutable direct `define` and source-`let` aliases. | The outer singleton fact is retained and permits the `value` accessor. Runtime `let` still has its parallel `fn`/`call` behavior. | Sections 1, 5, and 8 |
| In an exhaustive case on an unrefined `(Option Int)`, bind the whole `Some` value and its payload; separately handle `None` explicitly and use a final residual whole-value binder. | Explicit whole-value binding is singleton-refined. The residual binder is refined to `Some`, so its local accessor is allowed. A broader residual set grants only the surface justified for that set. | Sections 4 and 5 |
| Join branches returning `None` and `Some` at the same instantiation; reorder the branches. | Invariant arguments unify and only outer constructor sets are unioned, without order bias. Incompatible results fail; unrelated conforming families do not infer a protocol result unless context supplies it. | Sections 4 and 5 |
| Pass a refined occurrence through each loss point: declared method result, factory result, source annotation, general function parameter/result, family-typed payload, generic container, protocol conversion, and reflective unwrapping. | The earlier singleton does not escape that boundary. Ordinary family views require case analysis for multi-constructor locals; protocol views expose only protocol rows. The actual value retains its family, arguments, constructor, and payload. | Sections 5, 7, 10, 14, and 15 |
| Evaluate a case on an unrefined concrete family, with every branch well typed and effects or other distinguishing behavior available through permitted operations. | The scrutinee is evaluated once and exactly one branch executes; payload bindings follow declaration order. An ill-typed unselected branch is rejected statically and is not a valid laziness demonstration. | Sections 1, 4, 9, and 15 |
| For a non-generic family `Choice` with nullary constructors `A`, `B`, `C` declared in that order and an unrefined scrutinee, write only a `C` clause. Separately case-analyze a singleton-known `Some` while also writing a `None` clause. | The first reports missing `A`, then `B`; the second rejects an impossible clause. Correct exhaustive clauses and a final nonempty-residual default remain valid. | Sections 3–5 |
| Use a closed family with two nullary constructors, `Known` and `Other`, and an unrefined scrutinee. | Explicit clauses for both are exhaustive. A `Known` clause plus final `else` covers residual `Other`, but `Other` itself is never a default marker. Empty-residual or misplaced defaults are rejected. | Section 4 |
| Edit an owning family declaration to add a constructor, then recheck consumers, body tables, and conformance. | Previously exhaustive consumers without `else` and complete per-constructor tables need the new case. Conformance is revalidated. Consumers with a still-valid residual `else` opt out of missing-case diagnostics. This is source declaration growth, not runtime constructor extension. | Sections 3, 4, 7, and 9 |

### Open protocols, extensions, and transactions

| Scenario and context | Required observation | Governing rules |
| --- | --- | --- |
| Declare a family conforming to multiple protocols with compatible requirements, including identical required signatures. | Whole-family rows cover the full required domains; one row may satisfy identical requirements. Narrow-only coverage or incompatible obligations at the same parameter shape fail. | Sections 7 and 9 |
| Call through a broader protocol row while the concrete family has a narrower applicable overload. | Concrete dynamic specificity remains useful, and the selected result is usable as the statically promised result. An incoherent narrower result is rejected during combined validation. | Sections 7, 9, and 10 |
| Let declaration bodies call other rows in the same declaration; let rows within one extension call one another. Supply a required conformance row by a later allowed extension in the same complete loaded unit. | Signatures are installed before their bodies are checked; the combined extension is coherent; conformance is finalized over the complete source unit. This does not permit replacement rows, local additions, or orphan claims. | Sections 7–9 |
| Add a new nominal family explicitly conforming to an existing protocol; separately amend the protocol by adding a requirement. | The new family is permitted without modifying the protocol. The new requirement rechecks existing conformers, rejecting those without compatible coverage. | Section 7 |
| Cause a static failure in a declaration, in one row of a combined extension, or in a transitive load; observe the live driver state and permitted effects. | No partial static state commits and no evaluation begins for the failed transaction. A loaded unit includes its transitive loads; a REPL datum is its own smaller transaction. | Sections 7–9 |
| Successfully check a unit, execute a guarded host operation, then fail at a later runtime obligation or result check. Separately attempt an injection whose name is bound on either driver side. | Runtime effects are not rolled back. Injection preflight leaves existing bindings intact and installs no partial new pair. These observations test different guarantees. | Sections 9, 14, and 15 |

### Recursive values, equality, display, and reflection

| Scenario and context | Required observation | Governing rules |
| --- | --- | --- |
| Use regular `Tree T` payload references directly and beneath existing `List` or function types; build finite recursive data. | The current family is available at full arity with the same ordered parameters. Reordered, changed, mutual, or unresolved forward references fail; no positivity or termination proof is required. | Sections 6, 9, and 10 |
| Compare separately allocated equal `Point` or `Some` data at one exact instantiation, then unequal same-typed family data. | Kernel equality follows exact nominal structure independently of allocation and user `=`. Source `check` returns the right-hand value for equality and reports both datums and values for unequal same-typed operands. | Sections 1, 12, and 18 |
| Compare `None` at `(Option Int)` and `(Option String)` in trusted internal runtime comparison; separately submit differently typed operands to source `check`. | Kernel comparison returns unequal because the arguments differ. Source `check` rejects incompatible operand types before evaluation; the internal observation does not license that source comparison. | Sections 5, 11, and 12 |
| Distinct nominal declarations have identical names/layouts, or a permitted payload contains an opaque function/capability. | Matching descriptions do not imply family equality or owner compatibility. Opaque leaves retain their specified identity semantics; host state is neither structurally compared nor exposed. These observations need no new module, serialization, or identity-token facility. | Sections 10–12 and 15 |
| Render `(Point Int)` with coordinates `1`, `2`; `(Option Int)` values `None` and `Some 1`; and a `(Tree Int)` branch of leaves `1`, `2`. Separately use an applicable whole-family `show`, including one that fails or recurses at runtime. | Raw forms stay `#<Point 1 2>`, `#<Option.None>`, `#<Option.Some 1>`, and the specified nested `Tree` form. Exact type context can appear separately. Raw remains independent of `show`; text parsing produces no refinement or missing-case diagnostics. | Sections 13 and 14 |
| Reflect one-constructor `Point`, both constructors of `(Option Int)`, the `Option` type object, and a family value viewed through a protocol. | `Point` locals/accessors remain visible; `Option` instance locals stay absent even inside a refined branch. The type object exposes constructors/factories with roles and generics. A protocol view reflects the actual family's permitted public surface; per-constructor bodies yield one row per overload. | Sections 14 and 16 |
| Inspect instance `map` metadata and a type-object generic row; enumerate overloads and allowed extension rows in a finalized image. | Fixed family arguments are substituted, fresh row-local variables remain descriptive, and constructor/factory generic order is preserved. Enumeration follows declaration/textual/finalized-definition order; messages deduplicate first occurrences. New rows may move menu positions without changing exact row authority. | Sections 9 and 14 |
| Use one `(Option Int)` family-row signature on another constructor at the same instantiation, then attempt a different instantiation or unrelated same-named owner. Invoke with mismatched arguments or result obligations as well. | The first use succeeds; owner, argument, and contextual-result mismatches are guarded as specified. Invocation executes the chosen descriptor without selector redispatch. Multi-constructor locals cannot be obtained as an escaping capability. | Sections 11 and 14 |
| Keep a `None` constructor row hidden in a `Signature` variable and supply a checked `(Option Int)` result expectation; separately leave required generic evidence absent. | Context may resolve the nullary construction under the exact selected row. Missing evidence is rejected without runtime payload/result reconstruction. Contextual `subject` is checked and forgets earlier refinement. | Sections 8, 11, and 14 |
| Ask the generic `Result` type object's `Ok` row to accept a mirror of `1`. Separately query an integer receiver's `+` row with a mirrored `String`, and a zero-argument row with a valid mirror. | The generic query returns `#t`, solving input `T = Int` but not result-only `E` or specializing the signature. Invocation still needs sufficient context. The incompatible and non-one-parameter queries return `#f`, without invocation or refinement. | Section 14 |

### Mirrored invocation and Gel inference closure

These obligations cover the user-approved U1 amendment in sections 8, 14–16.
They describe future validation, not executable checkpoint-89F tests.

| Scenario and context | Required observation | Governing rules |
| --- | --- | --- |
| Check all three proposed Gel helper bodies in section 16 and their unchanged zero-argument, plain-argument, and mirrored-argument call sites. | No source inference variable escapes. The fixed parameter supplies `(List Mirror)` context to `List empty`; both direct helpers return `Mirror` and select the Mirror `push` overload. The generic helper wraps its bound `T` argument and delegates to the Mirror overload. | Sections 8, 14, and 16 |
| Invoke an ordinary-result row, then a row whose declared and actual result is already a Mirror. Separately return an invalid value for the fully instantiated result type. | Validate the ordinary result first. Wrap a valid non-Mirror result once; return an already-Mirror result unchanged. Invalid results fail after execution, before adaptation; prior effects are not rolled back. | Sections 11 and 14 |
| Supply a list element that mirrors a subject; separately supply `(Mirror of existing-mirror)` to a row expecting a Mirror object. | Unwrap each list element exactly once. The first passes the subject; the second passes the existing Mirror object. No recursive unwrapping or flattening occurs. | Section 14 |
| Evaluate receiver, signature, and argument-list expressions with permitted observable effects; supply lists of correct and incorrect target arity, including empty lists for nullary rows. | The three expressions evaluate once in ordinary send order. The API has two arguments regardless of the selected row's arity; the list length must equal that row's ordinary arity. Arity failure prevents selected-row execution. | Sections 1 and 14 |
| Invoke a row on an exact `(Option Int)` owner and invoke its generic `map` with a mirrored, checked `(-> Int String)` function. Invoke `Option.Some` with a mirror of `1` in a separate call. | Owner `Int` remains fixed. `map` resolves fresh `U = String` before calling the function; `Some` resolves fresh `T = Int` before construction. Neither invocation mutates the signature or shares inference variables with later calls. | Sections 5, 11, 14, and 16 |
| Pass a mirror of an already checked empty `(List Int)` to the `Option.Some` row. Separately use the checked function argument to `map` above. | Sealed evidence gives `T = (List Int)` even with no elements to inspect, and the arrow gives the map result type without executing the function. List element and function types are preserved, not reconstructed from contents or behavior. | Sections 14–16 |
| Invoke `Option.None` with an empty mirror list, `Result.Ok` with a mirror of `1`, or a factory whose fresh parameter occurs only in its result. Separately construct `(Option None (type Int))` ordinarily and mirror it. | The first three fail before any selected body or constructor runs because `T`, `E`, or the result-only parameter remains unresolved. `Result.Ok accepts?` may still return `#t`. Expected `Mirror` adds no missing evidence; no type header is forwarded to the selected row. The explicit ordinary construction succeeds. | Sections 5, 8, 14, and 16 |
| Use a value through a protocol view; separately pass invariantly incompatible family/list arguments to a fixed parameter, or use a row from another exact nominal owner. | Reflection uses the subject's actual permitted nominal surface. Existing invariant list elements and arrow types stay fixed; same names or descriptive metadata confer no compatibility. Owner and argument mismatches prevent execution. | Sections 11, 14, and 15 |
| Introduce malformed foreign subjects, invalid sealed evidence, or forged row authority at existing internal defensive boundaries. | Mirrors cannot bless malformed values. Missing evidence, incompatible arguments, and wrong authority fail before the row runs, without public descriptor constructors, a type-query API, or a new testing hook. | Sections 11, 14, and 19 |
| Leave an ordinary `subject` or ordinary-result `invoke` unconstrained, even inside `Mirror of`; contrast the closed `invoke-mirrored` helpers. | Ordinary source closure still rejects the unresolved intermediate. Only the explicit operation resolves its selected row inside the sealed boundary; no source-visible unknown type escapes. | Sections 8, 14, and 16 |
| Inspect the Mirror instance API and an ordinary mirrored subject; inspect multi-constructor family values inside and outside refined branches. | The appended `invoke-mirrored` row has params `(Signature (List Mirror))`, return `Mirror`, type-params `()`, and role `operation`. Existing Mirror API rows keep their order. Ordinary subject menus gain no row; explicitly browsing Mirror objects shows the intentional addition. Multi-constructor locals remain absent. | Sections 14 and 16 |
| Invoke typed host rows through `invoke-mirrored`, comparing direct and ordinary reflective calls with the same owner, state, scalar arguments, results, failures, and breaks. | All routes retain exact ownership, `Int`/`Bool`/`String` crossings, string immutability, target receiver state, failure causes, and break propagation. The Mirror result wrapper expands no host crossing or capability authority. | Sections 14 and 15 |

### Preserved expression and host behavior

| Scenario and context | Required observation | Governing rules |
| --- | --- | --- |
| Bind a source name matching a selector; use ordinary sends, `fn` through `call`, and parallel `let`. Exercise lazy `if`/`cond` with well-typed branches. | Selectors remain literal, functions run only through `call`, binding right-hand sides use the outer environment, and exactly the selected conditional branch executes. `(f x)` is a send of `x`, not function application. | Sections 1 and 15 |
| Use same-kind numeric operands, explicit `(n float)`, invariant homogeneous lists, contextual empty lists, and the existing `List` methods/extension route. | Existing arithmetic and library results are preserved; mixed numeric/list types, invalid collection operations, and escaped inference variables fail. `map`/`fold` callbacks use `call`, and no stored constructor refinement or runtime type fallback is introduced. | Sections 1, 5, 8, and 15 |
| Declare valid fixed-shape host methods; try duplicate selectors, unsupported crossing types, or optional/variadic/keyword implementation shapes. Explicitly inject a valid receiver into a fresh driver. | Invalid declarations are rejected. The valid binding installs matching runtime/checker identity once, while default environments still have no optional capability. | Section 15 |
| Share a host signature between receivers of the same exact interface, then between distinct same-named interfaces; compare direct and reflective sends. | The shared-interface target uses its own state. The unrelated owner is rejected. Both invocation routes retain the same argument/result/failure guards and sealed public boundary. | Sections 14 and 15 |
| Supply a bad crossing argument, return a bad crossing result, pass mutable strings across the boundary, raise an implementation failure, and propagate a break. | Bad arguments prevent execution; bad results are rejected after execution. Strings become immutable in both directions. Failures retain Aloe context and their original Racket cause; breaks pass through. No broader crossing type is admitted. | Section 15 |
| Invoke the existing Term `write-line` through explicit checked injection. Carry an injected receiver in a family payload where ordinary typing permits. | Term emits the string and CRLF, flushes, and returns the string. The payload may bind an opaque leaf but grants no host-state inspection or new host method argument/result vocabulary. | Sections 10 and 15 |

Defensive malformed-value and forged-authority coverage belongs at the
existing internal validation boundaries, not in invented Aloe construction
syntax. Each future scenario must supply well-typed branch bodies and enough
expected-type/refinement context to establish its intended observation.
Coverage of these scenarios checks this catalogue; it is not the final
whole-candidate Decision 1–10 consistency audit, which is recorded separately
in the [89F design audit](unified-nominal-adts-design-audit.md).

## 22. Application validation and eventual completion evidence

Future completion requires application evidence as well as isolated semantic
scenarios. These obligations do not authorize building or migrating the
applications in checkpoints 89E or 89F.

| Application | Required future evidence | Governing rules |
| --- | --- | --- |
| `Point` | Explicit product construction, fields, methods, equality, raw display, and sole-constructor local reflection. | Sections 3, 10–14, and 16 |
| Boids | Nested generics, immutable products, lists, numeric sends, explicit conversion, and both `(demo step)` sends producing the expected `Sim` results. | Sections 1, 3, 5, 10, and 15 |
| MPL | Open `Math`, additive operations, overload specificity and return coherence, ordinary domain equality, and `show` without changing trusted kernel comparison. | Sections 7, 9, and 12–15 |
| `Option` | Nullary/unary generics, contextual and explicit construction, factories, exhaustive consumers, and reflection. | Sections 3–5, 8, 14, and 16 |
| `Result` | Two independent parameters, constraints across alternatives, and insufficient-context rejection. | Sections 4, 5, 8, and 16 |
| `Tree` | Regular recursion, recursive payloads and methods, equality, printing, and nested case expressions. | Sections 4, 6, 9–13, and 16 |
| Filesystem model | Closed classification with ordinary `Other`, local capabilities, defaults, and exhaustive consumers. This supplies no OS capability API or expanded host crossing. | Sections 3, 4, 7, and 15 |
| Gel | Useful exact reflection through all three `invoke-mirrored` helper paths while pending/state representations use families where specified; existing valid flows, results, keys, and emitted text are preserved except for the intentional Mirror instance API menu addition. | Sections 5, 14–16, and 21 |
| Term and host tests | Exact interface ownership, explicit injection, guarded direct/reflected invocation, unchanged Term output, and the sealed public boundary. | Sections 14 and 15 |

During later implementation, Gel's pending sentinel list is to become
`Option GelRow`. A further application state family is conditional on making
the application clearer; no state schema is chosen here. Application call sites
remain unchanged under the section 16 helper rewrites. Existing valid-flow keys
and emitted text remain unchanged except that explicitly browsing a Mirror
object shows its appended `invoke-mirrored` row. That approved API addition
does not imply that extended introspection output is byte-for-byte identical
or that every generic row can execute without sufficient sealed input evidence.
Filesystem coverage tests the closed/open semantic boundaries without selecting host selectors,
marshalling, or a new capability design.

Eventual completion must establish that the migrated historical suite and
these application scenarios pass; evaluation carries all required checked
static information; exact nominal, reflective, and host guarantees hold; and
the temporary legacy bridge and dual user nominal model are gone. The
completed source language has only `define-family` for user nominal data and
rejects legacy `define-class`. Built-in algebraic rewrites remain optional.
Normative acceptance into `SPEC.md` still requires later atomic ratification.
None of this evidence is claimed to have been achieved by this catalogue or
by a passing regression suite for the unchanged checkpoint-88 implementation.

Future implementation slices must preserve the approved boundaries and reject
unavailable behavior rather than approximate it with name-based identity,
partial case, reflected locals, or unresolved construction. This records
validation obligations, not detailed checkpoint instructions, future test
filenames, algorithms, or a handoff. The sequence is recorded separately in
the [accepted corrected 89G roadmap](unified-nominal-adts-implementation-roadmap.md).
The [89H handoff](unified-nominal-adts-implementation-handoff.md) is drafted
for review; final reconciliation and atomic ratification remain later work.
The completed whole-candidate audit is recorded in the
[89F report](unified-nominal-adts-design-audit.md).

## Pending completion

89F's audit and U1 resolution, the corrected 89G plan, and 89H's handoff are
accepted inputs. The complete target and 25-entry sequence are promoted in
the **89I ratification change submitted for review**. This is the remaining
review boundary for checkpoint 89; no further unspecified 89-series artifact
is needed to supply the same ratification. Implementation and its final
documentation seal remain future work. A passing checkpoint-88 suite proves
preservation, not implementation of the target.

### Promotion map

Section numbers remain aligned. The normative text uses the approved rules
and replaces stage-specific candidate wording; the preserved text above stays
available for comparison. Sources are this candidate and `SPEC.md` at
`616c0ceecd7d52d7f9c3e2c4df89e9037ed57aaa`; no new semantic decision is introduced.

| Candidate section | Normative location and disposition |
| --- | --- |
| [1. Preserved expression model](#1-preserved-expression-model) | [SPEC §1](../SPEC.md#1-preserved-expression-model) — preserved expression rules plus existing form details |
| [2. One nominal family ontology](#2-one-nominal-family-ontology) | [SPEC §2](../SPEC.md#2-one-nominal-family-ontology) — approved rules and obligations promoted |
| [3. Family declarations and callable surfaces](#3-family-declarations-and-callable-surfaces) | [SPEC §3](../SPEC.md#3-family-declarations-and-callable-surfaces) — approved rules and obligations promoted |
| [4. Exhaustive receiver-anchored `case`](#4-exhaustive-receiver-anchored-case) | [SPEC §4](../SPEC.md#4-exhaustive-receiver-anchored-case) — approved rules and obligations promoted |
| [5. Types, generic inference, and constructor refinements](#5-types-generic-inference-and-constructor-refinements) | [SPEC §5](../SPEC.md#5-types-generic-inference-and-constructor-refinements) — approved rules and obligations promoted |
| [6. Direct regular recursion](#6-direct-regular-recursion) | [SPEC §6](../SPEC.md#6-direct-regular-recursion) — approved rules and obligations promoted |
| [7. Protocols and additive extensions](#7-protocols-and-additive-extensions) | [SPEC §7](../SPEC.md#7-protocols-and-additive-extensions) — conformance/extensions plus preserved protocol declaration signatures |
| [8. Checked programs and elaboration](#8-checked-programs-and-elaboration) | [SPEC §8](../SPEC.md#8-checked-programs-and-elaboration) — approved rules and obligations promoted |
| [9. Shared descriptors, linking, and transactions](#9-shared-descriptors-linking-and-transactions) | [SPEC §9](../SPEC.md#9-shared-descriptors-linking-and-transactions) — approved rules and obligations promoted |
| [10. Runtime family values and dispatch](#10-runtime-family-values-and-dispatch) | [SPEC §10](../SPEC.md#10-runtime-family-values-and-dispatch) — approved rules and obligations promoted |
| [11. Central runtime type relation and constructor integrity](#11-central-runtime-type-relation-and-constructor-integrity) | [SPEC §11](../SPEC.md#11-central-runtime-type-relation-and-constructor-integrity) — approved rules and obligations promoted |
| [12. Kernel equality](#12-kernel-equality) | [SPEC §12](../SPEC.md#12-kernel-equality) — approved rules and obligations promoted |
| [13. Raw and user-facing display](#13-raw-and-user-facing-display) | [SPEC §13](../SPEC.md#13-raw-and-user-facing-display) — approved rules and obligations promoted |
| [14. Family-aware reflection](#14-family-aware-reflection) | [SPEC §14](../SPEC.md#14-family-aware-reflection) — approved rules and obligations promoted |
| [15. Specialized built-ins and typed host integration](#15-specialized-built-ins-and-typed-host-integration) | [SPEC §15](../SPEC.md#15-specialized-built-ins-and-typed-host-integration) — integration plus explicit preserved numeric/List/Symbol operation details |
| [16. Candidate examples](#16-candidate-examples) | [SPEC §16](../SPEC.md#16-target-examples) — all examples, including U1 before/after helpers; target and baseline labels clarified |
| [17. Reconciliation and compatibility boundary](#17-reconciliation-and-compatibility-boundary) | [SPEC §17](../SPEC.md#17-reconciliation-and-compatibility-boundary) — completed-source boundary and the accepted temporary-bridge schedule |
| [18. Diagnostics and detection boundaries](#18-diagnostics-and-detection-boundaries) | [SPEC §18](../SPEC.md#18-diagnostics-and-detection-boundaries) — approved rules and obligations promoted |
| [19. Required rejection catalogue](#19-required-rejection-catalogue) | [SPEC §19](../SPEC.md#19-required-rejection-catalogue) — approved rules and obligations promoted |
| [20. Consolidated exclusions and deferrals](#20-consolidated-exclusions-and-deferrals) | [SPEC §20](../SPEC.md#20-consolidated-exclusions-and-deferrals) — approved rules and obligations promoted |
| [21. Semantic validation obligations](#21-semantic-validation-obligations) | [SPEC §21](../SPEC.md#21-semantic-validation-obligations) — approved rules and obligations promoted |
| [22. Application validation and eventual completion evidence](#22-application-validation-and-eventual-completion-evidence) | [SPEC §22](../SPEC.md#22-application-validation-and-eventual-completion-evidence) — all application/completion obligations plus preserved Point/Boids observations |

The preserved and superseded material from the pre-ratification `SPEC.md` is
accounted for separately; historical bare section numbers retain that meaning.

| Old SPEC material | Disposition in the normative target |
| --- | --- |
| Introduction and §§1–2: reader, atoms, sends, literal selectors, `self`, capitalization | [§1](../SPEC.md#1-preserved-expression-model) and [§3 callable surfaces](../SPEC.md#local-and-whole-family-methods) retain the expression contracts; class-specific dispatch is replaced by the family surfaces in [§10](../SPEC.md#10-runtime-family-values-and-dispatch). Branch-specific/version-experiment authority is superseded by one target/status note. |
| §§3.1–3.2, 4.5: classes, fields, construction | Replaced deliberately by [§§2–3](../SPEC.md#2-one-nominal-family-ontology) and [§17](../SPEC.md#17-reconciliation-and-compatibility-boundary): explicit constructors and constructor-owned fields, no generated `new` or permanent class syntax. |
| §§3.3–3.4, 4.8: protocol signatures/markers and overloads | [§7](../SPEC.md#7-protocols-and-additive-extensions) retains declarations and receiver-anchored specificity; positional single claims are superseded by multiple uniform family `conforms`, full-domain/coherence checks, and exact identity. |
| §§4.1–4.4, 4.7, 4.9: define, optional fn annotations, call, parallel let, lazy if, one-expression bodies, check | [§1 preserved forms](../SPEC.md#preserved-syntax-and-forms) retains the detailed contracts, with [§8](../SPEC.md#8-checked-programs-and-elaboration) closure/provenance and [§12](../SPEC.md#12-kernel-equality) trusted equality. The old `42-fn` anchor remains meaningful. |
| §4.6 and §6: List extension route and operations | [§15](../SPEC.md#numeric-and-list-operation-reference) retains messages, callback `call`, library ownership and `T` scope; [closure](../SPEC.md#inference-closure-and-source-aliases) replaces permissive unresolved empties. |
| §5: types, generics, checking | [§5](../SPEC.md#5-types-generic-inference-and-constructor-refinements) and [§8](../SPEC.md#8-checked-programs-and-elaboration) retain invariance, annotation/arrow checking, numeric separation and no constraint syntax; add approved complete headers, enclosing constraints, refinements and closure. Family construction receives checked arguments. |
| §§7–7.2 and §11: numeric/Bool/String/Symbol and display contracts | [§15 operation reference](../SPEC.md#numeric-and-list-operation-reference), [§1 conditionals](../SPEC.md#if-and-cond), and [§13 display](../SPEC.md#13-raw-and-user-facing-display) retain explicit conversion, laziness, interned names and `show`/`:raw` separation. |
| §§7.3–7.4 and §12: Mirror/Signature | [§14](../SPEC.md#14-family-aware-reflection) preserves the APIs with closed contextual obligations and exact rows, adds approved roles/generics and U1, and hides multi-constructor locals. All [Gel/generic examples](../SPEC.md#gel-invocation-through-mirrors) remain explicit. |
| §8: exclusions | [§20](../SPEC.md#20-consolidated-exclusions-and-deferrals) preserves unaffected exclusions; required protocol signatures and multiple conformances are intentionally included. |
| §9: Point/Boids goldens and five type errors | [§22 preserved observations](../SPEC.md#preserved-point-and-boids-observations) retains every observation under its stated complete definitions/type context; current sources remain checkpoint-88 programs until migration. |
| §10: interpreter sketch and early let lowering | [§8](../SPEC.md#required-pipeline) retains the Racket interpreter/checker and prohibition on elaborating object sends into Racket evaluation; checked elaboration and alias provenance replace the raw sketch and early loss of `let`. |
| §11: load and cond | [§1](../SPEC.md#preserved-syntax-and-forms) retains shared environment, relative path order and required final `else`; [§9](../SPEC.md#transactional-checking-and-evaluation) finalizes transitive loads atomically before evaluation. |
| §13: complete typed-host boundary | [§15 host declarations](../SPEC.md#host-declarations-and-scalar-crossings) and [injection/sealing](../SPEC.md#injection-ownership-and-opaque-composition) retain the exact interface, paired preflight, limited crossings, immutable strings, causes, breaks, and sealed public/internal boundary. |

The [index](../CHECKPOINTS.md#future-family-implementation) preserves 90B's
checked contextual MPL observations, 91C's atomic U1/helpers/closure work,
103C's bridge removal, and all later application owners. Review of 89I is
pending; no runtime change, test migration, commit, or next checkpoint is part
of this promotion.
