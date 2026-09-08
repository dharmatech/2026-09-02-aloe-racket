# Checkpoint 0088 — Seal the typed host boundary

Status: Proposed

Depends on checkpoints 0083–0087.

## Goal

Close the typed host-capability experiment by recording its accepted design in
Aloe's canonical documentation and pinning down its deliberately small public
surface.

This checkpoint changes no language or runtime behavior.  It adds no new host
mechanism.  If the documentation audit exposes a real mismatch between the
accepted design and production behavior, stop and propose a separate addendum
rather than repairing that behavior inside this checkpoint.

After this checkpoint is accepted, review the experiment branch as a whole
before deciding whether to merge it.  Do not begin filesystem capability work
in the same change.

## Canonical specification

Add a concise normative typed-host-capability section to `SPEC.md`.  It must
record the boundary that now exists:

- a host capability is a Racket-created receiver that is explicitly injected
  into a driver;
- a `host-interface` is an opaque nominal identity containing ordered,
  uniquely selected `host-method` declarations;
- one host-method declaration supplies its selector, fixed parameter types,
  return type, and Racket implementation;
- the only crossing types are `Int`, `Bool`, and `String`;
- Strings are normalized to immutable values in both crossing directions;
- arguments are validated before the implementation and results afterward;
- implementation failures receive consistent Aloe host-failure context while
  retaining their Racket causes, and breaks pass through;
- the checker derives sends from the same exact interface identity used at
  runtime;
- driver injection preflights and installs the runtime and checker bindings as
  one logical operation without overwriting existing names;
- host interface names are diagnostic but are not source-written Aloe type
  names;
- Mirror messages, signatures, type data, ownership, and exact-row invocation
  derive from the same descriptor; and
- default environments contain no optional capability.

Keep this section at the level of Aloe's observable and architectural
contract.  Do not copy constructor validation algorithms, Racket module names,
or the checkpoint-by-checkpoint implementation history into the language
specification.

The source type grammar must continue to omit `Term` and arbitrary host
interface names.  Make that omission explicit rather than silently expanding
the grammar.

Also state the hard exclusions: there is no arbitrary Racket call, Racket
evaluation, namespace access, dynamic library surface, ambient capability, or
second send/evaluation rule.

## Decisions and philosophy

Update `docs/decisions.md` with one dated decision for typed host capabilities.
It should capture:

- why a nominal descriptor was chosen as the single source of truth;
- why injection is explicit and paired through the driver;
- why the initial crossing vocabulary is only the three scalar types;
- why reflected signatures use exact interface ownership and the ordinary
  guarded invocation core; and
- why source-written host types, opaque handles, and a comprehensive FFI remain
  deferred.

Revise the earlier terminal-input text that still says `(term read-key)` may be
added later.  It should now describe Term as the first optional capability and
both terminal runners as checked, explicitly injected clients.

Add a short host-boundary principle to `docs/philosophy.md`: Racket supplies
irreducible host facts and effects, while Aloe owns domain objects, application
policy, and composition.  Capabilities are explicit values rather than ambient
kernel powers.

Do not turn either document into an API reference or speculate about a future
filesystem shape.

## Checkpoint index

Append concise entries to `CHECKPOINTS.md` for:

- 83 — validated host declarations;
- 83A — exact positional implementation call shape with no keywords;
- 84 — guarded descriptor-driven runtime sends and the production Term
  interface;
- 85 — nominal checker types and atomic driver injection;
- 86 — checked optional terminal runners;
- 87 — descriptor-driven host reflection and exact-row invocation; and
- 88 — canonical documentation and public-surface sealing.

These entries summarize accepted outcomes, matching the compact style of the
existing checkpoint index.  Do not paste the full checkpoint specifications
into `CHECKPOINTS.md`.

Historical files under `docs/checkpoints/` retain the scope and deferrals that
were true at each stage.  Do not rewrite their status or provisional language
to make earlier checkpoints read as though later work already existed.

## Gel documentation

Bring the factual current-state portions of `docs/gel.md` up to date:

- Term has one descriptor-defined runtime and checker shape;
- the evaluator and checker both consume the injected capability;
- `term-run.rkt` and `gel-run.rkt` use checked driver injection;
- `Mirror`, `Signature`, and exact-row invocation now exist; and
- Gel domain policy remains implemented in Aloe around the small Term effect.

Remove or revise stale statements that call Gel or reflection future work,
including the old “Eval will send” and deferred ask-API descriptions.  Remove
obvious duplicate lines encountered in those same sections.

Keep future filesystem, process, Git, and shell-personality prose explicitly
exploratory.  Do not choose selectors, types, handles, object boundaries, or
policy for those capabilities in this checkpoint.

## Public and internal surfaces

Document the intended Racket-facing surface without changing it.

The ordinary public host declaration API consists of validated constructors,
predicates, and safe accessors for methods, interfaces, and receivers; the
receiver send operation; and recognition/access to the retained cause of an
Aloe host failure.

The following remain unavailable from the primary public modules:

- raw `host-method`, `host-interface`, and `host-receiver` constructors;
- receiver state access;
- the raw host-failure constructor;
- the checker's host-receiver type constructor, predicate, and interface
  accessor;
- the checker injection hook; and
- the evaluator's exact-host-method invocation hook.

The last two operations may remain in their narrowly named internal submodules
for the driver and evaluator.  “Private” here means absent from the ordinary
module surface; it does not require inventing a stronger Racket encapsulation
mechanism.

The host-method implementation accessor remains Racket-facing declaration
data used by the boundary.  It is never exposed as an Aloe value.  Do not
remove or conceal required Racket-side declaration accessors merely to make a
negative export test broader.

## Tests

Add `tests/checkpoint-88.rkt` as a compact sealing test rather than repeating
all behavioral matrices from checkpoints 0083–0087.

Cover at least:

- the intended top-level host constructors, predicates, accessors, send
  operation, and failure inspection operations remain exported;
- `driver-inject-host!` and the production `term-interface` remain exported;
- each raw constructor, receiver-state accessor, raw failure constructor,
  checker host-type operation, checker injection hook, and exact-method hook
  listed above is absent from its primary public module;
- the two internal hooks remain reachable only through their existing narrow
  submodules so the driver and evaluator architecture is not accidentally
  severed;
- a fresh driver has no `term` binding in either environment;
- the ordinary driver, main entry point, and `bin/aloe` contain no dependency
  on `host/racket/term.rkt` or `tui/term` and do not inject Term;
- the production host and terminal modules contain no legacy `host-message`,
  synthetic `HostTerm`, or `make-term-type-environment` path; and
- one small injected Term send still succeeds, demonstrating that the sealed
  public route is usable.

Use behavioral `dynamic-require` checks for public exports where practical.
Restrict source/dependency assertions to the architectural absences that
cannot be observed reliably through ordinary execution.  Do not assert every
line or every export of a module.

All existing boundary, Term, runner, reflection, Gel, Boids, and MPL tests must
remain green.

## Hand check

The final public route should remain sufficient:

```racket
(require "aloe/driver.rkt"
         "host/racket/term.rkt")

(define output (open-output-string))
(define state (make-driver))
(driver-inject-host!
 state 'term (make-term-receiver output (lambda () "unused")))

(list (driver-eval! state '(term write-line "sealed"))
      (get-output-string output))
```

Expected result:

```racket
'("sealed" "sealed\r\n")
```

## Acceptance

This checkpoint is complete when the canonical specification, decisions,
philosophy, checkpoint index, and current Gel documentation agree with the
implemented typed host boundary, and the small public-surface test protects
its intended seams.

Production `.rkt` and Aloe source files should have no behavioral changes in
this checkpoint.  Documentation wording and the new sealing test are the only
expected edits.

Run checkpoint 0088, the full suite, the hand check, and `git diff --check`.
All must pass.  Stop for review without committing, merging, or beginning a
new capability.

## Explicit non-goals

- Do not change runtime dispatch, checking, injection, validation, errors, or
  reflection.
- Do not change the public API or move the two existing internal hooks.
- Do not update historical checkpoint documents to erase staged decisions.
- Do not add `Term` or any host interface name to source type syntax.
- Do not add crossing types or opaque host handles.
- Do not design or implement a filesystem API.
- Do not add a capability registry, dynamic loader, plugin system, or general
  FFI.
- Do not add ambient namespace or terminal access.
- Do not change Term behavior, runner behavior, Gel policy, Boids, or MPL.
- Do not commit, merge, tag, or delete the experiment branch.
