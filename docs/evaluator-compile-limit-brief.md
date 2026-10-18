# Checkpoint-manager brief — the evaluator under the compile limit

**Status.** Working handoff for **one** checkpoint-manager conversation.
Not law. Not a checkpoint. Not an implementer assignment.

**Your job.** Write **one global checkpoint** at the next free number:
bring `aloe/eval.rkt` back under Racket CS's compile limit, with room
to spare, and add a test that fails when an evaluator module crosses
it again. No Aloe behavior changes. Then **stop**. Do not implement.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this brief, `SPEC.md` (it does not change), the shape of an
   existing spine checkpoint
   ([`docs/checkpoints/0114-string-len-take.md`](checkpoints/0114-string-len-take.md)),
   and `aloe/eval.rkt`.
2. Take the next free global number. `CHECKPOINTS.md` lists through
   117; 116 and 117 are Gel-directory work on another branch, and
   there is no 118. Do not reuse a number written down elsewhere as
   reserved.
3. Write `docs/checkpoints/NNNN-slug.md`.
4. Stop for human review.

The implementer will not have this brief. Put every rule they need in
the checkpoint itself.

## 2. Why this slice exists

Racket CS compiles a module body to machine code as one unit only when
it is smaller than `PLT_CS_COMPILE_LIMIT`, 10,000 terms by default.
A larger body is compiled in interpretable mode. Each procedure is
still machine code, but calls between the module's own procedures go
through variables and nothing is inlined across them.

Commit `0e20fae` (modules 006, 14 October 2026) added 39 lines to
`aloe/eval.rkt`, from 1871 to 1910. Recompiling only that file at a
range of limits brackets its size: before the commit it compiled whole
at 10,000 and not at 9,500; at `21d1a36` it compiles whole at 10,500
and not at 10,000. It now sits just over the line.

The cost is measured in
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md`](../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md),
section 1:

- `List rest` of 971 Strings went from 26 to 42 µs, and one zipper
  step from 30 to 48 µs. With `eval.rkt` alone recompiled at a limit
  of 1,000,000, both returned to the earlier numbers.
- `tests/aloemacs/window-pictures.rkt`, run alone, went from 2.7, 23.1,
  and 14.5 ms to 3.2, 27.9, and 17.7 ms at that commit. With `eval.rkt`
  recompiled whole at `21d1a36` it is 2.6, 22.8, and 14.1 ms. Its
  30 ms bar now fails in most `-j 4` suite runs.
- Garbage collection does not explain it, and the commits around it
  move nothing.

The evaluator runs every Aloe program. This is not editor work. The
editor's frame-time series does not edit `aloe/`. Its spec may be
written before this checkpoint lands, but none of its checkpoints goes
to an implementer until this one has landed.

## 3. Required behavior

Locks:

- **No behavior change.** Every Aloe result, error, printed value, and
  test outcome stays the same. `SPEC.md` does not change. No message,
  form, or type is added or removed.
- **The evaluator's surface stays.** `aloe/eval.rkt` stays the module
  other code requires, with the same `provide` list. `aloe/driver.rkt`,
  `aloe/main.rkt`, and every test that requires `eval.rkt` keep their
  `require` forms.
- **Room under the limit.** After the change, the phase-0 body of
  `aloe/eval.rkt`, and of every module the evaluator is split into,
  compiles whole with `PLT_CS_COMPILE_LIMIT=8000`. That is 20 percent
  of headroom under Racket's default. From the bracketing above, the
  body that stays in `eval.rkt` has to lose roughly a quarter of its
  terms.
- **Keep the hot path in one module.** Moving it apart loses the
  inlining this checkpoint exists to recover. The hot path is
  `eval-expr` and the forms it evaluates directly, message lookup and
  every `send-to-…` table, `make-list-value`, `runtime-type-of`,
  `same-runtime-type?`, method selection and application, and function
  calls. Cold code is what an ordinary send does not reach: Mirror and
  signature support, value printing, and the load cache with its file
  exports. By top-level definitions those are about 440, 70, and 120
  lines, a third of the file. Lines are not terms, so only the guard
  below says whether a cut is enough. The manager chooses the cut and
  names it.
- **Send it back rather than split the hot path.** If the cold code
  cannot bring the module that holds the hot path under 8,000 terms,
  stop and send this brief back to the discussion that wrote it. Do not
  separate `eval-expr` from `make-list-value`, or any other part of the
  hot path, to make the number.
- **No cycle.** Racket modules cannot require each other in a cycle.
  If a moved piece calls back into dispatch, as Mirror invocation does,
  the checkpoint names the one indirection it uses, or picks a
  different cut.

The guard:

- A new `tests/checkpoint-N.rkt` compiles the evaluator modules in a
  subprocess into a temporary directory, with `PLT_CS_COMPILE_LIMIT=8000`
  and `PLT_LINKLET_SHOW_POST_INTERP=1`. It fails if any evaluator
  module's phase-0 module body takes the post-interp step. In that
  output a body is identified by the header lines
  `;; compile-linklet: module: <name>`, `;; compile-linklet: phase: 0`,
  and `;; compile-linklet: name: module`, followed by
  `;; compile-linklet: step: post-interp`. At `21d1a36` the bodies
  that take it at 8,000 are `eval` and `type`.
- The variable is a Racket CS debugging aid, observed on Racket 9.3 CS.
  The test must not pass because the output changed shape. It proves
  the detector works in the same run, for example by compiling one
  evaluator module at a very small limit and requiring the post-interp
  step there.
- Recompiling `eval.rkt` alone this way took about 1.1 s with its
  dependencies already compiled. The probe
  [`interp-check.sh`](../archive/design-sketches/2026-10-18-aloemacs-frame-time/interp-check.sh)
  shows the whole-directory form.

The speed check:

- The guard proves the compile mode. It does not prove the hot path
  stayed in one module: a cut that separates it passes the guard and
  stays slow. The speed check is what shows the inlining came back, so
  the checkpoint's verification and acceptance sections require it. A
  note in a summary is not enough.
- Three trees, each running `tests/aloemacs/window-pictures.rkt` alone,
  interleaved round-robin, at least three rounds, nothing else running:
  the parent commit as built (*before*); the parent commit with only
  `aloe/eval.rkt` recompiled at `PLT_CS_COMPILE_LIMIT=1000000`, the
  whole-compile *reference*; and the checkpoint at the default limit
  (*after*). The implementer records all three medians of every run.
- Acceptance gates on the two deep medians, widest leaf deep and one
  window deep. Each of *after*'s two lands with the *reference*: it is
  no more than a stated fraction of the *before*-to-*reference* gap
  above the *reference*. The checkpoint states that fraction. It is
  small enough that a split which recovers only half the speed fails;
  a quarter of the gap does that. At `21d1a36` on the record's machine,
  *before* was 27.6 and 17.6 ms and *reference* was 22.8 and 14.1 ms,
  gaps of about 4.8 and 3.5 ms.
- The first-screen median is recorded, not gated. Its gap is about
  0.6 ms (3.2 to 2.6 ms), too small to judge a split by.

## 4. Pins to carry

Some tests read `aloe/eval.rkt` as text or as a module, and a split
moves text between files. Known pins, found by grepping `tests/` for
`eval-path`:

- `tests/checkpoint-17.rkt`: the source has no `[(map)` and no `[(fold)`
  case. Its intent is that List dispatch has no such Racket case. If
  List dispatch leaves `eval.rkt`, the pin must cover the module it
  moves to. It must not pass by looking at the wrong file.
- `tests/checkpoint-88.rkt`: `eval.rkt` does not export
  `host-receiver-invoke-method`.
- `tests/checkpoint-115.rkt`: `eval.rkt` contains `split-lines` and
  does not contain `starts-with?`.

Before writing the file scope, apply the cut to a scratch copy of the
repository, run `TMPDIR=/tmp raco test -j 4 -y tests`, and list every
failing file. That list is the inventory. Tests under
`tests/editor/host-queries/` load host modules by collection path and
fail in a copy for that reason alone. Check them in the real tree.

## 5. File scope (expected)

- `aloe/eval.rkt` and the new evaluator module or modules beside it
- `tests/checkpoint-N.rkt`
- the pinned tests in §4, only as far as a pin has to follow moved code
- `CHECKPOINTS.md`, one entry
- `docs/decisions.md`, one short dated note: evaluator modules stay
  under the compile limit with room, and the guard enforces it

Not `SPEC.md`, `aloe/type.rkt`, `lib/`, `examples/`, or `host/racket/`.

## 6. Non-goals

- `aloe/type.rkt` is over the limit too. It is the checker, and the
  timed paths in the record keep it outside every interval. It is a
  separate item. The guard does not cover it, and this checkpoint
  does not split it.
- Making `List` `cons` and `rest` cheaper. The record measured it. It
  changes what those sends do inside `aloe/eval.rkt`, and no document
  has opened it. The aloemacs Index charter §4.3 ruled out a kernel
  `Vector` inside an editor layer and asked for that kind of
  measurement to come back to a discussion. It did not rule on cheaper
  `cons` and `rest`.
- Raising the limit through the environment, a launcher, or a build
  flag. Bytecode built by an ordinary `raco make` or `raco test -y`
  must be fast.
- Any change in what Aloe means.

## 7. Stop condition

The conversation is done when `docs/checkpoints/NNNN-slug.md` exists.
Do not implement it.
