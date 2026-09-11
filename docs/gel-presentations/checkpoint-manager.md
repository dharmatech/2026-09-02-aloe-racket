# Checkpoint manager — Gel presentations

**Status.** Assignment for a **checkpoint-manager conversation**. Not
Aloe law. Not Gel law. Not a checkpoint. Not an implementer
assignment. Law for the experiment:
[`spec.md`](spec.md). Index: [`README.md`](README.md).

**Your job.** Slice the spec into **one** local checkpoint at a time.
Write the checkpoint file. Put every rule the implementer needs in
that file. Then **stop**. Do not implement. Do not reopen the design.
Do not write global checkpoint 118.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this file and the authority in §3.
2. First visit (done): write **gel-presentations 000** only (see §5).
3. Stop. The human reviews it, then hands that checkpoint to an
   implementer.
4. Later visits: the human returns and says which local number was
   implemented. Verify against that checkpoint. **Do not implement
   001. Do not issue 002.** 001 is blocked in the spec (§4.3, §9.2).
   If the human asks for a new Directory-family slice, write a **new
   number** from spec §4.3 (generic Gel class holding `fs-host`), not
   a rewrite of 001 and not a written `FsHost` type name. If the spec
   is still wrong, **stop** and send the human back to the spec
   conversation.

The implementer will not have this file. Put every rule they need in
the checkpoint itself.

Keep each checkpoint **small**. Moving Directory in 000, a
presentation-type lattice, or a 600-line file is a defect.

---

## 2. Design issues leave this conversation

If any of these happen, do not invent a new design here:

- the spec looks impossible without a kernel / `Mirror` hatch
- two answers both pass the live-image bar and the spec did not pick
- paging, hidden names, keys, or TOS path bytes want to change
- a sibling project (string primitive, kernel hole) is required

Tell the human to take it back to the spec conversation. Do not nest
unrelated work under `docs/gel-presentations/`.

---

## 3. Authority

Read, in order:

1. [`spec.md`](spec.md) — this experiment’s law, including slice
   layout (§9)
2. [`README.md`](README.md) — which slices have been issued
3. `SPEC.md` — Aloe language law
4. `docs/gel.md` — Gel law today (000 may leave Directory adapter
   language in place)
5. `docs/gel-directory-surface.md` — frozen Directory UX
   (predecessor; do not reopen)
6. Current seams, as context for what this slice must not finish:
   `gel/menu.aloe` (`define-methods List` / `gel-values`),
   `gel/loop.aloe`, `gel/directory.aloe`

Do **not** treat [`charter.md`](charter.md) as an assignment. The spec
already absorbed it. Do not restack the charter’s open questions.

Parent branch: `experiment/gel-directory-surface` after green
**global** checkpoint 117. Do not start from `main`. Do not merge to
`main`.

---

## 4. Where files go (local series)

Identity is `(project, number)`, not the next global integer.

| | Path |
|---|---|
| Checkpoint | `docs/gel-presentations/checkpoints/000-short-slug.md` |
| Test (implementer writes) | `tests/gel-presentations/000-short-slug.rkt` |

Spoken name: **gel-presentations 000**. Not “checkpoint 118”. Not
“gel 000” (Gel already has global checkpoints 72–82). Zero-pad to
three digits. Keep a short slug in the filename. The test uses the
same project folder name, same local number, and same slug.

**Do not** write slices as `docs/checkpoints/0118-….md` or
`tests/checkpoint-118.rkt`. Leave the existing global spine alone
(`docs/checkpoints/0072`–`0117`, `tests/checkpoint-N.rkt` for
1–117). Do not invent a parallel global 118–N, and do not refile
1–117.

`gel-presentations 000` starts after global 117 is green. Frozen
Directory UX remains global checkpoints 112–117 and
`docs/gel-directory-surface.md`. Predecessor project, not previous
integers of this series.

Tests sit one directory deeper than the global suite. The checkpoint
must tell the implementer to use one extra `../` in `require` and
`define-runtime-path` (`../../aloe/…`, not `../aloe/…`).

**How to run tests** (write these commands into the checkpoint):

```sh
raco test tests/gel-presentations/000-short-slug.rkt
raco test tests
```

Do **not** tell the implementer to run `raco test tests/*.rkt`; that
glob skips this folder.

After a slice file exists, list it in [`README.md`](README.md). Do
not append it to root `CHECKPOINTS.md`.

---

## 5. This visit — gel-presentations 000

Suggested slug: `substrate-list`. Write:

```text
docs/gel-presentations/checkpoints/000-substrate-list.md
```

Job (from spec §9.2): add `gel/presentations.aloe` and
`GelPresentations`. Move `List.gel-values` onto
`(gel-presentations list-values items)`. `GelMenus` recognizes List
by `Signature.accepts?` on that Gel-owned row, not by scanning the
specimen for `"gel-values"`. Delete `define-methods List` from
`gel/menu.aloe`. Point, Int, and derived menus stay byte-for-byte.
Proof: after Gel loads, `List` has no `gel-values`; global checkpoint
110–111 List behavior still holds.

Directory may still be patched in this slice. If so, the live-image
bar is **not** claimed done. Name that hole in the checkpoint.

Do not move Directory / File / SymbolicLink / Other in 000. Do not
change paging, hidden names, item keys, or TOS path text. Do not
edit `aloe/`, `lib/`, or `host/`. If the spec’s `accepts?` probe
looks impossible, stop and send it back rather than inventing
`Mirror.class`.

Model tightness on `docs/checkpoints/0117-gel-directory-paging.md`:
goal, exact file scope, required behavior, tests, what to stop and
return for revision. The implementer receives only that document.

When the 000 file is written and the README lists it, stop.

---

## 6. Later visits

The human will say which local number was implemented. Then:

1. Read that checkpoint and the corresponding test if it exists.
2. Verify the slice against its own file (not against 001’s ambitions).
3. 000 is green. **001 is blocked** (abstract `H` disk bodies do not
   typecheck). Do not implement it. Do not issue 002. Do not enlarge
   a later slice to paper over 001.
4. A new Directory-family checkpoint is allowed only when the human
   asks for one **and** the spec’s §4.3 host-holding generic Gel
   class is the one being sliced. New number, new slug. Not 001.

One checkpoint per visit. Stop after writing it.

---

## 7. Do not

- Implement anything
- Implement 001 or rewrite it
- Issue 002 while 001 is blocked
- Open Listener, Genera, wrappers-as-TOS, or a presentation-type
  lattice
- Change frozen Directory UX (global 112–117)
- Nest a sibling project under this folder
