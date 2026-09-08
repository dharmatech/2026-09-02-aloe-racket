# Checkpoint 99 — generic host-type retention

**Branch.** `experiment/host-boundary`

**Depends on.** Checkpoint 98 (`(List String)` crossing)

**Status.** Ready to implement

## Goal

Confirm that an Aloe generic field can retain a host-receiver type so
the filesystem wrapper can be `(define fs (Fs new fs-host))`.

Do not add source-written host interface names. Do not build `Fs`,
`Path`, `Entry`, or a filesystem capability. Prefer a confirmation test
if the checker already does this; if it does not, a small local checker
or `runtime-type-of` fix is in scope.

This is the last host-boundary slice in this pair.

## Depends on

- `experiment/host-boundary` after checkpoint 98.
- Working design: `docs/host-boundary-extensions.md` slice 99.
- Consumer: `docs/filesystem-vocabulary.md` §4 Wrapper and §7 item 3.
- Keep checkpoint 85: `Term` (and any host interface name) is still not
  a source type. `(fields (value Term))` must remain a type error.

## Authority / starting point

Law: `SPEC.md` §14 (host names are diagnostic, not source-written) and
the merged checker.

Facts on this branch after 98 (do not redesign them):

- `host-receiver-type` unifies by exact interface identity.
- Generic `(fields ...)` method bodies are not checked at definition.
  `infer-instance-send` rechecks them at each send with the
  instantiated substitution.
- Construction already infers class type parameters from field
  payloads.
- `runtime-type-of` currently classifies a host receiver as `'Object`.
  That may only affect raw display of a `(Holder Host)` instance.
- Checkpoint 85 already rejects `(define-class TermHolder (fields
  (value Term)) ...)`.

The intended encoding is inference, not a written host type:

```aloe
(define-class (Holder T)
  (fields
    (value T))
  (methods
    (names (path String) (List String)
      ((self value) names path))))

(define h (Holder new names-host))
(h names "dir")
```

`T` is inferred from `names-host`. Methods that send to `(self value)`
must typecheck at that send using the retained host-receiver type.

## Exact file scope

**May edit:**

- `aloe/type.rkt` only if the golden fails (unification, substitution,
  send-time body check). Do not add source type names.
- `aloe/eval.rkt` only if `runtime-type-of` must classify host
  receivers for the golden or for honest raw display of
  `(Holder Host)`. Do not add a second send rule.
- `tests/checkpoint-99.rkt` (new)
- `CHECKPOINTS.md` (append 99)
- `docs/handoff.md` (current-state test line; typed-host / application
  pressures must not still say crossing is only three scalars; record
  that the generic wrapper encoding works **or** that filesystem must
  use the argument-passing fallback)
- `docs/host-boundary-extensions.md` (status: 99 done / fallback)
- `docs/decisions.md` only if you have to record a fallback or a
  source-written host-type decision

**Do not edit:**

- `aloe/host.rkt` (crossing is done)
- `aloe/parse.rkt`
- `SPEC.md` unless source-written host names become the only honest
  path — that is a SPEC change and must be called out in the PR text.
  Prefer not.
- Historical checkpoints 83–98
- `docs/filesystem-vocabulary.md`
- `examples/`, `lib/`, `gel/`, MPL
- no `host/racket/fs.rkt`, no `lib/fs.aloe`, no `lib/option.aloe`,
  no `Path` / `Entry` / `Fs` classes

## Required behavior

### Accept

Inject the same shape of test host as checkpoint 98 (`names` :
`String -> (List String)`). Then:

1. The `Holder` class above typechecks.
2. `(define h (Holder new names-host))` typechecks. `T` is the
   injected host's receiver type (diagnostic name may appear as
   `NamesHost` or whatever the test interface is named).
3. `(h names "dir")` typechecks as `(List String)` and evaluates to a
   two-element list `"a"`, `"b"` (same controlled state as 98).
4. `(h names "empty")` has `len` 0.
5. Field read `(h value)` still answers the host's `names` message.
6. Ordinary generics still work: `(Holder new 1)` and a method that
   returns the `Int` field.
7. `(define-class TermHolder (fields (value Term)) (methods))` is still
   a type error (checkpoint 85). Do not make `Term` a source type to
   pass the wrapper golden.

### If the golden already passes

Do not “improve” the checker. Add the tests, update handoff, stop.

### If the golden fails

Prefer, in this order:

1. A small local fix so send-time body checking sees the instantiated
   `host-receiver-type` on the field (construction inference,
   `instance-substitution`, `infer-instance-send`).
2. `runtime-type-of` mapping a host receiver to its interface identity
   instead of `'Object`, if that is what blocks the golden or makes
   `(Holder Host)` lie in raw display.
3. **Only if 1–2 cannot work:** document the filesystem-vocabulary §4
   fallback (pass the host receiver as an argument to each public
   operation) in `docs/handoff.md` and
   `docs/host-boundary-extensions.md`, with a test that shows the
   generic field golden failing and the fallback shape that *does*
   typecheck. Do not flatten `Path` to `String`. Do not add
   source-written host interface names unless that fallback also cannot
   typecheck and you call it out as a SPEC change.

Do not weaken the checker to skip method-body checking.

### Handoff leftovers from 98

`docs/handoff.md` still has two stale sentences from 97:

- Current state: “Tests through checkpoint 97 are green”
- Application pressures: “the host crossing vocabulary remains only
  `Int`, `Bool`, and `String`”

Update both. Crossing is `Int` / `Bool` / `String` / `(List String)`.
Tests through 99. `Path` / `Entry` / `Fs` still do not exist. Say
whether `(define fs (Fs new fs-host))` is now a viable encoding.

`CHECKPOINTS.md` compact entry:

```text
## 99. [Generic host-type retention](docs/checkpoints/0099-generic-host-type-retention.md)

- A generic field can retain an injected host-receiver type, so a
  wrapper like `(Fs new fs-host)` typechecks without source-written
  host names. (If this slice had to take the argument-passing fallback,
  say so here instead.)
```

Adjust the bullet if the fallback was required.

## Tests and hand check

Add `tests/checkpoint-99.rkt`. Do not repeat 83–88 or 98's crossing
matrix.

Cover the accepts above, plus:

- Two independently constructed host interfaces with the same name are
  still nominal: a `Holder` inferred from one must not typecheck a
  field assignment or construction from the other (same spirit as
  checkpoint 87's twin-interface test). If construction of a second
  `Holder` is a separate value, at least sending one holder’s field to
  a method that expects the other host interface is a type error.
- Term on a fresh driver: `(term write-line "sealed")` still returns
  `"sealed"`. Default drivers still have no `term`.

### Hand check

Term check unchanged:

```racket
'("sealed" "sealed\r\n")
```

Plus:

```racket
(driver-eval! state '(h names "dir"))
```

is a list of length 2, not a type error.

If you took the fallback instead, the hand check is the documented
fallback send, and the `Holder` golden is the recorded type error.

## Acceptance

- `raco test` green, including 85, 98, and 99.
- Hand checks hold.
- `git diff --check` clean.
- No filesystem library. No source-written host names unless the
  fallback path forced a dedicated SPEC sentence (prefer not).
- Stop. Do not implement `lib/fs.aloe` or write filesystem checkpoints.

## Explicit non-goals

- `Path`, `Entry`, `Fs`, `lib/fs.aloe`, real directories, Gel UI.
- `lib/option.aloe`.
- Further crossing types (`(List Entry)`, nested lists, `Result`).
- Ambient filesystem capability.
- Merging this branch to `main`.
- Writing the filesystem designer brief.
