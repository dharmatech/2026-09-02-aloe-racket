# Aloe 0.2 spec

Sections 1–10 describe the 0.1 language. Section 11 lists 0.2 additions.

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

An object has a class and a field vector. A class has:

- name
- type parameters (zero or more)
- fields: ordered `(name Type)`
- methods: selector, parameters, return type, body (more than one method may share a selector; see 3.4)
- generated class message `new`
- optional protocol (zero or one in this experiment)

Classes are first-class values. Evaluating the name `Point` yields the class object.

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
```

- `fields` and `methods` are required labels. `methods` may be empty.
- Field order is `new` argument order.
- Method parameter types and return type are required in 0.1.
- `self` is implicit in every method body.
- No inheritance. No setters. Fields do not change after `new`.
- Overloading: a class may have more than one method with the same selector (section 3.4).
- A method-local `(type A ...)` header introduces type parameters inferred independently at every send.
- The optional `Protocol` after `Name` is section 3.3.

### 3.2 Construction

```
(ClassName new arg ...)
```

- `new` is generated. Arity = number of fields.
- Arguments bind to fields in declaration order.
- The instance is immutable.
- For a generic class, type parameters are inferred from the argument types.
- Mismatched arity → error.
- Argument types that do not determine a consistent parameter assignment → type error.

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

---

## 5. Types

Types appear only in **annotation position**: field types, method parameter and return types, optional `fn` annotations. A type list is never evaluated as a send.

### 5.1 Type grammar

```
Type ::= Int | Float | Bool | String | Symbol | Mirror | Sim | Math
       | (Point Type)
       | (Boid Type)
       | (List Type)
       | (-> Type ...)
       | (Name Type ...)
       | ProtocolName
       | T
```

Examples:

```
Int
Float
String
Symbol
Mirror
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
- `new`: check args against field types; infer class type parameters from those args.
- `define` / `let`: infer from the right-hand side.
- Arrow-typed parameters push expected types into `fn` arguments.
- Written annotations on `fn` are checked.
- `Int` and `Float` do not mix.
- A value whose class opted into protocol `P` may be used where `P` is expected.
- A method annotated to return `P` is checked by requiring each returned class to have opted into `P`.

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
