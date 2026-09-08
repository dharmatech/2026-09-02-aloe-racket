# Filesystem vocabulary sketch

**Status:** Historical incoming sketch. Superseded as working design by
[`docs/filesystem-vocabulary.md`](../../docs/filesystem-vocabulary.md).
Keep this file as provenance; do not edit it to track later decisions.

**Original status:** Provisional, non-normative design handoff. This is not a
checkpoint or implementation specification. Names and exact signatures remain
open for discussion.

## Aim

Design a small, read-only filesystem vocabulary that feels like ordinary Aloe
code. It must work in the listener, tests, or any Aloe application without
depending on Gel. Gel may later consume the vocabulary, but should not define
its domain model.

The first useful slice should let a program:

- obtain its current working location;
- represent paths without doing platform-specific String manipulation;
- form parent and child paths;
- inspect a path and classify what is there;
- list the immediate entries of a directory; and
- distinguish regular files, directories, symbolic links, and unsupported or
  platform-specific entries.

Reading a text file is a plausible next feature once this foundation is sound.

## Provisional Aloe model

`Path` is a nominal Aloe value representing a filesystem location. A path does
not promise that anything currently exists there. Operations such as joining,
finding a parent, normalization, and extracting a name must ultimately respect
host-platform path rules rather than reimplementing those rules with Aloe
String concatenation.

`Entry` is one nominal class with a closed constructor set. In the smallest
form, each alternative can carry the observed path:

```aloe
(define-class Entry
  (constructors
    (RegularFile (fields (path Path)))
    (Directory (fields (path Path)))
    (SymbolicLink (fields (path Path)))
    (Other (fields (path Path))))
  (methods
    (path () Path
      (self case
        (RegularFile (path) path)
        (Directory (path) path)
        (SymbolicLink (path) path)
        (Other (path) path)))))
```

Consequently, a mixed directory listing still has the homogeneous type
`(List Entry)`. Callers can use exhaustive `case` when the distinction matters,
while whole-class methods can provide common behavior such as `path`, `name`,
`directory?`, or `show`.

Constructors are not themselves types. If later operations genuinely need
distinct `File` and `Directory` objects with variant-specific messages, an
`Entry` constructor can instead carry one of those typed objects:

```aloe
(RegularFile (fields (file File)))
(Directory (fields (directory Directory)))
```

An exhaustive `case` then exposes a `File` or `Directory` value with its own
message vocabulary. This richer factoring should be introduced only when a
concrete operation requires it.

The initial constructor set should probably contain `Other` so unfamiliar
devices, sockets, FIFOs, and platform-specific objects remain representable.
A hard link is normally metadata/identity shared by directory entries, not a
separate entry kind. Symbolic-link classification should initially avoid
following the link so the link itself remains observable.

## Capability and domain split

An explicitly injected filesystem capability supplies irreducible host facts,
effects, and platform path mechanics. The default Aloe environment should not
receive ambient filesystem authority.

The Racket side should own operations such as:

- obtaining the process working directory;
- platform-correct path joining, parent, name, and normalization operations;
- immediate directory enumeration;
- non-following entry classification and basic metadata; and
- eventually reading file text.

The Aloe side should own:

- the public `Path` and `Entry` domain values;
- conversion of validated host facts into those values;
- common methods, predicates, presentation, and collection composition; and
- policy about which small set of host operations forms the public vocabulary.

Exact selectors are not settled, but the intended use is approximately:

```aloe
(fs current)                 ; Path
(path child "src")           ; Path
(path parent)                ; perhaps Path or an optional/result value
(fs inspect path)            ; Entry
(fs entries path)            ; (List Entry), immediate children only

(entry case
  (RegularFile (path) ...)
  (Directory (path) ...)
  (SymbolicLink (path) ...)
  (Other (path) ...))
```

The filesystem receiver should be replaceable in tests by another receiver
with the same exact nominal host interface and controlled state. Production
tests that touch the real filesystem should use isolated temporary
directories.

## Time and failure semantics

`Path` is a stable immutable value denoting a location. An `Entry` is an
immutable observation made during `inspect` or enumeration. The external
filesystem remains live: an entry may disappear or change after it was
observed, and a later operation must consult the host again rather than pretend
the snapshot controls the world.

The first checkpoint must state its failure behavior explicitly. Class
constructors make `Option`, `Result`, and structured filesystem-error values
possible, but the current typed host boundary does not automatically convert a
Racket exception into such a value. It may be acceptable for the first narrow
slice to propagate a checked host failure; recoverable errors as Aloe data
would require a separate generic boundary design.

## Known prerequisites and open questions

- The class-constructor work and Typed Host Boundary checkpoints 83–88 live on
  divergent branches and must be deliberately integrated and tested together.
- The accepted host crossing vocabulary is only `Int`, `Bool`, and `String`.
  Immediate enumeration naturally pressures a generic homogeneous crossing
  such as `(List String)`. That boundary extension should be designed and
  implemented separately before a filesystem checkpoint consumes it.
- Class constructors solve the Aloe representation of `Entry`; they do not by
  themselves define how structured stat results or recoverable failures cross
  the host boundary.
- The exact `Path` representation, root-parent behavior, normalization rules,
  metadata set, error API, and whether the first `Entry` payload is merely a
  `Path` remain open.
- Constructor-aware Mirror and raw-printer behavior was deferred. It is not a
  prerequisite for a Gel-independent filesystem vocabulary, but matters before
  reflective UI depends on these values.

## Explicit non-goals for the first slice

No copying, moving, deletion, chmod, recursive walking, globbing, watching,
process execution, Git integration, opaque mutable directory handles, or Gel
filesystem UI. Do not encode a directory listing into a delimiter-separated
String merely to avoid extending the typed boundary.

