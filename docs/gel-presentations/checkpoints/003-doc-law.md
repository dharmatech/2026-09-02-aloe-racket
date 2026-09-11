# gel-presentations 003 — doc law

**Spoken name.** gel-presentations 003. Not “checkpoint 118”. Not
“gel 003”. Not a rewrite of 001.

**Branch.** Continue on `experiment/2026-09-11-gel-presentations`
after green gel-presentations 002. Do not start from `main`. Do not
merge to `main`.

**Depends on.** gel-presentations 000 (List) and 002 (Directory
family on the host-holding class). **001 stays blocked.** Frozen
Directory UX remains global 112–117.

**Status.** Complete (implemented; current Gel law describes 000/002).

**Authority.** `docs/gel-presentations/spec.md` §11, applied to the
shape that actually landed (§4.3 / §6.2 / 002). `SPEC.md` is Aloe
language law. Frozen Directory UX is
`docs/gel-directory-surface.md` and global 112–117; do not reopen
it.

The implementer receives only this document.

## Goal

Apply Gel-presentations wording to current Gel law. Code already
moved. This slice is **docs only**.

Replace the private-seam story (`List.gel-values` on `List`,
`gel-directory-values` / `gel-up` / `gel-tos-text` on disk types,
string-matching those names on the specimen) with Gel-owned
presentations. Keep the frozen UX sentences. Keep the reserved-name
table: Listener, Inspector, Browser.

Do **not** copy spec §11’s withdrawn sentence that
`gel/directory.aloe` extends `GelPresentations`. 001 is blocked.
002 put Directory methods on `GelDirectoryPresentations`, which
holds `fs-host`. Document that.

Stop and return this checkpoint for revision before writing any
code if the work starts to do any of:

- edit `gel/`, `aloe/`, `lib/`, or `host/`
- rewrite historical global checkpoint 110–117 files
- rewrite or implement 001
- change paging, hidden names, item keys, or TOS path text
- rename Gel, implement Listener, or open a presentation lattice

## Required wording

### `docs/gel.md` §4

Replace:

> Adding a capability means adding an Aloe class or method (plus host
> primitives when the OS must be touched). Gel itself does not grow a
> new framework per personality.

with the spec §11 paragraph, except Directory is **not** a method on
`GelPresentations`. The replacement must say all of:

- Gel does not grow a plugin, hook, pane, or extension API per
  personality.
- A personality is a Gel-owned presentation: methods indexed by
  Aloe type via `Signature.accepts?`, taking the specimen as an
  argument.
- List personality lives on `GelPresentations`. Directory
  personality lives on a generic Gel class that holds `fs-host`.
- Domain classes keep their own vocabulary. After Gel loads,
  `Directory` still only answers disk.

### `docs/gel.md` §5 (adapter paragraphs)

Delete the private-seam story:

- `List.gel-values` installed on `List`
- `GelMenus` recognizing a zero-argument `"gel-values"` row on the
  specimen
- `gel/directory.aloe` installing `gel-directory-values` /
  `gel-directory-all-values` / `gel-up` / `gel-tos-text` on disk
  types
- `GelMenus` / `GelText` / `GelUps` string-matching those names on
  the specimen

Write, in current Gel prose, that:

- `GelMenus`, `GelText`, and `u` consult Gel-owned presentation
  objects, never the TOS method table, for Gel behavior.
- List: arity-1 `list-values` on `gel-presentations`.
- Directory family: arity-1 `directory-values` /
  `directory-all-values` / `up` / `tos-text` on
  `gel-directory-presentations` (`GelDirectoryPresentations` holding
  `fs-host`). Ordinary Gel does not load `gel/directory.aloe`;
  `GelMenus` discovers that instance through an optional
  zero-argument `directory-presentations` index installed from that
  file.
- The directory application still loads `gel/directory.aloe` after
  `lib/disk.aloe`. That file extends Gel, not `Directory`.
- After Gel then the directory module load, disk classes still have
  only the `lib/disk.aloe` vocabulary. `List` still has only the
  list-library vocabulary for this concern.

Keep the frozen UX sentences already in §3 / §5: 22-row page, `.`,
`n` / `p`, `u`, labels `/` and `@`, TOS path form, List unpaged,
idle precedence. Keep the reserved-name table in §2.

Also retarget the later §5 sentences that still say `gel-tos-text`
on disk objects and “Directory adapter”. TOS path text comes from
`tos-text` on the host-holding presentations object. `GelText`
prefixes `"TOS: "` as today.

§8 “The adapter lives in Gel application code; reusable disk
vocabulary remains unaware of Gel” may stay in substance. Call it a
Gel-owned presentation, not a private adapter on disk types.

### `docs/gel-directory-surface.md`

Replace “private Gel adapter” / “private seam” language with
“Gel-owned presentation”. Keep “`lib/disk.aloe` stays Gel-ignorant”
and strengthen it: after Gel loads, disk method tables are
unchanged. Authored keys remain in Gel, not in the disk vocabulary.

Do not reopen locked UX (children as the menu, 22-row pages, hidden
names, `u`, Escape, `q`). Do not mark search `/` implemented. The
ranked follow-up that 113 called a private adapter is still
implemented as TOS path text; say that text now comes from a
Gel-owned presentation.

### `docs/handoff.md`

Current state only. Record:

- gel-presentations 000 and 002 are green on
  `experiment/2026-09-11-gel-presentations` (or whatever branch the
  work is on).
- 001 stays blocked; do not implement it.
- List values come from `gel-presentations list-values`. Directory
  listing, `u`, and TOS path text come from
  `GelDirectoryPresentations` holding `fs-host`. Disk types and
  `List` no longer carry `gel-*` selectors.
- Frozen Directory UX (112–117) is unchanged.
- This series is still local (`gel-presentations N`), not global
  118.

Remove the stale “Do not issue 002” / “000 is green; 001 is
blocked” paragraph that predates 002.

Do not dump a Gel tutorial into the handoff. Do not rewrite
unrelated 0.4 bullets.

### Global checkpoints 110–117

Leave those historical documents on the global spine. Do not rewrite
them to pretend they were presentations.

## Exact file scope

Implementation may edit only:

- `docs/gel.md`
- `docs/gel-directory-surface.md`
- `docs/handoff.md`
- `tests/gel-presentations/003-doc-law.rkt` (new)
- `docs/gel-presentations/README.md` is updated by the checkpoint
  manager, not the implementer

Do not edit `gel/`, `aloe/`, `lib/`, `host/`, `examples/`,
`SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, or
`docs/gel-presentations/checkpoints/001-directory-family.md`. Do not
add `tests/checkpoint-118.rkt`. Do not change tests that prove
behavior; this slice is wording.

Tests sit one directory deeper than the global suite. Use one extra
`../` in `require` and `define-runtime-path`.

## Tests and acceptance

Add `tests/gel-presentations/003-doc-law.rkt`. Cover at least:

1. **`docs/gel.md` dropped the private seam.** Source no longer
   claims `List.gel-values` is installed on `List`, or that
   `GelMenus` / `GelText` / `u` find Directory by scanning the
   specimen for `"gel-values"`, `"gel-directory-values"`,
   `"gel-directory-all-values"`, `"gel-up"`, or `"gel-tos-text"`.
   It does say `Signature.accepts?`, `gel-presentations` /
   `list-values`, `GelDirectoryPresentations` holding `fs-host`,
   and that after Gel loads `Directory` still only answers disk.
2. **Frozen UX remains.** `docs/gel.md` still records the 22-letter
   pool omitting `n` / `p` / `q` / `u`, List unpaged, Directory
   paging, hidden `.`, `u` parent, labels `/` and `@`, and the
   reserved names Listener, Inspector, Browser.
3. **`docs/gel-directory-surface.md`** no longer calls the live
   surface a “private Gel adapter” or “private seam” as current
   law. It still says `lib/disk.aloe` stays Gel-ignorant, and that
   after Gel loads disk method tables are unchanged.
4. **`docs/handoff.md`** names 000 and 002 green, 001 blocked, and
   does not say “Do not issue 002”. It does not claim disk types
   still own `gel-*` selectors.
5. **History is untouched.** `docs/checkpoints/0110-gel-list-value-rows.md`,
   `0112-gel-live-directory.md`, `0113-gel-directory-tos.md`, and
   `0117-gel-directory-paging.md` still describe the private-seam
   design they implemented. No new `docs/checkpoints/0118-*.md`. No
   `tests/checkpoint-118.rkt`.
6. **Scope.** No edits under `gel/`, `aloe/`, `lib/`, or `host/`.
   gel-presentations 000 and 002 plus global 110–113, 116, 117 and
   the full suite remain green.

Run:

```sh
raco test tests/gel-presentations/003-doc-law.rkt
raco test tests
git diff --check
```

Do **not** run `raco test tests/*.rkt`; that glob skips this folder.

No TTY. No Aloe behavior change.

The checkpoint is complete when the three current-law files describe
presentations as they landed in 000/002, historical 110–117 files
are unchanged, and no code moved. Stop for review without
committing.

## Explicit non-goals

- No Gel, Aloe, library, or host code
- No rewrite of 001
- No rewrite of global checkpoint 110–117 documents
- No Listener, Inspector, Browser, command tables, or translators
- No change to paging, hidden names, item-key pool, or TOS path bytes
- No global checkpoint 118
