# Aloe checkpoints

> **GOVERNING IMPLEMENTATION ORDER — 89I RATIFICATION CHANGE SUBMITTED FOR REVIEW**
>
> [SPEC.md](SPEC.md) defines the unified target; runtime behavior remains
> complete through checkpoint 88. Acceptance of 89I completes the design and
> documentation arc. Future entries are planned, not completed or blanket
> authorization. 90A needs its own checkpoint document and authorization.

The [accepted roadmap](docs/unified-nominal-adts-implementation-roadmap.md)
supplies detailed prerequisites, allocation rationale, and evidence. The
[implementation handoff](docs/unified-nominal-adts-implementation-handoff.md)
explains how to work from repository files. This index governs their order.

## Historical implementation through 88

The entries and original discipline below retain their stage-specific
terminology, including classes, generated `new`, and early reflection behavior.
They describe completed historical slices, not the target grammar. Their bare
SPEC section references refer to the pre-ratification document at
`616c0ceecd7d52d7f9c3e2c4df89e9037ed57aaa`.

> Checkpoints 12–52 live as `tests/checkpoint-N.rkt`; the original 1–11
> implementation sequence remains below unchanged.

Work one checkpoint at a time. Each ends when `raco test` is green and you have run one expression by hand. Do not start Boids until checkpoint 11.

Rules for every slice:

- One feature.
- Tests live in the same change.
- Never treat list head as a function. `(f x)` is a send of selector `x` to `f`.
- `let` desugars to `(fn … call …)`, nothing else.
- Stop and wait for review when a checkpoint is green.

## 1. Reader + atoms

`1`, `1.0`, bound symbol lookup. No sends.

## 2. Send skeleton

`(r sel)` on a dummy object errors `unknown message`. Selector is not evaluated.

## 3. `define-class` + `new` + field read

Non-generic `Point` is enough.

```text
(Point new 1 2)
((Point new 1 2) x)    ; => 1
```

## 4. Method send + `self`

```text
((Point new 1 2) + (Point new 3 4))    ; => (Point new 4 6)
```

## 5. Numbers as objects

```text
(1 + 2)          ; => 3
(3.0 * 4.0)      ; => 12.0
(1 + 2.0)        ; type/runtime error — no mix
```

## 6. `fn` + `call`

```text
((fn (x) (x + 1)) call 2)    ; => 3
((fn (x) x) 2)               ; illegal (2 would be the selector)
```

## 7. `let`

Parallel bindings. Must expand to `call`.

## 8. `List of` / `len` / `map` / `fold`

Monomorphic list is enough.

## 9. Generics

`(Point T)`, infer `T` from `new`. `(Point new 1 2.0)` fails.

## 10. Type checker on 1–9

Accept the must-run goldens in `SPEC.md` §9. Reject the five must-fail programs.

## 11. Boids

Load `examples/boids.aloe`. Typecheck. Evaluate `(demo step)` twice.
`len` is `Int`; divide points by `(n float)`, not `n`.

## 52. `check` + MPL identities workbook

`(check left right)` compares same-typed values, returns the right value on
success, and reports both source datums and displayed values on failure.
`examples/mpl/identities.aloe` records the established MPL show-identities.

## 53. MPL identities use normalized value equality

## 54. `Symbol`

- Primitive interned names support `(Symbol intern String)`, `(sym name)`, and
  `(sym = other)`; selectors remain implicit and `perform` is not implemented.

## 55. `Mirror` + `messages`

- `(Mirror of value)` reflects a value and `(mirror messages)` returns its
  unique `(List Symbol)` selectors; `signatures` and `invoke` are not included.

## 56. `Signature` + `(mirror signatures)`

- `(mirror signatures)` returns one kernel-created `Signature` per dispatch
  row. `selector`, `params`, and `return` expose the row as `Symbol`/`List`
  type-grammar data; `invoke` remains deferred.

## 57. `(mirror invoke signature argument ...)`

- `Mirror.invoke` checks the signature owner, arity, argument types, and result
  type, then runs that exact dispatch-table row without resolving its selector
  again; `perform` remains absent.

## 58. Gel menu rows in Aloe

- `gel/menu.aloe` turns any value's reflected signatures into ordered,
  one-based `GelRow` menu data; keyboard input, the stack loop, and send
  building remain deferred.

## 59. Gel `(List Mirror)` stack + zero-argument invoke

- `gel/stack.aloe` stores one mirror per stack slot, treats `first` as TOS,
  and invokes an arity-zero `GelRow` before pushing its mirrored result;
  subject unwrapping and argument builders remain deferred.

## 60. `(mirror subject)`

- `(mirror subject)` returns the value held by a `Mirror`; its checker result
  is the expected type when available and otherwise a fresh type variable.

## 61. One-argument Gel invoke from the stack

- `(gel-invoke-one call stack row argument)` invokes the row against the TOS
  mirror, unwrapping a mirrored argument with `subject`, then pushes the
  mirrored result.

## 62. Pure Gel key step

- `(gel-handle-key call stack key)` maps `"q"` and digit strings in Aloe;
  digits select arity-zero reflected rows, while TTY input remains a host skin.

## 63. Gel menu text + runner

- `(gel-menu-text call value)` formats indexed selector/arity rows in Aloe;
  `host/racket/gel-run.rkt` is the thin interactive TTY skin.

## 64. `(term write-line String)`

- The injected `term` receiver writes a `String`, CRLF, and a flush using
  Racket `display`, then returns the original string; it is not a tui-term API.

## 65. `gel-main` in Aloe

- `gel/main.aloe` prints menus, reads `String` keys, steps, and recurses;
  `host/racket/gel-run.rkt` only injects `term`, loads Gel, and starts it.

## 66. Print Gel TOS from Aloe

- `(gel-tos-text call stack)` builds a `String` containing `TOS` and a
  subject presentation; `gel-main` writes it before the unchanged menu.

## 67. One-argument Gel keys from the stack

- Selecting an arity-one row uses the subject of the mirror immediately under
  TOS as its argument; a one-item stack leaves the key as a no-op.

## 68. `(mirror raw)` + structural TOS text

- `(mirror raw)` returns the reflected subject's structural printer text;
  `gel-tos-text` prefixes that text with `TOS: ` and does not use `show`.

## 69. Pending arity-one sends + typed stack picks

- Selecting an arity-one row stores it in `GelStep.pending`; the pending menu
  numbers only stack mirrors accepted by that signature, and a second digit
  invokes with the chosen subject. Pending `q` cancels without quitting Gel.

## 70. Type an `Int` into a pending hole

- For an exact `Int` hole, digit keys accumulate `acc * 10 + digit` and
  `"return"` invokes with the entered value; stack picks are paused for that
  hole, while pending `q` cancels and discards the accumulator.

## 71. Echo Gel keys

- `gel-main` writes `key ` followed by every `String` received from
  `term read-key` before handling that key, including no-ops and quit.

## 72. Nominal `GelStack`

- `GelStack` owns the immutable `(List Mirror)` storage behind `items`, with
  `tos` and overloaded `push`; all Gel stack boundaries now use `GelStack`.

## 73. `GelStack` invocation

- `GelStack.invoke-zero` and the two `invoke-one` overloads invoke reflected
  rows against TOS and push their results; the callable helpers are removed.

## 74. Empty `GelStack`

- `gel-empty-stack` is the shared immutable starting stack; callers construct
  one- and two-item stacks with direct `push` sends instead of start wrappers.

## 75. `GelStep` key transitions

- `(step handle-key key)` and its transition methods live on immutable
  `GelStep` values; the stateless callable key handler is removed.

## 76. `GelKey`

- `GelKey` gives terminal text `digit-value`, `menu-index`, `quit?`, and
  `return?`; `GelStep` constructs one per public String key transition.

## 77. `GelRows` mirror overload

- `GelRows.call` builds rows in one exact `Mirror` overload; its generic
  overload reflects ordinary values and delegates, and the separate
  mirror-row callable is removed.

## 78. `GelRow` semantics

- `GelRow.expected-text`, `int-hole?`, and `accepts?` own pending-argument
  presentation, exact-Int detection, and mirror acceptance; the separate
  Int-hole callable is removed.

## 79. Nominal `GelPicks`

- `GelPicks` wraps the ordered `(List GelPick)` and owns `len` and valid-index
  `select`; matching and menu boundaries use it, and the separate pick
  selector callable is removed.

## 80. `GelStack.matching-picks`

- `GelStack.matching-picks` filters its mirror items through a `GelRow` and
  returns compactly indexed `GelPicks`; the stateless matching callable is
  removed.

## 81. `GelRows` operations

- `GelRows.of` constructs rows from ordinary values or exact mirrors, and
  `GelRows.select` owns valid-index lookup; the function-shaped `call` API and
  separate row selector callable are removed.

## 82. Unified `GelText` renderer

- `GelText.menu` renders ordinary values, mirrors, and Gel state, while
  `GelText.tos` renders the stack top; the separate menu/TOS renderers and
  function-shaped rendering sends are removed.

## 83. Validated host declarations

- Opaque nominal host interfaces contain ordered, uniquely selected method
  declarations over the fixed `Int`/`Bool`/`String` crossing vocabulary.

## 83A. Exact host implementation call shape

- Host implementations accept exactly one state argument plus their declared
  positional arguments, with no optional, variadic, or keyword call shape.

## 84. Guarded descriptor-driven host sends

- Runtime host sends validate both crossing directions through one descriptor;
  the production Term interface supplies `read-key` and `write-line`.

## 85. Typed atomic host injection

- A driver atomically injects a receiver and its nominal interface type, and
  the checker derives host sends from that exact descriptor identity.

## 86. Checked terminal runners

- The optional Term and Gel runners inject Term into one checked driver used
  for full-file checking and evaluation.

## 87. Descriptor-driven host reflection

- Host receivers use the existing Mirror and Signature protocol with nominal
  interface ownership and guarded exact-row invocation.

## 88. Seal the typed host boundary

- Canonical documentation records the accepted host-capability design, and a
  compact test seals its intended public and internal Racket surfaces.

## 89. Unified family design and documentation

89A–89H are accepted, including the completed U1 audit resolution and corrected
roadmap; their historical headers do not reopen those reviews. 89I is the
ratification change submitted for review. Its acceptance completes checkpoint
89, while implementation remains future work.

| Slice | Accepted outcome or current review boundary |
| --- | --- |
| [89A](docs/checkpoints/0089a-draft-family-language-core.md) | Language/static core drafted in the [historical candidate](docs/unified-nominal-adts-spec-candidate.md). |
| [89B](docs/checkpoints/0089b-draft-family-execution-model.md) | Checked execution, descriptors, transactions, and runtime values drafted. |
| [89C](docs/checkpoints/0089c-draft-family-reflection.md) | Exact family-aware reflection drafted. |
| [89D](docs/checkpoints/0089d-draft-builtins-and-host-integration.md) | Specialized built-ins and sealed typed-host integration drafted. |
| [89E](docs/checkpoints/0089e-draft-diagnostics-and-validation.md) | Diagnostics, exclusions, and validation catalogues drafted. |
| [89F](docs/checkpoints/0089f-audit-unified-family-design.md) | [Audit](docs/unified-nominal-adts-design-audit.md) completed with approved [U1](docs/unified-nominal-adts-reflection-resolution-proposal.md) adopted and rechecked. |
| [89G](docs/checkpoints/0089g-draft-family-implementation-roadmap.md) | [Corrected roadmap](docs/unified-nominal-adts-implementation-roadmap.md) accepted, including 90B ownership of the MPL observations. |
| [89H](docs/checkpoints/0089h-draft-family-implementation-handoff.md) | [Durable handoff](docs/unified-nominal-adts-implementation-handoff.md) accepted with no findings. |
| [89I](docs/checkpoints/0089i-ratify-unified-family-design.md) | Complete target promoted into SPEC, sequence into this index, and entry documents reconciled; ratification review pending. |

## Future family implementation

All 25 entries below are **planned and unimplemented**. Each requires the
preceding entry, hence all transitive prerequisites, plus the specific support
named in its linked roadmap entry. 90A requires accepted 89I ratification and
the accepted implementation handoff. Every entry also requires its own
authorized checkpoint document; no such future document is created by 89I.

Each implementation slice supplies relevant tests, runs the full
`raco test tests` suite and its required hand observation, and stops for review
when green. Test counts are not fixed. Every feature has its complete guards,
diagnostics, and exclusions from first admission; later forms stay rejected.
Preparatory checked/evidence work does not claim closure before atomic 91C.
Preserve List, numeric, host, and application contracts throughout; runtime
effects after successful checking are not rolled back. Historical test
migrations retain their valid purpose and internal defensive coverage.

| Planned entry and detailed roadmap | Prerequisite | Outcome and boundary |
| --- | --- | --- |
| [90A — Retain the static decisions needed by execution](docs/unified-nominal-adts-implementation-roadmap.md#90a--retain-the-static-decisions-needed-by-execution) | Accepted 89I and handoff | Retain source/alias provenance, checked send decisions, contextual obligations, and existing written/inferred function types; no production activation or new syntax. |
| [90B — Evaluate one checked source transaction](docs/unified-nominal-adts-implementation-roadmap.md#90b--evaluate-one-checked-source-transaction) | 90A | Evaluate checked transactions across driver/helpers, bootstrap, loads and runners. Migrate checkpoint 36's unchecked MPL concrete-field observations to checked contextual reflection here; static failure installs nothing or evaluates nothing. |
| [90C — Retain checked collection and function types in values](docs/unified-nominal-adts-implementation-roadmap.md#90c--retain-checked-collection-and-function-types-in-values) | 90B | Retain invariant List element types, including empties, and checked function arrows needed by exact validation; unresolved types supply no closed evidence. |
| [91A — Use one nominal model behind the legacy declaration bridge](docs/unified-nominal-adts-implementation-roadmap.md#91a--use-one-nominal-model-behind-the-legacy-declaration-bridge) | 90C | Replace the user nominal model with shared opaque identities and checked construction behind a source-only legacy bridge. Supply product integrity/equality/raw behavior and admitted single-claim/extension coherence immediately; migrate MPL raw goldens. |
| [91B — Seal reflected input evidence and exact signature authority](docs/unified-nominal-adts-implementation-roadmap.md#91b--seal-reflected-input-evidence-and-exact-signature-authority) | 91A | Seal retained family/List/function input types and exact owned rows, guards, roles/generics and enumeration before U1 is exposed; this is preparation, not universal closure. |
| [91C — Close production inference with usable mirrored invocation](docs/unified-nominal-adts-implementation-roadmap.md#91c--close-production-inference-with-usable-mirrored-invocation) | 91B | Activate invoke-mirrored, all three Gel helper rewrites, and source closure atomically. Migrate closure-sensitive reflection/empty-list observations and preserve internal defensive guards; no Gel exemption or unchecked production alternative. |
| [92 — Construct and use explicit product families](docs/unified-nominal-adts-implementation-roadmap.md#92--construct-and-use-explicit-product-families) | 91C | Admit non-generic explicit product families, fields/local/uniform rows and the validated uniform extension route; reject later generic/variant/case/factory forms. |
| [93 — Construct closed variants without representation leaks](docs/unified-nominal-adts-implementation-roadmap.md#93--construct-closed-variants-without-representation-leaks) | 92 | Admit non-generic closed variants and direct singleton payload access with integrity/equality/raw behavior and immediate exclusion of multi-constructor reflected locals. |
| [94 — Resolve generic sends across their enclosing expression](docs/unified-nominal-adts-implementation-roadmap.md#94--resolve-generic-sends-across-their-enclosing-expression) | 93 | Admit generic families, full send headers and fresh row parameters, with symmetric enclosing conditional constraints and invariance. Cover input-determined Some and insufficient None/Ok mirrored calls. |
| [95 — Preserve shallow refinement and restrict local authority](docs/unified-nominal-adts-implementation-roadmap.md#95--preserve-shallow-refinement-and-restrict-local-authority) | 94 | Propagate shallow aliases and joins, admit variant local methods, and enforce local authority and specified refinement loss points. |
| [96 — Eliminate families with fully checked explicit case](docs/unified-nominal-adts-implementation-roadmap.md#96--eliminate-families-with-fully-checked-explicit-case) | 95 | Admit exhaustive explicit case with symmetric checking of every branch, opaque clause identities, one scrutinee/selected branch, and generic Option map evidence. Defaults remain unavailable. |
| [97 — Cover residual constructors with an explicit default](docs/unified-nominal-adts-implementation-roadmap.md#97--cover-residual-constructors-with-an-explicit-default) | 96 | Admit only final nonempty-residual else, residual whole binding, and the same complete result/outer-refinement joins. |
| [98 — Execute complete per-constructor family bodies](docs/unified-nominal-adts-implementation-roadmap.md#98--execute-complete-per-constructor-family-bodies) | 97 | Admit complete per-constructor family body tables with singleton self and one reflected row; enforce full coverage and selector partitions. |
| [99A — Construct through ordinary declared factories](docs/unified-nominal-adts-implementation-roadmap.md#99a--construct-through-ordinary-declared-factories) | 98 | Admit ordinary declaration factories with type-object self, complete family-then-row instantiation and unrefined declared results; result-only U1 parameters fail before execution. |
| [99B — Extend family and type-object behavior atomically](docs/unified-nominal-adts-implementation-roadmap.md#99b--extend-family-and-type-object-behavior-atomically) | 99A | Admit full factory/uniform family extensions, staged and validated together without replacement, representation/local additions or conformance claims. Preserve List's existing route. |
| [100 — Validate multiple uniform family conformances](docs/unified-nominal-adts-implementation-roadmap.md#100--validate-multiple-uniform-family-conformances) | 99B | Admit native multiple uniform nominal conformances with full-domain, combined overload/result coherence and whole-unit finalization; revalidate MPL. |
| [101 — Construct and consume regular recursive families](docs/unified-nominal-adts-implementation-roadmap.md#101--construct-and-consume-regular-recursive-families) | 100 | Admit direct regular recursive payloads and validate Tree values, methods, nested case, equality and raw printing; reject changed self arguments, mutual/forward families. |
| [102 — Seal the complete family reflection surface](docs/unified-nominal-adts-implementation-roadmap.md#102--seal-the-complete-family-reflection-surface) | 101 | Seal all admitted family reflection surfaces together, including contextual hidden None, exact generic ownership, metadata, exclusions, Gel and host guards. |
| [103A — Migrate Point, Boids, and MPL sources](docs/unified-nominal-adts-implementation-roadmap.md#103a--migrate-point-boids-and-mpl-sources) | 102 | Migrate Point, Boids and MPL declarations/claims while preserving both Boids steps and MPL domain behavior; earlier checked/raw migrations stay with their owners. |
| [103B — Migrate Gel and the remaining repository-owned source](docs/unified-nominal-adts-implementation-roadmap.md#103b--migrate-gel-and-the-remaining-repository-owned-source) | 103A | Migrate Gel and every remaining repository-owned executable source, including embedded datums/strings, fixtures and tests. This changes nominal syntax, not Gel pending state. |
| [103C — Remove the source bridge and all legacy acceptance](docs/unified-nominal-adts-implementation-roadmap.md#103c--remove-the-source-bridge-and-all-legacy-acceptance) | 103B | Remove the 91A bridge and every public legacy acceptance path; reconcile active syntax documentation. No alias, fallback or migration switch survives. |
| [104 — Validate canonical ordinary Option and Result examples](docs/unified-nominal-adts-implementation-roadmap.md#104--validate-canonical-ordinary-option-and-result-examples) | 103C | Provide canonical ordinary Option/Result examples using the already established semantics; neither becomes a privileged built-in. |
| [105 — Replace Gel's pending sentinel with Option](docs/unified-nominal-adts-implementation-roadmap.md#105--replace-gels-pending-sentinel-with-option) | 104 | Replace Gel pending List sentinel with Option GelRow and validate exhaustive consumers and live TTY flows. Further state restructuring is optional when it clarifies the application. |
| [106A — Validate a closed filesystem classification](docs/unified-nominal-adts-implementation-roadmap.md#106a--validate-a-closed-filesystem-classification) | 105 | Validate ordinary closed filesystem classification, Other, local capabilities and exhaustive consumers/defaults; choose no OS API or expanded host crossing. |
| [106B — Seal the implemented unified model](docs/unified-nominal-adts-implementation-roadmap.md#106b--seal-the-implemented-unified-model) | 106A | Seal all preceding implementation and application evidence, including Point, both Boids steps, MPL, Option/Result, Tree, filesystem, Gel and Term. Reconcile final documentation and remove residual duplication; built-in rewrites remain optional. |
