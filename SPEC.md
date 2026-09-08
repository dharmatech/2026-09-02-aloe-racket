# Aloe 0.4 spec

Sections 1–10 describe the original 0.1 language and its ratified
generalizations. Sections 11–12 summarize the 0.2–0.3 additions, section 13
summarizes the 0.4 constructor additions, and section 14 records the typed
host boundary.

Aloe is an s-expression language. Evaluation is message send, not Scheme apply.
Prototype host: Racket (`2026-09-02-aloe-racket`).
Target program: `examples/boids.aloe`.
Deliverable for 0.1: Racket interpreter + type checker. No compiler, no macros, no mutation, no inheritance.

`experiment/math-interface` adds section 3.3 protocols (0.2 experiment).
`experiment/overload` adds section 3.4 overloading (0.2 experiment).
Those sections are law on their branches until merged to main.

---

## 1. Syntax

A program is a sequence of s-expressions. The reader is the Scheme/Racket reader.

Atoms:

- integers: `0`, `10`, `-3` — type `Int`
- floats: `0.0`, `1.0`, `0.01` — type `Float`
- strings: `"x"`, `"hello"` — type `String`
- symbols: `demo`, `x`, `+`, `step`, `Point`
- booleans: `#t`, `#f` — type `Bool`

A combination is a list. Special forms are listed in section 4. Every other list of length ≥ 2 is a **send**.

Type names and class names start with a capital letter by convention (`Point`, `Int`, `List`). This is not enforced by the machine.

---

## 2. Evaluation model (sends)

```
(receiver-expr selector argument-expr ...)
```

In environment `E`:

1. `r := eval(receiver-expr, E)`
2. `selector` is the source symbol. It is **not** evaluated.
3. `a_i := eval(argument-expr_i, E)` for each argument (zero or more)
4. `method := lookup(r, selector, types of a_i)` — field or method on `r`'s class
5. If missing → runtime error: unknown message
6. Run the method with implicit `self = r` and parameters bound to `a_i`

This is not Scheme. `(step demo-flock)` does **not** apply `step` to `demo-flock`. It sends the selector `demo-flock` to the value of `step`.

Illegal:

- `()` — error
- `(only-one)` — error (no selector)

### 2.1 Atoms

| Form | Meaning |
|---|---|
| number / float | itself (an object of class `Int` or `Float`) |
| string | itself (an object of class `String`) |
| `#t` `#f` | itself |
| symbol | environment lookup; unbound → error |

### 2.2 `self`

Every method and field read runs with `self` bound to the receiver. Field access is a send: `(a x)` looks up selector `x` on `a`.

---

## 3. Objects and classes

An instance records its class, generic arguments, constructor, and
that constructor's ordered immutable payload. A class has:

- name
- type parameters (zero or more)
- a finite, nonempty, declaration-ordered constructor set
- methods: selector, parameters, return type, body (more than one method may share a selector; see 3.4)
- optional protocol (zero or one in this experiment)

Classes are first-class values. Evaluating the name `Point` yields the class object.
Constructors are not types, subtypes, or top-level bindings.

### 3.1 `define-class`

```
(define-class Name
  (fields
    (field-name Type)
    ...)
  (methods
    (selector (type A ...)
      (param Type) ... ReturnType
      body)
    (selector (param Type) ... ReturnType
      body)
    ...))

(define-class (Name T ...)
  (fields ...)
  (methods ...))

(define-class Name Protocol
  (fields ...)
  (methods ...))

(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))))
```

- A class has exactly one data section: `(fields ...)` or
  `(constructors ...)`. The `(methods ...)` section is required and may be
  empty.
- `(fields ...)` is the one-constructor case. Its constructor selector is
  `new`, and field order is its payload order.
- Each explicit constructor is `(Name (fields ...))`. Its selector is unique
  within the class, and its ordered payload may be empty.
- Constructor selectors cannot be overloaded or used as instance method
  selectors on the same class.
- Method parameter types and return type are required in 0.1.
- `self` is implicit in every method body.
- Methods belong to the whole class, not to individual constructors.
- No inheritance. No setters. Payload values do not change after construction.
- Overloading: a class may have more than one method with the same selector (section 3.4).
- A method-local `(type A ...)` header introduces type parameters inferred independently at every send.
- The optional `Protocol` after `Name` is section 3.3.
- `define-methods` may add instance methods, but not constructors, and may not
  add a method whose selector collides with a constructor.

### 3.2 Construction

```
(ClassName Constructor arg ...)
```

- The selector names a constructor in the class's constructor set.
- Arguments bind to that constructor's payload in declaration order.
- `(Point new 1 2)` is the `(fields ...)` class case; no constructor other
  than `new` is generated for such a class.
- The instance is immutable.
- For a generic class, type parameters are inferred from payload arguments
  and/or an expected type.
- Mismatched arity → error.
- Argument types that do not determine a consistent parameter assignment → type error.
- Constructor names are not callable without the class object: there is no
  `(Some "x")` construction form.

Labeled construction (`make`) is out of scope.

`List` is not constructed with field-`new`. See section 6.

### 3.3 Protocols (0.2 experiment)

A protocol is a named type. A class may opt in. The checker treats instances of that class as that type as well as their class type.

```
(define-protocol Math
  (math-name () String)
  (same-term? (other Math) Bool)
  (coeff-plus (other Math) Math))

(define-class Sym Math
  (fields
    (name String))
  (methods
    (math-name () String
      (self name))
    (+ (type U) (other U) Math
      body)))
```

Rules for this slice:

- `define-protocol` declares a name and may list required method signatures.
  `(define-protocol Math)` remains legal as an empty marker.
- Every class that opts into a protocol with signatures must implement each
  required method with compatible parameter and return types.
- `define-class Name Protocol ...` opts the class into one protocol.
- A value of class `Sym` has type `Sym` and also type `Math`.
- A method may return `Math` when every returned value's class has opted in.
- A send whose receiver is statically typed `Math` is checked against Math's
  declared signatures; runtime lookup remains on the receiver's class.
- `(x + 2)` and `(x + y)` may both be typed `Math`.
- Sending still looks up the selector on the *class*, not on the protocol. The protocol is a type, not a second method table.
- No `super`. No inherited fields. No default implementations.
- A class without a protocol is unchanged.

Out of scope here: multiple protocols per class and implementation inheritance.

### 3.4 Overloading (0.2 experiment)

A class may have more than one method with the same selector.

Lookup is:

```
(class of receiver, selector, types of the evaluated arguments)
```

Rules:

- Arity must match.
- Each argument type must match the parameter type exactly (same class, or a protocol the argument class opted into when the parameter is typed as that protocol). No implicit `Int` to `Math` lift.
- If exactly one method matches, use it.
- If none match: type error in the checker; unknown message at runtime.
- If more than one matches: most specific wins (exact class beats protocol). If still tied: ambiguity error.
- Fields stay unique; only methods overload.

Example: `Sum` may have both

```
(+ (n Int) ...)
(+ (s Sym) ...)
```

`((x + 2) + 3)` picks `Int`. `((x + 2) + x)` picks `Sym`.

---

## 4. Special forms

These lists are not sends.

### 4.1 `define`

```
(define name expr)
```

Binds `name` in the top-level environment to `eval(expr)`. Type of `name` is inferred from `expr`.

No `(define (f x) …)` sugar.

### 4.2 `fn`

```
(fn (x y ...) body)
(fn ((x Type) (y Type) ...) body)
(fn ((x Type) ...) ReturnType body)
```

Evaluates to a function object. That object understands one message:

```
(f call arg ...)
```

Parameter types and return type are optional. If omitted, infer from an expected type or from the body. If neither determines a unique type → type error.

A `fn` is **not** applied as `(f x)`. That would treat `x` as the selector.

### 4.3 `let`

```
(let ((name expr) ...) body)
```

Parallel bindings (a name is not visible in later `expr`s of the same `let`). Type of each name is inferred from its `expr`. Value is `body`.

Desugaring (this is the definition of `let`):

```
(let ((n e1) (bs e2)) body)
→ ((fn (n bs) body) call e1 e2)
```

### 4.4 `if`

```
(if test then else)
```

This is syntax sugar for a send to `Bool.if` with lazy branches:

```
(test if (fn () then) (fn () else))
```

Only the selected zero-argument function receives `call`.

### 4.5 `define-class`

See section 3.1. Top-level only in 0.1.

### 4.6 `define-methods`

```
(define-methods List
  (methods
    (selector (param Type) ... ReturnType body)
    ...))
```

Adds Aloe method bodies to the existing built-in `List` class. `T` denotes the list element type in these declarations.

### 4.7 Method / `fn` / `let` bodies

A body is a single expression. Nested `let` is how locals are introduced. No `begin` in 0.1.

### 4.8 `define-protocol`

```
(define-protocol Math)
```

See section 3.3. Top-level only. Not a send.

### 4.9 `check`

```
(check left right)
```

`check` evaluates its two expressions from left to right and requires them to
have the same type and equal values. On success it returns the right-hand
value. On failure it raises an error that shows both original source datums and
both resulting values.

Instance equality includes the instance's class, constructor identity, and
payload values.

### 4.10 `case`

```
(scrutinee case
  (Constructor (payload-name ...) body)
  ...
  (else body)?)
```

`case` is syntax, not a send; `case` in the second position is reserved. The
scrutinee is evaluated once. Its constructor selects one clause, whose payload
names bind the stored payload values in declaration order. Only the selected
body is evaluated. An optional final `else` handles every constructor not
named by an earlier clause.

---

## 5. Types

Types appear only in **annotation position**: field types, method parameter and return types, optional `fn` annotations. A type list is never evaluated as a send.

### 5.1 Type grammar

```
Type ::= Int | Float | Bool | String | Symbol | Mirror | Signature | Sim | Math
       | (Point Type)
       | (Boid Type)
       | (List Type)
       | (-> Type ...)
       | (Name Type ...)
       | ProtocolName
       | T
```

`Term` and arbitrary host-interface names are deliberately absent from this
source grammar. An explicitly injected host value has an internal nominal type
for checking, but that diagnostic name cannot be written as an Aloe type
annotation.

Examples:

```
Int
Float
String
Symbol
Mirror
Signature
Math
(Point Int)
(Point Float)
(List String)
(List (Point Int))
(List (Boid Float))
(-> U)
(-> T U)
(-> A T A)
```

`(Point Int)` in an expression position would mean “send `Int` to `Point`”. Do not write that. Construction is `(Point new 10 20)` and `T` is inferred.

### 5.2 Generics

Generic classes follow the C# class shape: one definition, type parameters, invariant.

- `Point[T]` is written `(Point T)` as a type.
- `List[Int]` is not a `List[Float]`.
- Constraints (`T : Num`) are not in 0.1. `Point` methods assume `T` understands `+ - * /` the same way `Int`/`Float` do. The Boids program instantiates `T = Float`.

### 5.3 Checking

Bidirectional:

- Check a send: check the receiver, look up `selector` on its class using argument types (section 3.4), check each argument against the chosen method’s parameter types, result is the return type (or the field type).
- Construction checks arguments against the selected constructor's payload
  types; `new` is the selector for a `(fields ...)` class. Every generic class
  parameter must be determined by payload arguments and/or an expected type.
  A parameter still unknown at the end of the expression is a type error, as
  in `(define n (Option None))`.
- `define` / `let`: infer from the right-hand side.
- Arrow-typed parameters push expected types into `fn` arguments.
- Written annotations on `fn` are checked.
- `Int` and `Float` do not mix.
- A value whose class opted into protocol `P` may be used where `P` is expected.
- A method annotated to return `P` is checked by requiring each returned class to have opted into `P`.
- Constructor names are not source types.
- `case` requires a concrete class instance, not a protocol-typed value.
  Without `else`, clauses name every constructor exactly once. With `else`,
  named clauses form a nonempty proper subset of the constructor set. Unknown,
  duplicate, and impossible constructors are errors; missing constructors are
  reported in declaration order. Payload binders have the selected
  constructor's field types within that clause only.
- There is no send-site `(type ...)` header. `List empty` retains its existing
  expected-type behavior.

The checker must accept `examples/boids.aloe` and reject the programs in section 9.

---

## 6. Built-in `List`

Type: `(List T)`.

Construction (class message, variadic):

```
(List of x y z)
(List empty)
```

All `of` elements must share a type `T`. `List empty` takes its element type from context when available; otherwise later use must determine it.

Messages:

| Send | Meaning | Type |
|---|---|---|
| `(xs len)` | element count | `Int` |
| `(xs empty?)` | whether the list has no elements | `Bool` |
| `(xs first)` | first element; error when empty | `T` |
| `(xs rest)` | all but the first element; error when empty | `(List T)` |
| `(xs cons x)` | immutable list with `x` prepended | `(List T)` when `x` is `T` |
| `(xs map f)` | apply `f` to each element | `(List U)` if `f` : `T → U` |
| `(xs fold acc f)` | left fold | type of `acc` |

`map` and `fold` invoke the function with `call`:

```
(f call element)
(f call acc element)
```

`fold`, `reverse`, and `map` are Aloe methods defined in `lib/list.aloe`.
The host implements only `of`, `empty`, `empty?`, `first`, `rest`, `cons`, and `len`.

---

## 7. Built-in numbers

`Int` and `Float` values are objects. Messages:

```
(+ other)  (- other)  (* other)  (/ other)
(< other)  (> other)  (<= other)  (>= other)  (= other)
```

Operands have the same class (`Int` with `Int`, `Float` with `Float`).
Arithmetic returns that numeric class; comparisons return `Bool`. No implicit coercion.

`Point` uses the same four selectors for vector arithmetic (`*` and `/` take a scalar of type `T`).
It also defines `(point dist2 other)`, returning the squared distance as `T`.

`Int` does not mix with `Float`. Convert explicitly:

```
(n float)    ; Int → Float
```

Boids must use `(avg-pos / (n float))`, not `(avg-pos / n)`. No implicit promotion in 0.1.

### 7.1 `Bool`

`Bool` understands `(condition if then-fn else-fn)`. Both arguments are zero-argument function objects with the same result type. Exactly one receives `call`, according to the receiver.

### 7.2 `Symbol`

`Symbol` is a primitive interned name with no reader literal. `(Symbol intern
string)` accepts a `String`, `(sym name)` returns that string, and `(sym =
other)` compares two `Symbol` values. Equal strings intern to the same object.
Source symbols remain environment lookups in expression position and
unevaluated selectors in selector position.

### 7.3 `Mirror`

`Mirror` is the primitive reflection boundary. `(Mirror of value)` accepts any
Aloe value, and `(mirror messages)` returns the unique instance or class
selectors known for that value as a `(List Symbol)`. Fields appear as
zero-argument selectors. These kernel messages exist only on `Mirror`; user
objects do not acquire `messages`, and source selectors remain unevaluated.

`(mirror subject)` returns the ordinary Aloe value originally passed to
`(Mirror of value)`; it does not wrap that value in another mirror. The
checker uses the expected result type when one is present and otherwise a
fresh type variable. At a runtime type boundary, a subject that does not match
that expected type is rejected using the same runtime type relation as
`Mirror.invoke` arguments.

`(mirror raw)` returns a `String` containing the subject's structural display,
using the same printer as the REPL's `:raw` command. It is a kernel method on
`Mirror` only.

### 7.4 `Signature`

`(mirror signatures)` returns a `(List Signature)` with one kernel-created row
per overload. `(signature selector)` returns a `Symbol`, `(signature params)`
returns the parameter types as a `List`, and `(signature return)` returns the
result type. Type grammar is reified as values: a simple type name is a
`Symbol`, while a compound type such as `(Point Float)` is a `List` containing
the `Point` and `Float` symbols. These lists are data, not sends. `Signature`
values are not user-constructed. Selectors in source remain unevaluated.

`(signature accepts? mirror)` returns whether a one-parameter signature accepts
the mirror's subject under the same runtime type relation used by `invoke`; it
returns `#f` for signatures of any other arity.

`(mirror invoke signature argument ...)` sends to the mirror's subject using
the chosen table row, not a fresh overload search by selector. The signature
must come from a mirror of the same subject type. At runtime `invoke` checks
the row owner, argument count, each argument type, and the result type before
returning the ordinary Aloe result. The checker requires the first argument to
be `Signature` and infers the remaining arguments normally; because it cannot
know a signature variable's row, its result is the expected type when present
and otherwise a fresh type variable.

---

## 8. Out of scope for 0.1

- inheritance, `super` (protocols in 3.3 are not inheritance)
- mutation, setters
- full Julia/CLOS multimethods (receiver is not special)
- labeled `make`
- `begin`
- macros
- modules beyond `load`
- computed selectors
- native compilation
- required protocol method lists
- multiple protocols per class

---

## 9. Golden programs

Must run (after the Boids file’s definitions, or equivalent stubs):

1. `(Point new 1 2)` → a `(Point Int)`
2. `((Point new 1 2) x)` → `1`
3. `((Point new 1.0 2.0) + (Point new 3.0 4.0))` → `(Point new 4.0 6.0)`
4. `((List of 1 2 3) len)` → `3`
5. The last two lines of `examples/boids.aloe`: `(demo step)` twice, each result a `Sim`

Must be type errors:

1. `(Point new 1 2.0)` — `T` inconsistent
2. `(demo len)` — `Sim` has no `len`
3. `((Point new 1 2) position)` — `Point` has no `position`
4. `(List of 1 2.0)` — mixed element types
5. `((Point new 1 2) + (Point new 3.0 4.0))` — `Point[Int]` vs `Point[Float]`

The `Option` definition in section 3.1 must also run these expressions:

1. `(Option Some "x")` → an `(Option String)`
2. `((Option Some "x") present?)` → `#t`
3. `((if #t (Option None) (Option Some "x")) present?)` → `#f`
4. `((Option Some "x") case (None () "unknown") (Some (name) name))`
   → `"x"`

This recursive class must typecheck and evaluate:

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
          ((left size) + (right size)))))))
```

Tree goldens:

1. `((Tree Leaf 1) size)` → `1`
2. `((Tree Branch (Tree Leaf 1) (Tree Leaf 2)) size)` → `2`

These Option programs must be rejected:

1. `(define n (Option None))` — `T` remains unknown
2. `(Some "x")` — a constructor is not a top-level binding
3. `((Option Some "x") case (Some (name) name))` — missing `None`

---

## 10. Implementation note

Implement in Racket as a definitional interpreter:

```
sexpr → parse → AST → type-of → interp
```

Do not elaborate into Racket evaluation for object sends. `let` may be expanded to `fn` + `call` before `type-of` / `interp`.

---

## 11. 0.2 additions

- `load` reads, typechecks, and evaluates another Aloe file in the same
  environment, resolving relative paths from the loading file before the
  current directory and project root.
- `cond` is syntax sugar for nested `if` forms; its final `else` clause is
  required.
- `define-protocol` declares a protocol type and may declare required method
  signatures for classes that opt in.
- Methods may overload a selector by parameter types. Lookup uses the receiver
  class, selector, and argument types; exact matches beat protocol matches.
- `String` is a primitive type. Objects may implement `show`; the default REPL
  printer uses it when present, and `:raw` prints the structural `#<…>` form.
- `Symbol` is a primitive interned name constructed with `(Symbol intern
  String)`; it does not change source-symbol lookup or selector syntax.

## 12. 0.3 additions

- `Mirror` keeps reflection separate from the base object protocol;
  `(Mirror of value)` produces a mirror whose `messages` result is the value's
  unique `(List Symbol)` selectors.
- `(mirror signatures)` exposes overload-table rows as `Signature` values;
  their types are reified as `Symbol` and `List` grammar data.
- `(mirror invoke signature argument ...)` invokes that exact owned row with
  runtime checks, without turning a selector symbol into `perform`.
- `(mirror subject)` unwraps the reflected value; its result type is supplied
  by context or represented by a fresh type variable.
- `(mirror raw)` returns the subject's structural REPL display as a `String`.
- A one-parameter signature answers `(signature accepts? mirror)` for Gel's
  typed stack-slot filtering.

## 13. 0.4 additions

- Classes have finite constructor sets; `(fields ...)` remains the singleton
  `new` form, while `(constructors ...)` declares named payload alternatives
  (sections 3.1–3.2).
- Receiver-anchored `case` selects an instance constructor and checks exact or
  `else`-completed coverage (sections 4.10 and 5.3).
- Generic construction may combine payload constraints with an expected type;
  every class parameter must be determined by the end of the expression
  (section 5.3).

## 14. Typed host capabilities

A host capability is a Racket-created receiver made available to Aloe only by
explicit injection into a driver. Its opaque `host-interface` is a nominal
identity containing an ordered list of uniquely selected `host-method`
declarations. Each method declaration is the single source of its selector,
fixed parameter types, return type, and Racket implementation.

The complete crossing vocabulary is `Int`, `Bool`, `String`, and homogeneous
`(List String)`. Nested lists and `(List T)` for every other `T` are excluded.
Arguments are validated before an implementation runs, and its result is
validated before it enters Aloe. Strings are normalized to immutable values in
both directions.
Implementation failures receive consistent Aloe host-failure context while
retaining the original Racket cause; breaks pass through unchanged.

The checker derives host sends from the same exact interface identity used by
runtime dispatch. Injection preflights both sides of a driver and installs the
runtime receiver and checker type as one logical operation; it never
overwrites an existing name. Interface names appear in diagnostics, but are
not source-written Aloe types.

`Mirror` derives a host receiver's messages, signatures, scalar type data,
nominal signature ownership, and exact-row invocation from that same
interface. Reflected invocation uses the ordinary guarded host invocation
boundary, while the target receiver supplies the state. Default environments
contain no optional capability.

There is no arbitrary Racket call, Racket evaluation, namespace access,
dynamic library surface, ambient capability, or second send or evaluation
rule. Host access remains an explicit, typed value boundary.
