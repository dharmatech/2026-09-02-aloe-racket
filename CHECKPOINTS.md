# Aloe 0.1 checkpoints

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

## 89. [Proposal B documents](docs/checkpoints/0089-class-constructors-docs.md) (documentation only)

## 90. [Parse constructors and case](docs/checkpoints/0090-parse-constructors-and-case.md)

- Explicit `(constructors ...)` class sections and receiver-anchored `case`
  forms parse into dedicated AST nodes; runtime and type semantics remain
  deferred.

## 91. [Constructor id on instances](docs/checkpoints/0091-instance-constructor-id.md)

- Every runtime instance records its constructor identity; existing
  `(fields ...)` classes and reflected construction record `new`.

## 92. [Evaluate case](docs/checkpoints/0092-eval-case.md)

- `case` switches on an instance's stored constructor identity, binds its
  payload in field order, and evaluates only the matching clause or `else`.

## 93. [Constructor sets and case checking](docs/checkpoints/0093-check-constructors-and-case.md)

- The checker records constructor sets, validates exhaustive `case` clauses,
  and infers generic constructor arguments from payloads and expected types.

## 94. [Named construction and Option goldens](docs/checkpoints/0094-option-goldens.md)

- Class objects install their constructor sets, named construction records the
  selected constructor and payload, and the Proposal B `Option` goldens run.

## 95. [Tree golden](docs/checkpoints/0095-tree-golden.md)

- Recursive constructor payloads preserve generic arguments, and exhaustive
  `case` methods recurse over `Tree` instances through ordinary sends.

## 96. [Ratify class constructors into SPEC](docs/checkpoints/0096-ratify-class-constructors.md) (documentation only)

- Proposal B's constructor sets, named construction, `case`, and generic
  inference rules are normative in `SPEC.md`; Proposal A remains rejected on
  this branch.

## 97. [Integrate typed host boundary](docs/checkpoints/0097-integrate-typed-host-boundary.md)

- `experiment/host-boundary` merges sealed host checkpoints 83–88 from
  `main` onto constructor checkpoints 89–96. Crossing remains
  `Int`/`Bool`/`String`. No filesystem capability.

## 98. [(List String) host crossing](docs/checkpoints/0098-list-string-crossing.md)

- Homogeneous `(List String)` is a host crossing type. Host `names` can
  return a list of strings. Nested lists and other `(List T)` forms are
  not crossing types. No filesystem capability.

## 99. [Generic host-type retention](docs/checkpoints/0099-generic-host-type-retention.md)

- Confirmed that a generic field retains an injected host-receiver type, so a
  wrapper like `(Fs new fs-host)` typechecks without source-written host names;
  no checker or evaluator change was required.

## 100. [Option library](docs/checkpoints/0100-option-library.md)

- `lib/option.aloe` is a loadable Option class (`None` / `Some`,
  `present?`, exhaustive `case`). Tests load it. It is not bootstrapped by
  `make-driver`. No filesystem capability.

## 101. [Filesystem host interface and test double](docs/checkpoints/0101-filesystem-host-double.md)

- Optional `fs-host` capability with one `FsHost` interface and a
  test double. Crossing values only. Default drivers do not get it.
  No production disk I/O. No `Path` / `Entry` / `Fs`.

## 102. [Production filesystem host](docs/checkpoints/0102-filesystem-host-production.md)

- Production `make-fs-receiver` shares the `FsHost` interface with
  the test double. Isolated temp-directory goldens. Default drivers
  still have no `fs-host`. No `Path` / `Entry` / `Fs`.

## 103. [Path and Fs path algebra](docs/checkpoints/0103-fs-path-algebra.md)

- `lib/fs.aloe` defines `Path` and generic `Fs`. Public `current`,
  `path`, `child`, `parent`, and `name` wrap `fs-host`. Parent at
  root is `None`. No `Entry`, `inspect`, or `entries`.

## 104. [Entry, inspect, and entries](docs/checkpoints/0104-fs-entry-and-listing.md)

- `lib/fs.aloe` adds `Entry` and `Fs` `inspect` / `entries`. Mixed
  listings are `(List Entry)` with exhaustive `case`. Absence is
  `None`. No file-text reading. No Gel UI.
