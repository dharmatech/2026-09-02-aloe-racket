# aloemacs-kill 002 — Physical kill keys

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.

## Goal

Map Ctrl-W, Ctrl-Y, Ctrl-K, and Ctrl-Space from `tui-term` key messages to
the four command strings already handled by `AloemacsSession`. Prove the
mapping and its neighboring cases without a TTY. Stop when the focused test
and full aloemacs suite pass. Do not add editor or session behavior.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); this checkpoint narrows the spec to one slice and
does not revise it. Sections 1–2 and 6–8 of that spec govern this work,
especially §6's key and character conditions. `SPEC.md` governs Aloe, but
this checkpoint changes only Racket Term conversion and its test.

- Identity: **aloemacs-kill 002**. This is the final local checkpoint in the
  series, not a global checkpoint. Do not issue 003.
- **aloemacs-kill 000 and 001** are implemented and reviewed. The session
  already consumes the strings `"mark"`, `"kill"`, `"kill-line"`, and
  `"yank"`. Keep those transitions and their tests untouched.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- `host/racket/term.rkt` owns `tkeymsg->aloe-key`. Its existing plain
  Ctrl-S/F/Z predicates and Return, Escape, Backspace, and printable paths
  are the conversion seam. The `Term` host interface stays unchanged.

## Exact file scope

### May edit

- `host/racket/term.rkt` — add the four guarded chord conversions
- `tests/aloemacs/kill-key-mapping.rkt` — new focused no-TTY tests

### Must leave untouched

- `examples/aloemacs/`, `lib/`, `aloe/`, `bin/`, and the runner
- every existing test, including `kill-session.rkt`, `kill-excerpt.rkt`,
  `key-mapping.rkt`, and prior Ctrl-S/F/Z mapping tests
- `Term` host methods, `make-term-receiver`, TTY lifecycle, output,
  size handling, and `read-next-key` behavior
- `SPEC.md`, `CHECKPOINTS.md`, accepted specs, and earlier checkpoints
- every file not listed under **May edit**

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Required conversion

In `tkeymsg->aloe-key`, recognize these exact messages before either
printable-character branch. Predicates parallel to the existing
`plain-ctrl-s-key?` are suitable.

| Physical chord | `tkeymsg-key` | `tkeymsg-mods` | Accepted `tkeymsg-char` | Aloe string |
|---|---|---|---|---|
| Ctrl-W | `#\w` | exactly `'(ctrl)` | `#f` or `#\w` | `"kill"` |
| Ctrl-Y | `#\y` | exactly `'(ctrl)` | `#f` or `#\y` | `"yank"` |
| Ctrl-K | `#\k` | exactly `'(ctrl)` | `#f` or `#\k` | `"kill-line"` |
| Ctrl-Space, explicit space key | `#\space` | exactly `'(ctrl)` | `#f` or `#\space` | `"mark"` |
| Ctrl-Space, raw NUL form | ``#\` `` | exactly `'(ctrl)` | `#f` or ``#\` `` | `"mark"` |

The installed `tui-term` VT decoder turns raw NUL into the backtick form:
key ``#\` ``, modifiers `'(ctrl)`, character ``#\` ``. This byte cannot
distinguish another physical chord that emits the same NUL; accept that
encoding without inventing a new key or Term method.

Keep all other conversion behavior:

- Plain `w`, `y`, `k`, and space remain printable strings.
- Ctrl-Shift and Alt variants of the letters, and Shift/Alt modified
  spaces, stay on the existing printable or unsupported-key path.
- A mismatched decoded character does not match a new Ctrl predicate; the
  existing character-first printable path still decides its result.
- Ctrl-S, Ctrl-F, Ctrl-Z, Backspace, Return, and Escape retain their current
  mappings. An ordinary constructed `#\nul` without the decoded backtick
  shape remains subject to the existing unsupported-key behavior.

Do not change the ordering of existing special-key branches except to put
the new guarded clauses before both printable branches. Do not add prefix
keys, a data keymap, or a second conversion stage.

## Required focused tests

Write `tests/aloemacs/kill-key-mapping.rkt` first and observe failure for
the missing conversions. Use `rackunit`, `make-tkeymsg` from
`tui/term/messages`, and `tkeymsg->aloe-key` from the local Term module.
No checked Aloe driver or physical TTY is needed for this slice.

Cover:

1. Both `#f` and matching-character `tkeymsg-char` forms for Ctrl-W/Y/K and
   explicit Ctrl-Space, each yielding exactly the table's string.
2. Both accepted backtick forms for Ctrl-Space. Verify the installed raw
   decoder's NUL shape using a no-TTY port and pass that decoded message
   through `tkeymsg->aloe-key`. A tested local fixture is:

   ```racket
   (require tui/term/vt-input-port tui/term/tqueue
            (only-in tui/term/messages
                     make-tkeymsg tkeymsg-key tkeymsg-mods tkeymsg-char))
   (define decoded
     (read (make-vt-input-port (make-tqueue)
                               (open-input-string "\u0000"))))
   ; decoded fields: #\`, '(ctrl), #\`
   ; (tkeymsg->aloe-key decoded) => "mark"
   ```

3. Plain `w`, `y`, `k`, and space. Test neighboring Ctrl-Shift and Alt
   modifiers, including explicit space, and mismatched decoded characters;
   assert the actual preexisting printable or unsupported result, not a new
   command string.
4. Ctrl-S/F/Z, Backspace, Return, and Escape still map as before. Keep
   the existing `#\nul` unsupported-key assertion green.

Tests should compare exact strings and use no TTY. The raw decoder fixture
may be factored into a helper inside the new test file; do not edit the
installed `tui-term` package or its tests.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/kill-key-mapping.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

`-y` rebuilds changed Racket bytecode and dependent modules. Do not commit
`compiled/`. No physical TTY hand check is required; the raw decoder shape
is tested without one. If launching the editor after the `.rkt` edit, first
run the test command or
`raco make host/racket/aloemacs-run.rkt bin/aloe`.

Complete this checkpoint when all four chords yield the exact Aloe strings,
the raw NUL path yields `"mark"`, neighboring keys retain their behavior,
and the focused and full aloemacs tests pass. Report the changed files and
results, then stop for human review. Do not start another checkpoint.
