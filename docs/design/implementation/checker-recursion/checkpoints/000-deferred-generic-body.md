# checker-recursion 000 — Terminate deferred generic body checking

**Status: Withdrawn. Not an assignment.**

If you have been told to read this file, stop. The completion
discussion withdrew this proposal as a predecessor. The assignment
is [`../../aloemacs/completion/charter.md`](../../aloemacs/completion/charter.md).
Do not implement this repair. The text below is the withdrawn
proposal and is not a locked contract.

## Goal

Make finite ordinary recursion on a legacy generic `(fields ...)` class
finish type checking. When a method body is already being checked for
the same receiver and method instantiation, a recursive back edge must
use its checked declared signature without re-entering that body. Its
send still checks the receiver, selected overload, arguments, inferred
method parameters, and result normally. The outer body remains checked
against its declared return type, including all branches.

Stop with this private checker repair and its regression proof. Do not
implement completion, change its algorithm or constructor fixtures,
amend language law, or add another checkpoint.

## Authority, identity, and starting point

This is a standalone checkpoint with no separate spec. The implementer
receives this file and the authority it names; the transcript and the
temporary reproduction are not additional rules.

- Identity is **checker-recursion 000**. No predecessor in this series.
  Do not renumber aloemacs-completion 000 or take a global integer.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../workflow.md),
  [`SPEC.md`](../../../../../SPEC.md), and
  [`CHECKPOINTS.md`](../../../../../CHECKPOINTS.md) before coding.
  SPEC §§3.1/3.4/5 govern classes, method-local types, overloads,
  generics, nominal checking, and sends. This checkpoint restores
  existing behavior without changing those rules.
- [aloe/type.rkt](../../../../../aloe/type.rkt) is the starting point.
  `check-class-definition!` ordinarily defers method bodies for generic
  classes using `(fields ...)`. `infer-instance-send` selects a method
  and unifies its arguments, derives its result, then calls
  `check-method-body!` for those legacy generic instances.
- `check-method-body!` builds self/parameter bindings and checks the
  complete body against the declared return. Recursive instance sends
  currently re-enter that body with no in-progress check. Preserve the
  single body-check path rather than adding a second checker.
- [editor expression-query spec](../../../../editor/expression-query/spec.md)
  §5 and [rigid generic-body checkpoint](../../../../editor/expression-query/checkpoints/002-rigid-generic-body.md)
  remain authority for selected deferred bodies, symbolic class/method
  parameters, complete-file failure, and suppression of captures beneath
  ordinary concrete instantiation. The observer implementation lives in
  [aloe/private/checker-observation.rkt](../../../../../aloe/private/checker-observation.rkt);
  preserve its hooks and contracts without editing that module.
- [aloemacs-completion 000](../../aloemacs/completion/checkpoints/000-complete-on-tab.md)
  is the blocked consumer, not this checkpoint's implementation scope.
  Its accepted spec §3.3 requires scans/folds as ordinary session methods
  on `(AloemacsSession H)`; its file scope excludes `aloe/`.

## Confirmed reproduction

The manager ran the following capability-free Racket program from
`/tmp/aloemacs-completion-recursion.rkt` on 2026-10-04:

```racket
#lang racket/base
(require (file "/home/dharmatech/journal/2026-09-02-aloe-racket/aloe/driver.rkt"))
(define st (make-driver))
(define (scan-class name)
  `(define-class ,name
     (fields (payload H))
     (methods
       (scan (text String) (offset Int) Int
         (if (offset >= (text len)) offset
             (self scan text (offset + 1)))))))
(driver-eval! st
  '(define-class PlainScan
     (fields)
     (methods
       (scan (text String) (offset Int) Int
         (if (offset >= (text len)) offset
             (self scan text (offset + 1)))))))
(displayln (driver-eval! st '((PlainScan new) scan "/cwd/" 0)))
(driver-eval! st (scan-class '(GenericScan H)))
(displayln "checking the same scan on a generic receiver")
(displayln (driver-eval! st '((GenericScan new 1) scan "/cwd/" 0)))
```

Command: `TMPDIR=/tmp timeout --signal=INT --kill-after=2s 6s racket
/tmp/aloemacs-completion-recursion.rkt` (one shell command). The plain
scan printed `5`; the generic scan printed no result and was interrupted
with exit 124. The interrupted stack repeatedly alternated
`infer-instance-send` and `check-method-body!`, through normal expression
and Bool-branch inference. The Int payload eliminates a host-capability
dependency. This is evidence of the checker defect, not a performance
benchmark or a test of filesystem/Term behavior.

Preserve the reproduction in the new focused test using repository
runtime paths and checked driver/checker entry points; acceptance must
not depend on the temporary file still existing.

## Exact file scope

### May edit or create

- `aloe/type.rkt`: only private tracking of method-body checks in progress
  and the minimal integration into the existing body-check/send paths.
  Keep its public exports, method lookup, generic deferral, nominal type
  representation, observer hooks, and errors intact. Small private
  helpers/data for tracking are allowed in this file.
- Create `tests/checker-recursion/000-deferred-generic-body.rkt` before
  the product edit. It owns all new regression, soundness, and observer
  coverage using existing public driver/checker APIs and existing query
  observation seams. Use `rackunit` and bundled Racket facilities only.

### Must leave untouched

- All other `aloe/` modules, including parser, evaluator, driver, host,
  signature catalog, expression/completion queries, and the private
  checker-observation module. Add no public export or new production
  module/dependency.
- All existing tests. Add proof in the focused file; do not loosen
  generic/overload/host/query expectations to obtain a pass.
- `lib/`, `examples/`, `host/`, `gel/`, `bin/`, and all completion
  product/tests/design files during this implementation.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, and this checkpoint's
  documents during implementation.

If another product file, new language decision, or larger checker
redesign is needed, stop and return the finding to the prerequisite
manager. Do not widen the repair or fold it into completion 000.

## Required checker behavior

1. Track checks **in progress**, with lifetime limited to the active
   checking call chain. Do not add a persistent completed-body cache,
   global success flag, or cross-program/driver memo. Success, failure,
   and breaks must leave no active marker behind.
2. Re-entry is identified by the actual class/method declaration and
   the relevant receiver and method-local type instantiation. Distinct
   overloads, class objects, class arguments, method-local arguments,
   rigid parameters, and nominal host interface identities must not be
   collapsed by a selector/name, `type->datum`, or diagnostic strings.
   Resolve inferred type bindings using existing checker semantics;
   recognizing a back edge must not invent new unifications.
3. On a matching active body check, avoid body re-entry only. Keep normal
   overload choice, arity/type checks, method-local inference, and declared
   result typing for that send. A different method/instantiation reached
   along a recursive path still receives its own body check.
4. The owning body still checks every expression/branch and its declared
   return. A recursive path cannot hide an unknown selector, wrong
   argument, invalid helper/overload, or incompatible return in a branch
   runtime does not take. Errors remain `exn:fail:aloe-type?` through
   the current error paths, not runtime evaluation or timeout success.
5. Preserve ordinary deferral: an unused bad body in a legacy generic
   fields class is not checked eagerly just to remove recursion. An
   actual concrete send to that body still rejects it. Non-generic,
   explicit-constructor generic, and built-in library body-check policy
   retain their current behavior.
6. Use the existing `check-method-body!` path for concrete instantiation
   and targeted rigid declaration checks. Preserve the observation
   suppression beneath concrete checking and the complete-file failure
   policy. A selected recursive body must terminate in its symbolic
   declaration context; later concrete uses cannot replace its answer.
   Unrelated unused deferred bodies remain unforced.
7. Same-instantiation direct recursion and finite mutual method cycles
   must terminate checking. This repair does not introduce a general
   solver for recursive expansion into ever-new generic types. If the
   bounded contract cannot be met without such a solver or changing
   language acceptance outside this defect, return the design finding.

The mechanism is a private checker implementation choice. Do not change
the runtime recursion algorithm, special-case AloemacsSession or the scan
selector, reject all recursion, globally suppress generic body checks,
or require application code to move to a nongeneric helper.

## Focused proof, written first

Add the focused file before editing `aloe/type.rkt`. Observe the missing
termination on the generic case while the plain control succeeds.
Use a bounded worker/custodian or equivalent bundled Racket facility so
the regression fails cleanly rather than hanging `raco test`; clean up
the worker on timeout or failure. A generous termination bound is only
a liveness guard, not a speed threshold. Assert actual returned types,
values, and expected exceptions independently of that guard.

Prove all of these:

1. The exact plain/generic finite scan has checked type Int and result
   `5`, including an empty string and repeated checks/sends. Pure
   `type-of` or `typecheck-program` also terminates without evaluating
   the recursive method. Default drivers stay capability-free.
2. A two-method mutual cycle on the same generic receiver terminates
   checking and evaluates a finite countdown. Recursion via another
   same-instantiation instance is recognized too; self identity is not
   a runtime-value shortcut.
3. The generic scan works with at least two concrete class arguments,
   and a recursive method-local `(type U)` example retains separate
   Int/String instantiations on the same class instance type. Check
   result types and values, not only lack of a timeout.
4. Ill-typed recursion is rejected: wrong argument/arity; a mismatched
   declared result in an unselected branch; a bad helper in a mutual
   cycle; and an invalid overload reached by an otherwise valid
   recursive overload. Overload declaration order/specificity and
   ordinary ambiguity behavior remain unchanged.
5. A valid generic instantiation does not mask an invalid different
   instantiation in the same driver or nested checking path. Cover a
   body whose operation is legal for one payload type and illegal for
   another. Distinct nominal host descriptors with the same diagnostic
   name retain the existing identity rules; a counted host must never
   be executed by checking.
6. Error unwind leaves no marker: check the same invalid recursive
   body again and observe the same type failure, then check a valid
   recursive body in that driver. Separate drivers/classes sharing a
   source name remain independent. No success/error result becomes a
   persistent cache that skips future checks.
7. An unused bad legacy generic body remains deferred in ordinary
   checking; sending to it rejects it. Preserve non-generic and explicit
   constructor recursion controls and ordinary List/String/Int methods.
8. Observe a selected expression inside a recursive legacy generic
   method through the existing observation seam: symbolic class and
   method-local types remain symbolic after later Int/String uses;
   an unrelated bad deferred body remains unforced; a later real type
   error still invalidates the observation. Include selector-receiver
   observation so completion's existing checker seam remains intact.

Reuse patterns from the existing generic, nominal host, and rigid-body
query proofs without requiring another test module or adding special
production instrumentation. Do not write or resurrect the completion
feature tests as part of this prerequisite.

## Verification and completion

Before product edits, capture the focused missing-behavior failure and
the current wider-suite baseline. After the repair, run from the root:

```sh
TMPDIR=/tmp raco test -y tests/checker-recursion/000-deferred-generic-body.rkt
TMPDIR=/tmp raco test -y tests/checkpoint-9.rkt tests/checkpoint-10.rkt tests/checkpoint-17.rkt tests/checkpoint-93.rkt tests/checkpoint-95.rkt tests/checkpoint-99.rkt
TMPDIR=/tmp raco test -y tests/editor/expression-query tests/editor/completion tests/editor/signatures-of-type
TMPDIR=/tmp raco test -y tests/aloemacs
TMPDIR=/tmp raco test -y tests
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test command. Do not commit
`compiled/`. The full recursive suite is required because a checker
change reaches language, host, library, application, and editor callers.
Do not repair unrelated baseline failures in this slice; report exact
paths/results and return them for review if they prevent a green stop.
Historical test counts/failures in older documents are not a current
baseline. No physical TTY, benchmark, launch, dependency install,
commit, push, or merge is required.

Review source as well as results: private active-check tracking has
bounded lifetime and preserves instantiation/nominal identities;
ordinary send matching still runs; the outer body and each newly reached
method/instantiation are checked; error cleanup holds; deferral and
observer rules remain intact. There is no public API or language change,
no completed-result cache, and no application-specific exception.

Complete when the focused and named regression suites are green,
`git diff --check` is clean, structural review passes, and exact scope
is respected. Report the original focused failure, changed files,
verification, and any baseline issue. Stop for human review. Do not
resume completion 000 or issue completion 001. After this repair is
reviewed, its manager returns the evidence to the completion manager,
who rechecks 000 readiness and keeps its full original acceptance bar.
