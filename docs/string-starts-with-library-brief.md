# Checkpoint-manager brief — String `starts-with?` library

**Status.** Working handoff for **one** checkpoint-manager conversation.
Not law. Not a checkpoint. Not an implementer assignment.

**Depends on.** Checkpoint 114 (`String` `len` / `take` /
`define-methods String`) already green. Do not start this conversation
before that lands. Do not add kernel String messages in this slice.

**Your job.** Write **checkpoint 115 only**: `starts-with?` as an Aloe
method in `lib/string.aloe`, bootstrapped the way `lib/list.aloe` is.
Then **stop**. Do not implement. Do not write Gel hidden files.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this brief, checkpoint 114’s result, `lib/list.aloe`, and
   `aloe/library.rkt`.
2. Write `docs/checkpoints/0115-string-starts-with.md`.
3. Stop for human review.

The implementer will not have this brief. Put every rule they need in
the checkpoint itself. Keep the checkpoint **short**.

## 2. Required method

```aloe
(define-methods String
  (methods
    (starts-with? (prefix String) Bool
      ((self take (prefix len)) = prefix))))
```

Goldens:

```aloe
("hello" starts-with? ".")     ; #f
(".bashrc" starts-with? ".")   ; #t
("." starts-with? ".")         ; #t
("" starts-with? ".")          ; #f
("abc" starts-with? "ab")      ; #t
("ab" starts-with? "abc")      ; #f
("abc" starts-with? "")        ; #t
("" starts-with? "")           ; #t
```

Locks:

- This is the entire string library for 115. No `ends-with?`,
  `contains?`, `drop`, or comments-as-essays
- Default `make-driver` / `bin/aloe` loads `lib/string.aloe` the same
  way it loads `lib/list.aloe`, so user programs may send
  `starts-with?` without an explicit `load`
- Do not put `starts-with?` in `aloe/eval.rkt`
- Do not edit Gel or disk
- `SPEC.md`: `starts-with?` is an Aloe method in `lib/string.aloe`,
  like List `fold`

## 3. Stop condition

The conversation is done when `docs/checkpoints/0115-string-starts-with.md`
exists. Hidden names are checkpoint 116. Do not write that file here.
