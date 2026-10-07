**I would use one explicit way to mark a labeled send, rather than automatically creating a second selector for every method.** The method would remain `scan-after`; the call syntax would say how its arguments are supplied.

There is a distinction here: an ordinary generated wrapper method would not be enough. Normal argument evaluation would try to evaluate `(focused focused)` as a send before the wrapper received it. Whichever spelling we choose, the language needs to recognize the labels as syntax.

My first choice to explore is **a single marker after the selector**, keeping the parenthesized pairs:

```lisp
(self scan-after #:named
  (focused         focused)
  (start           start)
  (query           query)
  (prefix-found    #f)
  (prefix-position (Position new 0 0)))
```

That preserves Aloe’s usual receiver and literal selector positions. It leaves `scan-after*` available as an ordinary method name, and it works equally well for construction:

```lisp
(Position new #:named
  (line   0)
  (column 0))
```

It also handles explicit constructors without inventing a suffix convention for them:

```lisp
(Option Some #:named
  (value "hello"))
```

Here, `#:named` would be a syntax marker shared by these forms. I checked that the existing Racket reader accepts it; Aloe would still need a rule for interpreting it.

A second approach, which I also like, is **a structured selector position**:

```lisp
(self (scan-after named)
  (focused         focused)
  (start           start)
  (query           query)
  (prefix-found    #f)
  (prefix-position (Position new 0 0)))
```

Construction would use the same convention:

```lisp
(Position (new named)
  (line   0)
  (column 0))
```

This uses only symbols and lists, and it reserves no suffix or ordinary method name. The tradeoff is that Aloe’s selector position would now accept either a symbol or a particular list structure. `(scan-after named)` would be interpreted literally there, rather than evaluated as a send. **This is my strongest alternative to `#:named`.**

A third approach is **letting distinctive label tokens identify the mode themselves**:

```lisp
(self scan-after
  #:focused         focused
  #:start           start
  #:query           query
  #:prefix-found    #f
  #:prefix-position (Position new 0 0))
```

That needs no separate mode marker and has less punctuation. Its cost is giving up the explicitly grouped `(label value)` units we liked earlier. Using ordinary symbols such as `focused:` instead would require deciding when those symbols are labels and when they are variable references.

There is also the straightforward generic form:

```lisp
(send-named self scan-after
  (focused         focused)
  (start           start)
  (query           query)
  (prefix-found    #f)
  (prefix-position (Position new 0 0)))
```

It reserves one special-form name and avoids method-name collisions. I find it less attractive for Aloe because it moves the receiver away from the first position.

**I would avoid detecting labeled mode merely from the presence of two-element lists.** For example, `(document text)` is already a legitimate ordinary argument expression. Its shape alone cannot tell us whether `document` is a receiver or a parameter label.

Beyond spelling, three decisions matter:

- **Parameter names become public API.** Renaming `prefix-found` would affect labeled callers. Constructor fields already have public names through field access; method parameters acquire a new compatibility obligation.
- **Evaluation order needs an explicit rule.** I would evaluate the receiver first, then each supplied value once in source order, even if labels are allowed out of declaration order.
- **Overloading needs attention.** Aloe dispatches by selector and argument types. Binding labels to positions can depend on the candidate signature, so it cannot always be a simple rearrangement before ordinary overload lookup.

My preference is **`#:named` with parenthesized pairs**: it keeps method identity intact, preserves the familiar send shape, and provides one convention for methods and constructors. The structured selector version is close behind if keeping the syntax entirely in symbols and lists matters more to you.