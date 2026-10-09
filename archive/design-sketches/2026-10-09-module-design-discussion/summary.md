# Module design discussion

Record of the October 2026 discussion about an Aloe module system, the Aloemacs class prefixes, and whether to split `examples/aloemacs/file.aloe`. This is a discussion record. It is not language law, not a charter, and not a decision to build modules.

Three participants: the user, Claude (in Claude Code), and Grok, which reviewed Claude's replies. Where the two agents disagree, the positions are named.

The code sketch that goes with it is `archive/design-sketches/2026-10-08-aloemacs-modules/`.

## Conclusion

The near term is agreed. Grow Aloemacs first. Leave the `Aloemacs` prefixes in place, and leave `file.aloe` as one file. When a module system exists, do the split, the imports, and the prefix removal as one adoption pass.

The prefix is the safe spelling until then. New classes should keep it, so a later rename stays mechanical. `UndoFrame` and `safe-cell-controls` in `editor.aloe` are the exceptions that already exist.

When module design starts is not agreed. Grok would revisit modules when a second application is about to use bare names such as `View` and `Buffer` in the same process, or when the module rules are actual decisions rather than open questions. Claude would start a charter now, on the strength of libraries alone, and run it beside the Aloemacs work, the way `with 000` changed the language and `with 001` converted Aloemacs afterward. The adoption pass would be the last checkpoint, taken at a quiet point between feature series. "Where the reviewers differ" has the details.

## How the question started

Aloe grows from applications. A language feature waits until a program creates pressure for it.

Aloemacs is far enough along to edit files. `file.aloe` defines a long list of classes, almost all prefixed: `AloemacsPrompt`, `AloemacsBuffer`, `AloemacsView`, `AloemacsWindowTree`, `AloemacsSession`, and the rest. Methods are already scoped by their class, so the prefix is only on the top-level name. It is the GNU Emacs and Smalltalk habit of keeping a shared namespace from colliding. The editor sources use those prefixed names about 326 times across `editor.aloe`, `file.aloe`, and `main.aloe`.

The wish was a small module system. Export everything. Import everything when you want to. Add rename and prefix only when a collision shows up. Keep path lookup as simple as `load`. The open worry was whether macros have to be designed first. They do not. `SPEC.md` still lists macros as out of scope, and no program is asking for them. Selectors are literals, so a later macro system would not need to hygienize them. The one rule worth remembering is that a macro written in one module must keep that module's bindings when it expands in another.

## What `load` does today

`load` reads a file into the same environment every time it is reached. The checker and the evaluator each keep a stack of paths only to reject a cycle. A second `define-class` for the same name silently replaces the first. Two classes with the same printed name are different types, because the checker compares class identity, not the name string.

That failure is real, and it is narrower than it first looked.

- A value built from `Box`, then `Box`'s file loaded again, then that value passed where the new `Box` is expected: `typecheck: type mismatch: expected Box, got Box`.
- The same shape with `Option`: `expected (Option Int), got (Option Int)`. Generic versus plain is not the difference.
- Two libraries that both load one shared class, with no value held across the second load, typecheck and run. That is what Aloemacs does. `lib/text.aloe` and `lib/fs.aloe` both load `lib/option.aloe`, and the double load is harmless. Method signatures are looked up by name when they are used, so after the second load every use sees the latest class.

The dangerous shape is a top-level value that still points at the old class after a later load of the class file.

## The first module proposal

Claude's first reply treated the prefixes as the weak evidence and the double load as the strong evidence, and offered a small system: one file is one module, export everything, `(import "path.aloe")` brings the names in bare, imports are not passed through, a prefix renames at the import, collisions are errors, and the acceptance test is that Aloemacs drops its prefixes and the tests still pass.

Grok's corrections, which Claude accepted:

- The `Option` case fails in the same way as `Box`. The report that it passed was wrong.
- Aloemacs is fine today. "This breaks as soon as two libraries share a class" was wrong.
- Dropping the prefixes and re-running the tests proves nothing about modules. `Buffer`, `View`, `Session`, and `Command` do not currently collide with `Text`, `Position`, `Path`, `Option`, or `Fs`. A plain rename would pass.
- A bare import leaves `main.aloe` saying `View`. That is the unaffiliated name the prefix exists to prevent. Only a written module name, or the same identity shown in errors and in hover, puts the application back on the name.
- Under one-file-one-module, `View` lives in `file.aloe`, so its module would be `file`. That says less than `AloemacsView`.
- `(fs Path)` is a bad spelling. It looks like the type `(Option Path)` and like a send. Qualification, if it ever exists, belongs on the import.

`with` was the comparison for repetitive workarounds. Aloemacs could already rebuild an object by calling `new` with every field, and `with` was added anyway because that rebuild was the daily case. The prefix is pressure of that same repetitive kind. The cost is different. `with` is one small form. A module system changes how every file is written, so the repetition alone does not clear the bar.

## The sketch

`archive/design-sketches/2026-10-08-aloemacs-modules/` is one candidate, not a proposal to adopt. A file exports every name it defines. An import brings those names in bare. Imports are not re-exported. `(import "path.aloe" (prefix aloemacs:))` renames them in the importing file. The prefix is written at the import. The directory is not a module. `lib/` is unchanged, and importing `text.aloe` does not bring `Option` with it.

- `editor.aloe` defines `Editor` and has to import `option.aloe` and `text.aloe` separately.
- `file.aloe` defines `Buffer`, `View`, `WindowTree`, and a shortened `Session`. Inside the file those names are short, and the module they belong to is still `file.aloe`.
- `main.aloe` imports each file it names. The window line is `(WindowTree Leaf (View new 0 0 0 0 #f))`. The word `aloemacs` does not appear.
- `main-prefixed.aloe` writes `aloemacs:View`. `Text`, `Path`, `Option`, and `Fs` stay bare. Both editor files can share that prefix only while they define different names.
- `other-app.aloe` defines its own `View` and refers to the editor's class as `aloemacs:View`.

The bare `file.aloe` is the better page to read. `aloemacs:View` is the current prefix with a colon. The sketch is not loaded by the editor, and most methods are omitted.

## Prefixes, hover, and the shared image

Inside `file.aloe` the prefix repeats the application's name on every field and every result type. `Buffer` is the precise name there. Outside that file, in `main.aloe`, in the tests, and in a future shell that holds an editor buffer, the reader needs to know whose `Buffer` it is. A handwritten prefix cannot be quiet in one of those places and present in the other.

A hover popup is the right place to show the full identity in the editor, and the checker has to print the same text. Today's hover shows the type and the message rows. It does not show a file or a module. The earlier failure was `expected Box, got Box`. A popup that says `aloemacs/view` while the checker still says `View` leaves the ambiguity in the REPL, the tests, a diff, and a file opened outside the editor.

In the current tree the honest path for `AloemacsView` is `examples/aloemacs/file.aloe`. The string `aloemacs/view` becomes honest only after `View` has its own file, or after a module name is declared. A later `aloemacs/buffers/...` is the same kind of name, added when those classes actually move.

The longer goal, stated in the discussion and not written into `docs/philosophy.md`, is one process with several applications in it: an editor, a documentation system, a shell, able to call each other. Philosophy still says the next hole should come from the next program, and it lists `require` among the things to grow later. Two applications that never load each other can each define `View`. The collision appears when one process loads both. Under that image, modules would scope class names, and a message send would stay the same across applications, so one program can hold another's buffer and send `insert` without sharing a global class name.

The prefix convention hides that collision. The next application will copy the house style and prefix its own classes, so waiting for a clash waits for something the convention is built to prevent. The language can already host `AloemacsView` and `DocsView`. What it cannot host is two bare classes named `View` in one process. The trigger worth using is the decision to give a second application those bare names, at the start of that application. Stripping the editor first, with nothing else loaded, creates the collision without teaching how two applications import each other. Building the module system in the quiet before that application is a scheduling choice. Its risk is the boundary: rewriting Aloemacs onto "the file is the module" means both applications move again when the module is the application.

The section on concurrency and libraries, below, weakens this trigger.

## One class per file

`file.aloe` is a pile. A file whose first lines show what that class uses would be easier to enter, and `load` can already write those lines. The file tree would be a filing order, not a scope. `view.aloe` defining `View` would still put `View` in the one shared environment.

The references in `file.aloe` run downward, toward `AloemacsSession`, so a load order exists. `AloemacsBinding` can load `AloemacsKeymap`. `AloemacsWindowTree` and `AloemacsWindowRect` are already ordered on purpose: the rectangle is declared, then `define-methods` adds the tree methods that need it. A pair of classes whose fields name each other cannot be ordered with `load`, and those stay together. `AloemacsSession` is the composition root. Its file would load almost everything else, and that long header would be the true one.

Splitting does not, by itself, create module pressure. It does make the prefix look more redundant, because the file would already be named `view`. And it widens the identity bug, because many files would load the same class.

## The keymap order bug

`aloemacs-global-keymap` and `aloemacs-ctrl-x-keymap`, at the bottom of `file.aloe`, are top-level values full of `AloemacsCommand` instances. In one file the class is defined once and the tables are built after it.

Split the class from the tables and the order starts to matter. A reduced copy of that shape:

- Load the command file, then the keymap file, which loads the command file again and then builds the list. This typechecks. The reload happens before the values exist.
- Load the keymap file, then load the command file again. This fails: `typecheck: generic instantiation mismatch for method run`. `Command` is not generic. That is the checker's ordinary message when a method argument's class identity does not match.
- Load only the keymap file, and let the command class arrive through it. This typechecks, because `load` is transitive and nothing reloads the class after the values exist.
- Load the keymap file, then have a later file load the command file because it mentions `Command`. This fails, even though the later file's own load line looks locally correct.

So a split where each file lists every class it uses makes typechecking depend on a global order that no single file can see. The robust fix is to run each path once. The checker and the evaluator each need a record of which paths have run, and the REPL needs a deliberate way to reload an edited file, because a second `load` would otherwise do nothing. That is smaller than a module system, and it is the base one would sit on. It is not settled, because the reload behavior is still an open design.

A per-file graph can be ordered so that nothing loads a class after a value of that class exists. That order is easy to break with the next dependency line. A single loader that loads each part once, with no `load` lines inside the parts, avoids the bug and also drops the per-file dependency headers that made the split attractive.

## Concurrency, and libraries instead of applications

The user raised a limit on the shared-image argument. Several interactive applications in one process run into the GNU Emacs and Gnus problem: one program waiting on the network freezes every window. Doing that properly needs non-blocking concurrency, such as coroutines or threads, or separate operating-system processes that exchange data. That is its own large design. Modules should not wait for it. And if that design ends in separate processes, the application-collision reason for modules mostly goes away.

Claude withdrew its earlier suggestion to write the one-process goal into `docs/philosophy.md` and use it as the trigger. A trigger that can vanish because of an unrelated decision is a poor trigger.

Libraries are the ordinary reason for modules, and they do not depend on concurrency. A single-threaded Python program still uses modules so that its libraries can live together. JavaScript ran on one thread in one page with one global namespace. jQuery and Prototype.js both wanted `$`, which is why `jQuery.noConflict()` exists, and collisions like that drove JavaScript's module patterns and later its built-in modules. Emacs, the model for the `Aloemacs` prefix, kept prefixes for decades and then added file-local shorthands in Emacs 28.

The repo already shows the library side:

- `lib/` uses bare names. `lib/disk.aloe` takes `Disk`, `Item`, `Other`, `Location`, `File`, `Directory`, and `SymbolicLink`. `lib/text.aloe` takes `Text`, `Position`, `Span`, and `EditResult`. `lib/fs.aloe` takes `Path`, `Entry`, and `Fs`. A program that loads those files cannot define its own `Item` or `Location`.
- Applications prefix to stay clear of each other and of `lib/`, and there are two of them. Gel uses `GelText`, `GelStack`, `GelRow`, `GelKey`, and the rest. Gel's natural name for `GelText` is `Text`, which `lib/text.aloe` already takes.

Some sharing needs no concurrency. A tool that examines loaded code runs while that code sits still. `host/racket/gel-run.rkt` already loads `gel/main.aloe` and `examples/point.aloe` into one driver and explores points. `docs/gel.md` says Gel may later explore the file system, processes, and repositories, which means loading those libraries beside Gel. A Genera-style listener, an inspector, or a documentation reader that reflects on live classes has the same shape. The case that needs concurrency is two interactive programs waiting for input at the same time.

One counterpoint still stands. Modules pay off most when the colliding code cannot be edited, such as someone else's library. Here one person owns everything, so a collision can be fixed by renaming at the source, and that is why the prefix has held. Claude's answer is that a rename costs every caller of the renamed class, and every bare name in `lib/` is unavailable to every future program.

If libraries are the reason, the smallest useful system grows a little. With export-everything and import-everything, two libraries that each define `Item` still collide in a file that imports both, and that file cannot fix it without editing a library. So Claude's minimum is: each file has its own names, one collision tool on the import (`prefix` or `only`, not both at first), and running each path once as the first slice.

## Grow the editor, or refactor it now

`AloemacsSession` is lines 812–1744 of `file.aloe`, about 930 of the file's 1,788 lines. Recent features land there plus a neighbor: completion in the prompt and the session, window bars in the mode line, the rectangle, the windows, and the session, the idle echo inside the session itself. One class per file would still leave a session of that size, and a feature would be spread across several files. The boundaries worth having may follow features, such as search, prompts, and windows, and those will be easier to see after the editor has more of them.

Doing the split now, with `load`, and removing the prefixes later, does the reorganization twice. After a module system exists, the split, the imports, and the prefix removal can be one pass. Letting the editor grow does not make that rename harder, provided new classes keep the prefix. The cost of waiting is reading the prefix. That is real, and it is the cost GNU Emacs already accepts. A charter does not take the prefix off the page. Only the adoption pass does.

Grok's objection to starting `docs/design/implementation/modules/` now is that it would hand a spec writer the open questions: `load` versus `import`, and how the REPL reloads a file. Those are the design, not details to resolve on the way to `spec.md`. The evidence still missing is the evidence growth can supply: which classes are helpers, which library names actually collide, and where the files should split. Claude's answer is under "Where the reviewers differ."

Both agents agree that growing the editor first supplies that evidence, whether or not a charter runs beside it.

## Where the user stands

- A module system will be needed. The prefixes read as a workaround for not having one.
- The prefix is pressure in itself. It is noise on every reading of the editor, and that noise grows with the editor.
- The prefixes come off only when a module system protects the bare names. Removing them into today's single environment invites a later collision.
- One class per file, or a move in that direction, is the preferred layout, with each file's dependencies written at its top.
- Aloemacs is now usable day to day, and the next work is features.
- Concurrency and multiple running applications are a separate discussion. Libraries alone are reason enough for modules, as they are in Python.

## Where the reviewers differ

Both agents like the bare-name sketch better as a page to read, and both agree on the near-term plan in the conclusion. They differ on these points.

- **When module design starts.** Grok: when a second application is about to take bare names, or when the rules are decisions. Until then the prefix is a working accommodation, and building modules early is a scheduling choice. Claude: now, as a charter beside the Aloemacs work, because libraries are reason enough and the prefix convention keeps the collision from ever appearing on its own.
- **Whether open questions block a charter.** Grok: `load` versus `import` and REPL reload are the design, so a spec writer would be designing the language. Claude: `docs/workflow.md` defines `charter.md` as the place for open questions, and the designer's job is to resolve them. The workflow's real gate is earlier: the discussion has to decide that the work exists.
- **Gel and `lib/`.** An earlier draft of this record said Gel was not part of the discussion. Claude raised it in the reply on concurrency, and counts Gel's prefixes, Gel's loading of `examples/point.aloe` into its own environment, and the bare generic names in `lib/` as library-side pressure that exists today. Grok's view of that evidence is not recorded.
- **The unit of a module.** Grok: "the file is the module" may be the wrong boundary, because an application can be several files, and rewriting Aloemacs onto files first means moving it twice. Claude: once each class has its own file, the path carries the hierarchy, as in `examples/aloemacs/view.aloe`, and a barrel file can make the application a unit later without a declared library name.
- **Ergonomic pressure.** Both say the prefix is the same kind of pressure as the rebuilds that motivated `with`. Grok says the repetition alone does not clear the bar for a change this large. Claude says it counts, and the question is when to pay for it, not whether.

## If a module system is built later

These points were stable by the end of the discussion:

- Modules scope names. They do not scope selectors. `define-methods` still adds methods to a class by name.
- One file exports the names it defines. There is no export list until a program needs a name that importers must not see. `AloemacsCompletionScan` and `AloemacsSearchScan` already look like helpers, which is a reason to notice the question and not a reason to answer it yet.
- Imports are written as path strings and found the way `load` finds files. No load-path variable, no packages, no versions.
- Names are bare inside the defining file. A prefix or a rename is written on an import that actually collides.
- No qualified-call syntax such as `(fs Path)`.
- The class's module identity is what hover shows and what the checker prints. The displayed name should be the real path or the real module name, not a decorative one.
- Imports at the top of the file, with literal paths, leave room for a later macro system. Macros stay later.
- A barrel file that passes every editor name upward is the likely first addition past that minimum, because `main.aloe` and the tests currently see every name through one `load`.
- The useful displayed name `aloemacs/view` depends on the split having already put `View` in its own file.

## Still open when this is picked up again

- When module design starts: a charter now, beside the Aloemacs work, or at the second application.
- How several interactive applications would share one process (coroutines or threads), or whether they run as separate processes that communicate. That is a separate design, and modules do not wait for it.
- Whether `load` remains "include into this environment" beside `import`, or whether `load` itself becomes the once-only form.
- How an edited file is reloaded in the REPL and in a long-lived process.
- Whether the module is the file path or the application, which may be several files.
- Which collision tool comes first, `prefix` or `only`, and whether a shared prefix such as `aloemacs:` is enough or `rename` is ever required.
- Which classes, if any, stay private.
