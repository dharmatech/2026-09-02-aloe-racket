# Checkpoint 0089 — Ratify unified nominal algebraic families

Status: Proposed

Depends on: Checkpoint 0088

## Goal

Ratify the approved unified nominal algebraic family design as Aloe's next
normative language contract before any part of that design is implemented.

This is a documentation-only checkpoint. It must:

- rewrite `SPEC.md` into one coherent normative account of the approved
  language;
- extend `CHECKPOINTS.md` with the approved implementation sequence beginning
  at checkpoint 89; and
- update `docs/handoff.md` into the durable, self-contained implementation
  handoff and status record for checkpoints 90–106.

It must not change parsing, checking, evaluation, runtime values, dispatch,
reflection, host behavior, application behavior, or any Aloe program. The
repository must still implement exactly the checkpoint-88 language when this
checkpoint stops for review.

## Sources of authority and the ratification transition

Before this checkpoint is accepted:

1. `SPEC.md` is the normative language specification.
2. `archive/unified-nominal-adts.md` is the comprehensive approved design
   draft through Decisions 1–10, but it is provisional and non-normative.
3. `CHECKPOINTS.md` records the implemented history through checkpoint 88.
4. `docs/handoff.md` records the current implementation and working rules.

Use `archive/unified-nominal-adts.md` as the design source for this
ratification. Rewrite its accepted semantics as specification language; do not
merely link to it, append it verbatim, or make future readers reconstruct the
language from ten decision narratives.

The discussion transcripts preserved in Git commit `8e6955c` are historical
and non-normative. Do not read, restore, quote, or add them to the working tree
during this checkpoint. If the consolidated archive contains a contradiction
or an unresolved choice that would materially alter the language, stop and
report the exact ambiguity instead of consulting the transcripts by default or
inventing a rule. Transcript consultation requires an explicit explanation of
why `SPEC.md`, `CHECKPOINTS.md`, the consolidated archive, and the repository
could not resolve that ambiguity.

After this checkpoint is reviewed and accepted:

1. the revised `SPEC.md` is normative for the unified nominal algebraic family
   language;
2. `CHECKPOINTS.md` is authoritative for implementation order and staging;
3. `docs/handoff.md` is the non-normative operational status record for future
   checkpoint tasks; and
4. `archive/unified-nominal-adts.md` remains non-normative historical design
   provenance.

State that transition explicitly in both the specification front matter and
the handoff. The normative specification will intentionally be ahead of the
implementation after checkpoint 89. The handoff must distinguish a specified
destination from currently implemented behavior, and implementation
checkpoints must continue rejecting later syntax until the checkpoint that
introduces it.

## Expected file scope

The checkpoint-89 implementation diff is limited to:

- `SPEC.md`;
- `CHECKPOINTS.md`; and
- `docs/handoff.md`.

Do not edit or delete the archived design. Do not change `README.md`, historical
checkpoint documents, release notes, decisions, philosophy, Gel documentation,
or other prose merely to make every historical use of “class” read as though
the future implementation already existed. Record genuinely stale follow-up
documentation in the handoff for the repository-migration or final-seal
checkpoint.

Do not add a checkpoint test that asserts prose fragments. Existing tests and
the current application smoke checks supply the behavioral regression evidence
for this documentation-only change.

## Normative `SPEC.md` rewrite

Rewrite `SPEC.md` as a cohesive current specification. Do not preserve the
present structure in which the 0.1 language is followed by partially
duplicative 0.2 and 0.3 addition lists. Use a neutral current-language title
unless a release number has been approved separately; this checkpoint must not
invent a version promise.

The front matter must say:

- the document specifies the approved unified-family destination;
- implementation is staged by `CHECKPOINTS.md` and its current progress is in
  `docs/handoff.md`;
- sends remain Aloe's expression model; and
- built-ins and host capabilities may retain specialized implementations while
  obeying their specified observable contracts.

The rewrite may reorganize and renumber sections. It must retain all accepted
existing behavior that the unified design does not replace, and it must cover
the following normative subjects without depending on the archive.

### 1. Expression and evaluation continuity

Preserve these established rules:

- a non-special list has the form `(receiver-expr selector argument-expr ...)`;
- the receiver and arguments are evaluated, the second element is a literal
  selector, and list heads are never implicitly applied;
- functions execute only through the `call` message;
- `let` retains its existing parallel-binding semantics and runtime
  equivalence to an `fn`/`call` send;
- `if`, `cond`, `define`, `fn`, `load`, `check`, and the existing primitive
  sends retain their accepted meanings unless the family design expressly
  refines their static treatment; and
- there is no second general application, send, or evaluation rule.

Specify the two deliberate additions to send-shaped syntax:

- `(receiver case ...)` is the receiver-anchored exhaustive special form; and
- an optional `(type Type ...)` header immediately after a selector is static
  send metadata, not a runtime argument.

Make the reservation boundaries exact: `case` is reserved in second position,
`else` is reserved as the head of a `case` or `cond` clause,
`per-constructor` is recognized only as a whole-family method body mode, and a
post-selector `(type ...)` list is always the static type-argument header.

### 2. Unified nominal ontology

Specify one user-defined nominal data model:

- one `define-family` declaration creates one opaque nominal family identity,
  one ordinary family type object, and a finite nonempty ordered set of opaque
  representation-constructor identities;
- a one-constructor product and a multi-constructor variant are the same kind
  of family;
- a constructor is not a nominal subtype, source type, global binding, or
  first-class function;
- a family value records its family, resolved invariant generic arguments,
  actual constructor, and immutable ordered payload;
- constructor and family names are lookup and presentation labels, not runtime
  identities; and
- protocols are the open operation axis while a family's constructors and
  payload representation remain closed.

Include the complete `define-family` grammar from Decision 9: optional ordered
`conforms`, required `constructors`, optional `factories`, and optional
whole-family `methods` sections. Each constructor has a required `fields`
section, including the empty section for a nullary constructor, and may have a
local `methods` section.

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

Sections occur only in the displayed order. Preserve the existing method-row
grammar for methods and factories, including zero-argument rows and row-local
type parameters:

```text
(selector (parameter Type) ... ReturnType body)
(selector () ReturnType body)
(selector (type U ...) (parameter Type) ... ReturnType body)
```

Make these declaration invariants explicit:

- at least one constructor;
- constructor declaration order is semantic for diagnostics and reflection;
- constructor selectors are unique, not overloaded, and reserved throughout
  the owning family from factories, family methods, local methods, additive
  extensions, `case`, and `else`;
- payload names are unique within a constructor;
- generated payload accessors are constructor-local;
- local overloads may repeat a selector within their allowed overload rules;
- a payload accessor cannot collide with a local method selector in the same
  constructor;
- a local selector may repeat on different constructors without creating a
  family message;
- local and whole-family selector partitions are disjoint; and
- all constructors are public in this language version.

There is no implicitly generated `new`. A product conventionally declares its
sole constructor as `new`, preserving construction such as `(Point new 1 2)`
as an ordinary send to the family type object.

### 3. Construction, factories, and method surfaces

Specify representation constructors as bodyless type-object rows whose result
is their owning family refined to that constructor. Construction is freshly
polymorphic at each send and uses the checked, resolved generic arguments; the
evaluator never infers missing arguments from runtime payloads.

Specify factories as ordinary, possibly overloaded type-object methods with
bodies. In a factory body, `self` is the family type object. A factory can send
constructor or factory messages, but its caller receives only the factory's
declared unrefined result type; factory execution history is not stored in the
value.

Distinguish the two instance operation surfaces:

- whole-family messages are explicitly declared and statically available for
  every value of the family; and
- constructor-local methods and payload accessors are statically available
  only for a singleton-refined receiver, with the sole constructor of a
  one-constructor family always known.

Repeating compatible local rows on every constructor does not infer or promote
a whole-family row.

Specify the two, mutually exclusive body modes for each whole-family overload:

- one uniform expression body, checked with unrefined `self` except in the
  inherently singleton one-constructor case; or
- one declaration-only `per-constructor` table containing exactly one body for
  every constructor, with `self` singleton-refined in each body.

There is no default-plus-override method model. Local methods and factories
cannot use `per-constructor`.

### 4. Additive extensions

Retain `define-methods` as the receiver-owned additive extension form. Specify
its optional `factories` section followed by its optional whole-family
`methods` section, with at least one section present.

```text
ExtensionDeclaration ::=
  (define-methods FamilyName
    FactorySection?
    FamilyMethodSection?)
```

At least one optional section must be present. Empty omitted sections do not
authorize an otherwise empty extension.

An extension may add factory rows, uniform whole-family methods, and compatible
overloads. It may not add or change constructors, payloads, local methods,
per-constructor body tables, conformance claims, or existing exact rows.

The target family's parameters are in scope. All declaration-owned and
extension-owned rows participate in the same finalized overload ambiguity,
selector partition, and return-coherence checks. A staged extension commits no
rows if any part fails.

### 5. Exhaustive `case`

Include the complete flat case grammar from Decision 9:

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

The form has at least one explicit or default clause. Constructor labels are
literal and resolved within the concrete scrutinee family's namespace. The
scrutinee is evaluated exactly once, branches are lazy, and runtime selection
uses opaque constructor identity.

Case analysis is available only for a concrete nominal family with a known
finite possible-constructor set, not directly for a protocol, unconstrained
type variable, family type object, `Mirror`, or reflective description.

For a scrutinee currently refined to possible set `S`, require all of the
following:

- without `else`, the explicit set equals `S` exactly;
- duplicates, unknown constructors, constructors impossible under `S`, and
  wrong payload-binder arities are errors;
- missing constructors are diagnosed in declaration order;
- `else` is final and legal only when its residual set is nonempty;
- a default may bind only the residual-refined whole value and no payloads;
- a constructor named `Other` is an ordinary explicit constructor, unrelated
  to `else`; and
- every reachable branch participates in result checking.

With an expected result type, check every branch against it. Without one,
perform a symmetric, branch-order-independent join: exact types unify,
invariant arguments of the same family unify, and outer family refinements are
unioned. Do not invent a shared protocol result as a least upper bound.

Exclude nested patterns, guards, alternatives, fallthrough, wildcard payload
patterns, and silently partial case analysis.

### 6. Types, generic inference, and refinements

Replace the current example-specific type grammar with a general grammar for
primitive types, `Mirror`, `Signature`, protocols, type variables, arrows,
`List`, and nominal family applications. Constructor names and constructor-set
refinements never appear in source types. Host interface names remain
diagnostic-only and unavailable in source annotations.

Family parameters are invariant. Expected exact family types may choose a
constructor instantiation directly; that is not covariance. Constraints come
from explicit type arguments, exact expected family results, runtime argument
expressions, and the enclosing expression, including sibling case branches.

Specify the explicit send type header exactly:

- for a family type-object send, arguments name all family parameters followed
  by all row-local factory parameters;
- for an instance send, family arguments are fixed by the receiver and the
  header supplies all row-local method parameters;
- the full ordered list is supplied or the header is omitted; there is no
  partial placeholder syntax; and
- a candidate with a different generic arity is inapplicable.

Inference variables may remain temporarily during checking but may not escape
a top-level expression or definition, method or factory body, explicitly typed
function body, or complete program transaction. Consequently a context-free
generic nullary construction such as `(Option None)` is rejected, while
contextual or explicit construction such as `(Option None (type Int))` is
well-defined.

Describe constructor-set refinement as internal shallow flow knowledge kept
separate from nominal type identity. It is introduced by direct constructor
sends, explicit case branches, per-constructor family bodies, and immutable
direct aliases. Case defaults subtract handled constructors and branch joins
union possibilities. Widening to an ordinary family, conversion to a protocol,
declared method and factory results, general function boundaries, generic
storage, family-typed payload positions, source annotations, and reflective
unwrapping forget refinement as specified in the approved design.

An immutable source `define` or `let` alias may preserve the outer refinement
of its direct value. This is a checker fact, not function-argument subtyping;
runtime `let` semantics remain unchanged.

### 7. Direct regular recursion

Specify direct regular self-recursion for families:

- the current family and all constructor identities are registered before its
  payload types and bodies are checked;
- a recursive occurrence uses the same parameters at full arity and in the
  same order;
- it may occur beneath ordinary `List`, family, or function types;
- previously declared families remain available; and
- parameter permutation, nonregular or polymorphic self-recursion, mutual
  recursion, and unresolved forward families are rejected.

Do not add a positivity restriction, termination claim, GADT result equation,
existential constructor parameter, mutual-recursion group, or full inductive
type theory.

### 8. Protocols and overload coherence

Replace the positional single-protocol class syntax with an explicit family
`(conforms ProtocolName ...)` section supporting zero or more protocols. An
empty `conforms` section is invalid.

Conformance is nominal, explicit, attached to the whole family, and uniform
over every generic instantiation. Protocols remain non-generic and own no
runtime method table. Protocol requirements may be satisfied only by
whole-family rows, including rows supplied by allowed extensions before global
finalization; constructors, factories, accessors, local methods, and reflective
operations are not candidates.

Specify compatibility as parameter acceptance over the complete protocol
domain with a result usable as the protocol result. Additional narrower
overloads remain allowed, but every row runtime dispatch may choose in place of
a statically broader row must satisfy return coherence. Exact concrete matches
retain their existing precedence over protocol matches; unresolved ambiguity
is rejected.

A family value may widen to any protocol declared by its family without a
runtime wrapper. Widening forgets constructor refinement. Protocol-typed code
sees only protocol rows and cannot use exhaustive family case directly.

Do not add structural conformance, per-constructor conformance, conditional
generic conformance, orphan conformance, protocol defaults, protocol
inheritance, protocol intersections, or protocol parameters.

### 9. Linked checking and elaboration

Replace the current `parse -> type-of -> interp` implementation note with the
normative staging boundary required by generic nullary constructors:

```text
source
  -> parsed source AST
  -> linked nominal declarations and opaque identities
  -> type checking and elaboration
  -> globally validated checked program
  -> evaluation
```

The checked program carries runtime-relevant decisions, including resolved
family, constructor, and row identities; resolved static type arguments; and
resolved case-clause constructors. Refinements used only for checking need not
be runtime data.

Only a successfully checked and globally finalized unit is evaluated.
Finalization validates conformances, complete per-constructor tables, overload
ambiguity and return coherence, selector classification, extension ownership,
and the absence of unresolved inference variables. A failed declaration,
extension, or source transaction does not partially mutate the static
environment or begin evaluation. Runtime effects after successful checking are
not rolled back.

Describe one linked graph of opaque protocol, family, constructor, and row
identities shared by checking, evaluation, conformance, equality, printing, and
reflection. This is an observable architectural contract, not a requirement to
publish descriptor structs to Aloe.

### 10. Runtime values, dispatch, equality, and printing

Specify the semantic family value as:

```text
<family identity, resolved type arguments, constructor identity, payloads>
```

Values are shallowly immutable structural data and expose no allocation
identity, per-instance behavior table, method closures, factory provenance, or
protocol wrapper. Runtime implementations may optimize representation without
changing those observations.

After overload selection, dispatch uses the selector's disjoint classification:

- constructors and factories are rows of a family type object;
- whole-family selectors use the family row and either its uniform body or the
  body indexed by the actual constructor; and
- local selectors use the actual constructor's table only where the checked
  receiver view permits that surface.

One central nominal runtime relation must cover exact family identity,
invariant type arguments, optional permitted-constructor membership, explicit
protocol conformance, primitives, functions, lists, and host interfaces. Apply
the same relation at constructor payloads, factory results, dynamic overload
arguments and results, reflection, and host boundaries. Names and equal layouts
never establish runtime type compatibility.

Retain kernel, non-overridable equality for `check`. Two family values are
kernel-equal exactly when their family identities, resolved type arguments,
constructor identities, payload arities, and recursively compared payloads
agree. Scalar and algebraic payload leaves retain value equality; functions,
family type objects, host capabilities, and other explicitly opaque values use
their established opaque identity unless their built-in kind already defines
value semantics. A user-defined `=` remains an ordinary domain operation and
does not replace kernel equality.

Specify the exact concise structural forms:

```text
#<Point 1 2>
#<Option.None>
#<Option.Some 1>
#<Tree.Branch #<Tree.Leaf 1> #<Tree.Leaf 2>>
```

One-constructor families omit the redundant constructor label;
multi-constructor families use `Family.Constructor`; payloads retain declaration
order. Raw rendering never invokes Aloe methods and is neither parseable source
nor serialization. Type-aware errors display exact generic instantiations
separately where needed. Normal display may continue to use an applicable
zero-argument whole-family `show` returning `String`.

Defensive runtime construction and injection must reject a constructor owned by
another family, wrong payload arity or type, or unresolved generic arguments.
Ordinary case evaluation may rely on those invariants.

### 11. Reflection

Preserve the sealed `Mirror`/`Signature` authority model: no reflection methods
on every value, no `perform`, no user-created signatures, no selector-based
dynamic send, and no second overload search during `Mirror.invoke`.

Specify the reflected callable surface by subject:

| Subject | Reflected rows |
| --- | --- |
| Multi-constructor family instance | Whole-family rows only |
| One-constructor family instance | Whole-family rows plus sole-constructor local methods and payload accessors |
| Family type object | Representation constructors and factories |
| Primitive value or type object | Its existing public primitive rows |
| Host capability | Rows of its exact host interface |
| `Mirror` | The established reflection API |

A mirror uses the subject's dynamic nominal family, even when the original
static expression was protocol-typed, but never captures a constructor
refinement. A multi-constructor instance mirror exposes no current constructor,
payload, local row, constructor predicate, conformance list, or refinement
certificate. Constructor schema is discovered from the family type object's
constructor signatures.

Add the normative `Signature` queries:

```text
(signature role)        -> Symbol
(signature type-params) -> (List Symbol)
```

The closed role vocabulary is `constructor`, `factory`, `family`, `local`, and
`operation`. A per-constructor whole-family implementation reflects as one
`family` row. Parameter and return type data remain descriptive `Symbol`/`List`
grammar data, never an identity, cast token, or first-class type universe.

Signature authority retains exact opaque owner, receiver instantiation where
needed, and row identity. Constructor and factory signatures are owned by the
family type object; a family row works across its family's constructors; local
rows retain their allowed constructor ownership; primitive and host ownership
remain exact. `Mirror.invoke` validates ownership, arity, instantiated argument
types, generic resolution, and result type before returning an ordinary Aloe
value, and invokes that exact row without selector lookup.

Retain the narrow one-parameter `Signature.accepts?` contract and deterministic
signature ordering. `accepts?` checks a candidate mirror's subject with the
same invocation relation and returns `#f` for every other row arity. Generic
input variables may be solved from the candidate; a true result does not claim
that unrelated result-only variables are resolved.

Ordering within a finalized program image is:

- constructor rows in constructor declaration order;
- declaration-owned factory and method rows in textual order;
- additive rows in finalized program-definition order;
- every overload retained as a separate signature row; and
- `messages` deduplicated by selector while preserving the first signature
  occurrence.

A whole-family row with per-constructor bodies remains one reflected row, not
one row per body. Reified names and raw strings provide no refinement or
invocation authority.

### 12. Built-ins and typed host capabilities

Preserve the accepted observable contracts for `List`, numbers, `Bool`,
`String`, `Symbol`, `Mirror`, `Signature`, and typed host capabilities. They may
remain specialized runtime kinds and need not be rewritten as source-defined
families for this project to be complete.

Carry forward the complete checkpoint-88 host boundary without broadening it:

- explicit paired driver injection;
- exact nominal interface identity shared by checker, evaluator, and
  reflection;
- ordered fixed rows over only `Int`, `Bool`, and `String` crossings;
- immutable String normalization;
- pre-call argument and post-call result validation;
- contextual host failures with retained causes and unwrapped breaks;
- no source-written host type names; and
- no default ambient capability, Racket evaluation, namespace access, dynamic
  library surface, arbitrary Racket call, or second dispatch/evaluation rule.

Adapt obsolete “class” wording around built-ins only where needed to avoid
claiming a second user-visible nominal ontology. Do not promise that primitive
implementations are already family descriptors.

### 13. Examples, diagnostics, and explicit exclusions

Include compact, complete normative examples for at least:

- one-constructor generic `Point` with an explicit `new` constructor;
- generic `Option` with nullary `None`, unary `Some`, explicit and contextual
  construction, and exhaustive elimination;
- two-parameter `Result` showing cross-branch constraints; and
- direct regular recursive `Tree` with a recursive whole-family operation and
  external case analysis.

Examples in the ratified specification describe the destination and are not a
request to add or run them as repository applications in checkpoint 89. Retain
the existing Boids, MPL, Gel, Term, scalar, function, collection, and reflection
goldens that are still semantically applicable, rewriting declaration snippets
into family syntax where necessary.

State required diagnostic facts without freezing punctuation-sensitive error
sentences: declaration collisions and malformed sections; unresolved or
conflicting generic arguments; invalid construction; case coverage and binder
errors; illegal local access after refinement loss; invalid recursion; protocol
incompatibility; overload ambiguity or incoherent results; reflection ownership;
and runtime boundary failures.

Rebuild the out-of-scope section so it does not retain claims superseded by the
approved design. It must explicitly defer at least:

- inheritance, mutation, setters, macros, compiler work, and computed
  selectors;
- permanent `define-class` compatibility;
- nested or guarded patterns and silently partial case analysis;
- constructor-specific type parameters, existentials, GADTs, variance, and
  source-written refinement types;
- nonregular, polymorphic, mutual, or general forward recursion;
- structural, conditional, inherited, intersected, defaulted, generic, or
  retroactive protocol conformance;
- constructor visibility controls and representation-opening reflection;
- a general first-class type universe or dynamic cast facility;
- broader host crossings, opaque host handles, ambient capabilities, and a
  general FFI; and
- mandatory rewrites of specialized built-ins.

## Required reconciliation audit

Do not append the family design while leaving contradictory class-era rules
normative elsewhere. Review every existing `SPEC.md` section and deliberately
retain, replace, relocate, or remove it. At minimum, audit these current claims:

| Current normative subject | Required disposition |
| --- | --- |
| “0.1 language plus later additions” organization | Fold accepted behavior into one specification; retain history only as clearly non-normative context if useful |
| “Objects and classes” ontology | Replace with the unified family/type-object/constructor/value ontology |
| `define-class` grammar | Replace with `define-family`; state legacy syntax is rejected by the completed language |
| generated `new` | Replace with explicit representation constructors, conventionally named `new` for products |
| one positional protocol | Replace with ordered `(conforms P ...)` and multiple direct protocols |
| class-local fields and methods | Classify them as sole- or constructor-local accessors/methods versus explicit whole-family rows |
| existing `define-methods` | Preserve additive whole-family methods and add the constrained factories section |
| send grammar | Add the static `(type ...)` header and reserve receiver-shaped `case` without weakening literal selectors |
| current type grammar | Generalize family applications and keep constructors, refinements, and host interface names out of source types |
| generic construction inference | Require checked resolved arguments and prohibit runtime payload reconstruction |
| protocol and overload rules | Add family-wide multiple conformance, compatibility, finalization, and return coherence |
| reflection | Add family/type-object surfaces, roles, generics, and multi-constructor representation hiding |
| structural equality and raw printing | Define family, instantiation, and constructor behavior explicitly |
| implementation note | Replace independent checking/evaluation with linked checking and elaboration before evaluation |
| old out-of-scope list | Remove now-accepted exclusions such as required protocol signatures or multiple protocols |
| built-ins and typed host section | Preserve their accepted behavior and exclusions without pretending they were rewritten |

Search the completed specification for `class`, `define-class`, generated
`new`, single-protocol wording, and version-addition language. Every remaining
occurrence must be either a deliberate historical/rejection statement or a
term needed to describe a specialized built-in—not an accidental second
ontology.

Also audit all syntax blocks against Decision 9. Examples must retain
receiver-first sends, literal selectors, explicit `call`, and explicit numeric
conversion. Do not accidentally introduce `(f x)` application, constructor
application, qualified constructor expressions, a top-level match form,
implicit `Int`/`Float` coercion, or an unspecified special form.

## `CHECKPOINTS.md` implementation index

Extend the compact index with checkpoints 89–106. Checkpoint 89 is the
ratification checkpoint; 90–106 are the approved dependency-ordered
implementation plan. Keep entries concise and outcome-oriented. They should
convey the following boundaries without becoming detailed checkpoint
specifications:

- **89 — Ratify unified nominal algebraic families:** normative specification,
  implementation index, and durable handoff; no runtime change.
- **90 — Checked evaluation seam:** checked/elaborated results gate production
  evaluation and failed checking prevents evaluation or commit.
- **91 — Nominal descriptor nucleus:** shared opaque protocol, family,
  constructor, and row descriptors under a temporary legacy-class bridge.
- **92 — One-constructor `define-family`:** explicit product constructors and
  uniform methods, with malformed new declarations rejected.
- **93 — Multiple representation constructors:** closed constructor sets,
  immutable payloads, opaque identities, equality, and structural printing.
- **94 — Explicit type arguments and generic constructors:** checked send
  headers, resolved generic construction, invariance, and no escaping unknowns.
- **95 — Constructor refinements and local surfaces:** singleton construction
  knowledge, direct-alias preservation, local access, and specified widening.
- **96 — Exhaustive explicit `case`:** explicit clauses, once-only scrutinee,
  lazy branch selection, binding, and coverage diagnostics.
- **97 — Defaults and branch joins:** residual `else`, symmetric constraints,
  and refinement union without inferred protocol joins.
- **98 — Whole-family body modes:** complete `per-constructor` tables,
  constructor-indexed dispatch, selector partitions, and row coherence.
- **99 — Factories and additive extensions:** type-object factory bodies,
  declared-result widening, atomic extension staging, and no replacement.
- **100 — Multiple protocols and global coherence:** explicit conformances,
  whole-family compatibility, overload ambiguity, and return coherence.
- **101 — Direct regular recursion:** linked self-recursive family payloads and
  rejection of nonregular or mutually recursive declarations.
- **102 — Family-aware reflection:** roles, type parameters, exact row
  descriptors, type-object construction surfaces, and hidden variant locals.
- **103 — Repository migration and bridge removal:** migrate all Aloe sources
  and tests, reject `define-class`, and remove the temporary dual vocabulary.
- **104 — Canonical `Option` and `Result`:** ordinary user-family examples
  covering nullary inference, two-parameter constraints, cases, factories, and
  reflection.
- **105 — Gel state validation:** replace the pending sentinel list with
  `Option` and preserve Gel behavior and output while validating reflection.
- **106 — Filesystem validation and final seal:** exercise a closed filesystem
  family with explicit `Other`, run all application evidence, remove transition
  debt, and finalize documentation.

Preserve checkpoints 1–88 as historical implementation outcomes. Do not create
`docs/checkpoints/0090-*.md` or any later detailed checkpoint document here.
Each later detailed checkpoint is designed only after its predecessor's
implementation and review results are known. If a later slice must be split,
record that through a reviewed checkpoint amendment rather than silently
reordering dependencies.

## Durable implementation handoff

Use `docs/handoff.md` as the separate, durable implementation handoff/status
artifact. It is the repository's established live handoff, already records the
current state and designer/implementer roles, and is part of the normal reading
order. Update it rather than creating a second competing handoff or status
ledger.

The revised handoff must be self-contained for subsequent checkpoint tasks. It
must not require the absent transcripts or the archived provisional draft for
normal implementation work. It must contain:

1. **Reading order and authority.** Read `AGENTS.md`, normative `SPEC.md`,
   `CHECKPOINTS.md`, the current detailed checkpoint, and the handoff; identify
   `SPEC.md` as law, the checkpoint as the current change contract, the index as
   ordering, the handoff as operational status, and the archive as non-normative
   provenance.
2. **Current implementation baseline.** State that behavior is complete through
   checkpoint 88 at checkpoint 89's start and remains unchanged by ratification.
   After acceptance, mark 89 complete and 90 as the next design/implementation
   boundary without implying that family syntax already runs.
3. **Destination capsule.** Summarize the one-family ontology, explicit
   constructors and factories, whole/local surfaces, exhaustive case,
   invariant generics and shallow refinements, open protocols, linked checked
   evaluation, exact nominal runtime identity, structural equality/printing,
   and sealed reflection boundary.
4. **Non-negotiable guardrails.** Preserve receiver-first send, `call`, `let`,
   immutability, no inheritance, no implicit numeric coercion, opaque nominal
   identity, no runtime generic inference, no partial case, no structural
   conformance, and no reflection-based representation opening.
5. **Implementation architecture boundary.** Record the checked elaboration
   pipeline, shared descriptor graph, atomic program finalization, temporary
   legacy declaration lowering, and mandatory removal of that bridge at
   checkpoint 103. Distinguish permitted temporary syntax support from the
   final language.
6. **Checkpoint map and live status.** List 89–106 with one-line outcomes and an
   explicit status marker such as complete, current, or pending. Name the next
   checkpoint and its dependency. Future accepted checkpoints update this
   table rather than creating detached status notes.
7. **Application evidence.** Map `Point`, Boids, MPL, `Option`, `Result`,
   `Tree`, Gel, Term/host tests, and the filesystem model to the invariants they
   validate and the checkpoint at which each becomes required.
8. **Migration inventory.** Note that current sources and historical tests use
   `define-class`, positional conformance, and current reflection structures;
   they remain untouched at 89 and are migrated deliberately by later
   checkpoints. Record any syntax-selector collision audit result relevant to
   `case`, `else`, `per-constructor`, and `(type ...)`.
9. **Validation and work discipline.** One checkpoint at a time; add tests with
   behavioral changes; run the checkpoint test, full suite, required hand
   check, and `git diff --check`; keep later syntax rejected; stop for review
   when green; never advance automatically.
10. **Deferred and rejected work.** Carry the project's explicit exclusions so
    a later implementer does not add GADTs, general subtyping, mutual recursion,
    first-class type descriptors, representation-opening reflection, built-in
    rewrites, a general FFI, or indefinite compatibility while completing a
    narrower checkpoint.
11. **Status-maintenance rule.** Each accepted implementation checkpoint
    updates only the factual current-state, next-checkpoint, migration, and
    validation evidence portions of the handoff. Normative semantics change
    only through an approved specification checkpoint or addendum.

Keep the useful current typed-host-boundary and application context in the
handoff. Remove or clearly relabel stale “candidate next application” language
that conflicts with the now-approved 89–106 sequence. The result should remain
a readable operational handoff, not a second full copy of `SPEC.md`.

## Runtime-preservation audit

Because this checkpoint changes authority without changing implementation,
perform these checks before review:

- confirm the diff contains only `SPEC.md`, `CHECKPOINTS.md`, and
  `docs/handoff.md`;
- confirm there are no `.rkt` or `.aloe` changes and no new generated files;
- confirm `archive/unified-nominal-adts.md` and historical checkpoint documents
  are unchanged;
- inspect the specification diff for accidental behavioral edits outside the
  approved Decisions 1–10 and deliberate reconciliation of old class rules;
- inspect every cross-reference among the three edited documents;
- confirm `CHECKPOINTS.md` and the handoff give the same order and current/next
  status;
- confirm the handoff does not treat planned syntax as implemented; and
- confirm no detailed checkpoint 90–106 document has been created.

Run:

```sh
git diff --check
git status --short
git diff --name-only
raco test tests
```

If this repository's established full-suite invocation differs, use the
established equivalent and record the exact command and result. The suite is a
regression check only; do not change tests to make a documentation checkpoint
pass.

Run one existing checkpoint-88 behavior by hand through the checked driver or
an existing application command. It must use only currently implemented syntax.
Do not attempt a `define-family`, `case`, explicit send type header, or other
future golden as the hand check for checkpoint 89.

## Acceptance

Checkpoint 89 is complete when all of the following are true:

- `SPEC.md` is a self-contained normative specification of the approved unified
  nominal algebraic family language, not a link to or lightly edited copy of the
  archived decision log.
- The specification preserves receiver-first sends, `call`, existing scalar
  and collection behavior, current reflection authority, and the sealed typed
  host boundary while deliberately replacing the class ontology.
- `define-family` is the sole normative user nominal declaration, constructors
  are explicit, and completed-language `define-class` rejection is clear.
- Construction, factories, local and whole-family messages, extensions,
  per-constructor bodies, exhaustive case, generics, refinements, recursion,
  protocols, runtime identity, equality, printing, elaboration, and reflection
  have concrete normative rules.
- Every material semantic commitment from Decisions 1–10 appears in the
  revised specification or is explicitly listed as deferred/rejected.
- No contradictory generated-`new`, one-protocol, class-as-parallel-ontology,
  runtime-generic-inference, partial-case, or representation-opening-reflection
  rule remains normative.
- `CHECKPOINTS.md` preserves completed history and contains the concise approved
  89–106 sequence in dependency order.
- No detailed future checkpoint document has been written.
- `docs/handoff.md` is the single durable implementation status artifact,
  distinguishes normative destination from current behavior, and contains the
  required authority, guardrail, architecture, sequence, evidence, migration,
  validation, and maintenance information.
- The archive and transcript commit remain non-normative and untouched.
- The implementation diff contains no production source, checker, evaluator,
  runtime, reflection, host, application, fixture, or test changes.
- The existing full suite and current-syntax hand check pass unchanged.
- `git diff --check` passes and the final status/diff audit shows only the three
  authorized documentation files.

Stop for review without committing. Do not begin checkpoint 90, create its
detailed checkpoint document, introduce an elaborated AST, add a family
descriptor, or accept any new source syntax in the same change.

## Explicit non-goals

- Do not implement `define-family`, constructors, factories, `case`, explicit
  send type arguments, refinements, recursion, multiple protocols, new
  reflection metadata, or checked elaboration.
- Do not change the parser, AST, type checker, evaluator, driver, environment,
  runtime representation, equality, printer, reflection, or host boundary.
- Do not migrate or edit Aloe libraries, examples, Gel, Boids, MPL, Term,
  fixtures, or historical tests.
- Do not add a temporary `define-class` bridge yet; checkpoint 91 owns its
  internal introduction after the checked-evaluation seam.
- Do not add aliases, compatibility promises, deprecation warnings, or runtime
  feature flags.
- Do not rewrite built-ins as families.
- Do not design filesystem selectors, host handles, or a broader crossing
  vocabulary.
- Do not infer family messages from repeated local selectors, use names as
  nominal identities, reconstruct generic types from payloads, or expose a
  variant's constructor through reflection.
- Do not silently resolve a material contradiction in the approved design.
- Do not consult or restore the original transcripts without the exceptional
  ambiguity justification described above.
- Do not write, implement, or commit checkpoint 90.
