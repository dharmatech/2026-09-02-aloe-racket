# Object-oriented filesystem vocabulary

**Status.** Working design, reviewed by the program conversation. Not law.
Not a checkpoint. `SPEC.md` remains law. Thin vocabulary in
[`docs/filesystem-vocabulary.md`](filesystem-vocabulary.md) is unchanged.

Checkpoint-manager brief:
[`docs/filesystem-oo-designer.md`](filesystem-oo-designer.md).

**Not this file.** Thin API: `lib/fs.aloe`. This surface is a **second**
library beside it (`lib/disk.aloe`). Same injected `fs-host`. This
library does **not** `load` `lib/fs.aloe`.

## 1. Aim

Everyday filesystem locations as objects you construct from a string and
then send messages to.

```aloe
(define fs (Disk new fs-host))
(define here (fs at "/home/me/src"))
(here name)
(here parent)
(here child "lib")
```

A location is a first-class object. Full spelling, last component, and
parent are properties of **that object**, not functions of a manager.

The first slice of this surface lets a program:

- obtain cwd and any string path as a `Location` (absolute, host-resolved);
- send `name`, `text`, `parent`, `child` on that location without promising
  existence;
- `inspect` a location and get a live `Item` if something is there;
- list a live directory as `(List Item)` of already-classified objects;
- `case` those items and send kind-specific messages to nested `File` /
  `Directory` / `SymbolicLink` / `Other` objects.

Thin `lib/fs.aloe` stays the FileManager-style foundation for comparison.
This library talks to the **same** `fs-host` and defines its own Aloe
types. No second host capability. No ambient `fs`. `bin/aloe` stays
capability-free.

## 2. Locked construction

Public construction is a send to a **sibling wrapper**, not thin `Fs`:

```aloe
(define fs (Disk new fs-host))
(define here (fs at "/home/me/src"))     ; Location; relative strings OK
(define src  (fs at "lib/fs.aloe"))
(define cwd  (fs current))               ; Location, absolute
```

`Disk` cannot be named `Fs`. Thin already owns that class. Everyday code
still binds the wrapper as `fs`.

`(fs at string)` always returns one `Location`. It asks the host to
**resolve** the string (relative against cwd, result absolute). It does
**not** ask `kind`. Missing paths are locations. File vs directory is
later, via `inspect`.

`(Location new host text)` exists because every `(fields …)` class has
`new`. It is not the public vocabulary, same rule as thin `(Path new …)`.
Ordinary programs use `(fs at …)` and `(fs current)`.

Aloe does not concatenate path strings. `child` / `parent` / `name` /
`resolve` stay host work.

## 3. Locked model

### Disk

`Disk` is the OO capability. It stores the injected host in a generic
field (checkpoint 99). It is not a second host type.

```aloe
(define-class (Disk H)
  (fields
    (host H))
  (methods
    (current () Location
      …)
    (at (string String) Location
      …)))
```

`Disk` sends to `H` directly (`current`, `resolve`, …). It does not
store or construct thin `Fs`. It does not `load` `lib/fs.aloe`. Kind
strings are mapped here the same way thin `Fs.inspect` maps them
(`"missing"` / `"file"` / `"directory"` / `"symlink"` / else). That
small table is duplicated on purpose so both libraries can load in one
environment.

### Location

`Location` is a path. It does not promise that anything exists there. It
carries the host so later messages do not go back to a manager.

```aloe
(define-class (Location H)
  (fields
    (host H)
    (text String))
  (methods
    (name () String
      …)
    (parent () (Option Location)
      …)
    (child (name String) Location
      …)
    (inspect () (Option Item)
      …)))
```

There is **no** `text` method. `text` is the field accessor. `(here
text)` is the resolved absolute spelling, same word as thin `Path`.
Writing `(text () String (self text))` would recurse forever.

`name` is the host last-component rule. `parent` is path algebra:
`(Option Location)`, `None` at root, no disk look. `child` takes one
component (`"lib"`), not a slash-separated string, and returns a
`Location`.

`inspect` looks at the disk. `None` if absent. No separate `exists?`.

### Item and nested live classes

`inspect` and directory listing return `Item`: one nominal class, four
constructors. The name is **`Item`**, not `Entry`, so a program may
`load` both `lib/fs.aloe` and `lib/disk.aloe` without clashing on thin
`Entry`. Constructors are not types. A mixed listing is still
homogeneous `(List Item)`.

Each constructor **carries a nested live object**. After `case`, kind-
specific messages go to that object, not to `Item`. Methods are
whole-class; `File` and `Directory` need different messages, so they are
separate classes.

```aloe
(define-class (Item H)
  (constructors
    (File (fields (file (File H))))
    (Directory (fields (directory (Directory H))))
    (SymbolicLink (fields (link (SymbolicLink H))))
    (Other (fields (thing (Other H)))))
  (methods
    ))
```

Constructor selectors match the nested classes (`File`, not thin
`RegularFile`). Thin `Entry` in `lib/fs.aloe` is untouched.

There is no `Missing` constructor. Absence is `Option`. A listing’s
exhaustive `case` has four live branches.

`File`, `Directory`, `SymbolicLink`, and `Other` each carry a `Location`
in a field named `location`. Path questions forward to that location,
except live `parent` (below). `inspect` on a live object forwards to
`(self location)` so you can look again after the world changes.

Thread `H` through `Disk`, `Location`, the live classes, and `Item`.
Infer `H` from `fs-host` at `(Disk new fs-host)`.

| Class | Always | Kind-specific in this slice | Later |
| --- | --- | --- | --- |
| `File` | `location`, `name`, `text`, `child` → `Location`, `inspect` → `(Option Item)`, `parent` → `(Option Directory)` | (none yet) | `size`, `read` |
| `Directory` | same | `entries` → `(List Item)` | `enter` |
| `SymbolicLink` | same | (none yet) | `target` |
| `Other` | same | `kind` → `String` (host diagnostic) | |

`child` on a live object is still a path: a name under here, not a `cd`.
The string might be missing or a file.

`parent` on a live object is **not** path algebra. The object in hand is
already live, so `parent` is the containing directory on disk:
`(Option Directory)`. `None` at root, or if the parent vanished, or if
inspect of the parent path is not a `Directory` (for example a symlink).
This is the same kind of fact as `entries`.

Classification does not follow symbolic links. A hard link is not an
item kind. `Other` is devices, sockets, FIFOs, and other platform
objects; `kind` is a diagnostic string, not a second taxonomy.

## 4. Public vocabulary

Exact everyday sends:

```aloe
(define fs (Disk new fs-host))

(fs current)                     ; Location
(fs at string)                   ; Location, host-resolved

(here name)                      ; String
(here text)                      ; String, absolute (field)
(here parent)                    ; (Option Location); None at root
(here child "lib")               ; Location
(here inspect)                   ; (Option Item); None if missing

((here inspect) case
  (None () "missing")
  (Some (item)
    (item case
      (File (file) (file name))
      (Directory (dir) (dir entries))
      (SymbolicLink (link) (link name))
      (Other (thing) (thing kind)))))

(file location)                  ; Location
(file inspect)                   ; (Option Item); look again

(dir entries)                    ; (List Item); only Directory
                                 ; has this message

(dir parent)                     ; (Option Directory)
(file parent)                    ; (Option Directory)
(dir child "lib")                ; Location
```

Foundation listing is a message on the **live** `Directory` only. A
location does not list. Sugar `(here entries)` and
`((fs at "/home/me/src") entries)` is a later layer: it still inspects,
still requires a directory, still fails if missing or a file.

`(dir enter "lib")` → `(Option Directory)` is the later `cd` sugar. It
is not this slice. `(dir child "lib")` must not return a `Directory`;
that would lie about existence and kind.

## 5. Capability and domain split

Same host as the thin library. Same crossing types: `Int`, `Bool`,
`String`, `(List String)`. Same injected binding `fs-host`.

**Racket / host owns** (unchanged):

- process working directory;
- join, parent, root test, last-component, resolve;
- immediate directory name enumeration;
- non-following classification (`kind`).

**Aloe owns:**

- `Disk`, `Location`, live `File` / `Directory` / `SymbolicLink` /
  `Other`, and `Item`;
- mapping host facts onto those objects;
- which sends are public.

Do not reimplement platform join/parent/name in Aloe string code. Do not
make `fs-host` ambient. Do not add a second host interface.

Thin public sends stay on thin `Fs`: `(fs path string)`, `(fs inspect
path)`, `(fs entries path)`, and so on. This surface does not redefine
them. A program may load both libraries; they must not fight over
bindings. That is why this library uses `Disk`, `Location`, and `Item`.

## 6. Listing

`(dir entries)`:

1. Host `names` on the directory’s `text`.
2. For each name, build `(dir child name)` and `inspect`.
3. `None` (vanished between list and inspect) is omitted.
4. A host failure inspecting a name fails the whole `entries` send.

Every element of the result is a live `Item`. Children are not
locations you must inspect again. TOCTOU is accepted; the world is live.

`names` on a non-directory remains a host failure. Programs reach
`entries` only after `inspect` has already produced a `Directory`.

## 7. Time and failure

`Location` is a stable immutable path. A live `File` / `Directory` / …
is an immutable observation. A later operation asks the host again.

Absence is data: `None` from `inspect`, from path `parent` at root, and
from live `parent` at root or if the container is gone.

Permission errors, I/O errors, and listing an unreadable directory are
host failures, same as the thin library. `Result` is not in this slice.

## 8. Survey (why this shape)

Looked at construction-from-string, receiver of `parent` / `name` /
listing, and whether the type is spelling or live directory.

| Language | Construct from string | Hits disk at new? | Missing | `parent` / `name` / listing |
| --- | --- | --- | --- | --- |
| Python `pathlib.Path` | `Path("…")` | no | still a `Path` | on the path; `iterdir` later, raises if not a dir |
| Ruby `Pathname` | `Pathname.new("…")` | no | still a Pathname | on the pathname; `children` later |
| Crystal `Path` vs `File`/`Dir` | `Path["…"]` lexical; `Dir.new` opens a stream | Path no; Dir/File yes | Path allowed; Dir.new fails | Path: algebra only. IO is a different type |
| Swift `URL` + `FileManager` | `URL(filePath:)` | optional directory hint | URL is spelling | algebra on URL; listing on FileManager |
| PowerShell `Get-Item` | `Get-Item path` | yes | error | `.Name` / `.Parent` on `FileInfo` / `DirectoryInfo` |
| .NET `FileInfo` / `DirectoryInfo` | `new FileInfo(path)` | no | `.Exists` later | you pick the class; wrong class + existing other kind → `.Exists` false |
| Smalltalk `FileDirectory` / Pharo `FileReference` | `FileDirectory on:`; `'…' asFileReference` | no | then `#exists` | the object *is* the place; disk is ambient |
| Rust `Path` vs `std::fs` | `Path::new("…")` | no | still a Path | algebra on Path; `parent` is `Option`; IO later |

Aloe answer: pathlib/Pathname/FileReference for **construction** (one
`Location`, no `kind` at `at`). Crystal’s split for **algebra vs IO**
(path messages vs inspect/entries), except the location carries the
capability so the object in hand can receive both families of messages.
PowerShell/Get-Item is **`inspect`**, not `at`. .NET warns against
`Directory new string` without a check. Swift FileManager is the thin
library; do not copy it a second time.

Live `parent` → `(Option Directory)` follows .NET `FileInfo.Directory` /
`DirectoryInfo.Parent` and the Smalltalk “object in hand” rule: a live
directory’s parent should still be a directory you can send `entries` to.
Path `parent` stays `(Option Location)` so missing paths and root stay
honest.

## 9. Non-goals for this foundation

No write, copy, move, delete, mkdir, chmod, cwd mutation, recursive
walk, glob, watch, process execution, Git, or Gel filesystem UI.

No `(here entries)` or `(dir enter name)` in the first lock (later
sugar). No `size` / `read` / symlink `target` yet (named as future).

No `Missing` constructor. No `directory?` as the required API; goldens
use `case`. No ambient `fs`. No second host. No rewrite of `lib/fs.aloe`
or `host/racket/fs.rkt`. No `load` of `lib/fs.aloe` from `lib/disk.aloe`.
Proposal A / `define-family` is not authority.

No inheritance. Nested live classes forward path messages; they do not
subclass `Location`.

## 10. Still open

- `extension`, `stem`, components.
- Sugar: `(here entries)`, `(dir enter name)`.
- `File` `size` / `read`; `SymbolicLink` `target`.
- `show` / Mirror / Gel menus. Design so `(here parent)` and
  `(dir entries)` are sends a menu could offer; Gel is not this slice.
- How much live `parent` should treat a parent path that inspects as
  `SymbolicLink` to a directory (`None` vs follow). Foundation: do not
  follow; `Some` only when inspect yields constructor `Directory`.
- Windows drives, trailing slashes, Unicode. Host-owned, same as thin.

Locked (no longer open): library file is `lib/disk.aloe`; `Disk` stores
`H` and talks to the host directly; listing type is `Item`; `text` is a
field; live objects have `location` and forwarded `inspect`; `H` is
threaded through `Disk`, `Location`, live classes, and `Item`.

## 11. Stop

Checkpoints are written by the conversation that follows
[`docs/filesystem-oo-designer.md`](filesystem-oo-designer.md), one slice
at a time. Do not implement from this document in a brainstorm or
checkpoint-manager chat.
