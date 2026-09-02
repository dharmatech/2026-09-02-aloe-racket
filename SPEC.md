# Aloe 0.1 spec

Aloe is an s-expression language. Evaluation is message send, not Scheme apply.
Prototype host: Racket (`2026-09-02-aloe-racket`).
Target program: `examples/boids.sexpr`.
Deliverable for 0.1: Racket interpreter + type checker. No compiler, no macros, no mutation, no inheritance.

---

## 1. Syntax

A program is a sequence of s-expressions. The reader is the Scheme/Racket reader.

Atoms:

- integers: `0`, `10`, `-3` — type `Int`
- floats: `0.0`, `1.0`, `0.01` — type `Float`
- symbols: `demo`, `x`, `+`, `step`, `Point`
- booleans: `#t`, `#f` (reserved; unused by Boids)

A combination is a list. Special forms are listed in §4. Every other list of length ≥ 2 is a **send**.

Type names and class names start with a capital letter by convention (`Point`, `Int`, `List`). This is not enforced by the machine.

---

## 2. Evaluation model (sends)

```text
(receiver-expr selector argument-expr ...)
```

In environment `E`:

1. `r := eval(receiver-expr, E)`
2. `selector` is the source symbol. It is **not** evaluated.
3. `a_i := eval(argument-expr_i, E)` for each argument (zero or more)
4. `method := lookup(r, selector)` — field or method on `r`'s class
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
- methods: selector, parameters, return type, body
- generated class message `new`

Classes are first-class values. Evaluating the name `Point` yields the class object.

### 3.1 `define-class`

```text
(define-class Name
  (fields
    (field-name Type)
    ...)
  (methods
    (selector (param Type) ... ReturnType
      body)
    ...))

(define-class (Name T ...)
  (fields ...)
  (methods ...))
```

- `fields` and `methods` are required labels. `methods` may be empty.
- Field order is `new` argument order.
- Method parameter types and return type are required in 0.1.
- `self` is implicit in every method body.
- No inheritance. No setters. Fields do not change after `new`.
- No overloading: one method per selector per class.

### 3.2 Construction

```text
(ClassName new arg ...)
```

- `new` is generated. Arity = number of fields.
- Arguments bind to fields in declaration order.
- The instance is immutable.
- For a generic class, type parameters are inferred from the argument types.
- Mismatched arity → error.
- Argument types that do not determine a consistent parameter assignment → type error.

Labeled construction (`make`) is out of scope.

`List` is not constructed with field-`new`. See §6.

---

## 4. Special forms

These lists are not sends.

### 4.1 `define`

```text
(define name expr)
```

Binds `name` in the top-level environment to `eval(expr)`. Type of `name` is inferred from `expr`.

No `(define (f x) …)` sugar.

### 4.2 `fn`

```text
(fn (x y ...) body)
(fn ((x Type) (y Type) ...) body)
(fn ((x Type) ...) ReturnType body)
```

Evaluates to a function object. That object understands one message:

```text
(f call arg ...)
```

Parameter types and return type are optional. If omitted, infer from an expected type or from the body. If neither determines a unique type → type error.

A `fn` is **not** applied as `(f x)`. That would treat `x` as the selector.

### 4.3 `let`

```text
(let ((name expr) ...) body)
```

Parallel bindings (a name is not visible in later `expr`s of the same `let`). Type of each name is inferred from its `expr`. Value is `body`.

Desugaring (this is the definition of `let`):

```text
(let ((n e1) (bs e2)) body)
→ ((fn (n bs) body) call e1 e2)
```

### 4.4 `define-class`

See §3.1. Top-level only in 0.1.

### 4.5 Method / `fn` / `let` bodies

A body is a single expression. Nested `let` is how locals are introduced. No `begin` in 0.1.

---

## 5. Types

Types appear only in **annotation position**: field types, method parameter and return types, optional `fn` annotations. A type list is never evaluated as a send.

### 5.1 Type grammar

```text
Type ::= Int | Float
       | (Point Type)
       | (Boid Type)
       | (Sim Type)
       | (List Type)
       | (Name Type ...)     ; other defined classes
       | T                   ; type parameter in a class header
```

Examples:

```text
Int
Float
(Point Int)
(Point Float)
(List String)            ; when String exists
(List (Point Int))
(List (Boid Float))
(Boid (Point Int))       ; not used; Boid is (Boid T)
```

`(Point Int)` in an expression position would mean “send `Int` to `Point`”. Do not write that. Construction is `(Point new 10 20)` and `T` is inferred.

### 5.2 Generics

Generic classes follow the C# class shape: one definition, type parameters, invariant.

- `Point[T]` is written `(Point T)` as a type.
- `List[Int]` is not a `List[Float]`.
- Constraints (`T : Num`) are not in 0.1. `Point` methods assume `T` understands `+ - * /` the same way `Int`/`Float` do. The Boids program instantiates `T = Float`.

### 5.3 Checking (0.1)

Bidirectional:

- Check a send: eval/check the receiver, look up `selector` on its class, check each argument against the method’s parameter types, result is the return type (or the field type).
- `new`: check args against field types; infer class type parameters from those args.
- `define` / `let`: infer from the right-hand side.
- `map` / `fold`: push an expected parameter type into the `fn`.
- Written annotations on `fn` are checked.
- `Int` and `Float` do not mix.

The first checker must accept `examples/boids.sexpr` and reject the programs in §9.

---

## 6. Built-in `List`

Type: `(List T)`.

Construction (class message, variadic):

```text
(List of x y z)
```

All elements must share a type `T`. Empty `(List of)` needs an annotation; unused in Boids.

Messages:

| Send | Meaning | Type |
|---|---|---|
| `(xs len)` | element count | `Int` |
| `(xs map f)` | apply `f` to each element | `(List U)` if `f` : `T → U` |
| `(xs fold acc f)` | left fold | type of `acc` |

`map` and `fold` invoke the function with `call`:

```text
(f call element)
(f call acc element)
```

---

## 7. Built-in numbers

`Int` and `Float` values are objects. Messages:

```text
(+ other)  (- other)  (* other)  (/ other)
```

Operand and result are the same class (`Int` with `Int`, `Float` with `Float`). No implicit coercion.

`Point` uses the same four selectors for vector arithmetic (`*` and `/` take a scalar of type `T`).

`Int` does not mix with `Float`. Convert explicitly:

```text
(n float)    ; Int → Float
```

Boids must use `(avg-pos / (n float))`, not `(avg-pos / n)`. No implicit promotion in 0.1.

---

## 8. Out of scope for 0.1

- inheritance, `super`
- mutation, setters
- overloading (two methods, same selector)
- labeled `make`
- `begin`, `if`, comparison messages (except as needed later)
- macros
- modules beyond a single program file
- computed selectors
- native compilation

---

## 9. Golden programs

Must run (after the Boids file’s definitions, or equivalent stubs):

1. `(Point new 1 2)` → a `(Point Int)`
2. `((Point new 1 2) x)` → `1`
3. `((Point new 1.0 2.0) + (Point new 3.0 4.0))` → `(Point new 4.0 6.0)`
4. `((List of 1 2 3) len)` → `3`
5. The last two lines of `examples/boids.sexpr`: `(demo step)` twice, each result a `(Sim Float)`

Must be type errors:

1. `(Point new 1 2.0)` — `T` inconsistent
2. `(demo len)` — `Sim` has no `len`
3. `((Point new 1 2) position)` — `Point` has no `position`
4. `(List of 1 2.0)` — mixed element types
5. `((Point new 1 2) + (Point new 3.0 4.0))` — `Point[Int]` vs `Point[Float]`

---

## 10. Implementation note

Implement in Racket as a definitional interpreter:

```text
sexpr → parse → AST → type-of → interp
```

Do not elaborate into Racket evaluation for object sends. `let` may be expanded to `fn` + `call` before `type-of` / `interp`.
