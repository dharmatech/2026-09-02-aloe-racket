# Checkpoint-manager brief — String `len` / `take` / `define-methods`

**Status.** Working handoff for **one** checkpoint-manager conversation.
Not law. Not a checkpoint. Not an implementer assignment.

**Your job.** Write **checkpoint 114 only**: give primitive `String` the
same growable shape `List` already has — two irreducible kernel
messages, and `define-methods String`. Then **stop**. Do not implement.
Do not write `starts-with?`, Gel, or hidden files.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this brief, `SPEC.md`, `docs/philosophy.md` (kernel vs library),
   and how `List` is extended (`lib/list.aloe`, `define-methods List`).
2. Write `docs/checkpoints/0114-string-len-take.md`.
3. Stop for human review.

The implementer will not have this brief. Put every rule they need in
the checkpoint itself.

This slice is language, not Gel. Keep the checkpoint **short**. A
600-line file or a generic “all primitives are classes” design is a
defect.

## 2. Why this slice exists

Gel needs to test whether a file name starts with `"."`. That predicate
is library code. Aloe `String` today only has `=` and `append`, and
`define-methods String` is not a class target (`aloe/eval.rkt` treats
String as a `send-to-string` table). Philosophy: look for the
restriction first. Lift **String only**, the same way List already
receives extra methods. Do not add `starts-with?` to the kernel.

## 3. Required kernel messages

Keep `=` and `append`. Add:

```aloe
("" len)                  ; 0
("abc" len)               ; 3
("abc" take 0)            ; ""
("abc" take 2)            ; "ab"
("abc" take 3)            ; "abc"
("abc" take 5)            ; "abc"
("abc" take -1)           ; ""
("" take 2)               ; ""
```

Locks:

- `(s len)` → `Int`. Same selector as List.
- `(s take n)` → `String`. `n` is `Int`, not Float. No numeric coercion.
- `n <= 0` → `""`
- `n >= (s len)` → `s` (the same characters; a new String value is fine)
- Otherwise the prefix of length `n`
- Do not add `drop`, `slice`, `at`, `empty?`, `Char`, `starts-with?`,
  `ends-with?`, or `contains?`
- Do not add `take` to List. List can already derive it from
  `first` / `rest`
- Do not make `Int`, `Float`, `Bool`, or `Symbol` extendable
- Do not generalize List-only checker tricks (expected-type
  propagation) unless a 114 test is otherwise impossible. String
  `take`'s argument is `Int`; that should not require a new inference
  rule

## 4. `define-methods String`

`String` must be a legal `define-methods` target, parallel to `List`:
kernel messages stay in the host; extra methods are Aloe.

Prove it in 114 with a **test-only** `define-methods String` (a tiny
method such as `empty?` as `(self len) = 0`, or an identity). Do **not**
add `lib/string.aloe` or bootstrap a string library yet. That is
checkpoint 115.

Do not invent a second dispatch rule. Sending to a string still finds
kernel messages first, then installed Aloe methods, same idea as List.

`SPEC.md` should list primitive String messages (`=`, `append`, `len`,
`take`) and note that further String methods may be installed with
`define-methods String`, as it already does for List’s `fold` / `map`.

## 5. File scope (expected)

- `aloe/eval.rkt` and whichever existing env/type files must know
  `String` as an extendable primitive (the List parallel, not a new
  abstraction layer)
- `SPEC.md` (String messages only)
- `docs/decisions.md` (short dated note: String kernel vs library)
- `tests/checkpoint-114.rkt`
- `CHECKPOINTS.md`

No Gel, no disk, no `host/racket/fs.rkt`, no `lib/string.aloe`.

## 6. Stop condition

The conversation is done when `docs/checkpoints/0114-string-len-take.md`
exists. Do not implement it. Do not write checkpoint 115.
