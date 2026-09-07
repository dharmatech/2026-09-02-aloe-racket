# Unified nominal algebraic families: specification candidate

> **STATUS — INCOMPLETE AND NON-NORMATIVE**
>
> This document authorizes no language, checker, evaluator, runtime, library,
> application, or compatibility change. `SPEC.md` remains law and is the
> governing Aloe specification. Checkpoint 89A covers only the proposed
> language surface and
> static semantics. Later 89-series checkpoints must complete and audit the
> candidate, then atomically ratify it or reject it. Until that happens, none
> of the syntax below is implemented or normative.

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
classification, and affected protocol obligations are validated before any of
the rows commit. A failed extension commits none of them.

An external whole-family method that needs constructor knowledge uses the
ordinary exhaustive case expression on `self`; extensions cannot add
constructor-indexed body tables.

## 8. Candidate examples

These examples illustrate the candidate syntax. They are not checkpoint-89A
goldens and are not accepted by the current implementation.

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

## 9. Reconciliation with the current specification

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

`define-class` is not a permanent alias in the candidate. Retaining both forms
would retain two apparent nominal ontologies. No migration bridge is specified
or authorized by checkpoint 89A.

The candidate preserves all unaffected expression behavior, including literal
selectors, `fn` through `call`, parallel `let`, lazy `if` and `cond`, `load`,
`check`, homogeneous invariant `List`, explicit numeric conversion, existing
primitive types, and the separation between protocol types and runtime method
tables. It does not carry forward contradictory rules for generated `new`,
class-level fields, one positional conformance, or constructors inferred from
class layout.

## Pending completion

> **INTENTIONALLY UNSPECIFIED IN CHECKPOINT 89A**

The candidate is incomplete. Later linked 89-series work must specify, audit,
and reconcile all of the following before the proposal can be ratified or
implemented:

- linked checking and checked elaboration;
- runtime representation and dispatch;
- kernel equality;
- raw structural printing and user-facing display;
- reflection and exact signature behavior;
- the relationship of built-ins to the family model;
- typed host-capability integration;
- the complete diagnostic and exclusion catalogue; and
- the final whole-specification reconciliation audit.

This section reserves those subjects; it does not draft them. Nothing in this
candidate authorizes checkpoint 89B, implementation work, migration, parser
acceptance, or changes to the behavior complete through checkpoint 88.
