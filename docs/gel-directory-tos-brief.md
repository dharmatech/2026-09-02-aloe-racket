# Checkpoint-manager brief — Gel Directory TOS text

**Status.** Working handoff for **one** checkpoint-manager conversation.
Not law. Not a checkpoint. Not an implementer assignment.

**Your job.** Write **checkpoint 113 only**: make a live disk object's
Gel TOS line show a path, not the structural `Mirror.raw` dump. Then
**stop**. Do not implement. Do not write checkpoint 114.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this brief and the authority files in §3.
2. Write one checkpoint document: `docs/checkpoints/0113-gel-directory-tos.md`.
3. Stop. The human reviews it, often with a second designer glance.
4. An implementer conversation gets only that checkpoint file.

The implementer will not have this brief. Put every rule they need in
the checkpoint itself.

Checkpoint shape follows `docs/checkpoints/0108-gel-application-start.md`
and `docs/checkpoints/0112-gel-live-directory.md`, but this slice is
**small**. A 600-line checkpoint is a defect. Aim for a short file:
goal, depends on, file scope, required bytes, tests, non-goals.

## 2. Why this slice exists

Checkpoint 112 is complete. First live use printed:

```text
TOS: #<Directory #<Location #<FsHost> "/home/dharmatech">>
```

The north star in `docs/gel-directory-surface.md` §1 is:

```text
TOS: #<Directory "/home/dharmatech">
```

`Directory.text` already returns the path string. Gel's TOS printer
uses `(top raw)`, which dumps fields, including the host. This
checkpoint is presentation in Gel, not a new disk library.

## 3. Authority

- `docs/gel-directory-surface.md` — ranked follow-up item 1, “TOS path
  text.” Items 2–4 and the parked list are **out of scope**.
- `docs/gel.md` — current Gel TOS/menu behavior.
- `docs/filesystem-oo-vocabulary.md` and `lib/disk.aloe` — `text` /
  `name` already exist. Do not add messages there unless the checkpoint
  proves a public disk message is missing, which is not expected.
- `SPEC.md` is law.
- Parent branch: `experiment/gel-directory-surface` after checkpoint 112.

## 4. Required observable

When TOS is a live `Directory`, `File`, `SymbolicLink`, or `Other`,
`GelText.tos` must print a one-line path form:

```text
TOS: #<Directory "/home/dharmatech">
TOS: #<File "/etc/passwd">
TOS: #<SymbolicLink "/bin">
TOS: #<Other "/dev/null">
```

Use the existing path from `(object text)` (Location's stored path).
Keep the class name so Directory vs File is still visible.

Locks:

- Point, List, Int, and other non-disk TOS lines stay byte-for-byte
  `(top raw)` as today.
- Do not change `Mirror.raw` globally.
- Do not change `lib/disk.aloe`.
- Do not print extra stack levels, menus, colors, or ANSI.
- Child value-row labels (`lib/`, `link@`) stay as checkpoint 112.
- `u`, Escape, `q`, item keys, runners, and `fs-host` injection stay
  unchanged.

Preferred shape, matching checkpoint 112: a Gel-owned presentation
seam under `gel/` (likely `gel/directory.aloe` plus `GelText.tos`),
not a generic `show` protocol and not class-name string parsing.

## 5. Explicit non-goals

Do not mention these as later work inside the 113 document beyond a
short non-goals list. Do not sneak them into file scope.

- Hidden-file filter or toggle
- Paging, search, armed window, multi-column
- Options object, home `~`, root jump
- Color / AS400 TUI
- Visible stack history (levels 2/3)
- File contents, edit, refresh, workspace, processes
- GelFS, hooks, plugins, keymaps

## 6. Stop condition

The conversation is done when `docs/checkpoints/0113-gel-directory-tos.md`
exists and you have not started implementation. Wait for human review.
