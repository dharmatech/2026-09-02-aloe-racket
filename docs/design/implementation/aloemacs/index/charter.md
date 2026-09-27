# Charter — aloemacs index

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for
**immutable indexed lines**: movement and `frame` fetch the
current or visible lines without rebuilding or scanning the whole
buffer. Then **stop**. Do not write checkpoints. Do not implement.
Do not specify mutation, a compiler, incremental paint, windows,
or keymaps.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.7.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-index 000**, … under
   `docs/design/implementation/aloemacs/index/checkpoints/`.
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice**. A rope, a kernel `Vector`,
Chez Emacs `paint.sls`, Legmacs syntax highlighting, and `set!`
are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../text/`](../text/) | `Text` is an exact source `String`; `lines` is `split-lines` of the whole source |
| [`../loop/`](../loop/) | `AloemacsEditor` movement, `frame`, keys |
| [`../file/`](../file/) | Session visit/save uses `(text to-string)`; do not reopen Fs |

**Measured (do not re-litigate):** scripted no-TTY Down + 80×24
`frame` on one-character lines, near the **start** of the file:

| Lines | Per key + frame |
|---:|---:|
| 1 | 0.69 ms |
| 100 | 6.24 ms |
| 10 000 | 17.9 s |

About 73% of sampled CPU was `make-list-value` and callers.
`move-down` and `line-length` send `(text lines)` (full split);
`frame` sends it again; `source-line` walks from the list head.

**Withdrawn:** the Scale charter (scan `(text to-string)` with
`drop` / `take`, “examine at most the visible rows”). Finding
line 9 000 in a single string still inspects earlier text. Repeated
`drop` is Racket `substring` and can copy suffixes. Hold-Down from
line 0 to line *N* is \(1+2+\cdots+N\) if every key scans from the
start. Do **not** specify that as the product solution.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Loop movement and frame *bytes* stay.** Same wrap, clamp,
   EOF no-op, same ANSI. `tests/aloemacs/editor-keys.rkt` and
   `frame.rkt` stay green without new goldens for behavior.
   File visit/save still round-trip `(text to-string)` as File
   specified (exact UTF-8, no CRLF conversion).
2. **Line lookup does not grow with cursor depth.** After the
   index exists, fetching line *k* or stepping to the next line
   must not resplit the whole source and must not scan from
   character 0 of a source string. `frame` of `rows` screen rows
   visits those rows (and empty pad rows), not the tail of the
   file and not every prior line on each key.
3. **Immutability stays.** Nested edit is rebuild. No Aloe
   mutation, no mutable bindings, no host-side smash of `Text`.
   The runner may still rebind `aloemacs-editor`.
4. **Tests first, no TTY.** Existing Loop/File tests plus:
   - correctness of motion/`frame` on a many-line fixture
   - a hand check (or documented timing) of Down+`frame` on
     ~10 000 one-character lines **at the start and near the
     end** (about line 9 000). Both must be orders of magnitude
     below 17.9 s/key. A spec that only speeds up the first
     three Downs is a defect.
5. No compiler, no `Vector` kernel type, no paint cache, no
   highlighter.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Indexed lines, Legmacs-shaped

Copy the **seam**: lines are the addressable unit; movement
uses the current line; `frame` maps visible rows. Chez Emacs
`text.sls` also stores an immutable line sequence and shares
unchanged line strings on edit. Do not copy e's mutable store,
screen cache, or Legmacs's derived highlight scan.

### 4.2 Full frame, same keys, same File string

One `frame` `String`, `(term write …)`. `"down"` is still
`move-down`. Ctrl-S / Escape / visit / save unchanged. Do not
add dirty rectangles or cursor-only host moves.

### 4.3 Aloe 0.1 `List`, not a new kernel type

There is no `Vector`. Prefer a structure you can write in Aloe
now: a **list zipper** (lines above, current line, lines below),
and/or `Text` whose payload is the line sequence with
`to-string` / `from-string` as conversions. A language-spine
`Vector` is out of this spec unless you can show that after an
Aloe index exists, `List` lookup is still the measured floor —
and even then, **stop and send that back**; do not sneak a
kernel type into this layer.

### 4.4 Where code may live

- `lib/text.aloe` if the algebra's storage becomes lines (keep
  `from-string` / `to-string` / `replace` / validity)
- `examples/aloemacs/editor.aloe` (and session only if it must
  forward new construction)
- Tests under `tests/aloemacs/`
- Not the runner, Term, Fs host, Gel, `aloe/eval.rkt`

### 4.5 Out of this layer

- Mutation (`set!`, boxes, mutable fields)
- Compiler / changing evaluation
- Ropes, piece tables, gap buffers as the first design
- Incremental paint, `wcwidth`, wrapping
- Windows, minibuffer, prefix maps
- Treating 0.69 ms on a 1-line file as the problem

### 4.6 Representation (resolve this)

Pick one closed design and name constructors, fields, and who
owns the index:

1. **Zipper on the editor.** `Text` may stay a source string
   (or become lines). The editor holds an immutable cursor into
   the line sequence so Down/Up/`frame` are local rebuilds.
   Insert/delete update the current line and rebuild `Text` as
   specified (every key vs at save — pick one; File must still
   see a correct `to-string`).
2. **`Text` as a line sequence.** Payload is nonempty
   `(List String)` (no embedded LF), plus whatever is required
   for exact `to-string` (trailing-newline fact if you need it).
   `lines` is cheap. The editor still needs O(1) or zipper-style
   access for line *k* near the bottom; a bare `List` plus
   `source-line` from the head is **not** enough by itself.
3. **A smaller variant you can defend** (for example line-start
   offsets) that still meets §3.2 without `drop`-scanning the
   source on every Down.

Do not keep two sources of truth that can disagree. Do not
cache `(text lines)` on every edit as a shadow copy of the
old string `Text` — that still allocates the whole list.

### 4.7 How cheap is enough (resolve this)

Name the 10 000-line fixtures: N Downs + 80×24 frames at the
**top**, and the same near the **bottom** (start the editor at
a high line, or Down until there once in setup that is **not**
the timed region). Name a budget or a minimum speedup vs
17.9 s/key. Prefer a recorded hand check plus structural
rules (“must not send `(text lines)` on motion/`frame` if that
send still splits the source”; “must not `source-line` from
head for each visible row”) over a flaky CI timeout.

Specify Up, Left, Right, and `line-length` in the same series
if they would otherwise keep the old walks.

## 5. Authority

- [`../README.md`](../README.md) — no mutation
- [`../text/spec.md`](../text/spec.md) — algebra *behavior*
  (`from-string` / `to-string` / replace / positions). Storage
  may change if those hold.
- [`../loop/spec.md`](../loop/spec.md) — keys, movement, frame
  bytes
- [`../file/spec.md`](../file/spec.md) — exact save/load strings
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
- Legmacs `buffer.lg` (indexed lines, new states) and
  `render.lg` (full frame from visible rows) — seam catalog;
  do not copy highlight
- Chez Emacs `text.sls` — immutable line sequence on edit;
  do not copy the mutable store or `paint.sls` cache

`SPEC.md` remains language law. This spec is not language law.

## 6. Non-goals

- Faster Aloe evaluation in general
- Mutable `Text`, mutable editor fields, mutable bindings
- Kernel `Vector` (unless returned to the high-level discussion)
- Screen cache, dirty rectangles
- File I/O performance
- Syntax highlighting
