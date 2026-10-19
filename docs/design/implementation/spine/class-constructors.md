# Proposal B — class constructors

**Status.** Ratified on `experiment/class-constructors` by checkpoint 96.
`SPEC.md` on this branch is law for the running language. This file retains
the historical proposal and implementation sequence.

**Not law here.** Proposal A lives on `codex/unified-nominal-adts`
(ratified family spec, `define-family`, factories, local methods,
`per-constructor`, send-site `(type …)` headers, elaboration IR).
Do not implement that design on this branch.

## 1. Aim

Generalize the class we already have so a class may have one constructor
or several. Products and variants are the same kind of thing.

Add one special form: receiver-anchored `case`.

Keep every current program. A class written with a single `(fields …)`
block is unchanged: it has one constructor named `new`.

## 2. What a class is

A class still introduces one nominal type and one class object.

It also introduces a finite, nonempty, declaration-ordered set of
constructors. Each constructor has an ordered immutable payload
(possibly empty).

A runtime instance records:

- its class
- resolved generic arguments, when the class is generic
- its constructor
- that constructor’s payload

Current instances are the one-constructor case. Their constructor is
`new`.

Constructors are not types, not subtypes, and not top-level bindings.
The source type is the class: `Point`, `(Option Int)`.

## 3. Declaration

Existing form, unchanged:

```aloe
(define-class (Point T)
  (fields
    (x T)
    (y T))
  (methods
    (+ (other (Point T)) (Point T)
      (Point new
        ((self x) + (other x))
        ((self y) + (other y))))))
```

That is sugar for one constructor named `new`. `(Point new 1 2)` stays
a send to the class object. Field order is still argument order.
Generic arguments are still inferred from those arguments.

New form — explicit constructors:

```aloe
(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))
    (map (f (-> T U)) (Option U)
      (self case
        (None () (Option None))
        (Some (value) (Option Some (f call value)))))))
```

Rules:

- A class has either a class-level `(fields …)` section or a
  `(constructors …)` section, not both.
- `(fields …)` means one constructor, `new`.
- Each constructor has a unique selector and a `(fields …)` payload,
  which may be empty.
- Constructor selectors cannot be overloaded.
- Constructor selectors are reserved on that class: they are not
  instance method names.
- Methods remain whole-class. `self` has the class type. Branch with
  `case` in the body.
- Protocol opt-in stays as it is today: `(define-class Name Protocol …)`.
  Conformance is the whole class, not a single constructor.
- `define-methods` may add instance methods. It may not add
  constructors.

`map` above uses method-local `U` the same way `fold` already does.
If the present checker cannot yet infer `U` from the function argument
and the result, write the existing `(type U)` method header. That header
stays on the method declaration. It is not a send-site form.

## 4. Construction

Construction is a send to the class object:

```text
(ClassName Constructor arg ...)
```

The selector is the constructor name. Arguments are the payload in
declaration order.

```aloe
(Point new 1 2)
(Option Some "x")
(Option None)
```

No generated constructor besides the `new` sugar in section 3.
No `(Some "x")` without the class object. No second meaning of a list.

## 5. `case`

```text
(scrutinee case
  (Constructor payload-name ... body)
  ...
  (else body)?)
```

This is syntax, not a send. `case` in the second position of a list is
reserved. `else` is reserved only as the last clause head, as in `cond`.

Semantics:

- Evaluate the scrutinee once.
- Its class must be a concrete nominal class with a known constructor
  set `S`.
- Choose the clause whose constructor is the scrutinee’s constructor.
- Evaluate only that clause.
- Payload names bind the fields in declaration order. Arity must match.
- Without `else`, the clauses must name each constructor in `S` exactly
  once.
- With `else`, the named constructors must be a nonempty proper subset
  of `S`. `else` covers the rest.
- Reject unknown, duplicate, or impossible constructors.
- Report missing constructors in declaration order.
- No nested patterns, guards, alternatives, or fall-through.

```aloe
(maybe case
  (None () "unknown")
  (Some (name) name))
```

## 6. Types

Source types do not change: primitives, `(List T)`, arrows, class
applications, protocols, type variables.

Constructor names are not source types. There is no `Option.Some` type.

Inside a matching `case` clause, payload binders have the field types of
that constructor. That knowledge does not escape the clause.

A value used at a protocol type forgets which constructor it has.
`case` on a protocol-typed scrutinee is a type error. Case needs the
class.

Generic construction must determine every class type parameter.

- Payload argument types contribute constraints (`(Option Some 1)`
  determines `T = Int`).
- An expected type contributes constraints (`(Option None)` is legal
  where `(Option String)` is expected).
- If a parameter is still unknown at the end of the expression, that is
  a type error.

There is no send-site `(type …)` header in this proposal.

So this is rejected:

```aloe
(define n (Option None))    ; T unknown
```

These are accepted:

```aloe
(define s (Option Some "x"))          ; T = String
(if ok (Option Some "x") (Option None))
```

The `if` arms share expected type `(Option String)`.

## 7. Compatibility

These keep their current meaning:

- send, unevaluated selector
- `fn` / `call`, parallel `let`, `if` / `cond`, `load`, `check`
- `(n float)`, no implicit `Int`/`Float` mix
- `define-class` with `(fields …)` and generated `new`
- Boids, MPL, Gel, `lib/list.aloe`

`let` is still `((fn (…) body) call …)`.

## 8. Runtime sketch

One object representation. Add a constructor identity. Existing classes
store `new`.

Eval of `case` switches on that identity and evaluates one body.

No method dictionaries on instances. No protocol wrappers. No second
value kind.

The evaluator still runs source after a successful check. This proposal
does not add an elaboration IR.

## 9. Not in this slice

Do not add any of the following until a later program cannot be written
without it:

- `define-family` as a second declaration
- deleting `define-class`
- factories
- constructor-local methods
- `per-constructor` method bodies
- send-site `(type …)` headers
- constructor names as source types
- nested patterns, guards, wildcards
- GADTs / per-constructor result types
- a checked Core / elaboration pipeline
- changing `Mirror` or Gel to use `Option`

## 10. Goldens for the first implementation

Must keep running: current suite, including Boids and MPL.

Must accept, after `Option` is defined as in §3:

```aloe
(Option Some "x")
((Option Some "x") present?)          ; => #t
((Option None) present?)              ; expected type from method result / test harness
((Option Some "x") case
  (None () "unknown")
  (Some (name) name))                 ; => "x"
```

Must reject:

```aloe
(define n (Option None))              ; T unknown
(Some "x")                            ; Some is not a binding
((Option Some "x") case
  (Some (name) name))                 ; missing None
```

A later golden, not required for the first green slice:

```aloe
(define-class (Tree T)
  (constructors
    (Leaf (fields (value T)))
    (Branch (fields (left (Tree T)) (right (Tree T)))))
  (methods
    (size () Int
      (self case
        (Leaf (value) 1)
        (Branch (left right)
          (((left size) + (right size))))))))
```

## 11. Implementation order

One checkpoint at a time. Full suite green after each.

1. Land this document. No code.
2. Parse `(constructors …)` and `(e case …)`. Existing classes still
   mean one `new`. Reject mixed `fields` + `constructors`.
3. Store a constructor id on every instance. Current instances use `new`.
4. Evaluate `case`.
5. Check constructor sets and exhaustiveness. Infer generics as in §6.
6. `Option` goldens. Then `Tree` if that slice is still small.

Stop. Do not migrate MPL or Gel in the same breath.
