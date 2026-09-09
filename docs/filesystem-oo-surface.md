# Object-oriented filesystem surface — design conversation brief

**Status.** Working handoff for one Grok **design** conversation. Not law.
Not a checkpoint. Do not implement.

If you have been told “read `docs/filesystem-oo-surface.md`,” this file
is the whole assignment.

## 1. Job

Design the **everyday Aloe surface** for filesystem locations: objects
you construct from a string and then send messages to.

This conversation only brainstorms and writes a surface sketch. It does
not write implementation checkpoints, does not edit `aloe/`, `host/`,
`lib/`, or `tests/`, and does not replace the existing thin library.

When the human is happy with a sketch, they take it back to the program
conversation. A later pair may implement it as a **second** library
beside `lib/fs.aloe`.

## 2. Why this conversation exists

`lib/fs.aloe` on `experiment/filesystem` is a thin, host-honest wrapper:

```aloe
(define fs (Fs new fs-host))
(define p (fs path "lib/fs.aloe"))
(p text)                 ; field: full spelling
(fs name p)              ; capability is the receiver
(fs parent p)
```

That matches FileManager-style APIs. It does not feel like Aloe.
The human wants FileDirectory / pathlib style:

```aloe
(define here (SomeClass new "/home/me/src"))   ; or a relative string
(here name)
(here parent)
(here child "lib")
```

A location is a first-class object. You type a string once, get an
object, and send messages. Full path vs last component vs parent
directory should feel like properties of **that object**, not functions
of a manager.

Keep `lib/fs.aloe` and `host/racket/fs.rkt` as the foundation. The new
surface layers on top (objects may store the injected host in a generic
field — checkpoint 99 already proved that). Do not add a second host
capability. Do not make `fs-host` ambient. `bin/aloe` stays capability-
free; the existing `host/racket/fs-repl.rkt` is how a REPL gets
authority.

## 3. Target construction story (refine, don’t abandon)

From the user’s perspective:

1. They have a string: absolute or relative, file or directory.
2. They pass it to a class construction send (`Class new string`, or
   whatever you lock after the survey).
3. They get back an object that **is** that location.
4. They send it messages: parent, name, last component, extension,
   components, later size / entries / inspect, etc.

Relative strings are resolved by the host against cwd. Aloe does not
concatenate path strings.

**Open on purpose — this is the design heart, not a bug:**

- Does `new` always return one `Location`/`Path` type, with
  file-vs-directory decided later by `inspect` (Python `pathlib`)?
- Or does `new` talk to the host immediately and return a `File` or
  `Directory` object (PowerShell `Get-Item`)?
- What if the path is missing? `Option`, a third class, or a location
  that does not promise existence?
- What if they construct `Directory` and the path is a file?

Survey real languages before picking. The Aloe answer should feel like
sending messages, not like calling `fs-name`.

## 4. How to work

This is a design conversation with the human, back and forth. Do not
one-shot a spec.

1. Read this brief and the authority files in §5.
2. Survey the languages in §6. For each, write a short note: how you
   construct from a string, what the object is, important messages,
   whether construction hits the disk, how missing paths work, what
   feels good / bad for Aloe.
3. Propose 1–2 Aloe surfaces with example sends (not Racket).
4. Refine with the human until one surface is locked enough to write
   down.
5. Write one working-design file (suggested:
   `docs/filesystem-oo-vocabulary.md`) in the same tone as
   `docs/filesystem-vocabulary.md`: locked construction and messages,
   host vs Aloe split, non-goals, still-open list. Not law. Not a
   checkpoint list.
6. Stop. The human returns to the program conversation.

Do not implement. Do not write `0105-…` checkpoints. Do not edit
`lib/fs.aloe` to “fix” the thin API in place.

## 5. Authority

Read, in order:

1. This brief.
2. `docs/filesystem-vocabulary.md` — locked **thin** API. Do not
   silently rewrite it. The OO surface is a second vocabulary.
3. `lib/fs.aloe`, `lib/option.aloe`, `host/racket/fs.rkt`,
   `host/racket/fs-repl.rkt`, `archive/fs-worksheet.aloe` — what exists.
4. `SPEC.md` on `experiment/filesystem`: send, `define-class`,
   constructors, `case`, `Option`, no constructor-local methods.
5. `docs/class-constructors.md` (historical): methods are whole-class.
   If `File` and `Directory` need different messages, they are
   **separate classes**, not extra methods on one `Entry` constructor.
6. Host boundary: crossing is `Int`, `Bool`, `String`, `(List String)`.
   Injected `fs-host`. No source-written host type names. Generic
   fields may retain the host-receiver type.

Proposal A / `define-family` is not authority.

## 6. Languages to survey

Do a real look (docs, not memory) at least:

| Language | Start here |
| --- | --- |
| Python | `pathlib.Path` |
| Ruby | `Pathname` |
| Crystal | `Path` vs `File` / `Dir` / `File.info` (they split algebra from IO) |
| Swift | `URL` file URLs + `FileManager` (capability vs object) |
| PowerShell | `Get-Item` → `FileInfo` / `DirectoryInfo`; `.Name`, `.FullName`, `.Parent`, `.Extension` |
| Optional extras | Smalltalk `FileDirectory`; .NET `FileInfo` / `DirectoryInfo`; Rust `std::path::Path` vs `std::fs` |

For each, record construction from a string, receiver of `parent` /
`name` / listing, and whether the type is “path spelling” or “live
directory.”

Aloe’s slogan is Scheme + Smalltalk + Types. Prefer a surface Steve
Jobs would like on a Smalltalk machine: the object in your hand *is*
the location. Do not copy `FileManager` a second time.

## 7. Constraints the surface must respect

- Ordinary programs still need injected `fs-host`. Construction from a
  string may use it (resolve, optional inspect). The worksheet/REPL
  already injects it; `bin/aloe` does not.
- Do not reimplement platform join/parent/name in Aloe string code.
- First slice of the **thin** library is still read-only. The OO
  surface may *name* later messages (`size`, `read`) as future, but
  lock a small everyday set first: construct from string, name,
  parent, child, inspect/classify, directory listing.
- Homogeneous listings still need a type. `List Entry` with
  exhaustive `case` is the constructor proof. An OO listing might be
  `(List Location)` or `Entry` constructors that **carry** `File` /
  `Directory` objects. Pick with evidence from the survey.
- Absence stays data (`Option` / `None`) unless the survey plus Aloe
  constructors strongly prefer something else. Don’t revive a
  `Missing` constructor on `Entry` without saying why listings then
  have a dead branch.
- No Gel UI in this design. Gel should later put these objects on the
  stack; design so `(here parent)` is a send a menu could offer.

## 8. Deliverable

One working design document plus the survey notes (survey can be a
section of the same file). The program conversation will review it
before any implementation pair starts.

## 9. First action

Survey the languages in §6. Then discuss construction-from-string with
the human: one location type vs File/Directory at `new` time vs
inspect-later. Do not write the working-design file until that choice
is explicit.
