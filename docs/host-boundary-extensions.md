# Host-boundary extensions

**Status.** Checkpoints 98 and 99 are implemented, and checkpoint 101 has
started a second optional capability on `experiment/filesystem` with an
`fs-host` test double. Production filesystem I/O remains later work. Not law.
`SPEC.md` remains law.

**Not this file.** Filesystem vocabulary stays
`docs/filesystem-vocabulary.md`. There is still no `Path`, `Entry`, `Fs`, or
`lib/fs.aloe`.

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

At checkpoint 97 in `aloe/host.rkt`:

- Crossing types are the symbols `Int`, `Bool`, and `String`.
- `crossing-type?` is `memq` on that flat list, so `'(List String)` is
  rejected (checkpoint 83 still lists it as unsupported).
- `normalize-crossing-value` identity-checks scalars and freezes
  strings. It has no list case.
- Host implementations already see Racket values for scalars. Aloe
  lists are `list-value` structs in `aloe/eval.rkt`, so `(List String)`
  is the first crossing type that must marshal.

At checkpoint 97 in the checker:

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

Before checkpoint 98, SPEC §14 said the complete crossing vocabulary was
`Int`, `Bool`, and `String`. Checkpoint 98 extended that sentence. Checkpoint
83's **document** stays historical; its **living tests** no longer treat
`(List String)` as unsupported.

## Slice 99 — generic host-type retention

**Done.** The existing checker accepts and evaluates this confirmation encoding
without a checker or evaluator change:

```aloe
(define-class (Holder T)
  (fields (value T))
  (methods
    (names (path String) (List String)
      ((self value) names path))))
(define h (Holder new names-host))
(h names "dir")
```

Construction retains the exact injected interface identity as `T`, field reads
preserve it, and send-time method-body checking can dispatch through the generic
field. Same-named but independently constructed interfaces remain distinct.
Therefore `(define fs (Fs new fs-host))` is a viable encoding for the later
filesystem wrapper without making a host interface name source-writable.

The argument-passing fallback from filesystem-vocabulary §4 was not required.

## Explicitly later

- `(List Entry)` crossing, nested lists, opaque path handles, `Result`.
- `lib/fs.aloe`, real directory goldens, Gel UI.
- A production filesystem receiver injected beside Term; checkpoint 101 has
  only the shared interface and controlled test double.
