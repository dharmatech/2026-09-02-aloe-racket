# Filesystem vocabulary

**Status.** Working design on `experiment/class-constructors`. Not law.
`SPEC.md` remains law for the running language. This file is what later
checkpoints implement; it is not itself a checkpoint.

**Not this file.** Incoming sketch:
`archive/design-sketches/filesystem-vocabulary.md`. Checkpoints will live
under `docs/checkpoints/` one slice at a time. Do not copy this into
`SPEC.md` until a ratification checkpoint says so.

## 1. Aim

A small, read-only filesystem vocabulary that feels like ordinary Aloe.
It must work in tests and any Aloe program without depending on Gel. Gel
may later consume these objects; it must not define them.

The first slice lets a program:

- obtain the process working directory as an absolute `Path`;
- form child and parent paths through the host, not String concatenation;
- inspect a path and classify what is there;
- list a directory's immediate entries as `(List Entry)`;
- distinguish regular files, directories, symbolic links, and other
  platform entries.

Reading file text is the next feature after this foundation, not part of
it.

## 2. Locked model

### Path

`Path` is a nominal Aloe product. It names a location. It does not promise
that anything exists there.

```aloe
(define-class Path
  (fields
    (text String))
  (methods
    ))
```

`text` is the host-facing spelling. Path algebra, classification, and
listing are not methods of `Path` in the first slice. Those messages
belong to the filesystem capability, so a `Path` does not carry host
authority.

First-slice programs obtain paths from the capability (`current`, `path`,
`child`, `parent`), not from `(Path new ...)`. The class still has `new`
because every `(fields ...)` class does; it is not the public vocabulary.

Working-directory results are absolute. `child` of an absolute path is
absolute. Relative strings passed to `path` are resolved by the host
against the process cwd. Aloe does not reimplement platform path rules.

### Entry

`Entry` is one nominal class with a closed constructor set. Constructors
are not types. A mixed listing is still homogeneous `(List Entry)`.

```aloe
(define-class Entry
  (constructors
    (RegularFile (fields (path Path)))
    (Directory (fields (path Path)))
    (SymbolicLink (fields (path Path)))
    (Other (fields (path Path) (kind String))))
  (methods
    (path () Path
      (self case
        (RegularFile (path) path)
        (Directory (path) path)
        (SymbolicLink (path) path)
        (Other (path kind) path)))))
```

`Other` exists so devices, sockets, FIFOs, and platform-specific objects
remain representable. Its `kind` is a host diagnostic string, not a
second classification system.

A hard link is metadata/identity, not an entry kind. Classification does
not follow symbolic links, so the link itself remains observable.

There is no `Missing` constructor. Absence is `Option`, not `Entry`.
That way a listing's exhaustive `case` has four live branches, not a
dead fifth.

Do not add nested `File` / `Directory` objects until a message truly
needs a distinct type. Do not make `directory?` the primary API; goldens
must use `case`. A later whole-class predicate is sugar.

### Option

`(fs inspect path)` and `(fs parent path)` return `(Option Path)` or
`(Option Entry)` as ordinary Aloe values. `Option` is the class already
specified:

```aloe
(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))))
```

It is not a host crossing type. The library may `load` `lib/option.aloe`
if Option is not already a loadable library.

## 3. Public vocabulary

`fs` is an Aloe object wrapping an injected host capability. It is the
receiver, matching Term's style. Exact selectors:

```aloe
(fs current)                 ; Path, absolute
(fs path string)             ; Path, via host resolution
(fs child path name)         ; Path
(fs parent path)             ; (Option Path); None at root
(fs name path)               ; String, host last-component rule
(fs inspect path)            ; (Option Entry); None if absent
(fs entries path)            ; (List Entry), immediate children only

(entry case
  (RegularFile (path) ...)
  (Directory (path) ...)
  (SymbolicLink (path) ...)
  (Other (path kind) ...))
```

`name` in `child` is a single component (`"src"`), not a slash-separated
string. Joining multi-component strings in Aloe is out of scope.

There is no separate `exists?`. Absence is `(fs inspect path)` returning
`None`.

## 4. Capability and domain split

An explicitly injected host capability supplies irreducible facts,
effects, and platform path mechanics. Default environments receive no
filesystem authority.

**Racket / host owns:**

- process working directory;
- join, parent, root test, last-component, and normalization;
- immediate directory name enumeration;
- non-following classification;
- encoding those facts as `Int`, `Bool`, `String`, and later
  `(List String)`.

**Aloe owns:**

- `Path`, `Entry`, `Option`, and `Fs`;
- mapping host facts onto those values;
- common methods, presentation, and collection composition;
- which host operations are part of the public vocabulary.

The host receiver is not the public `fs` object. Host methods take and
return crossing values only. Aloe constructs `Path` / `Entry` after a
successful host send.

Suggested host messages (names may tighten in the host checkpoint):

| Host selector | Arguments | Result | Meaning |
| --- | --- | --- | --- |
| `current` | none | `String` | absolute cwd |
| `resolve` | `String` | `String` | absolutize / normalize |
| `child` | `String`, `String` | `String` | join one component |
| `root?` | `String` | `Bool` | no parent |
| `parent` | `String` | `String` | parent; Aloe does not call this when `root?` is true |
| `name` | `String` | `String` | last component |
| `kind` | `String` | `String` | see below |
| `names` | `String` | `(List String)` | immediate child names, no `.` or `..` |

`kind` strings locked for Aloe mapping:

- `"missing"` → `None`
- `"file"` → `RegularFile`
- `"directory"` → `Directory`
- `"symlink"` → `SymbolicLink`
- any other string → `Other` with that string as `kind`

### Wrapper

`Fs` is an Aloe class that stores the injected host receiver in a field
and exposes the public vocabulary. Host interface names are still not
source type names. The intended encoding is a generic field whose type
parameter is inferred from the injected receiver:

```aloe
(define fs (Fs new fs-host))
```

If the checker cannot yet retain a host-receiver type as a class type
argument, that is a host-boundary obligation of the merge/extension
checkpoints, not a reason to flatten `Path` back into `String` in the
public API. Fallback if generics cannot hold the host: pass the host
receiver as an argument to each public operation until the checker
catch-up exists. Do not make `Path` capture the capability in the first
slice.

## 5. Listing

Public `(fs entries path)` returns `(List Entry)`.

Internally:

1. Host `names` returns `(List String)`.
2. For each name, Aloe builds `(fs child path name)` and `(fs inspect ...)`.
3. `None` (vanished between list and inspect) is omitted.
4. A host failure inspecting a name fails the whole `entries` send.

No structured name+kind crossing in the first slice. The world is live;
TOCTOU is accepted.

`(fs entries path)` on a missing path or a non-directory is a host
failure, not `None` and not an empty list. Inspect is how you ask what
a path is.

## 6. Time and failure

`Path` is a stable immutable location. `Entry` is an immutable
observation from `inspect` or `entries`. A later operation asks the host
again.

Absence is data: `None`.

Permission errors, I/O errors, and inspect/list of an unreadable path
are host failures (the existing Aloe host-failure path). Recoverable
errors as `Result` values need a separate generic crossing design and
are not in this slice.

## 7. Prerequisites before a filesystem checkpoint

These are separate slices. The filesystem library does not invent them
in passing.

1. Integrate typed host boundary checkpoints 83–88 onto this
   class-constructors line (merge `main`, keep constructor 89–96 and
   host 83–88 both normative).
2. Extend host crossing with homogeneous `(List String)` so `names` can
   return a list. Do not encode listings as a delimiter-separated
   `String`.
3. Confirm that an Aloe generic field can retain a host-receiver type,
   or take the explicit fallback in §4.
4. Provide loadable `Option` if the filesystem library cannot share the
   test-only definition.

Term stays unchanged. Filesystem is a second optional injected
capability.

## 8. Tests

The host receiver is replaceable by another receiver with the same exact
nominal interface and controlled state. Production tests that touch the
real filesystem use isolated temporary directories.

Goldens must include exhaustive `case` over `Entry`, `None` from
`inspect` and from `parent` of root, and a directory whose children
include at least two different constructors.

## 9. Non-goals for the first slice

No read/write bytes, copy, move, delete, mkdir, chmod, cwd mutation,
recursive walk, glob, watch, process execution, Git, opaque mutable
directory handles, or Gel filesystem UI.

No `Path` methods that perform host effects. No `Missing` constructor.
No `directory?` as the required API. No `File` / `Directory` classes.
No `Result` crossing. No ambient `fs`. No source-written host type
names unless a prerequisite checkpoint is forced to add them for the
wrapper.

## 10. Still open

- Exact host selector spellings and the injected binding name
  (`fs-host` is the current suggestion).
- How much normalization `resolve` / `child` perform (Unicode, trailing
  slashes, Windows drives). Host-owned; lock with the host checkpoint's
  goldens, not here.
- `show` / raw / Mirror for `Entry` constructors. Not required to use
  the vocabulary; required before Gel depends on these values.
- Whether `lib/option.aloe` is a filesystem prerequisite or a tiny
  prior checkpoint of its own.
