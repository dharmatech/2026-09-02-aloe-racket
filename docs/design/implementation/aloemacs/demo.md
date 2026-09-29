# Try aloemacs

A hands-on tour of the first-product ladder: one buffer, a full-screen
frame, visit a path, type, save with Ctrl-S, quit with Escape. The bottom
echo row shows `untitled` or the bound path and reports `saved:` or
`failed:` after Ctrl-S until the next key. There is no minibuffer or
`C-x` prefix. This file describes behavior that already exists. It does
not change the specs.

## Start

From the repository root, with a real TTY:

```sh
raco pkg install tui-term   # once, if the package is not already installed
racket host/racket/aloemacs-run.rkt
```

That opens an **untitled** empty buffer. Keep one session for the steps
below, or restart when a step says to. Stop with **Escape**. This tour
does not cover windows, find-file, or `C-x C-s`.

To open a file instead:

```sh
racket host/racket/aloemacs-run.rkt path/to/file
```

A relative path is resolved against the process working directory. A
missing path starts empty and **bound** to that location; the file is
created on the first successful save. A directory, symlink, or other
non-file is refused and the runner exits.

## Keys

| Key | What it does |
|---|---|
| Printable character | Inserts that character. `q` and `s` are letters, not commands. |
| Return | Newline |
| Backspace | Delete backward (joins lines at column 0) |
| Arrow keys | Move; wrap at line ends; clamp on up/down |
| **Ctrl-S** | Save. Writes the current text to the **bound** path and reports success or failure on the echo row. |
| **Escape** | Quit. Does **not** save. |

Untitled Ctrl-S writes nothing and shows `failed: untitled`. There is no
prompt.

## Steps

Use a throwaway file so you do not overwrite anything you care about.

1. **Untitled, then quit.** From the repo root run
   `racket host/racket/aloemacs-run.rkt`. You should see a cleared
   screen and a cursor at the top-left. Type `hello`, press Return,
   type `world`. Arrows should move through that text. Press Escape.
   The process exits. Nothing was written to disk.

2. **Visit a new path.** Run:

   ```sh
   racket host/racket/aloemacs-run.rkt /tmp/aloemacs-demo.txt
   ```

   If that file did not exist, the buffer is empty but bound to
   `/tmp/aloemacs-demo.txt`. Type a short line, for example `demo`.

3. **Save.** Press **Ctrl-S**. The echo row shows `saved:` and the bound path. Press
   Escape. In another terminal:

   ```sh
   cat /tmp/aloemacs-demo.txt
   ```

   You should see `demo` (and a newline only if you pressed Return).

4. **Visit again and edit.** Run the same command as step 2. The
   buffer should show what you saved. Move, insert, Backspace, then
   Ctrl-S again. Escape. `cat` the file and confirm the new text.

5. **Quit without saving.** Open the file, type `oops`, press Escape
   **without** Ctrl-S. `cat` the file: `oops` must not be there.

When you are done, delete `/tmp/aloemacs-demo.txt` if you created it.
