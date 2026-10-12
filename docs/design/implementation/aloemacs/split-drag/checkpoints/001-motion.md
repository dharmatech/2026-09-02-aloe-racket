# aloemacs-split-drag 001 — Motion and the field

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
Read the spec sections named below, implement this slice, and stop
when green.

## Goal

A mouse move reaches Aloe while a button is held, and the session
gains the field a drag will arm. Nothing arms, nothing drags, and a
move leaves every session unchanged.

- `AloemacsWindows` gains a last field, `drag`, an `(Option Int)`,
  with `armed` and `disarmed`. Every window send keeps it. Every
  construction in the program and the tests gains the fifth value.
- The mouse string gains a second shape, `mouse move <column> <row>`.
  `AloemacsMouse` gains `move?`, and `event?` accepts the shape.
- The session gains `disarmed`. A key disarms before `handle-key`. A
  left press disarms before `press-at`. A release, a middle or right
  button, and any other press disarm. A move is inert.
- `term.rkt` formats motion and skips it in `read-key`. The TTY entry
  asks for motion while a button is held, mode `1002`, instead of
  `1000`, inside the alternate screen.
- Forty-one existing test files change construction spelling, one
  formatter pin, and the mode phrases. Every expected session, frame,
  and count stays.

This is the second of four checkpoints. Stop when the focused proof
and the wider suite pass. Do not start 002.

## Authority, identity, and starting point

The implementer receives this checkpoint and the spec. The
checkpoint narrows the spec to one slice, restates its migration
inventory from a scratch run of the tree at issuance, and adds one
file that inventory predates. It does not revise the spec.

- Identity: **aloemacs-split-drag 001**, filed as
  `checkpoints/001-motion.md`. This is a local editor checkpoint. It
  takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`. `new*`
  requires every field (SPEC §4.11). No mutation, macros,
  inheritance, or new special forms.
- [../spec.md](../spec.md) governs:
  - §2.1: the predecessors, including the `tui-term` facts.
  - §3: the product boundary and the out-of-scope list.
  - §4: the file table and what stays alone.
  - §5.5: the field, `armed`, `disarmed`, the session's `disarmed`,
    `handle-event`, `handle-mouse`, and the event table.
  - §5.8: the move string, `move?`, `mouse-event-pattern`,
    `tmousemsg->aloe-mouse`, and the runner's bytes.
  - §5.9: what the series leaves in place.
  - §7: this layer. §7.1 is the product edit, §7.2 the examples,
    §7.3 the migration, §7.4 the focused proof.
  - §10: verification and the acceptance list.
- [000-weights.md](000-weights.md) is implemented and reviewed. The
  weights, the division, and `tests/aloemacs/split-drag-weights.rkt`
  are the starting point and do not change, except that the new
  focused file's declaration pin gains the field, under
  **Migration**.
- The accepted mouse spec stays the authority for the press and
  release strings, `read-event`, the quit rule, the refusals, and
  `press-at`. The accepted alternate-screen checkpoint stays the
  authority for `1049` and its order around the mouse mode. Do not
  edit those documents.
- `tui-term` as installed with this Racket is read, not edited.

### Current tree

Line numbers are from the tree at issuance on 2026-10-11, with 000
applied, and are approximate; search before editing.

- [examples/aloemacs/file.aloe](../../../../../../examples/aloemacs/file.aloe):
  - `AloemacsWindows` (line 803) has `tree`, `selected`, `columns`,
    `rows`. Its methods begin with `text-rect`. `with-split` (841)
    takes `(scroll-row scroll-col point below?)`. `with-toggled-lock`
    (848) takes nothing. `with-buffer` (858) takes a buffer.
    `without-buffer` (861) takes `(removed-id replacement)`.
    `with-size` (870) takes `(columns rows)` and returns `self` when
    either is not positive. All of them rebuild through `with`, so
    a fifth field survives them without edits.
  - `AloemacsMouse` (line 999) keeps one field, `event`. `event?`
    requires `mouse `, then `action-length` above 0, then
    `button-length` above 0, then two canonical decimals.
    `action-length` is 5 for `down `, 3 for `up `, else 0.
    `after-action` drops it. `button-length` is 5, 7, or 6 for
    `left `, `middle `, `right `, else 0. `coordinates` drops it;
    `column-text` and `row-text` split on the first space.
    `decimal?`, `digits?`, `digit?`, `digit-value`, and
    `decimal-value` are the parsers.
  - The session (line 1094): `unchanged` (1757) returns `self`.
    `handle-key` (2052). `handle-event` (2061) returns the receiver
    after quit, sends a mouse string to `handle-mouse`, and
    everything else to `handle-key`. `handle-mouse` (2069) refuses
    while `searching`, while `prompt` is present, and while
    `pending` is present; otherwise only a string with `down?` and
    `left?` reaches `press-at` (2084). `press-at` and
    `press-mode-line` do not change in this checkpoint.
- [examples/aloemacs/main.aloe](../../../../../../examples/aloemacs/main.aloe):
  `initial-windows` (line 39) is an `AloemacsWindows new*` with
  `tree`, `selected`, `columns`, `rows`.
- [host/racket/term.rkt](../../../../../../host/racket/term.rkt):
  requires `tui/term/geometry` for `tpoint?`, `tpoint-x`,
  `tpoint-y` (line 10). `mouse-event-pattern` (137) is the press
  grammar. `tmousemsg->aloe-mouse` (146) formats `button-down` and
  `button-up` with a `left`, `middle`, or `right` button at a
  `tpoint` of exact non-negative integers, else `#f`.
  `read-next-key` (164) returns the formatter's string for a
  `tmousemsg` and loops on `#f`. `term-read-event` (189) and
  `term-read-key` (194) are unchanged by this checkpoint.
- [host/racket/aloemacs-run.rkt](../../../../../../host/racket/aloemacs-run.rkt):
  the comment at lines 89–93 says "button presses and releases only
  (1000)". `run-aloemacs` (94) wraps `run-aloemacs-with-term` in a
  `dynamic-wind` whose before thunk writes
  `"\e[?1049h\e[?1000h\e[?1006h"` and whose after thunk writes
  `"\e[?1000l\e[?1006l\e[?1049l"`, each with `write-string` to
  `(current-output-port)` and a flush. ESC is spelled `\e`.
- `tui/term/messages` provides `make-tmousemsg` with fields
  `kind pos left right middle button`; it accepts five or six
  arguments, and the sixth, `button`, defaults to `#f`. The SGR
  decoder delivers motion with the button held as kind `move`.
- `tests/aloemacs/mouse.rkt` item 5 pins that a `move` formats as
  `#f`. Item 6 pins the phrases `[?1000h`, `[?1006h`, `[?1000l`,
  `[?1006l` in the runner and lists phrases absent from the runner,
  `term.rkt`, `gel-run.rkt`, and `term-run.rkt`. Item 7's runner
  test checks that no frame contains `[?1000h` or `[?1006h`.
  `tests/aloemacs/alternate-screen.rkt` defines `buttons-on` and
  `buttons-off` as the `1000` phrases and orders them around `1049`.
- `tests/aloemacs/runner.rkt` builds its session with an
  `AloemacsWindows new*` at line 58. Seven tests pin the
  configuration's field list as data, and thirty-seven test files
  construct it positionally. They are listed under **Migration**.

At issuance, from the project root,
`TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction`
passes 658 tests. 000 is implemented in the working tree; commit it
before starting this checkpoint, so that this checkpoint's diff is
its own.

### Size

One conversation. The product edit is one field and two short
methods on `AloemacsWindows`, one method and two small changes on
`AloemacsMouse`, one method and two reshaped methods on the session,
one label in `main.aloe`, one regexp and one reshaped procedure in
`term.rkt`, and two strings and a comment in the runner. Forty-one
test files take spelling edits, most of them one token per
construction. The focused file is new.

The manager applied exactly the product edit of **Required
behavior** to a scratch copy of the tree and ran the wider suite.
Forty-one files failed, the forty-one in **Migration** below: the
spec's §7.3 inventory plus `split-drag-weights.rkt`, which 000 wrote
after that inventory and which pins the configuration's fields.
After the migration edits below, all 658 passed with product changes
only in the four files named. The manager then checked every example
of §7.2 against that copy: the grammar, every rejected string, the
field reads, `read-event` and the `read-key` skip, the four
formatter values, the inert move on every listed session, the field
surviving every listed send, the nine disarming events, the inert
move on an armed session, and the three-frame runner script. All
hold. If you cannot finish in this conversation, stop and report
which files remain. Do not split the slice or write 002.

The implementation on 2026-10-11 followed this checkpoint as
written, after committing 000 as bf1d1e8. The manager reviewed the
diff against this checkpoint and found it conforming: the product
diff is the field, `armed`, `disarmed`, `move?`, the three
`AloemacsMouse` changes, the session's `disarmed`, the two handler
bodies, the `main.aloe` label, the regexp and the formatter with
their comments, and the runner's two strings and comment, and
nothing else; the forty-one test files change only in the places
named, with `alternate-screen.rkt` taking the allowed renames; the
focused file covers the nine items; the two focused files pass 20
tests, the wider suite 667, and `git diff --check` is clean. The
implementer found one defect in this document: it said seventeen
tests pin the ordered class list, but 000's focused file had made
it eighteen, and this checkpoint's makes it nineteen. The wording
above is now count-free.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, in exactly these places:
  1. `AloemacsWindows`: the field `drag` after `rows`, and the two
     methods `armed` and `disarmed`. Nothing else on the class.
  2. `AloemacsMouse`: `move?`, and the `event?`, `action-length`,
     and `button-length` changes of **Required behavior §3**. The
     other parsers may stay as they are; private helpers are allowed.
  3. `(AloemacsSession H)`: `disarmed`, and the bodies of
     `handle-event` and `handle-mouse`. Nothing else on the session.
  You may add a comment above each new method.
- `examples/aloemacs/main.aloe`: the one label in `initial-windows`.
- `host/racket/term.rkt`: `mouse-event-pattern` and
  `tmousemsg->aloe-mouse`. Nothing else.
- `host/racket/aloemacs-run.rkt`: the two mode strings and the
  comment above `run-aloemacs`. Nothing else.
- Create `tests/aloemacs/split-drag-motion.rkt` before the product
  edit, and watch it fail.
- The forty-one files under **Migration**, each only in the places
  that section names.

### Must leave untouched

- In `file.aloe`: every class other than the three above, including
  `AloemacsWindowTree`, `AloemacsWindowRect`, and `AloemacsView`;
  on `AloemacsWindows`, every existing method; on the session,
  `handle-key`, `press-at`, `press-mode-line`, `select-view`,
  `button-send`, `place-in`, `place-at`, `unchanged`, `enter-view`,
  `other-window`, `split-window`, `delete-window`, `ensure-visible`,
  `fit-rect`, `root-rect`, `frame`, `record-pictures`, the echo
  tokens, and the keymap tables. The tree gains no send: no
  `first-id`, `handle-id`, `min-rows`, `min-columns`, `handle-at`,
  or `with-cut-at`. The session gains no `press-handle` or
  `drag-to`. Do not change the order of declarations. The ordered
  `define-class` list is unchanged, so the tests that pin it as data
  need no edit for that reason; there were eighteen at issuance, and
  each focused file in this series adds one. `file.aloe` stays ASCII
  bytes.
- `examples/aloemacs/editor.aloe`, `host/racket/gel-run.rkt`,
  `host/racket/term-run.rkt`, `host/racket/fs.rkt`, `lib/`, `aloe/`,
  `bin/`, `gel/`, `archive/`, `SPEC.md`, `CHECKPOINTS.md`, and
  `tui-term`. In `term.rkt`: `term-interface`, `read-next-key`,
  `term-read-key`, `term-read-event`, `make-term-receiver`,
  `call-with-tty-term-receiver`, and `tkeymsg->aloe-key`. In the
  runner: `run-aloemacs-with-hosts`, `run-aloemacs-with-term`, the
  loop order, and the `dynamic-wind` shape. Add no Term method, host
  capability, kernel message, `lib/` method, Text method, class,
  command, key, keymap entry, face, or build step. Do not write
  `1000` or `1003`. Do not call `term-enable-mouse`.
- Every test not named under **Migration**. If one fails, the
  product is wrong; fix the product. Do not edit a fixture, a
  geometry, or an expectation to force the suite green. Create no
  shared helper module.
- Every document: this checkpoint, `000-weights.md`, `spec.md`,
  `charter.md`, and `README.md` in this folder; the mouse,
  alternate-screen, mode-buttons, windows, window-bars, and
  window-point documents; `docs/gel.md`; `docs/decisions.md`; and
  the parent `aloemacs/README.md`, `discussion.md`, and
  `explorations.md`.

If another file, another method, or a change to `press-at` seems
necessary, stop and report it. Do not widen this checkpoint.

## Required behavior

### 1. The field and its two sends (spec §5.5)

```text
(define-class AloemacsWindows
  (fields
    (tree AloemacsWindowTree)
    (selected Int)
    (columns Int)
    (rows Int)
    (drag (Option Int)))
  ...)
```

Add two methods. They can be pasted as they are:

```aloe
    (armed (id Int) AloemacsWindows
      (self with (drag (Option Some id))))

    (disarmed () AloemacsWindows
      (self with (drag (Option None))))
```

`drag` is `None` in every configuration the program builds; `armed`
is called by nothing in this checkpoint. `with-size`, `with-split`,
`with-toggled-lock`, `with-buffer`, and `without-buffer` already
rebuild through `with` and keep the field without edits. Nothing in
`file.aloe` constructs `AloemacsWindows` with `new`. The field is not
painted.

### 2. The session's `disarmed`, `handle-event`, and `handle-mouse` (spec §5.5)

Add `disarmed` and replace the bodies of `handle-event` and
`handle-mouse`. This can be pasted as it is:

```aloe
    ;; Nothing armed: the receiver itself. Otherwise the configuration
    ;; with drag cleared.
    (disarmed () (AloemacsSession H)
      (if (((self windows) drag) present?)
          (self with (windows ((self windows) disarmed)))
          self))

    (handle-event (event String) (AloemacsSession H)
      (cond
        ((self quit) (self unchanged))
        (((AloemacsMouse new event) event?) (self handle-mouse event))
        (else ((self disarmed) handle-key event))))

    ;; A search, a prompt, or a pending prefix refuses every mouse string.
    ;; A move is inert until 002. A left press disarms and then reaches
    ;; the cell; a release and every other button disarm.
    (handle-mouse (event String) (AloemacsSession H)
      (cond
        ((self searching) (self unchanged))
        (((self prompt) present?) (self unchanged))
        (((self pending) present?) (self unchanged))
        (else
          (let ((mouse (AloemacsMouse new event)))
            (cond
              ((mouse move?) (self unchanged))
              ((mouse down?)
                (if (mouse left?)
                    ((self disarmed) press-at (mouse column) (mouse row))
                    (self disarmed)))
              (else (self disarmed)))))))
```

`disarmed` returns the receiver itself when nothing is armed, so an
unarmed session is unchanged by identity, not by rebuilding. The
move arm is `(self unchanged)` in this checkpoint; 002 replaces it
with `drag-to`. `handle-key` is unchanged. Quit still wins before
the string is examined. The three refusals still come before the
cell is classified. The table this implements:

| Event | While not armed | While armed (a constructed configuration) |
|---|---|---|
| `mouse move` | Unchanged | Unchanged |
| `mouse down left` | Today's path | Disarms, then today's path |
| `mouse up left` | Unchanged | Disarms. Nothing else changes |
| `mouse down` or `mouse up` with middle or right | Unchanged | Disarms. Nothing else changes |
| A key | Today's path | Disarms, then today's path |
| Any mouse string during a search, a prompt, or a pending prefix | Unchanged | Unchanged |
| Any event after quit | Unchanged | Unchanged |

"Today's path" is the session `(s0 handle-event event)` returns on
the same session with `drag` `None`. Since every program-built
configuration has `drag` `None`, every existing expected session is
unchanged.

### 3. The move string and `AloemacsMouse` (spec §5.8)

A mouse event is one of these entire strings, fields separated by
one space, coordinates canonical decimals, 0-based:

```text
mouse <down|up> <left|middle|right> <column> <row>
mouse move <column> <row>
```

Accepted: `mouse move 0 0`, `mouse move 30 5`, and every string the
mouse spec accepts. Rejected, and therefore keys:
`mouse move left 30 5`, `mouse move 30`, `mouse move 030 5`,
`mouse move 30 5 ` with a trailing space, `mouse move -1 5`,
`mouse  move 30 5` with two spaces, `Mouse move 30 5`, and the mouse
spec's rejected strings.

| Send | Result |
|---|---|
| `(mouse event?)` | The whole string matches either shape |
| `(mouse move?)` | The action field is `move` |
| `(mouse down?)` | The action field is `down`; false on a move |
| `(mouse left?)` | The button field is `left`; false on a move |
| `(mouse column)`, `(mouse row)` | The decimals, as `Int`, on either shape |

One way, which the manager's scratch copy used and which passes
every example in this checkpoint: a move's action is five
characters, like `down `, and it has no button field, so the
coordinates follow the action directly.

```aloe
    (event? () Bool
      (if ((self event) starts-with? "mouse ")
          (if ((self action-length) > 0)
              (if (if (self move?) #t ((self button-length) > 0))
                  (if (self decimal? (self column-text))
                      (self decimal? (self row-text))
                      #f)
                  #f)
              #f)
          #f))

    ;; A move carries no button; its coordinates follow the action.
    (move? () Bool
      ((self after-mouse) starts-with? "move "))
```

`action-length` gains the arm `(((self after-mouse) starts-with? "move ") 5)`
before `else`. `button-length` answers 0 on a move before its
`cond`, so `coordinates` is everything after the action. That is
what rejects `mouse move left 30 5`: its column text is `left`, not
a decimal. `down?` and `left?` keep their definitions; both are
false on a move, because `after-mouse` does not start with `down `
and `after-action` is the coordinates. `column` and `row` keep their
definitions and read the coordinates on either shape. Add no kernel
message and no `lib/` method. On a string that is not an event,
`column` and `row` return some `Int` without raising; nothing sends
them then.

### 4. `term.rkt` (spec §5.8)

Replace the grammar:

```racket
(define mouse-event-pattern
  #rx"^mouse ((down|up) (left|middle|right)|move) (0|[1-9][0-9]*) (0|[1-9][0-9]*)$")
```

`read-key` skips a move exactly as it skips a press, with no change
to `term-read-key`. Replace `tmousemsg->aloe-mouse` so that kind
`move` at a `tpoint` of exact non-negative integers formats as
`mouse move <x> <y>`, reading neither the three held flags nor the
`button` field; `button-down` and `button-up` format as today. A
wheel kind, a negative or non-integer component, and a press or
release whose button is not `left`, `middle`, or `right` stay `#f`.
This can be pasted as it is:

```racket
(define (tmousemsg->aloe-mouse message)
  (and (tmousemsg? message)
       (let ([position (tmousemsg-pos message)])
         (and (tpoint? position)
              (exact-nonnegative-integer? (tpoint-x position))
              (exact-nonnegative-integer? (tpoint-y position))
              (let ([coordinates (string-append (number->string (tpoint-x position))
                                                " "
                                                (number->string (tpoint-y position)))])
                (case (tmousemsg-kind message)
                  [(move) (string-append "mouse move " coordinates)]
                  [(button-down button-up)
                   (and (memq (tmousemsg-button message) '(left middle right))
                        (string-append
                         "mouse "
                         (if (eq? (tmousemsg-kind message) 'button-down) "down" "up")
                         " "
                         (symbol->string (tmousemsg-button message))
                         " "
                         coordinates))]
                  [else #f]))))))
```

`read-next-key` is unchanged: it returns the formatter's string and
loops on `#f`, so a move reaches `read-event` and a wheel message is
still dropped. `term.rkt` contains no mouse mode: neither `1000`,
`1002`, `1003`, nor `term-enable-mouse`.

### 5. The runner's bytes (spec §5.8)

In `run-aloemacs`, the before thunk writes
`"\e[?1049h\e[?1002h\e[?1006h"` and the after thunk writes
`"\e[?1002l\e[?1006l\e[?1049l"`, each followed by its flush, as
today's strings are. Only `1000` becomes `1002` in each. The comment
above `run-aloemacs` says motion while a button is held, `1002`, in
SGR form, inside the alternate screen; for example its first two
lines become:

```text
;; The alternate screen (1049) first, then motion while a button is held
;; (1002) in SGR form (1006): enabled after with-term owns the output port,
```

The runner source then contains the substrings `[?1049h\e[?1002h\e[?1006h`
and `[?1002l\e[?1006l\e[?1049l` once each, where `\e` is the two
source characters backslash and `e`, and contains neither `1000`,
`1003`, nor `term-enable-mouse`. ESC stays `\e`; the runner tests
forbid the six characters `\u001b` and `write-line` in that source.
`with-term`'s cleanup still writes `1003l` and `1006l` afterwards;
the runner's `1002l` is what turns motion reporting off for the
shell. `run-aloemacs-with-hosts`, `run-aloemacs-with-term`, and
`call-with-tty-term-receiver` do not write those bytes. A scripted
run writes none.

### 6. `main.aloe`

`initial-windows` gains `(drag (Option None))` after `(rows 0)`.
`new*` requires every field, so the load fails until it does. The
scratch copy typed the bare `(Option None)` there; no `if #t`
spelling is needed.

### 7. What stays in place (spec §5.9)

The frame's bytes are unchanged. `press-at` still classifies with
the geometry of the last fit, and a left press still places a point
or runs a label. The catalog keeps six Term rows. Gel still sends
only `read-key` and `write-line`. The picture key does not gain the
field. No keymap binding, command constructor, kernel message, or
`SPEC.md` row.

## Tests

### Focused proof: `tests/aloemacs/split-drag-motion.rkt`

Write this file first and watch it fail. It uses a checked driver,
`rackunit`, `make-term-receiver`, and `run-aloemacs-with-hosts`, and
does not open a TTY. It does not call `with-term`,
`call-with-tty-term-receiver`, or `run-aloemacs`. Copy the helpers
you need from `tests/aloemacs/mouse.rkt` (`ev`, `def!`, `same`,
`dtype`, `rejects`, `scripted-driver`, `make-scripted-term`,
`frame-tail`) and from `tests/aloemacs/split-drag-weights.rkt`
(reading `file.aloe` as data). Do not `require` another test module.
Requires: `rackunit`, `racket/list`, `racket/port`,
`racket/runtime-path`, `racket/file`, `../../aloe/driver.rkt`,
`../../aloe/parse.rkt`, `../../aloe/type.rkt` (`exn:fail:aloe-type?`,
`type-of`, `type->datum`), `../../host/racket/term.rkt`,
`../../host/racket/fs.rkt`, `../../host/racket/aloemacs-run.rkt`,
`(only-in tui/term/messages make-tmousemsg)`, and
`(only-in tui/term/geometry tpoint)`.

The fs double is the one `mouse.rkt` uses:

```racket
(make-fs-double "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
  (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b"))
```

Fixtures, each an Aloe expression on the loaded `main.aloe`:

| Name | Expression |
|---|---|
| `s0` | `((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt")) ensure-visible 80 24)` |
| `saved` | `(s0 with-echo "saved")` |
| `tree` | `((s0 windows) tree)` |
| `b` | `(s0 current-buffer)` |
| `w` | `((s0 windows) armed 7)` |
| `a` | `(s0 with (windows ((s0 windows) armed 7)))` |

"Equals" is `(check actual expected)` through the driver.
"Unchanged" means the result equals the receiver. Prove:

1. **Types and arities.** `((AloemacsMouse new "x") move?)` types as
   `Bool` and rejects an argument. `((s0 windows) armed 7)` types as
   `AloemacsWindows`; `armed` with zero and two arguments and with
   `"7"` is rejected. `((s0 windows) disarmed)` types as
   `AloemacsWindows` and rejects an argument. `(s0 disarmed)` types
   as the session type (`(dtype 's0)`) and rejects an argument.
   `((s0 windows) drag)` types as `(Option Int)`.
   `(AloemacsWindows new tree 0 80 24)` is rejected and
   `(AloemacsWindows new tree 0 80 24 (Option None))` types as
   `AloemacsWindows`. `handle-event` and `handle-mouse` keep the
   session type. Read as data with `port->list read`,
   `AloemacsWindows` declares
   `(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int) (drag (Option Int)))`,
   the session's `fields` list has fourteen entries, and the ordered
   `define-class` list is the one `split-drag-weights.rkt` pins,
   unchanged.
2. **Grammar.** `event?` is true for `mouse move 0 0`,
   `mouse move 30 5`, `mouse down left 4 2`, `mouse up middle 0 0`,
   and `mouse down right 10 12`, and false for each rejected string
   in **Required behavior §3** and each rejected string of
   `mouse.rkt` item 2. For `mouse move 30 5`: `move?` true, `down?`
   false, `left?` false, `column` 30, `row` 5. For `mouse move 0 0`:
   `column` 0, `row` 0. For `mouse down left 4 2`: `move?` false,
   `down?` true, `left?` true, `column` 4, `row` 2.
3. **Reader.** With `make-term-receiver` over a thunk that yields
   `"mouse move 30 5"` then `"x"`: `(term read-event)` through a
   checked driver returns the move string, and a second returns
   `"x"`. With a fresh receiver over the same script,
   `(term read-key)` returns `"x"`. Over `"mouse move 030 5"` then
   `"x"`, `read-key` returns `"mouse move 030 5"`.
4. **Formatter.** `(tmousemsg->aloe-mouse (make-tmousemsg 'move (tpoint 30 5) #t #f #f))`
   is `"mouse move 30 5"`;
   `(make-tmousemsg 'move (tpoint 4 2) #f #f #f 'left)` formats as
   `"mouse move 4 2"`; `(make-tmousemsg 'move (tpoint -1 2) #t #f #f)`
   and `(make-tmousemsg 'wheel-up (tpoint 4 2) #f #f #f)` format as
   `#f`. `(make-tmousemsg 'button-down (tpoint 4 2) #t #f #f 'left)`
   still formats as `"mouse down left 4 2"`, and a `button-down`
   with button `#f` is still `#f`.
5. **Sources.** Read each file with `file->string`. The runner
   contains `[?1049h\e[?1002h\e[?1006h` and `[?1002l\e[?1006l\e[?1049l`
   once each, spelled in the test as
   `"[?1049h\\e[?1002h\\e[?1006h"` and `"[?1002l\\e[?1006l\\e[?1049l"`;
   it contains `(term read-event)` once; and it contains neither
   `1000`, `1003`, nor `term-enable-mouse`. `term.rkt` contains
   none of `1000`, `1002`, `1003`, `term-enable-mouse`. `gel-run.rkt`
   and `term-run.rkt` contain none of `read-event`, `1000`, `1002`,
   `term-enable-mouse`.
6. **A move is inert.** `(saved handle-event "mouse move 30 5")` is
   unchanged, and its `echo` is `"saved"`. Each of `(s0 split-right)`,
   `(s0 split-below)`, `((s0 ensure-visible 40 10) split-below)`,
   `(s0 handle-key "find")`,
   `(((s0 handle-key "ctrl-x") handle-key "find") handle-key "tab")`,
   `(s0 handle-key "ctrl-x")`, and `(s0 handle-event "escape")` is
   unchanged by `handle-event "mouse move 30 5"`. Assert first that
   the fourth has `searching` true, the fifth a present `prompt`,
   the sixth a present `pending`, and the seventh `quit`.
7. **The field survives.** `(((s0 windows) drag) present?)` is
   false. It is still false on each of `(s0 split-below)`,
   `(s0 split-right)`, `((s0 split-below) other-window)`,
   `((s0 split-below) delete-window)`, `(s0 toggle-window-lock)`,
   `(s0 ensure-visible 120 24)`, `(s0 record-pictures 80 24)`,
   `(s0 find-file-submitted "b.txt")`, `(s0 handle-event "x")`,
   `(s0 handle-event "mouse down left 4 0")`, and
   `(s0 handle-event "mouse up left 4 0")`. `(w drag)` equals
   `(Option Some 7)`, and so does `drag` on each of
   `(w with-size 120 24)`, `(w with-split 0 0 (Position new 0 0) #t)`,
   `(w with-toggled-lock)`, `(w with-buffer b)`, and
   `(w without-buffer 41 b)`. `(((w disarmed) drag) present?)` is
   false.
8. **Events disarm.** `a` does not equal `s0` (assert that the
   `check` raises) and `(((a windows) drag) present?)` is true. For
   each of `"x"`, `"left"`, `"ctrl-x"`, `"find"`, `"escape"`,
   `"mouse up left 4 0"`, `"mouse down middle 4 0"`,
   `"mouse up right 4 0"`, and `"mouse down left 4 0"`:
   `(a handle-event e)` equals `(s0 handle-event e)`, and its `drag`
   is not present. `(a handle-event "mouse move 4 0")` equals `a`;
   002 changes this one row. `(s0 disarmed)` equals `s0` and
   `(a disarmed)` equals `s0`.
9. **Runner.** With `make-scripted-term` as `mouse.rkt` item 7
   builds it, the fs double above, and `"a.txt"`: the script `x`,
   `mouse move 3 3`, `escape` leaves the key list empty and records,
   for each of the three keys in order, `(columns 80)`, `(rows 24)`,
   `(write frame)`, `flush`, `(key k)`. There are three frames; the
   third equals the second, and the second does not equal the
   first, because `x` was inserted. No frame contains `[?1000h`,
   `[?1002h`, `[?1006h`, or `[?1049h`.

### Migration (spec §7.3)

Forty-one test files change, plus `main.aloe` under **Required
behavior §6**. Every expected session, frame, count, and refusal in
these files stays as it is. Line numbers are from the tree at
issuance; search for the text before editing.

**Positional constructions.** Each `(AloemacsWindows new tree selected columns rows)`
gains a fifth argument, written literally as ` (Option None)` after
the fourth, inside the form's own closing paren. The count is the
number of forms in that file; a helper such as
`` `(AloemacsWindows new ,tree ,selected ,w ,h) `` counts once and
becomes `` `(AloemacsWindows new ,tree ,selected ,w ,h (Option None)) ``:

| File | Forms |
|---|---:|
| `buffer-session.rkt` | 3 |
| `buffer-value.rkt` | 3 |
| `completion-frame.rkt` | 1, the `windows` helper |
| `completion-page-frame.rkt` | 1, the `windows` helper |
| `completion-page-session.rkt` | 3 |
| `completion-session.rkt` | 5 |
| `echo-session.rkt` | 1 |
| `file-session.rkt` | 3 |
| `idle-echo.rkt` | 2 |
| `keymap-prefix.rkt` | 5 |
| `keymap-session.rkt` | 5 |
| `kill-session.rkt` | 2 |
| `minibuffer-session.rkt` | 2 |
| `minibuffer-value.rkt` | 3 |
| `mode-buttons-paint.rkt` | 1, the `session` helper |
| `mode-line-one-view.rkt` | 3 |
| `mode-line-split-views.rkt` | 1, the `windows` helper |
| `motion-editor.rkt` | 1 |
| `mouse.rkt` | 1 |
| `prompt-commands-find-file.rkt` | 2 |
| `prompt-commands-save-as.rkt` | 2 |
| `prompt-commands-select-buffer.rkt` | 2 |
| `safe-cells.rkt` | 1 |
| `search-session.rkt` | 2 |
| `undo-session.rkt` | 1 |
| `viewport-editor.rkt` | 3 |
| `visited-unchanged.rkt` | 2 |
| `window-bars-one-view.rkt` | 1, the `windows` helper |
| `window-bars-split.rkt` | 1, the `config` helper |
| `windows-buffer-identity.rkt` | 3 |
| `windows-delete-and-other.rkt` | 1, the `config` helper |
| `windows-layout-and-rendering.rkt` | 1, the `config` helper |
| `windows-lock.rkt` | 1, the `config` helper |
| `windows-split.rkt` | 1, the `config` helper |
| `windows-state-foundation.rkt` | 3: the `windows` helper at lines 65–68, whose last line becomes `,view ,columns ,rows (Option None)))`, and the two typed sends at lines 188–189, each becoming `(AloemacsWindows new tree 19 80 24 (Option None))` |
| `windows-state.rkt` | 2 |
| `tests/parenthetical-construction/session.rkt` | 1 |

**Labeled construction.** `tests/aloemacs/runner.rkt` line 58 uses
`new*`; it gains `(drag (Option None))` after `(rows 0)`, as
`main.aloe` does.

**Declaration pins.** Each pins
`(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int))`
and gains `(drag (Option Int))` at the end:

| File | Line |
|---|---|
| `mode-line-row.rkt` | 35 |
| `split-drag-weights.rkt` | 99 |
| `window-bars-one-view.rkt` | 171 |
| `window-bars-split.rkt` | 210 |
| `windows-layout-and-rendering.rkt` | 475 |
| `windows-state.rkt` | 638 |
| `windows-state-foundation.rkt` | 146 |

`mode-line-row.rkt` and `split-drag-weights.rkt` construct nothing
positionally and fail only on this pin; the other five also
construct. Spec §7.3 predates `split-drag-weights.rkt`; this
checkpoint adds it.

**Keep rejected.** `windows-state-foundation.rkt` lines 207–209
send `(AloemacsWindows new tree 19 80)`,
`(AloemacsWindows new tree 19 80 24 0)`,
`(AloemacsWindows new v4 19 80 24)`,
`(AloemacsWindows new tree #t 80 24)`,
`(AloemacsWindows new tree 19 #f 24)`, and
`(AloemacsWindows new tree 19 80 "24")` inside a rejection loop.
Three arguments, four, five with an `Int` fifth, and the type-wrong
forms are all still rejected; those lines do not change.

**Host pins.**

- `tests/aloemacs/mouse.rkt` item 5, line 175: the `check-false` on
  `(make-tmousemsg 'move (tpoint 4 2) #f #f #f 'left)` becomes a
  `check-equal?` against `"mouse move 4 2"`. The other formatter
  pins stay.
- `tests/aloemacs/mouse.rkt` item 6, lines 187–196: the required
  runner phrases become `[?1002h`, `[?1006h`, `[?1002l`, `[?1006l`,
  `aloemacs-editor handle-event`; the list of phrases absent from
  the runner gains `"1000"`; the list absent from `term.rkt` gains
  `"1002"`; the list absent from `gel-run.rkt` and `term-run.rkt`
  gains `"1002"`. The test-case name may say motion. Item 7's frame
  checks for `[?1000h` and `[?1006h` stay as they are; a frame
  contains neither.
- `tests/aloemacs/alternate-screen.rkt` lines 31–32: `buttons-on`
  and `buttons-off` become `"[?1002h"` and `"[?1002l"`. Rename them
  if you like, and make the test-case names and the header comment
  say motion instead of button tracking. The order assertions do
  not change.

No other file changes. The class-list pins stay green: no class is
added. If any file outside the forty-one fails, the product is
wrong; fix the product.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/split-drag-weights.rkt tests/aloemacs/split-drag-motion.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction
```

```sh
git diff --check
```

Every agent test run includes `TMPDIR=/tmp`, `-j 4`, and `-y`. Do
not commit `compiled/`. This checkpoint edits `.rkt` files, so a
launch by hand afterwards needs
`raco make host/racket/aloemacs-run.rkt bin/aloe` first; the test
command rebuilds what it runs. The implementer does not need a TTY.
`tests/aloemacs/window-pictures.rkt` holds a 30 ms timing bar and
can fail under heavy parallel load; a failure there alone is rerun
by itself, not fixed.

The checkpoint is complete when:

- both test commands pass and `git diff --check` is clean; the
  second command passes its 658 tests at issuance plus the new file's
- the only product changes are: in `file.aloe`, the field, `armed`,
  `disarmed`, `move?`, the three `AloemacsMouse` changes, the
  session's `disarmed`, and the two handler bodies; in `main.aloe`,
  the one label; in `term.rkt`, the regexp and the formatter; in
  the runner, the two strings and the comment
- `file.aloe` is still ASCII bytes, the runner source contains no
  `1000`, and `term.rkt` contains no `1002`
- the existing-test changes are limited to the forty-one files
  above, in the places named
- `tests/aloemacs/split-drag-motion.rkt` exists and covers the nine
  items above

Report the files changed and the verification output. Then stop.
Do not write 002.

### Optional smoke check

The series' hand check is the human's, after 003. Because this
checkpoint changes the bytes the shell sees, the human may run this
once after the tests are green, on a real terminal with SGR mouse
reporting, after `raco make host/racket/aloemacs-run.rkt`:

```sh
racket host/racket/aloemacs-run.rkt /tmp/motion.txt
```

Press a button in the text and move with it held: the point stays on
the press and nothing else changes. Release. Escape quits. In the
shell, mouse selection works again and moving the mouse prints
nothing. A failure sends the work back. It does not add a feature.

## Non-goals

- Spec §3's out-of-scope list: drag-to-select, hover, mode `1003`,
  the wheel, the middle and right buttons doing anything; a click
  on a path component, the directory browser, describe, or jump to
  definition; painting `│`, a fourth glyph, a painted drag state, a
  cursor change, or a new face; dragging the echo row or the bottom
  mode line; changing selection, a point, scrolling, or an entry
  handoff; a keyboard resize, a keymap change, or a new command
  constructor; balancing, equalizing, saved layouts, or writing a
  weight from anything but a split; a new class, a field on a view,
  a picture, or the session, or a Term method; changing
  `split-below`, `split-right`, `delete-window`, `other-window`, or
  the lock toggle; a display-width table; a change to `tui-term`,
  Gel, or `term-run.rkt`; editing any accepted spec or the parent
  map; a kernel message, a `SPEC.md` row, a `lib/` method, or a
  `CHECKPOINTS.md` entry.
- Everything 002 and 003 own: `first-id`, `handle-id`, `min-rows`,
  `min-columns`, `rows-from`, `columns-from`, `handle-at`,
  `with-cut-at`, `press-handle`, `drag-to`, any change to `press-at`
  or `press-mode-line`, and any move that writes a weight. Nothing
  calls `armed` in the program; an armed configuration exists only
  in the focused test.
- Painting `drag`, a bar glyph other than `|`, or any frame byte.
- Do not edit a spec, a charter, a README, or another checkpoint.
  Do not start Boids.
