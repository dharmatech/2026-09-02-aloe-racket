# Host-boundary extensions

**Status.** Checkpoint 98 implemented on `experiment/host-boundary`; working
design for checkpoint 99 and later. Not law. `SPEC.md` remains law.

**Not this file.** Filesystem vocabulary stays
`docs/filesystem-vocabulary.md`. This pair still does not build `Path`,
`Entry`, `Fs`, or `lib/fs.aloe`.

## Pressure

`docs/filesystem-vocabulary.md` §7 asks the host seam for two things
before a filesystem checkpoint can exist:

1. Homogeneous `(List String)` as a host crossing type, so a host method
   can return immediate directory names. Do not encode a listing as a
   delimiter-separated `String`.
2. An Aloe generic field that can retain a host-receiver type so
   `(define fs (Fs new fs-host))` typechecks, **or** an explicit
   decision that the checker cannot and filesystem must use the
   argument-passing fallback in filesystem-vocabulary §4.

Option as a loadable Aloe library is not a host-boundary obligation
unless a host test cannot be written without it. It cannot.

## Against the merged seam (checkpoint 97)

Today in `aloe/host.rkt`:

- Crossing types are the symbols `Int`, `Bool`, and `String`.
- `crossing-type?` is `memq` on that flat list, so `'(List String)` is
  rejected (checkpoint 83 still lists it as unsupported).
- `normalize-crossing-value` identity-checks scalars and freezes
  strings. It has no list case.
- Host implementations already see Racket values for scalars. Aloe
  lists are `list-value` structs in `aloe/eval.rkt`, so `(List String)`
  is the first crossing type that must marshal.

Today in the checker:

- `host-crossing-type->type` maps only those three symbols.
- `host-receiver-type` unifies by exact interface identity.
- Generic `(fields ...)` class method bodies are **not** checked at
  definition time. They are checked at each send with the instantiated
  substitution (`infer-instance-send`). Construction already infers a
  type parameter from a field payload, including a `host-receiver-type`.

So `(define-class (Fs H) (fields (host H)) ...)` plus
`(define fs (Fs new fs-host))` is the intended wrapper, and it looks
small and local — possibly already true. Runtime `runtime-type-of`
currently classifies a host receiver as `'Object`, which may only affect
raw display of `(Fs Host)`. That is a 99 question, not a 98 change.

## Slice 98 — `(List String)` crossing

Admit **exactly** one new crossing form: the type datum `'(List String)`.

- Still rejected: `'List`, `'(List Int)`, `'(List Entry)`,
  `'(List (List String))`, `Float`, host interface names, `Path`.
- Host implementations take and return a proper Racket list of strings
  for that form. Aloe programs see an ordinary homogeneous
  `(List String)`.
- Empty lists are allowed. Element strings are frozen both ways. Order
  is preserved.
- A test host with a `names` method `(String) -> (List String)` is the
  evidence. No `host/racket/fs.rkt`.

Marshalling belongs on the existing guarded invoke path (ordinary send
and reflected exact-row), not a second send rule. If building an Aloe
list needs the `List` class object, obtain it from the evaluator; do
not invent a second list representation.

SPEC §14 currently says the complete crossing vocabulary is `Int`,
`Bool`, and `String`. 98 must extend that sentence. Checkpoint 83's
**document** stays historical; its **living tests** must stop treating
`(List String)` as unsupported.

## Slice 99 — generic host-type retention

Separate from 98. Verify:

```aloe
(define-class (Holder T)
  (fields (value T))
  (methods
    (names (path String) (List String)
      ((self value) names path))))
(define h (Holder new names-host))
(h names "dir")
```

If that typechecks and evaluates after 98, 99 is a confirmation test
and a handoff sentence. If it fails, prefer a small local checker or
`runtime-type-of` fix. Do not add source-written host interface names
unless that is the only honest way, and call that out as its own SPEC
change.

Fallback if generics cannot hold the host: pass the host receiver as an
argument to each public operation (filesystem-vocabulary §4). Do not
flatten `Path` to `String`.

## Explicitly later

- `(List Entry)` crossing, nested lists, opaque path handles, `Result`.
- `lib/option.aloe`, `lib/fs.aloe`, real directory goldens, Gel UI.
- A second production capability (filesystem) injected beside Term.
