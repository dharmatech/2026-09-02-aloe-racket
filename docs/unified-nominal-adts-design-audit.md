# Unified nominal algebraic families: design audit

> **NON-NORMATIVE — CHECKPOINT 89F AUDIT COMPLETE**
>
> The review preserved bounded corrections C1–C6 and adopted and rechecked the
> user-approved resolution of [U1](#u1-gel-reflection-and-inference-closure).
> No material design issue remains unresolved in this audit. This completes
> checkpoint 89F's documentation audit, not checkpoint 89 as a whole.
> The candidate remains **incomplete and non-normative**. `SPEC.md` remains law;
> runtime behavior remains complete through checkpoint 88.

## Purpose and baseline

This report audits the [specification candidate][candidate] against the
approved, non-normative [Decisions 1–10][archive], as amended by the
[user-approved U1 resolution][u1-decision], the preserved current language,
and the boundaries of checkpoints 89A–89E. It records agreement, bounded
corrections, and the separately approved semantic amendment. It is not a
soundness proof, implementation certification, new semantic authority, or guarantee about
later changes to the candidate.

The review began on 2026-09-07 at commit
`3d6d5a6d5b9a4541f29823e93fd748ce95dbc329` on
`codex/unified-nominal-adts`. The starting worktree was:

```text
?? docs/checkpoints/0089f-audit-unified-family-design.md
```

The accepted candidate through 89E was committed and unchanged. The untracked
89F checkpoint was supplied by the user and is not new audit work. The initial
review created this report, applied C1–C6 to the candidate, and stopped for
the U1 design decision without committing.

The user then updated 89F and supplied the approved resolution. At resumption,
HEAD and branch were unchanged and the worktree was:

```text
 M docs/unified-nominal-adts-spec-candidate.md
?? docs/checkpoints/0089f-audit-unified-family-design.md
?? docs/unified-nominal-adts-design-audit.md
?? docs/unified-nominal-adts-reflection-resolution-proposal.md
```

The candidate corrections and report were existing uncommitted audit work;
the updated checkpoint and new resolution were user-provided read-only inputs.
The resumed review read both inputs completely, preserved C1–C6 and unaffected
conclusions, and adopted the amendment in the candidate and this report only.
It supersedes conflicting archived reflection/closure wording only within
its stated scope. Neither the archive nor either supplied input was edited.

Read completely before editing: [AGENTS.md](../AGENTS.md),
[SPEC.md][spec], [CHECKPOINTS.md](../CHECKPOINTS.md), checkpoints
[89A](checkpoints/0089a-draft-family-language-core.md),
[89B](checkpoints/0089b-draft-family-execution-model.md),
[89C](checkpoints/0089c-draft-family-reflection.md),
[89D](checkpoints/0089d-draft-builtins-and-host-integration.md),
[89E](checkpoints/0089e-draft-diagnostics-and-validation.md),
[89F](checkpoints/0089f-audit-unified-family-design.md), the entire candidate,
and the entire archive, including later syntax, implementation consequences,
guardrails, and completion criteria. Also reviewed the complete
[checkpoint-88 contract][cp88], [handoff](handoff.md), and [Gel document][gel-doc],
with relevant source and test evidence identified below. Neither historical
transcripts nor the monolithic plan were consulted or restored.

References to candidate sections below describe the final text reviewed in
this slice, including C1–C6 and the U1 amendment. Baseline line numbers in
findings locate the pre-correction text at the commit above.

## Decision coverage

Each row records the obligations checked, not merely a section locator.
“Agrees” means no discrepancy was found for those obligations in this review;
it does not certify future execution. U1's approved amendment is distinguished
from agreement with unchanged archived rules.

| Decision and governing archive subsections | Candidate coverage | Conclusion |
| --- | --- | --- |
| [1: Ontology][d1] — Recommendation; Types and refinements; Operations; Boundaries | Sections 2–5, 10–11 | Agrees: one opaque family and declaration-level type object, a nonempty closed constructor set, products as singleton families, constructor knowledge separate from nominal identity, and disjoint family/local surfaces. Specialized values need not be source families. |
| [2: Construction][d2] — One type object per declaration; Representation constructors; Factories; Generic argument inference; [D9 constructor declarations][constructor-syntax] | Sections 2–3, 5, 8, 10, 14 | Constructors are explicit public bodyless rows, freshly instantiated and singleton-refining; `new` is not generated. Factories are ordinary type-object rows whose results do not reveal construction history. Ordinary construction still uses checked full headers, arguments, expected families, and enclosing constraints. U1 adds sealed input-based selected-row instantiation before mirrored invocation; no result-based reconstruction is permitted. |
| [3: Messages and refinement][d3] — Explicit whole-family surface; Implementing a whole-family message; Runtime dispatch; Sources of refinement | Sections 3–5, 7–8, 10, 14 | Agrees: repeated locals do not promote; uniform and complete per-constructor modes are exclusive; local access requires singleton knowledge; aliases preserve only outer knowledge; declared results/storage/protocol views lose it. C4 makes preserved overload selection explicit without changing row coherence. |
| [4: Elimination][d4] — One receiver-anchored special form; Eligible scrutinees; Coverage; Default clause; Initial pattern and result model | Sections 1, 4–5, 8–11 | Agrees: concrete-family eligibility, exact coverage of the currently possible set, residual defaults, whole/payload binders, invariant symmetric joins, opaque once-only scrutinee selection, and one lazy branch. C3 supplies the missing context in the introductory example. No partial or reflective elimination is admitted. |
| [5: Generics and recursion][d5] — Invariant family parameters; Refinement propagation; Recursive families; [D10 inference][inference] | Sections 3, 5–6, 8–11, 14 | Ordinary inference agrees: fresh send variables, full explicit headers, invariant arguments, sibling constraints, closure, and shallow refinement. C5 states the absence of constraint syntax; C6 scopes regular self-reference to payload types. U1's fixed source signature introduces no escaping unknown type; its selected row must resolve freshly from the owner and closed sealed inputs before execution. Ordinary construction, `subject`, and `invoke` retain closure. |
| [6: Protocols and closed data][d6] — The two axes; Conformance; Signature compatibility; Using a conformance; Additive receiver extensions; Authority summary; Expression-problem boundary | Sections 3, 7, 9–11, 14 | Agrees: multiple nominal uniform family claims, a row covering the whole required domain, usable results and coherent narrower overloads, declaration-owned claims satisfiable by later allowed rows, atomic additive extensions, and no representation/local/orphan/replacement additions. C4 explicitly states the open implementation axis and rechecking consequences. |
| [7: Runtime behavior][d7] — Semantic representation through Defensive constructor integrity; Built-ins and host values; Rejected runtime alternatives | Sections 8–15 | Exact identities, immutable structural data, opaque leaves, one dynamic relation, constructor integrity, dispatch, equality, raw/display separation, and specialized kinds agree. U1 explicitly requires sealed closed input evidence, including invariant empty-list elements and checked function arrows; internal representation is free, content/behavior-based reconstruction is forbidden. Concise raw syntax follows D9's later resolution. |
| [8: Reflection][d8] — Callable surfaces; Signature role and generic metadata; Signature identity and ownership; Reflective invocation; `Signature.accepts?`; Ordering; Application consequences | Sections 5, 8, 11, 14–16 | Existing exact authority, descriptive metadata, contextual operations, narrow acceptance, and exclusion of multi-constructor locals agree. U1 adds the fixed `invoke-mirrored` row with one unwrap per argument, pre-execution generic resolution, and result validation before preserving an existing Mirror or wrapping once. It appends to the Mirror instance API; explicit Mirror browsing intentionally gains a menu entry. |
| [9: Syntax][d9] — Family declaration grammar; Method syntax; Whole-family implementation modes; Exhaustive case grammar; Reserved case markers; Explicit static type arguments; Source type grammar; Additive extension and conformance syntax; Reflection selector spellings; Raw rendering; Source-language transition | Sections 1–7, 13–17 | Fixed grammar, cardinalities, fields/binders, headers, raw syntax, and removal of class syntax agree. C1 distinguishes expression/declaration `type`; C2 restores preserved declaration/body rules; C3 repairs example context and an undeclared `Point.map`. U1 is an ordinary fixed-arity send, adds no special form or variadic convention, and forwards no type header to its selected row. |
| [10: Static and implementation consequences][d10] — Implementation boundary; Shared nominal descriptors; Component consequences; Declaration linking; Finalization; Inference; Lookup; Case/branch checking; Coherence; Runtime/reflection; Compatibility; Transactions; Validation; Sequencing; Completion criteria | Sections 8–22 and Pending completion | The linked checked pipeline, identities, linking/finalization, transactions, migration removal, and future application evidence agree. U1 supplies the closed-source Gel helper account and guarded evidence requirements. Diagnostics and validation cover its success/failure boundaries and intentional Mirror API addition. Roadmap allocation and durable handoff remain reserved; no provisional sequence is drafted or implemented. |

The archive's [cross-decision guardrails][guardrails] were also checked:
receiver-first sends, explicit `call`, closed constructors/open protocol
implementations, internal refinements, opaque identities, structural data,
trusted equality, no wrappers, exact reflection authority, one nominal source
form, checked construction, migration removal, hidden closures, and optional
built-in rewrites are retained. The reflection usefulness/closure interaction
is resolved by the explicit approved amendment, not an implementation freedom.

## Interactions across 89A–89E

| Interaction | Review result and supporting references |
| --- | --- |
| Syntax and evaluation | [Sections 1–5][expressions] preserve literal selectors, `call`, parallel aliases, lazy conditionals, `check`, and type/term separation. Case is a second-position syntactic marker; `else`, body modes, section labels, and type headers retain their contextual scopes. C1/C2 clarify preserved forms. Static checking still checks every reachable branch even when runtime selects only one. |
| Construction and inference | [Sections 5 and 8][types] retain full headers, independent sends, invariant constraints, branch-order independence, and ordinary closure. [Mirrored invocation][mirrored-invocation] explicitly instantiates the selected row from exact owner and sealed closed input types before execution. Result-only parameters remain failures; an outer expected Mirror supplies no missing evidence. |
| Refinement and local authority | [Shallow refinements][refinements], [case coverage][case-coverage], and [reflection][reflection] agree on construction, direct aliases, intersections, subtraction, unions, and loss points. An inherently singleton family stays singleton. A broader residual set, protocol view, stored value, or unwrapped mirror cannot acquire hidden multi-constructor local authority. |
| Declarations and global coherence | [Sections 7 and 9][protocols] install signatures before bodies, permit regular payload self-reference, stage extension rows together, and finalize declaration-owned conformance over complete loaded units. A later valid row may satisfy a requirement without adding a claim, constructor, or local. C4 connects declaration growth and protocol growth to their rechecking obligations. |
| Static and dynamic obligations | [Sections 8–11][checked] and [host integration][host] distinguish static failure, injection preflight, pre-execution owner/argument/generic guards, and post-execution result checks. U1 requires checked family/list/function evidence without executing behavior. Its ordinary result is checked before Mirror adaptation. Exact identities and invariance remain shared; runtime effects are not rolled back. |
| Equality, text, and reflection | [Sections 12–14][equality] preserve total kernel comparison, opaque leaves, user `=` as a domain operation, independent raw printing, optional whole-family `show`, and descriptive names/type data/menu positions. Different instantiations may be unequal internally while source `check` rejects incompatible types. Signature opacity promises no new equality/serialization API. |
| Built-ins and host composition | [Section 15][host], [SPEC sections 4–7 and 13][spec], and [checkpoint 88][cp88] agree on specialized values, invariant collections, explicit capability injection, exact owners, scalar crossings, opaque state, and guarded reflected calls. No adapter invents constructors, case eligibility, primitive bindings, or general extension rights. The existing `define-methods List` route remains explicit. |
| Diagnostics and validation | [Sections 18–22][diagnostics] retain condition-specific boundaries, evidence, legal negative answers, and the distinction between future obligations and current regressions. New [U1 scenarios][mirrored-validation] cover all three helpers, owner/input inference, missing result-only evidence, one unwrap, Mirror result reuse, exact metadata/menu ordering, and unchanged host guards. Gel preservation explicitly accounts for the approved Mirror API menu addition. |

## Findings and dispositions

### U1: Gel reflection and inference closure

**Original finding: a material missing rule. Disposition: resolved by the
user-approved U1 amendment, adopted in the candidate and rechecked below.**

The initial review found that the then-approved sources required both useful
dynamic Gel reflection and closed checked inference:

- [D8 Reflective invocation][reflective-invocation] permits an expected-result
  route for a hidden row, but also requires complete generic resolution.
  [D8 Application consequences][reflection-apps] preserves Gel's mirrored
  heterogeneous slots, exact invocation, and subject unwrapping.
- [D10 Generic inference and elaboration][inference] forbids unresolved
  variables at method and top-level boundaries. [D10 Validation applications][applications]
  requires preserving Gel key behavior and emitted text while its application
  data is migrated. Checkpoint 89C repeats both closure and client preservation.
- Candidate [section 8, Inference closure][closure] (baseline lines 706–724)
  requires closure. [Section 14, Mirror boundary][mirror-boundary] (lines
  1063–1078) says an unconstrained `subject` result is fresh and must resolve.
  [Checked exact-row invocation][invocation] (lines 1243–1265) says the same
  for hidden-row results. Sections 14, 16, and 22 retain Gel's general path.

The current application supplies a concrete counterpressure:
[GelStack](../gel/stack.aloe), lines 22–44 at the baseline, takes a `GelRow`
whose `Signature` is unknown to its body. `invoke-zero` pushes the result;
the mirrored-argument `invoke-one` also passes `(arg subject)` into the hidden
row. Generic `push`, lines 17–20, wraps an ordinary value with `Mirror of`.
Returning `GelStack` does not determine that intermediate value's type.

A small current-syntax driver observation, actually run in the initial review,
isolates the same issue without any family syntax:

```aloe
(define receiver (Mirror of 10))
(define signature ((receiver signatures) first)) ; the existing Int + row
(define argument (Mirror of 2))
((Mirror of (receiver invoke signature (argument subject))) raw)
```

The current checked driver returns the String `"12"`.
[Current checker code](../aloe/type.rkt), `infer-mirror-class-send` and
`infer-mirror-send` at lines 1279–1320, creates fresh `subject`/`invoke` types
and does not supply a concrete expectation through `Mirror of`.
[Checkpoint 73](../tests/checkpoint-73.rkt) also covers Gel's zero-argument,
ordinary-argument, and mirrored-argument stack paths. This is evidence of the
preservation obligation, not authority to retain unchecked inference in the
future implementation.

Under the pre-amendment candidate's stated rules, a hidden `Signature` supplies no static
parameter/result type to the checker. `Mirror of` accepts any Aloe value but
does not determine which type this occurrence has. Consequently the mirrored
argument and result have no specified way to close their fresh types in this
context. Choosing an arbitrary expected `Mirror` would reject ordinary Int or
Point results; `accepts?` supplies neither a type token nor refinement.
The successful contextual `(Option Int)`/`None` examples solve a different
problem and do not justify this general path.

The initial report requested a design decision specifying whether and how
opaque reflected arguments/results could pass through this Gel path while
satisfying closure, with a distinction from unresolved generic construction.
It stopped before semantic repair; ordinary contextual examples and a passing
runtime suite could not answer that question.

The user subsequently approved the [reflection resolution][u1-decision] and
updated [checkpoint 89F][updated-89f] to authorize its adoption. This is a
**substantive approved design amendment**, separate from C1–C6's bounded
corrections. It supersedes conflicting candidate/archive wording specifically
for the new operation and its required Gel helper changes. Ordinary-result
`invoke`, contextual `subject`, and ordinary constructor elaboration retain
their closure rules. The read-only proposal and archive remain unchanged.

The amendment adds `Mirror.invoke-mirrored` with exactly a `Signature` and a
`(List Mirror)` as arguments, returning `Mirror`, with no local type parameters
and role `operation`. Its selected row may resolve fresh parameters only from
the exact owner's fixed instantiation and sealed, already closed input type
evidence. Full instantiation, exact owner, arity, and argument validity are
required before execution. Each input mirror is unwrapped once. The ordinary
result is checked against the instantiated row result before returning the
same Mirror if already mirrored, or wrapping the ordinary result once.

No outer expected Mirror, forwarded type header, descriptive type data,
payload scan, callback execution, or returned value supplies missing generic
evidence. Empty-list element types and function arrows come from existing
checked metadata; malformed foreign subjects cannot gain validity by wrapping.
No public type query, `Any`, existential, cast, or type-token mechanism is added.

| Adoption area | Recheck and disposition |
| --- | --- |
| [Checked closure][closure] and runtime/integration sections 10–11 and 15 | Ordinary construction still receives resolved checked arguments. The explicit guarded operation has closed source types and requires already closed family, invariant list, and function-arrow evidence internally. Representation remains an implementation choice; executing behavior to discover types is excluded. |
| [Mirror operation contract][mirrored-invocation] | Fixed two-argument metadata, ordinary evaluation order, exact owner/row invocation, fresh generic binding, pre-execution guards, once-only unwrapping, and result validation before adaptation agree with the approved decision. Existing Mirror results are reused; explicitly mirroring a Mirror still reflects that object. Local family rows remain hidden. |
| [All three Gel helpers and call sites][gel-examples] | The candidate shows every current helper beside its approved replacement. Expected `(List Mirror)` closes the empty list; direct helpers return Mirror and select Mirror `push`; the bound generic helper delegates through `Mirror of arg`. Call sites stay unchanged and no unknown source type escapes. The integer example still specifies raw String `"12"`. These are reviewed future examples, not executed helper migrations. |
| Generic examples in section 16 | Fixed `(Option Int)` owners retain Int. A checked `(-> Int String)` map input fixes fresh `U` before callback execution; `Option.Some` with mirrored Int fixes `T`. `Option.None`, partially known `Result.Ok`, and result-only factory parameters fail before execution. Explicit ordinary `(Option None (type Int))` followed by mirroring remains valid. |
| [Diagnostics and exclusions][diagnostics] | Source closure, sealed selected-row resolution, and post-execution result validation are distinct. The approved exception is explicit wherever runtime reconstruction is excluded; wrong owners/arity/types, absent evidence, malformed subjects, and missing result parameters remain guarded failures. |
| [Validation catalogue][mirrored-validation] and application section 22 | Covers ordinary/Mirror results, empty and nonempty mirror lists, one unwrap, fixed/fresh generic evidence, invariant lists/functions, failures before effects, exact metadata, and host guards. Existing valid Gel flows retain results, keys, and text except for the appended row when explicitly browsing Mirror objects. Pending still becomes `Option GelRow`; further state restructuring remains conditional. |

The affected decision coverage, interactions, examples, and catalogue were
rechecked together. The approved rule supplies the missing account without
changing unrelated family, source-evaluation, refinement, or host guarantees.
No further material design issue was found in this review.

### Bounded corrections applied

These preserved corrections follow existing rules; the separate approved
amendment above resolves U1. Locations in
the “Before” column are baseline candidate locations; linked headings locate
the reviewed text after editing.

| Finding and before meaning | Authority | Correction and recheck |
| --- | --- | --- |
| **C1 — `type` scope**, section 1 Reserved-word scopes, lines 104–108: “only” post-selector wording could also exclude the retained declaration binder. | [D9 Method syntax](../archive/unified-nominal-adts.md#method-syntax), [Explicit static type arguments](../archive/unified-nominal-adts.md#explicit-static-type-arguments), and [SPEC 3.1][spec] | [Reserved-word scopes][markers] now qualifies expression use and separately identifies declaration `(type U ...)` as variable binding. Rechecked section 3 row grammar, section 5 instantiation order, and section 19 scoped-marker rejection; no global reservation added. |
| **C2 — Preserved declaration/body rules**, section 3 Declaration grammar, lines 158–239: top-level placement, single-expression bodies, and conventional capitalization were not explicit. | SPEC 1, 4.5, 4.7, 4.8; [D9 One nominal declaration form](../archive/unified-nominal-adts.md#one-nominal-declaration-form) and [Multi-constructor family example](../archive/unified-nominal-adts.md#multi-constructor-family-example) | [Declaration grammar][declarations] states family/protocol declarations are top-level, bodies have one expression, and capitalization is conventional. Rechecked all declarations and body examples plus section 19 malformed-form coverage. No nested declaration facility or capitalization restriction is introduced. |
| **C3 — Example context**, sections 2, 3, 4, 5: the wrapper `fn`, factory fragment, introductory case, and header examples left necessary context implicit; line 485 used `point map` although section 16's `Point` has no `map`. | [SPEC 4.2][spec]; [D9 Method syntax](../archive/unified-nominal-adts.md#method-syntax) and [Explicit static type arguments](../archive/unified-nominal-adts.md#explicit-static-type-arguments); [D10 static lookup](../archive/unified-nominal-adts.md#static-message-lookup); existing section 16 declarations | Added an expected arrow for the constructor wrapper, a bound `T` factory context, and an unrefined Option/fallback case context. [Header examples][headers] now use the existing `Option.map` with `(Option Int)` and `(-> Int String)` inputs. The `Some`/Math example states explicit conformance. Rechecked arity, full resolution, local access, branch coverage, and result `(Option String)`; no `Point.map` method was invented. |
| **C4 — Overload and open-axis rules**, section 7, lines 570–614: referred to ordinary ambiguity/coherence without stating exact-over-protocol selection; declaration/protocol growth observations appeared in section 21 without a complete direct statement in section 7. | [SPEC 3.4][spec]; [D6 Using a conformance](../archive/unified-nominal-adts.md#using-a-conformance), [Authority summary](../archive/unified-nominal-adts.md#authority-summary), [Expression-problem boundary](../archive/unified-nominal-adts.md#expression-problem-boundary); [checkpoint 32](../tests/checkpoint-32.rkt) | [Section 7][protocols] explicitly requires applicable selector/arity/type rows, preserves exact-over-protocol specificity and rejection of ties, and states the two growth/rechecking rules. Rechecked header filtering, section 9 finalization, section 10 dynamic results, section 19 rejection, and section 21 growth/specificity scenarios. No new ranking algorithm or structural conformance is specified. |
| **C5 — Generic constraints**, sections 5 and 20: the absence of generic-constraint syntax was only implicit in grammar and conditional-conformance exclusions. | [SPEC 5.2][spec]; [D6 Conformance](../archive/unified-nominal-adts.md#conformance); [D10 Generic inference and elaboration][inference] | [Source types][types] and the section 20 generic exclusions now state that no constraint syntax is added. Rechecked uniform family conformance and the preserved Point generic method example; this does not replace current generic checking or impose a new numeric protocol. |
| **C6 — Regular recursion scope**, section 6, lines 550–563: “every recursive occurrence” lacked the explicit payload qualification and could be read to prohibit a method's different result instantiation. | [D5 Recursive families](../archive/unified-nominal-adts.md#recursive-families); [D10 Bodies](../archive/unified-nominal-adts.md#bodies), specifically payload resolution; [D9 Method syntax](../archive/unified-nominal-adts.md#method-syntax) | [Section 6][recursion] now explicitly applies the same-parameter rule to recursive payload occurrences, including beneath containers/arrows. It distinguishes the already accepted `(Option U)` method result. Section 19's recursion rejection was qualified together; section 21 already specifies payload references. Nonregular recursive payloads remain rejected. |

The initial status recorded U1 and the incomplete audit. After adoption and
rechecking, the status records the completed 89F audit while the candidate
remains incomplete and non-normative. The historical scope of 89A–89E and the
fact that 89E's catalogue did not perform this audit remain intact.

### Deliberate boundaries and non-findings

- Replacing generated `new`, class fields, positional single conformance,
  and legacy declarations is intentional, under [D9 Source-language transition][transition]
  and [D10 Compatibility boundary][compatibility]. Required protocol signatures
  and multiple family conformances are destination rules, despite the older
  out-of-scope list in `SPEC.md`. No old class rule was restored.
- [D7 raw display][raw-archive] left generic-printing detail open; [D9 Raw
  rendering syntax][raw-syntax] supplies the later concrete answer. Candidate
  section 13 correctly uses concise values and separate exact type context.
  Cross-execution identities, raw round-tripping, stable menu indices, and
  user-visible signature comparison remain deliberately unpromised.
- Descriptor layout, refinement metadata representation, redundant-check
  elimination, row indexing/caching, and adapters remain internal choices
  subject to the observable contract, including U1's sealed closed evidence.
  An internal representation choice cannot weaken or expand that approved rule.
- Built-in algebraic rewrites, protocol inheritance, positivity/termination
  proofs, filesystem capability design, and further Gel state restructuring
  beyond the required pending `Option` transition are correctly optional,
  excluded, or conditional. They are not missing requirements for this audit.

## Example and catalogue review

All candidate grammar displays, fenced Aloe fragments, prose
observations, and every row of sections 19–22 were reviewed. Fragments using
metavariables are not complete programs. All family behavior was checked
against the rules, not executed against the checkpoint-88 parser.

| Examples or scenarios | Context and conclusion |
| --- | --- |
| Sections 1–6 expression, declaration, constructor-wrapper, factory, case, type-header, and recursive-type fragments | Literal selectors and `call` remain distinct; C3 makes the inference/refinement contexts explicit and removes the unavailable `Point.map`. Type displays and arrow grammar are annotation data, not expression sends to run. Nullary fields and binders remain visibly empty lists. |
| Section 16 `Point` | Explicit `new`; ordered `x`/`y : T`; whole-family `+`; explicit Float header plus `(2 float)` and `3.0` resolve one `(Point Float)`. Its sole constructor allows field access and local reflection. No added numeric constraints are required by this example. |
| Section 16 `Option` | Factory `self` is the type object; expected `(Option T)` resolves the `None` branch. `map` has fresh `U`, uses `call`, and checks both cases with unrefined `self`; returned family types are unrefined. `maybe-name` comes from the factory, so its two clauses are possible. `none-name` is separately singleton-known and is not used as that two-case scrutinee. |
| Section 16 `Result` and section 21 sibling alternatives | Explicit Error construction resolves both parameters; the separate unrefined `result : (Result String String)` makes both branches legal. Whole Error binding authorizes its accessor. The two-branch `Ok 1`/`Error "x"` scenario supplies independent constraints and is symmetric. Isolated `Ok 1` has no `E` evidence and fails. |
| Section 16 `Tree` and recursive validation | Payloads recurse at `(Tree T)`; `size` sends operate on base recursive payloads and return Int. The external example explicitly uses unrefined `(Tree Int)`, so its Leaf value and Branch size expression share a result type. Nested elimination is a future scenario, not a nested-pattern extension. |
| Section 16 reflection observations and section 21 reflection rows | Instance arguments are substituted; map's `U` stays fresh; constructor/factory roles and family-then-row metadata are descriptive. Option instance surfaces match across constructors. An Option Int family row transfers across its constructors, not instantiations. `Result.Ok accepts? 1` solves only `T`, not `E`. Ordinary contextual None/subject examples remain valid; context-free ordinary uses still fail closure. |
| Section 16 Gel comparison and section 21 mirrored-invocation scenarios | All three current helpers are explicitly historical evidence; all three proposed replacements follow the approved fixed operation. The zero-argument list closes as `(List Mirror)`; both direct results select Mirror `push`; the generic overload's bound `T` is mirrored before delegation. Calls, integer raw output, ordinary/Mirror results, once-unwrapped inputs, fixed-owner/fresh-row inference, and result-only failures match U1's adopted contract. No future snippet ran through the current Aloe parser. |
| Section 21 coverage, joins, aliases, and losses | `Choice` is explicitly nongeneric/nullary and unrefined, so the missing list is A then B. The separately singleton Some case rejects None. Residual Some can expose its local; a larger residual cannot. None/Some joins unify outer sets; every loss point is accounted for. Lazy branch scenarios require well-typed branches and permit only one execution. |
| Section 21 equality/raw/boundary scenarios | Same-instantiation structural equality is separated from internal cross-instantiation inequality and source `check` type errors. Exact payload values support all four raw forms. Forged values/rows are defensive boundary scenarios, not new Aloe construction syntax. Ordinary `accepts?` false and legal nonempty defaults stay successful operations. |
| Section 16 built-in/host observations and section 21 preservation rows | Same-kind arithmetic, explicit conversion, contextual empty-list inference, `List` callbacks, and opaque composition match the preserved contract. Same-interface target state differs from same-name ownership. Crossing failures, immutable strings, causes, breaks, and Term output retain their correct boundaries. |

Several archive examples are deliberately fragments whose necessary context
must not be lost when restated. [D9 Complete Result example](../archive/unified-nominal-adts.md#complete-result-example)
does not make an isolated `Ok 10` fully inferred; the explicit inference rule
still requires `E`. [D9 Complete recursive Tree example](../archive/unified-nominal-adts.md#complete-recursive-tree-example)
needs a matching element/result context for its external elimination.
[D9 Syntax nucleus](../archive/unified-nominal-adts.md#syntax-nucleus) must not
be read to authorize a None/Some case on a direct immutable alias already
known to be None. The candidate's section 16 correctly supplies a factory
result or explicitly unrefined value for these multi-branch observations.
No archive text was changed and none of these fragments overrides a rule.

The catalogue was checked in both directions:

| Catalogue | Traceability and coverage result |
| --- | --- |
| Sections 18–19 diagnostics/rejections | Each expression/declaration/type condition traces to sections 1–8; combined rows to 7–9; value integrity to 10–11; comparison to 12/18; reflection to 14; integration to 15; and completed syntax to 17. The archive's [required negatives][negatives] are represented. Context-sensitive header filtering, legal empty sections, residual defaults, and non-error acceptance answers were checked against the positive rules. |
| Section 20 exclusions | Exclusions trace to grammar, closed representation, shallow refinement, nominal compatibility, exact authority, and the sealed host boundary. C5 states the constraint-syntax exclusion. U1's sealed input-based selected-row instantiation is expressly permitted while ordinary runtime reconstruction, content scans, execution to discover types, and public type escape hatches remain excluded. Optional built-in rewrites are not completion debt. |
| Section 21 semantic scenarios | Construction, inference, aliases/losses, case, open/closed axes, protocols, extensions, transactions, recursion, values, reflection, and integration each have positive coverage paired with negatives. The new U1 group covers all approved helper, input-evidence, result-adaptation, authority, failure-timing, menu, and host obligations without inventing a test API. |
| Section 22 application/completion obligations | Matches [D10 Validation applications][applications] and [Completion criteria][completion] as amended by U1 for Gel helpers and the intentional Mirror API addition. These are future obligations; neither this report nor the current suite supplies their implementation evidence. |

## Application and preserved-behavior evidence

The application obligations were reconciled individually:

- [Point](../examples/point.aloe) and [Boids](../examples/boids.aloe) preserve
  product methods, nested generics, immutable lists, explicit numeric
  conversion, and both `(demo step)` sends. [Checkpoint 11](../tests/checkpoint-11.rkt)
  checks the existing application; the future family migration is separate.
- [MPL core](../examples/mpl/core.aloe), [identities](../examples/mpl/identities.aloe),
  and [checkpoints 32](../tests/checkpoint-32.rkt) and
  [36](../tests/checkpoint-36.rkt) provide concrete protocol, overload, and
  additive-operation evidence. Math remains open; normalization/domain `=`
  and `show` do not override trusted equality. Future combined return
  coherence is an approved obligation, not a claim about today's checker.
- Option and Result remain ordinary families. Tree covers regular recursive
  data and nested case. The filesystem model must cover explicit ordinary
  `Other`, local capabilities, and exhaustive consumers/defaults, without
  choosing an OS API or broader host crossing.
- [Gel stack](../gel/stack.aloe), [menu](../gel/menu.aloe),
  [loop](../gel/loop.aloe), [main](../gel/main.aloe), and [Gel documentation][gel-doc]
  confirm the pending sentinel list, exact-row menus, typed picks, integer
  entry, cancellation, and emitted text. Pending must later become
  `(Option GelRow)`; a further state family remains conditional. U1's approved
  helper rewrites explain the closed-source invocation path with unchanged
  application calls. Existing valid-flow results, keys, and text remain
  compatible except that explicit Mirror API browsing gains the appended row.
  This is not a claim of byte-for-byte identical extended introspection or
  successful execution for every row with missing generic evidence.
- [List library](../lib/list.aloe) retains Aloe `fold`, `reverse`, and `map`
  with `call` callbacks and the existing List extension route. The
  [checker](../aloe/type.rkt) and [evaluator](../aloe/eval.rkt) were inspected
  for overloads, contextual reflection, equality, and printing. Existing
  unresolved-type permissiveness and internal name/index representations are
  evidence of current behavior, not future language rules.
- [Host declarations](../aloe/host.rkt), [driver injection](../aloe/driver.rkt),
  and [Term](../host/racket/term.rkt), together with
  [checkpoints 83](../tests/checkpoint-83.rkt),
  [84](../tests/checkpoint-84.rkt), [85](../tests/checkpoint-85.rkt),
  [87](../tests/checkpoint-87.rkt), and [88](../tests/checkpoint-88.rkt),
  support unique declared rows, exact state-plus-positional call shape,
  `Int`/`Bool`/`String` crossings, normalization, guards, causes/breaks,
  nominal ownership, paired preflight, no ambient Term, and sealed exports.
  Host state stays opaque; no capability API is selected by this audit.

## Validation actually performed

The resumed audit reran the required checks on the unchanged checkpoint-88
runtime. These results are separate from the future family obligations above.

- The full `raco test tests` run passed: **1,297 tests**. A fresh writable
  directory under `/tmp` was supplied through `TMPDIR`, because the sandbox's default
  `/var/tmp` is read-only. This is an environment adjustment, not a code fix.
- The exact [checkpoint-88 hand check][hand-check] passed with
  `'("sealed" "sealed\r\n")`, using an in-memory output port.
- The current-syntax driver observation in the initial U1 review returned
  `"12"`; it is retained as preservation evidence. No proposed family or
  `invoke-mirrored` expression ran through the current Aloe parser or evaluator.
- All 21 fenced Aloe fragments in the candidate passed Racket's s-expression
  reader and the candidate fences were balanced. This is a delimiter check,
  not Aloe parser acceptance or future semantic execution.
- All seven Aloe blocks in the approved resolution are reproduced exactly
  in the candidate; C1–C6's report rows match their resumption baseline.
- Validated local links and heading targets, reference definitions,
  consistent table widths, balanced fences in both artifacts, and candidate
  section numbering 1–22. Reviewed every correction against its cited source,
  retained unaffected conclusions, and rechecked U1's complete approved contract
  against its affected examples/catalogue entries. Status now distinguishes
  the completed audit from the incomplete, unratified candidate.
- `git diff --check`, `git status --short`, and `git diff --name-only` were
  checked, together with the new untracked report and the tracked candidate
  diff, including comparisons with the preserved resumption copies. Baseline
  SHA-256 checks confirm every other tracked file is unchanged; separate
  resumption hashes confirm the updated 89F checkpoint and approved resolution
  input are unchanged by this work.
  Only the candidate and this audit record are implementation artifacts of
  this slice. No runtime, test, fixture, application, governing document,
  roadmap, or handoff change occurred.

These passing checks establish preservation and documentation integrity.
U1's resolution comes from the approved design and its consistency review,
not these regression results. They do not establish the future family model's
implementation correctness.

## Remaining boundary

The whole-candidate 89F audit is complete with C1–C6 preserved and the approved
U1 amendment adopted and rechecked. No material issue remains unresolved in
this audit. The candidate itself remains incomplete and non-normative;
checkpoint 89 as a whole is not complete or implementation-ready.

The implementation roadmap, durable handoff, and atomic ratification into
`SPEC.md` remain later 89-series work. The candidate's existing boundaries
agree with [D10 sequencing][sequence]: specify before implementing new forms,
carry checked decisions before family execution, preserve semantic guards
through staged migration, stabilize reflection/case before Gel migration,
remove the legacy bridge, and require application evidence before completion.
This report allocates no checkpoint sequence or implementation work.

Later substantive edits require review of affected conclusions before
ratification. No source acceptance, runtime feature, executable family test,
fixture, migration, roadmap, handoff, or
normative change is introduced here. Stop for review without committing.

[candidate]: unified-nominal-adts-spec-candidate.md
[archive]: ../archive/unified-nominal-adts.md
[u1-decision]: unified-nominal-adts-reflection-resolution-proposal.md
[updated-89f]: checkpoints/0089f-audit-unified-family-design.md
[spec]: ../SPEC.md
[cp88]: checkpoints/0088-seal-typed-host-boundary.md
[gel-doc]: gel.md
[d1]: ../archive/unified-nominal-adts.md#decision-1-ontology
[d2]: ../archive/unified-nominal-adts.md#decision-2-construction-and-type-objects
[d3]: ../archive/unified-nominal-adts.md#decision-3-messages-and-refinement
[d4]: ../archive/unified-nominal-adts.md#decision-4-elimination-and-exhaustiveness
[d5]: ../archive/unified-nominal-adts.md#decision-5-generics-and-recursion
[d6]: ../archive/unified-nominal-adts.md#decision-6-open-protocols-and-closed-data
[d7]: ../archive/unified-nominal-adts.md#decision-7-runtime-behavior
[d8]: ../archive/unified-nominal-adts.md#decision-8-reflection
[d9]: ../archive/unified-nominal-adts.md#decision-9-concrete-syntax
[d10]: ../archive/unified-nominal-adts.md#decision-10-static-and-implementation-consequences
[constructor-syntax]: ../archive/unified-nominal-adts.md#constructor-declarations
[inference]: ../archive/unified-nominal-adts.md#generic-inference-and-elaboration
[guardrails]: ../archive/unified-nominal-adts.md#cross-decision-guardrails
[reflective-invocation]: ../archive/unified-nominal-adts.md#reflective-invocation
[reflection-apps]: ../archive/unified-nominal-adts.md#application-consequences
[applications]: ../archive/unified-nominal-adts.md#validation-applications
[transition]: ../archive/unified-nominal-adts.md#source-language-transition
[compatibility]: ../archive/unified-nominal-adts.md#compatibility-boundary
[raw-archive]: ../archive/unified-nominal-adts.md#raw-printing-and-user-display
[raw-syntax]: ../archive/unified-nominal-adts.md#raw-rendering-syntax
[negatives]: ../archive/unified-nominal-adts.md#required-negative-tests
[completion]: ../archive/unified-nominal-adts.md#completion-criteria
[sequence]: ../archive/unified-nominal-adts.md#safe-checkpoint-sequence
[expressions]: unified-nominal-adts-spec-candidate.md#1-preserved-expression-model
[markers]: unified-nominal-adts-spec-candidate.md#reserved-word-scopes
[declarations]: unified-nominal-adts-spec-candidate.md#declaration-grammar
[case-coverage]: unified-nominal-adts-spec-candidate.md#coverage-and-validity
[types]: unified-nominal-adts-spec-candidate.md#source-types
[headers]: unified-nominal-adts-spec-candidate.md#explicit-send-type-headers
[refinements]: unified-nominal-adts-spec-candidate.md#shallow-constructor-refinements
[recursion]: unified-nominal-adts-spec-candidate.md#6-direct-regular-recursion
[protocols]: unified-nominal-adts-spec-candidate.md#7-protocols-and-additive-extensions
[checked]: unified-nominal-adts-spec-candidate.md#8-checked-programs-and-elaboration
[closure]: unified-nominal-adts-spec-candidate.md#inference-closure-and-source-aliases
[equality]: unified-nominal-adts-spec-candidate.md#12-kernel-equality
[reflection]: unified-nominal-adts-spec-candidate.md#14-family-aware-reflection
[mirror-boundary]: unified-nominal-adts-spec-candidate.md#mirror-boundary-and-receiver-view
[invocation]: unified-nominal-adts-spec-candidate.md#checked-exact-row-invocation-and-generics
[mirrored-invocation]: unified-nominal-adts-spec-candidate.md#invocation-with-mirrored-arguments-and-result
[gel-examples]: unified-nominal-adts-spec-candidate.md#gel-invocation-through-mirrors
[mirrored-validation]: unified-nominal-adts-spec-candidate.md#mirrored-invocation-and-gel-inference-closure
[host]: unified-nominal-adts-spec-candidate.md#15-specialized-built-ins-and-typed-host-integration
[diagnostics]: unified-nominal-adts-spec-candidate.md#18-diagnostics-and-detection-boundaries
[hand-check]: checkpoints/0088-seal-typed-host-boundary.md#hand-check
