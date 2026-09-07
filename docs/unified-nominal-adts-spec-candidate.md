# Unified nominal algebraic families: specification candidate

> **STATUS — INCOMPLETE AND NON-NORMATIVE**
>
> This document authorizes no language, checker, evaluator, runtime, library,
> application, or compatibility change. `SPEC.md` remains law and is the
> governing Aloe specification. Checkpoints 89A–89C cover only the proposed
> language and static model, checked execution and runtime-value model, and
> family-aware reflection. Later 89-series checkpoints must complete and audit
> the remaining subjects, then atomically ratify the candidate or reject it. The
> proposed family additions remain unimplemented and non-normative; runtime
> behavior remains exactly as implemented through checkpoint 88.

This candidate describes one proposed replacement for Aloe's user-defined
nominal class model. It unifies one-constructor products and closed variants as
nominal algebraic *families* while preserving Aloe's receiver-first expression
model and its open, nominal protocols.

The words “must,” “may,” and “reject” below state rules of the candidate, not
rules that the current implementation accepts.

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
- `type` is special only as the head of a list immediately following a send's
  selector. That complete list is static metadata and cannot simultaneously be
  the send's first runtime argument. `type` is not otherwise made a global
  special form or a globally reserved selector.

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
send explicitly:

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
ordinary receiver-first shape:

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

For example:

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
(point map (type String) formatter)
```

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

Every recursive occurrence of a generic family must use the current family's
parameters at full arity, in the same order:

```aloe
(Tree T)
```

The occurrence may appear beneath an ordinary container or function type, for
example `(List (Tree T))` or `(-> (Tree T) (Tree T))`. A non-generic family
refers to itself by its bare family type name.

The checker rejects nonregular or polymorphic recursion such as
`(Tree (List T))`, reordered parameters, missing or additional parameters,
mutual recursion, and references to unresolved forward families.

This rule does not add positivity checking, termination checking, GADTs,
existentials, mutual declaration groups, or a claim that Aloe supplies a full
inductive type theory. It specifies only direct regular recursion for nominal
algebraic families.

## 7. Protocols and additive extensions

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
payloads. In particular, the runtime type arguments of a parameterless
constructor come from the checked send, where context or an explicit header
resolved them.

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
generic instantiation. Generic arguments are resolved at checked send sites
and stored in the constructed value. A `None` at `(Option Int)` and a `None` at
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
selected overload arguments and results, and the reflective boundaries in
section 14. Specialized built-ins and typed host integration remain pending;
their later specifications must use this relation at host crossings and other
dynamic boundaries rather than introduce parallel compatibility rules.

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
not to every ordinary value. The existing vocabulary retains these roles:

| Operation | Result and role |
| --- | --- |
| `(Mirror of value)` | A `Mirror` of any Aloe value. |
| `(mirror messages)` | The unique callable selectors as a `(List Symbol)`. |
| `(mirror signatures)` | One opaque `Signature` per public overload row, as a `(List Signature)`. |
| `(mirror invoke signature argument ...)` | The ordinary result of invoking that exact owned row, with the checks below. |
| `(mirror subject)` | The original ordinary value, under contextual typing and runtime validation. |
| `(mirror raw)` | A `String` from the structural renderer in section 13. |
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
`accepts?`, exact `invoke`, contextual `subject`, and structural `raw`.
Reflecting an existing mirror's subject and explicitly reflecting a mirror
itself remain distinct. MPL retains reflection of the concrete family's
public surface through a protocol view, subject to the multi-constructor
local exclusion. Host reflection retains exact interface ownership and the
ordinary guarded invocation boundary with the target receiver's state.

Primitive and host rows here are preservation constraints only. Specialized
built-in and typed host integration remain later work; this section specifies
no adapter internals, new built-in schema, additional crossing types, or Gel
redesign.

## 15. Candidate examples

These examples illustrate the candidate syntax and reflection contract. They
are not checkpoint-89A, 89B, or 89C goldens and are not accepted by the current
implementation.

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

## 16. Reconciliation and compatibility boundary

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
checkpoint. Checkpoints 89A–89C add and authorize no bridge or implementation
scaffold.

The candidate preserves all unaffected expression behavior, including literal
selectors, `fn` through `call`, parallel `let`, lazy `if` and `cond`, `load`,
`check`, homogeneous invariant `List`, explicit numeric conversion, existing
primitive types, and the separation between protocol types and runtime method
tables. It does not carry forward contradictory rules for generated `new`,
class-level fields, one positional conformance, or constructors inferred from
class layout.

## Pending completion

> **INTENTIONALLY UNSPECIFIED AFTER CHECKPOINT 89C**

The candidate is incomplete. Later linked 89-series work must specify, audit,
and reconcile all of the following before the proposal can be ratified or
implemented:

- specialized built-ins and typed host-capability integration;
- the complete diagnostic, exclusion, and validation catalogue;
- the final whole-candidate Decision 1–10 audit;
- the implementation roadmap and durable handoff; and
- atomic ratification into `SPEC.md`.

This section reserves those subjects; it does not draft them. Nothing in this
candidate authorizes the next 89-series checkpoint, implementation work,
migration, parser acceptance, or changes to the behavior complete through
checkpoint 88.
