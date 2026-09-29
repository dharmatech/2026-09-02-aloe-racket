# Charter — linear String load and save

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not a checkpoint. Not an implementer
assignment. Specification will live beside this file as
[`spec.md`](spec.md). Process:
[`docs/workflow.md`](../../../workflow.md).

**Your job.** Turn this charter into a specification that makes
**opening a large file** and **writing it back** cheap: linear
`String.split-lines` (visit / `indexed-value`) and linear
reconstruction of a source string from indexed lines (`Text.to-string`
/ save). Then **stop**. Do not write checkpoints. Do not implement.
Do not specify echo, minibuffer, safe `ESC`/tab/CR display, class
methods, a StringBuilder, Vector, or mutation.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.8.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **string-load-save 000**, … under
   `docs/design/implementation/string-load-save/checkpoints/`
   (not `docs/checkpoints/0116` unless the human promotes after
   review).
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice**. Editor chrome, terminal
sanitizing, and a new String representation “because it might help
later” are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| Checkpoint 114 / 115 | Kernel `=`, `append`, `len`, `take`; `define-methods String`; `starts-with?` in [`lib/string.aloe`](../../../../lib/string.aloe) |
| aloemacs-text 000 | Kernel `drop`; Aloe `split-lines` with the empty-piece table |
| [`lib/text.aloe`](../../../../lib/text.aloe) | `from-string` / `indexed`; `indexed-value` splits; indexed `to-string` folds `append` |
| aloemacs File + Index | Visit builds `((Text from-string contents) indexed-value)`; save writes `(text to-string)` |
| Index zipper | Motion and frame are already cheap; this series does not retune them |

**Why this series:** scrolling a 10,000-line buffer is already
fast. Opening it and saving it are still quadratic. On this
machine, the Index fixture (10,000 one-character lines, source
length 19,999) measured:

| Send | Time |
|---|---|
| `(Text from-string source)` | ~0.02 ms |
| `(cold indexed-value)` / `(source split-lines)` | **~5.6–5.8 s** |
| `(indexed to-string)` at focus 0 (fold of `append` + `"\n"`) | **~1.5 s** |
| `(cold to-string)` | ~0.04 ms |

Visit pays the split. Save of an already-indexed buffer pays the
fold. The ~1.5 s figure is focus 0, where `lines` is a single
`cons`. At the last line, `lines` copies a vector per preceding
line before that fold starts. Cold `to-string` is already the
stored source.

**Consumer (do not rewrite the editor here):**
[`examples/aloemacs/file.aloe`](../../../../examples/aloemacs/file.aloe)
`visited` indexes at focus 0. `save` sends `to-string` on the
session `Text`, which stays focused at the cursor. Gel, frame
ANSI folds of a handful of pieces, and `Position.after` on a short
insert are out of scope except that they keep working.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **`split-lines` results are unchanged.** The table in
   aloemacs-text remains law:

   | `s` | `(s split-lines)` |
   |---|---|
   | `""` | `(List of "")` |
   | `"ab"` | `(List of "ab")` |
   | `"ab\ncd"` | `(List of "ab" "cd")` |
   | `"ab\n"` | `(List of "ab" "")` |
   | `"\n"` | `(List of "" "")` |

   Split is at LF only. CR stays inside a piece (`"a\r\nb"` →
   `"a\r"`, `"b"`). No Char type. Existing
   `tests/aloemacs/000-string-prerequisite.rkt` goldens stay green.

2. **Indexed `to-string` still round-trips** as Index requires:
   for every source `s` and valid focus `n`, focusing then
   `(text to-string)` equals `s` (multiple final LFs, CR, BOM,
   Unicode). Cold `from-string` `to-string` remains the stored
   source and stays O(1) in the source length.

3. **Load and save of the Index 10k fixture are cheap.** A
   no-TTY script, in the same spirit as
   [`tests/aloemacs/index-002-timing.rkt`](../../../../tests/aloemacs/index-002-timing.rkt)
   (`module+ main`, outside `raco test tests`), times three
   intervals separately:

   1. `(Text from-string source)` then `indexed-value`
      (visit / split).
   2. `to-string` of that value (focus 0, the visit result).
   3. `to-string` of an indexed value focused at the last
      line. Building that value, including any `focus-at`, is
      outside this interval.

   The spec names a numeric bar at least **50× below** the
   floors in §2. Interval 1 is judged against the ~5.6 s split.
   Intervals 2 and 3 are both judged against the ~1.5 s
   focus-0 join. A design that rewrites the current
   per-character Aloe loop and still copies the remainder on
   every `drop` has failed, even if it is somewhat faster. A
   design that joins `(self lines)` has failed interval 3 even
   when interval 2 passes.

4. **Tests first**, under `tests/string-load-save/` (not
   `tests/checkpoint-N.rkt` unless promoted). Cover the
   split-lines table, the §4.7 flatten edges (empty `above`,
   empty `below`, both empty, empty separator, many pieces, a
   final empty piece), indexed round-trip at more than one
   focus, and that `(3 split-lines)` or a non-String separator
   or `current` is a type error. Surgical catalog updates to
   existing String reflection tests are allowed when kernel rows
   change; do not weaken unrelated assertions.

5. No class methods, no mutating builder, no Vector, no
   `CHECKPOINTS.md` number, no echo/minibuffer/safe-cell work,
   no change to visit/save control flow unless those methods
   bypass the new linear path (today they do not).

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Same algebra, cheaper work

Public sends stay `(s split-lines)` and `(text to-string)`.
Line pieces, LF-only splitting, and exact save bytes do not
change. This series is cost, not a new text model.

### 4.2 Irreducible linear work is kernel-shaped

Aloe today has binary `append` and copying `take` / `drop`
(`substring` in `aloe/eval.rkt`). A per-character Aloe
`split-lines` copies the remainder at every step. A per-line
Aloe loop that `(s drop i)` after each LF still copies the
unread suffix once per line. Folding `(source append "\n")
append line` copies a growing prefix once per line.

Philosophy: facts that cannot be linear in Aloe with those
primitives belong in the kernel (or an equivalent host
implementation behind the same send), like `len` and `take`.
A rewritten Aloe character loop is not a solution. A
StringBuilder, mutation, or Vector is not a solution in this
series.

### 4.3 First consumer is already wired

`visited` indexes with `split-lines`. `save` writes
`to-string`. Make those sends linear. Prefer **not** editing
`examples/aloemacs/` at all. `lib/text.aloe` indexed
`to-string` may switch to the new flatten send; cold
`to-string` stays the stored payload.

### 4.4 Where code may live

- [`lib/string.aloe`](../../../../lib/string.aloe) — current
  Aloe `split-lines`; stays or shrinks according to §4.6
- [`lib/text.aloe`](../../../../lib/text.aloe) — indexed
  `to-string` (and only that, plus tests forcing a helper on
  Text)
- `aloe/eval.rkt`, `aloe/type.rkt`,
  `aloe/signature-catalog.rkt` if a kernel String message is
  added
- `SPEC.md` §7.5 if §4.8 says this series amends it
- Tests under `tests/string-load-save/`, plus surgical updates
  to String catalog / checkpoint 114–115 / editor signature
  fixtures when row order changes (same kind of maintenance
  aloemacs-text 000 did)
- **Not** Gel, Term, Fs host, `examples/aloemacs/` (unless §4.3
  is violated by a bypass), echo, `CHECKPOINTS.md`, parser
  syntax, class-method machinery, `lib/list.aloe` generic
  concat

### 4.5 Out of this series

- Safe display of `ESC` / tab / `CR` in the TTY
- Echo, minibuffer, `C-x`, windows, dirty bit
- Class methods / `(String join …)` as a class-side send
- Generic `(List T)` concat or protocols
- Mutating StringBuilder, Vector, compiler, paint cache
- Changing `take` / `drop` clamping or `append`
- Changing `List` `cons` / `rest`, the `List` spine, or adding
  generic list append. Making `(text lines)` linear
- Promoting the series onto `CHECKPOINTS.md` inside the spec
- Rewriting Index motion or `next-lines`

### 4.6 How `split-lines` becomes linear (resolve this)

Two honest designs; pick one and record why.

**A. Kernel `split-lines`.** Same public send, one Racket scan,
  one allocation per piece (unavoidable). Remove the Aloe body
  from `lib/string.aloe`. Kernel rows then include `split-lines`
  after `drop`. `starts-with?` remains Aloe. **Lean here:**
  smallest language change, same API, matches 114’s diamond
  (irreducible scan is kernel).

**B. Kernel suffix view / skip-prefix**, so `drop` (or a new
  skip) does not copy, plus an Aloe per-line split. This changes
  String representation or adds a slice type. Per-character Aloe
  remains too many interpreter sends even with O(1) drop.
  Choose B only if you can still meet the §3.3 bar without a
  kernel split, and you specify identity, sharing, and
  `take`/`drop`/`append` on the new representation.

Do not pick “Aloe with `index-of` plus copying `drop` per
line.” That is still quadratic in remaining bytes.

Name catalog order and which historical tests move a row.

### 4.7 How indexed `to-string` becomes linear (resolve the selector)

Indexed `to-string` flattens the three indexed fields in
document order. `above` stores the nearest preceding line
first, so the copy reads `above` from its last element back
to its first, then `current`, then `below` from first to
last. One LF between neighboring pieces. A trailing LF in
the source is an empty piece already in those fields, not an
extra separator after the last piece. Pieces are copied as
given. Cold `to-string` does not go through this path and
stays the stored source.

The copy is one kernel exact-size allocation (Racket
`string-join` / `string-append*` is the usual host fact).
The kernel message receives the separator and the three
fields, and indexed `to-string` sends it once. It does not
send `lines`, `reverse`, `fold`, `cons`, or `rest`.
Rebuilding the line list is not a step in this series.
`(text lines)` stays the reconstruction it is. Do not
invent a second public Text message if `to-string` is enough.

Class methods are **out**. A `(List String)` join is **out**:
`cons` copies, so a list built in Aloe is quadratic at a deep
focus, and generic list append is §4.5. The long-term
class-side `(String join separator parts)` stays parked.
Leave the selector name `join` free for that later method.

**Open:** the 0.1 instance selector and its catalog row.
Record the name (for example `joined-with`) and which
historical tests move a row. The arguments are fixed:

| Argument | Type |
|---|---|
| separator | `String` |
| above | `(List String)` |
| current | `String` |
| below | `(List String)` |

Result is `String`. An empty `above` or `below` list
contributes no pieces and no separator. An empty string
element is a real piece. Both lists empty returns
`current`. An empty separator concatenates in that same
document order.

### 4.8 SPEC.md (resolve this)

aloemacs-text 000 added kernel `drop` without editing
`SPEC.md`; §7.5 still lists `=`, `append`, `len`, `take`.
int-methods **did** amend SPEC for `define-methods Int`.

If §4.6 or §4.7 adds kernel rows, say whether this spec updates
§7.5 (and, while there, documents existing `drop`). Lean:
**update §7.5** so the language document matches the machine;
still **do not** take a global checkpoint number. If you leave
SPEC unchanged, say that promotion is a later human copy, as
with `drop`.

## 5. Authority

- [`SPEC.md`](../../../../SPEC.md) §7.5 (String kernel), §3.1
  (`define-methods` instance methods only), evaluation is send
- [`docs/philosophy.md`](../../../../docs/philosophy.md) —
  kernel small; grow from applications; irreducible host facts
- [`docs/checkpoints/0114-string-len-take.md`](../../../../docs/checkpoints/0114-string-len-take.md)
  and
  [`docs/checkpoints/0115-string-starts-with.md`](../../../../docs/checkpoints/0115-string-starts-with.md)
  — kernel vs Aloe String
- [`docs/design/implementation/aloemacs/text/spec.md`](../aloemacs/text/spec.md)
  §2.2 — `split-lines` table; §2.1 — `drop`
- [`docs/design/implementation/aloemacs/text/checkpoints/000-string-prerequisite.md`](../aloemacs/text/checkpoints/000-string-prerequisite.md)
- [`docs/design/implementation/aloemacs/index/spec.md`](../aloemacs/index/spec.md)
  §3 — indexed `to-string` round-trip; `to-string` is for save
  and tests, not motion
- [`lib/string.aloe`](../../../../lib/string.aloe),
  [`lib/text.aloe`](../../../../lib/text.aloe),
  [`aloe/eval.rkt`](../../../../aloe/eval.rkt) `send-to-string`
- [`examples/aloemacs/file.aloe`](../../../../examples/aloemacs/file.aloe)
  `visited` / `save`
- Parent editor map:
  [`docs/design/implementation/aloemacs/README.md`](../aloemacs/README.md)

`SPEC.md` remains language law. This spec amends it only as
§4.8 decides. Split-lines results and Text round-trip are
owned by the Text/Index specs; this spec supersedes only their
**cost**.

## 6. Non-goals

- Safe control-character display
- Echo, search, minibuffer, prefix maps, windows
- Class methods, StringBuilder, Vector, mutation, compiler
- A new `List` spine, generic list append, or a linear `lines`
- Gel `rows-text` or `frame-ansi` folds (few pieces)
- Changing Ctrl-S / visit / path policy
- Global checkpoint 116

## 7. Handoff (series facts)

- **Identity:** `string-load-save`. Spoken **string-load-save
  000**. Folder:
  `docs/design/implementation/string-load-save/`.
- **Project root:**
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- **Intended order** (manager writes one file at a time; may
  split a layer that misses checkpoint size, keeps this order,
  adds no features):

  1. **Linear `split-lines` (000).** Same results, cheap
     `indexed-value` / visit of the 10k fixture. Catalog and
     library rows as §4.6.
  2. **Linear flatten and indexed `to-string` (001).** The §4.7
     kernel message; indexed `to-string` sends it and does not
     rebuild `lines`. Focus-0 and last-line `to-string` of the
     10k fixture both meet §3.3. Round-trip goldens hold.
     `List` representation stays.

- Tests: `tests/string-load-save/` plus the surgical catalog
  edits §4.4 allows. Timing script: `module+ main`, like Index
  002; this machine may need `TMPDIR=/tmp`.
