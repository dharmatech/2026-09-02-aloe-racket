# Signatures of a type

**Status.** Design specification for the local
`editor-signatures-of-type` project. Not Aloe language law, not an
implementation checkpoint, and not a global checkpoint. The human reviews this
file before a later checkpoint-manager conversation slices it.

**Authority.** `SPEC.md` remains law for sends, classes, constructors,
overloading, protocols, `Mirror`, `Signature`, and the host boundary. This
experiment adds one Racket query over checker types and makes the existing
reflection catalog shareable. It does not add Aloe syntax or change dispatch.

---

## 1. Result

`aloe/type.rkt` provides this Racket-callable operation:

```racket
(type-signature-specs checker-type type-environment)
  ; -> (listof signature-spec?)
```

The environment must be the environment in which `checker-type` was obtained.
That matters for methods installed on `List` and `String`. A normal caller asks
for a type and then its rows with the same environment:

```racket
(define type (type-of expression environment))
(type-signature-specs type environment)
```

The query accepts an internal checker type, not an Aloe type datum, source
string, expression, runtime value, or cursor position. It does not parse,
typecheck, evaluate, load, or modify the environment. An expression-level
operation belongs to the later editor expression-query project.

Each result is the existing transparent Racket row shape, moved out of the
evaluator:

```racket
(struct signature-spec (selector parameters return) #:transparent)
```

- `selector` is a Racket symbol.
- `parameters` is an ordered list of type datums.
- `return` is one type datum.

Type datums use the representation already reified by `Signature`: `Int` is a
symbol and `(List String)` or `(Point Int)` is a proper list of type datums.
The query returns no Aloe values. In particular, it does not construct kernel
`Signature` values, a runtime `List`, or reified `Symbol` values.

The `signature-spec` structure is owned and exported by a new small Racket
module, `aloe/signature-catalog.rkt`. `aloe/type.rkt` re-exports the structure
and provides `type-signature-specs`. The evaluator imports the same structure
and catalog helpers, then remains responsible for turning a row into a kernel
`Signature` with its runtime owner and row index.

## 2. One catalog, two views

`aloe/signature-catalog.rkt` is shared language plumbing, not editor code. It
owns:

- the `signature-spec` row type;
- the ordered kernel rows listed in section 4;
- conversion of field, constructor, method, and host declarations into rows;
  and
- type-datum substitution within rows.

`type-signature-specs` selects the appropriate catalog from a checker type and
supplies checker substitutions. `value-signature-specs`, used by `Mirror`,
selects the same catalog from a runtime value and supplies runtime
substitutions. Do not copy the kernel row tables into `type.rkt`, and do not
create an editor-only table.

Class, protocol, `define-methods`, and host rows continue to come from their
existing declarations:

- user instance methods come from `class-info-methods` on the checker side and
  the corresponding class method declarations on the runtime side;
- constructors come from the class's constructor declarations;
- `List` and `String` extensions come from the environment-local method tables;
- protocol rows come from `protocol-type-signatures`; and
- host rows come from the exact nominal `host-interface` carried by the
  checker type.

There is no second method table. Adding a method with `define-methods` changes
the query because the query reads the updated checker table. It must not know
the names `fold`, `map`, `reverse`, or `starts-with?`.

The existing procedural send implementation may continue to perform dispatch
and type inference. This project does not replace dispatch with the catalog or
change overload selection. Catalog tests pin the declarative rows to the
existing send and Mirror behavior.

## 3. Row identity and order

A static row and a reflected row match when their selector, parameter type
datums, and return type datum are equal and they occupy the same list position.
Kernel `Signature` ownership, row index, and invocation metadata are runtime
details and are not fields of `signature-spec`.

The query never sorts or deduplicates rows:

1. Kernel instance rows use the order in section 4.
2. A legacy `(fields ...)` instance lists fields in declaration order, followed
   by methods in declaration/installation order.
3. An explicit `(constructors ...)` instance has no field sends; constructor
   payload is available through `case`, not as instance selectors. Its methods
   retain declaration/installation order.
4. A user class object lists constructors in constructor declaration order.
5. `List` and `String` list kernel instance rows first, then installed methods
   in installation order.
6. Protocols and host interfaces retain declaration order.
7. Every overload is a separate row. Repeated selectors are retained.

`Mirror.messages` may continue to remove duplicate selector names while
preserving first occurrence. This query returns signature rows, not that
deduplicated message list.

## 4. Catalogs by checker type

The following tables are normative. `A`, `T`, and `U` in kernel rows are type
variables represented by those symbols.

### 4.1 Primitive instances

`Int`:

| selector | parameters | return |
|---|---|---|
| `+` | `Int` | `Int` |
| `-` | `Int` | `Int` |
| `*` | `Int` | `Int` |
| `/` | `Int` | `Int` |
| `<` | `Int` | `Bool` |
| `>` | `Int` | `Bool` |
| `<=` | `Int` | `Bool` |
| `>=` | `Int` | `Bool` |
| `=` | `Int` | `Bool` |
| `float` | none | `Float` |
| `text` | none | `String` |

`Float` has the same first nine selectors and order. Its arithmetic parameter
and return types are `Float`, its comparisons return `Bool`, and it has no
`float` or `text` row.

`Bool` has one row:

```text
if : ((-> T) (-> T)) -> T
```

`String` has these kernel rows followed by every method installed with
`define-methods String`:

```text
=      : (String) -> Bool
append : (String) -> String
len    : ()       -> Int
take   : (Int)    -> String
```

`Symbol` has:

```text
name : ()       -> String
=    : (Symbol) -> Bool
```

`Mirror` has:

```text
messages   : ()          -> (List Symbol)
signatures : ()          -> (List Signature)
invoke     : (Signature) -> U
subject    : ()          -> U
raw        : ()          -> String
```

`Signature` has:

```text
selector : ()       -> Symbol
params   : ()       -> (List TypeData)
return   : ()       -> TypeData
accepts? : (Mirror) -> Bool
```

### 4.2 Lists and functions

For `(List E)`, substitute `E` for `T` in these kernel rows, then append the
environment's installed `List` method rows with the same substitution:

```text
empty? : ()  -> Bool
first  : ()  -> T
rest   : ()  -> (List T)
cons   : (T) -> (List T)
len    : ()  -> Int
```

For a checker function type `(-> P ... R)`, return exactly one row:

```text
call : (P ...) -> R
```

This is the useful static result: its arity and types come from the checker
function type rather than from the function's source parameter names.

### 4.3 User instances and class objects

For an instance type, substitute its class type arguments through the legacy
field and method declarations. Method-local type parameters remain symbolic
and are not replaced by class arguments.

For example, an instance `(Point Int)` whose `(fields ...)` section declares
`x` and `y` starts with:

```text
x : () -> Int
y : () -> Int
```

and then lists its method overloads. An `(Option String)` declared with
explicit `None` and `Some` constructors lists its methods but no `None`,
`Some`, or payload-field rows.

A user class object has one row per constructor. Constructor payload types are
the parameters and the class instance type is the return. Thus a generic class
object `Option` exposes:

```text
None : ()  -> (Option T)
Some : (T) -> (Option T)
```

A `(fields ...)` class is the singleton constructor case and exposes `new`.
The current evaluator incorrectly makes every class mirror report one `new`
row from `class-value-fields`, including classes with explicit constructors.
That behavior is a bug, not an exception: this project changes Mirror to use
the declaration-ordered constructor set, so static and reflected class-object
rows agree. Exact-row `Mirror.invoke` must continue to invoke the selected
constructor row.

### 4.4 Built-in class objects

The class-object catalogs are distinct from their instance catalogs:

```text
List:
  of    : (T) -> (List T)
  empty : ()  -> (List T)

Symbol:
  intern : (String) -> Symbol

Mirror:
  of : (T) -> Mirror
```

The `String` binding is an extension target but has no class sends, so its
class-object catalog is empty. `Int`, `Float`, `Bool`, and `Signature` are type
names rather than bound class objects and therefore have no class-object
checker types.

`List.of` remains represented by Mirror's existing unary generic row even
though an ordinary `(List of ...)` send is variadic. `signature-spec` has no
variadic parameter form, and adding one is outside this experiment. The static
query and Mirror must report the same unary row; this does not change ordinary
List construction.

### 4.5 Protocols

A `protocol-type` lists its declared protocol signatures in declaration order.
It does not search for a concrete implementing class and does not merge class
methods. This is the only honest catalog for a value whose static type is, for
example, `Math`: those are exactly the sends the checker permits through that
type.

Protocols remain types, not runtime method tables. Runtime dispatch still
selects a method on the concrete receiver class. Empty marker protocols have
an empty catalog.

### 4.6 Injected host receivers

A `host-receiver-type` lists the methods of its exact `host-interface` in
interface declaration order. Each row uses the declared crossing parameter
and return datums. Inspection does not invoke an implementation or inspect
receiver state.

Nominal interface identity determines which catalog is selected even when two
interfaces share a display name and structural shape. The identity is not
added to `signature-spec`, and host interface names remain unavailable in Aloe
annotation syntax.

### 4.7 Other internal checker types

A bound inference variable is resolved before lookup. An unresolved inference
variable has no stable catalog and returns an empty list without acquiring a
constraint. `Void`, `TypeData`, opaque internal types, and the `String` class
object also return an empty list.

A rigid `parameter-type` uses the current checker rule for a generic numeric
receiver: `+`, `-`, `*`, and `/` accept and return that same parameter type;
`<`, `>`, `<=`, `>=`, and `=` accept it and return `Bool`. It has no `float` or
`text` row. This records current checker behavior without adding generic
constraints to Aloe.

## 5. Generic substitution

Rows are expressed after receiver-level substitution:

- `(Point Int)` substitutes `Int` for the class parameter `T` in its fields
  and methods.
- `(Point T)` preserves the rigid `T` supplied by the surrounding generic
  checker context.
- A generic class object preserves its declared parameters, so constructor
  rows for `Point` return `(Point T)`.
- `(List String)` substitutes `String` for `T` in kernel and installed List
  rows.
- Method-local parameters such as `A` in `fold` or `U` in `map` remain in that
  method's row. They are inferred independently when the method is sent.

Substitution is recursive through compound class, List, and function type
datums. The query uses the checker's `type->datum` spelling for concrete and
nominal internal types; it does not make a host interface name legal in source.

## 6. Mirror parity and named exceptions

For synchronized checker and runtime environments, a value's static catalog
and `(Mirror of value)` signature rows must have the same triples and order,
except for these named cases:

1. **Protocol erasure.** A checker `protocol-type` reports the protocol
   contract. A runtime value retains its concrete class, so its Mirror reports
   that class's field and method rows instead. Tests compare the protocol query
   to the protocol declaration and separately prove that the concrete mirror
   remains concrete.
2. **Runtime-erased function types.** The checker query reports the actual
   `function-type` parameter and result datums. A runtime `function-value`
   retains only its arity, so Mirror keeps its existing `T ... -> U` `call`
   row. Tests require the same `call` selector and arity and record the type
   difference. Retaining inferred types on runtime closures is a separate
   project.
3. **Host types nested in generic runtime instances.** The checker retains an
   exact nominal host type as a generic argument, while today's runtime generic
   type datum is erased to `Object`/`?`. Direct injected host receivers are
   fully in scope and must match their Mirror rows. Repairing runtime generic
   host-type reification is deferred because it changes runtime type matching,
   `Signature.accepts?`, and exact-row invocation beyond this catalog query.

The explicit-constructor class-object gap described in section 4.3 is fixed in
both views and is not a parity exception. The fixed unary representation of
variadic `List.of` is also not a query/Mirror exception because both views use
the same row.

## 7. Required tests for the later slices

The implementation must establish the public Racket result shape first, then
cover catalog families without an editor client. At minimum, the completed
project proves:

- selector, parameter, return, overload multiplicity, and order for `Int`,
  `Float`, `Bool`, `String`, `Symbol`, `List`, functions, `Mirror`, and
  `Signature`;
- legacy fields before methods and concrete substitution for `(Point Int)`;
- declaration-ordered `None` and `Some` constructor rows on `Option`, with no
  fabricated `new`, in both the static query and Mirror;
- distinct instance and class-object catalogs;
- class and method generic substitution, including installed `List` methods;
- a method with a unique test selector added through `define-methods` appears
  once and in the same appended position in the static query and Mirror,
  without naming any library method in query code;
- protocol contract rows and the protocol-erasure exception;
- exact, declaration-ordered rows for an injected host interface, including
  two same-name interfaces with distinct nominal identities and no host call
  during inspection;
- function exact static rows and the runtime-erasure exception;
- the named nested-generic-host exception;
- empty catalogs for a marker protocol, the `String` class object, `Void`, and
  an unresolved inference variable; and
- unchanged direct sends, overload selection, `Mirror.messages`, and exact-row
  invocation, including invocation of each explicit constructor row.

Parity assertions must compare extracted row triples, not printed strings or
only selector sets. Use paired driver environments when comparing static and
runtime views so environment-local `define-methods` tables describe the same
program state.

## 8. Non-goals

- Source locations, buffers, cursor/type-at-position queries, or incomplete
  programs
- An expression-query CLI or any serialized row format
- LSP, JSON-RPC, VS Code, completion ranking, hover text, or documentation
  generation
- New Aloe syntax, special forms, macros, inheritance, mutation, or numeric
  coercion
- Changing send lookup, overload resolution, protocol conformance, or
  `define-class`
- A variadic signature grammar
- Retaining inferred checker types on runtime functions
- General repair of runtime generic host-type reification
- A second method table, an editor-private catalog, or hardcoded library
  selectors

When the implementation satisfies this specification, stop. Later projects
compose this query with source spans; they do not expand this project's scope.
