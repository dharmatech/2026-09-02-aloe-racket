# Checkpoint 113 — Gel Directory TOS path text

**Branch.** Continue on `experiment/gel-directory-surface`.

**Depends on.** Checkpoint 112 (live Gel `Directory` surface).

**Status.** Ready to implement.

**Revision (2026-09-10).** The first implementer attempt was restored
with no code landing. The original seam, a generic `GelText.tos-value`
overload on `(top subject)`, fails typecheck:

```text
typecheck: cannot infer method type parameter T for tos-value
```

The checker only propagates argument expectations for `List` methods
(`aloe/type.rkt`). That is a language limitation, not permission to edit
`aloe/` in this slice. This document now uses the checkpoint-112 private
selector plus typed `Mirror.invoke` pattern. Do not revive `tos-value`.
Do not expand this checkpoint into a checker change.

## Goal

When Gel's TOS is a live `Directory`, `File`, `SymbolicLink`, or `Other`,
render the object's class and existing absolute path instead of its nested
structural fields:

```text
TOS: #<Directory "/home/dharmatech">
TOS: #<File "/etc/passwd">
TOS: #<SymbolicLink "/bin">
TOS: #<Other "/dev/null">
```

This is Gel presentation only. Preserve every non-disk TOS byte, every menu,
and every key transition from checkpoint 112.

The implementer receives only this checkpoint. All rules for the slice are
here.

## Depends on

- `SPEC.md` remains Aloe law. Rendering uses ordinary sends and existing
  reflection; it adds no evaluator, checker, or dispatch rule.
- `docs/gel-directory-surface.md` ranked follow-up item 1 is the design
  authority for this slice.
- `docs/gel.md` defines the current `GelText.tos` behavior: `"TOS: "` plus
  `(top raw)`.
- `docs/filesystem-oo-vocabulary.md` and `lib/disk.aloe` define the four live
  classes. Each already answers `text` with its `Location` path.
- Checkpoint 112 already scans a TOS mirror for an exact zero-argument
  selector and invokes it through a typed helper (`gel-directory-values`,
  `gel-up`). Reuse that shape. Do not invent a second dispatch system.
- The parent is `experiment/gel-directory-surface` after completed checkpoint
  112.

## Exact file scope

Implementation may edit only:

- `gel/loop.aloe`
- `gel/directory.aloe`
- `tests/checkpoint-113.rkt` (new)
- `CHECKPOINTS.md` (append checkpoint 113 only)
- `docs/gel.md` (current TOS description only)
- `docs/gel-directory-surface.md` (mark ranked item 1 complete only)
- `docs/handoff.md` (current state only)

Do not edit `lib/disk.aloe`, any other `lib/` file, `aloe/`, `host/`, runners,
examples, `gel/menu.aloe`, `gel/stack.aloe`, `gel/main.aloe`, `SPEC.md`, prior
checkpoint documents, or prior tests.

Do not add a shared runner framework, a generic `show` protocol, `tos-value`,
or a checker special case.

## Required behavior

### Private TOS-text selector

In `gel/directory.aloe`, add one Gel-private zero-argument method to each of
`Directory`, `File`, `SymbolicLink`, and `Other`:

```aloe
(gel-tos-text () String
  (("#<Directory " append ((Mirror of (self text)) raw)) append ">"))
```

Use the matching class-name literal in each method (`Directory`, `File`,
`SymbolicLink`, `Other`). The path comes only from `(self text)`. Wrapping
that String in `Mirror` and taking `raw` reuses the existing escaped spelling
(quotes, backslashes, control characters) so the TOS stays one line.

Locks:

- These selectors are private integration seams, like `gel-directory-values`
  and `gel-up`. They are not a public disk-vocabulary change and not a
  protocol other classes should implement.
- Do not add `gel-tos-text` to `Location`, `Item`, `Disk`, List, Point, or
  any non-disk class.
- Do not include the host, `Location`, `Other.kind`, a trailing slash, or a
  symlink `@` in the TOS path form.
- Directory child-row labels remain exactly `name/`; symbolic-link child-row
  labels remain exactly `name@`.
- Do not parse `Mirror.raw` of the live object to obtain the class or path.

Keep the existing `gel-directory-values` and `gel-up` methods. This checkpoint
only adds the four `gel-tos-text` methods and any tiny local helper needed to
build those strings.

### `GelText.tos` uses the 112 invoke seam

Keep the public `(gel-text tos stack)` selector and `String` result. Change
its body only enough to append `"TOS: "` to a new helper on `GelText` that
takes the TOS `Mirror`.

That helper:

1. Scans `(top signatures)` for an exact zero-argument selector whose name is
   `"gel-tos-text"`.
2. If one is present, invoke that owned signature through the same mirror.
   Supply `String` as the invocation's expected type through a typed helper
   parameter/result, the same way `GelMenus.directory-values` supplies
   `GelValueRows`. Do not bind the reflective result to an unconstrained
   `let` variable.
3. If none is present, return `(top raw)`.

Consequences:

- Generic Gel without `gel/directory.aloe` keeps every checkpoint-112 TOS
  byte, including a live disk object's structural dump, because the selector
  is absent.
- After the Directory adapter is loaded, the four live classes print the path
  form.
- Point, List, Int, String, classes, host receivers, and all other non-disk
  values still use `(top raw)`.
- Do not call `(top subject)` as an argument to a generic `GelText` method.
  That is the failed `tos-value` design.
- Do not change `Mirror.raw`.
- Do not recognize disk objects by class-name parsing, host state, or Racket
  predicates.

`gel-main` continues to pass the `GelText.tos` String to `term write-line`,
which supplies the existing CRLF. No blank line, stack level, path header, or
menu text is part of `GelText.tos`. Disk and non-disk menus, stack contents,
keys, runners, capability injection, and application loading remain unchanged.

### Exact bytes

`(gel-text tos stack)` returns the following strings without a line ending:

| TOS subject | Result |
| --- | --- |
| live `Directory` at `/home/dharmatech` | `TOS: #<Directory "/home/dharmatech">` |
| live `File` at `/etc/passwd` | `TOS: #<File "/etc/passwd">` |
| live `SymbolicLink` at `/bin` | `TOS: #<SymbolicLink "/bin">` |
| live `Other` at `/dev/null` | `TOS: #<Other "/dev/null">` |

## Tests and hand check

Add `tests/checkpoint-113.rkt`. Cover at least:

1. Generic Gel without `gel/directory.aloe` preserves exact Int, String,
   List, and Point TOS strings. A live disk object also retains its old raw
   TOS until the Gel Directory adapter is loaded.
2. After loading `lib/disk.aloe` and `gel/directory.aloe`, all four live
   classes produce the exact table bytes above from their existing `text`.
   `Other.kind` is not printed.
3. A path containing a quote, backslash, or line-break character uses the
   existing escaped String spelling and does not create an extra output line.
4. The same objects' `(Mirror of object).raw` results remain the original
   structural dumps containing their stored fields; this checkpoint changes
   only `GelText.tos`.
5. Directory value rows and `u  up` retain checkpoint-112 bytes. File,
   SymbolicLink, and Other retain their derived menus. `gel-tos-text` must
   not appear as a selectable reflected row (zero-argument private selectors
   already used by the Directory surface stay hidden the same way
   `gel-directory-values` and `gel-up` are hidden).
6. A quit-only scripted `gel-main` run of the Directory application starts
   with `TOS: #<Directory "PATH">\r\n`, keeps its existing menu and key echo,
   and returns the unchanged one-item stack.
7. An isolated production-filesystem check renders the process's current
   live Directory with its actual absolute path. Automated tests do not open
   a physical TTY or depend on repository directory contents.
8. Checkpoint 112 and the full existing suite remain green; source assertions
   enforce the exact file scope (`aloe/` and `lib/disk.aloe` unchanged).

When a physical TTY and `tui-term` are available, run from the project root:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

The first line must be `TOS: #<Directory "ABSOLUTE-PROJECT-PATH">`; the child
menu is unchanged. Press `q` and confirm terminal restoration.

## Documentation and acceptance

Append only this entry to `CHECKPOINTS.md`:

```text
## 113. [Gel Directory TOS path text](docs/checkpoints/0113-gel-directory-tos.md)

- `GelText.tos` renders live `Directory`, `File`, `SymbolicLink`, and `Other`
  values with their class and existing path text; every other TOS and all Gel
  menus and controls remain unchanged.
```

Update only the corresponding current-state paragraphs in the allowed living
documents after tests are green.

Run:

```sh
raco test tests/checkpoint-113.rkt
raco test tests/*.rkt
git diff --check
```

The checkpoint is complete when all four live disk TOS forms have the exact
path presentation, every fallback still uses the original top mirror's raw
bytes, `aloe/` is untouched, and the named verification is green. Stop for
review without committing and without starting checkpoint 114.

## Explicit non-goals

- No hidden-file behavior; paging or search; options, home, or root commands;
  color, ANSI, multi-column/full-screen UI, or visible stack history.
- No file contents, edit, refresh, workspace, process, Git, or shell surface.
- No GelFS, hooks, plugins, keymaps, generic `show`/presentation protocol, or
  public disk-vocabulary change.
- No `tos-value`, no `(mirror subject)` generic send, no checker or evaluator
  edit, no widening of expected-type propagation beyond `List`.
- No new key, menu, runner, host capability, Aloe syntax, special form,
  mutation, inheritance, macro, or numeric coercion.
- Do not implement checkpoint 114.
- Do not start a language checkpoint for `aloe/type.rkt` in this change.
