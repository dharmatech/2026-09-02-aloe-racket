# 0.3 language merge

The constructor and filesystem experiment stack has landed on local `main`.
Proposal B keeps `(fields ...)` as the singleton `new` form, adds named class
constructors, and adds receiver-anchored exhaustive `case`. The loadable
`Option` library and the Tree golden exercised those language rules.

The same landing includes the typed filesystem host boundary and both Aloe
filesystem APIs: thin `Path` / `Entry` / `Fs` in `lib/fs.aloe`, and live
`Disk` / `Location` / `Item` objects in `lib/disk.aloe`. Tests cover the work
through checkpoint 107.

This remains an exploratory prototype, not a finished public release. The
Gel-directory surface, editor/LSP stack, and any kernel rewrite are not part of
this landing.
