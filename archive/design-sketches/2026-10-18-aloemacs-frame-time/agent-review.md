# A new agent's review of the charter

A review from a separate agent conversation, brought by the user on
2026-10-18 after `3f21114`. It read the record, the charter,
`lib/text.aloe`, and the sources of Legmacs (`~/src/legmacs`) and `e`
(`~/src/e`), and did not re-run the probes. What it changed is in the
"Review, 2026-10-18" section of [`summary.md`](summary.md). Grok's
answer to it is the fourth reply in [`grok-review.md`](grok-review.md).
Text is verbatim. The section titles it used are rendered as headings,
and its table is kept in a text block.

---

The Down half of this charter is worth doing. The typing half is a cache in front of a walk that Legmacs and e never perform, and I would not lock the series to it.

I did not re-run the probes. This is from the 18 October record, the charter, lib/text.aloe, and the two other editors (~/src/legmacs, which is the tree you also call Legmax, and ~/src/e).

## What the time actually is

A held Down and a held letter are different problems that happen to share a screen.

```text
┌─────────────────┬───────────┬──────────────────┬───────────────┐
│ Cost            │ Where it  │  Held Down, four │     One typed │
│                 │ sits      │  windows, ~2,400 │    character, │
│                 │           │ lines, evaluator │   same layout │
│                 │           │            fixed │               │
├─────────────────┼───────────┼──────────────────┼───────────────┤
│ Per-character   │ The leaf  │ Most of the drop │   About 30 ms │
│ loops (safe-    │ you       │  from 27.2 ms to │ of the 244 ms │
│ cells, spaces,  │ rebuild   │          14.7 ms │               │
│ fill)           │           │                  │               │
├─────────────────┼───────────┼──────────────────┼───────────────┤
│ Zipper steps    │ Text      │    The part that │ Almost all of │
│ that copy both  │ focus-up  │  still grows, ~3 │ the remaining │
│ line lists      │ / focus   │  ms per thousand │       ~214 ms │
│                 │ -down     │            lines │               │
└─────────────────┴───────────┴──────────────────┴───────────────┘
```

Down is already inside the kind of repair this charter is good at. At the length of examples/aloemacs/file.aloe, the wide case is 27.2 ms alone after the evaluator compiles whole, with no room for the -j 4 spread. Doubling spaces and fill, and checking a leaf for controls once, put that case at 14.7 ms and the one-window case at 10.6 ms. Those two changes are small, they keep the same bytes, and they are measured.

Typing is an order of magnitude past the bar, and those two changes barely touch it (244 ms to 214 ms). Each unselected window still walks from the cursor, near line 800, back to scroll row 0, and every step copies the whole line list. One window has no such walk, so the same key is already 11.0 ms. The charter's plan for the other three windows is §5.1 item 5: keep their recorded rows when the edit did not touch the lines they show. That plan was not prototyped.

The evaluator regression is real and it is not this series. 0e20fae pushed aloe/eval.rkt over Racket CS's compile limit and took about 20 percent off every frame. Fixing that is compiling the interpreter module whole. It helps every Aloe program. A compiler for Aloe would not be that fix.

## What Legmacs and e actually do

Both of them made the line an integer, and then painting a window stopped caring how far away the cursor is.

Legmacs keeps the buffer as a vector of line strings. Each window stores cursor-row and scroll-row as integers. A text row is (nth lines buf-row) in render.lg. An edit returns a new vector and shares the unchanged lines. The frame is rebuilt from the visible rows every time. The only cache, flat-cache in buffer.lg, is a mutable table for whole-buffer scans such as paren matching, keyed by the identity of the line vector. Cursor motion does not rebuild it. Legmacs does not keep painted rows across frames, and it does not need to.

e stores an immutable vector of line strings in lib/foundation/text.sls. apply-edit allocates one new vector, copies the line pointers above and below the edit, and shares the line strings. Each window has its own cursor and its own top. line-ref in lib/head/render.sls is vector-ref. On top of that, prepare reuses a previous projection when the text vector is eq?, and paint.sls skips terminal segments that did not change. That row reuse is an optimization sitting on a cheap miss. A miss is one index per visible row. e also coalesces keys; this charter is right to leave that, and the runner, alone.

Aloemacs already copied the seam those two use, in the index series: lines are the unit, the editor holds a focus, and frame visits visible rows. The representation underneath is a zipper, because that was what Aloe 0.1 could express. Text indexed is above, current, below, and focus. focus-down is above cons current and below rest. List cons and rest allocate a new vector and copy every element. One step at 971 lines is about 0.05 ms. Eight hundred steps, three windows, at the length of file.aloe, is the 214 ms.

So the index series did the right thing for the bug it had. It stopped frame from splitting the whole source. This record is the bill for the zipper: local motion is cheap, and reaching a distant scroll row is not.

Window-pictures 000 is the piece Aloemacs added because the miss was expensive. A leaf keeps its finished rows while the buffer id, history length, scroll, rectangle, name, and selection stay the same. Held Down hits that key, which is why Down is ~15–27 ms and typing is ~200 ms. History length changes on every edit. Legmacs never needed that key. e has a simpler one, vector identity, because rebuilding the missed rows is cheap.

## The charter, piece by piece

Doubled spaces and fill, and the block control check. Do these. They are ordinary algorithms expressed with the String messages that exist. Padding grows by appending a character to itself, so a row costs a handful of sends. A clean leaf is one find over the clipped text; a row that actually contains a control still walks. In an interpreter, a per-character send is the expensive way to fill 109 columns. Legmacs and e do not write this trick because a native string scan is already one loop. The idea is the same: the common row is a string operation, and the control rule stays on the rare row. A later compiler would make the old loops less embarrassing. It would not make them the algorithm you want, and it is not required to get Down under 30 ms with margin. These two are most of a leaf today (17.6 ms of a 24.1 ms rebuild at 971 lines). That is the bulk of the frame, not a squeeze.

One walk, and reusing the rows a one-line scroll still shows. Reasonable, and they belong in the editor. They cut the selected window's zipper, which is why Down still grows about 3 ms per thousand lines after the padding work (10.9 ms at 971 lines, 14.7 at 2,400, 22.6 at 5,000). At file.aloe the margin is already there. These two are how a longer file stays inside it. They are the same family as the index series: visit the lines you are about to paint.

Recorded rows on the one-window path. Leave it. One window is already 10.6 ms down and 11.0 ms typed, at 2,400 lines, with the padding and the block check.

Rows that survive an edit outside the lines they show. This is the complicated part, and it is the workaround.

It can be stated. A picture remembers the line interval it painted. A character typed on a line outside that interval, with the line count unchanged, leaves those bytes alone. A newline at line K invalidates every picture whose interval is not strictly above K. Undo and visit drop pictures, which is what window-pictures already does, because a snapshot restore is not an edit range. The favorable layout in the record — other windows still at the top, the cursor deep in the selected one — would then cost about what one window costs, near 11 ms rather than 214 ms. That estimate is plausible, and it is still an estimate.

The same design stays on the 200 ms walk whenever the key misses. Two windows showing the same lines, a newline above another window, a yank, a kill-line through a region another window is showing: each of those rebuilds every missed leaf by walking from the cursor. The charter's hand check is the layout where the key hits. The 30 ms promise would be true there and false in the layouts §5.3 is supposed to name.

e does not do this. When the text vector is not eq?, it reprojects the visible rows by index. Legmacs does not do it either. Both pay a full visible-row rebuild on every edit and stay fast because that rebuild does not walk the file. Item 5 is how you imitate their result while every miss is still Θ(distance × lines) copies. Window-pictures already showed how sharp that kind of key is: history length alone paints stale rows across undo, which is why a record has to land between the undo and the next edit. Item 5 is a second key, on more cases, unmeasured.

## Where this wants to live

A compiler is the wrong tool for the walk. The List prototype in the record is already a stand-in for "make cons and rest cheaper": one vector copy, no retype. Frame goldens passed. Typing in four windows fell to 46 ms at 971 lines, 58 ms at 2,400, and 88 ms at 5,000. Still over 30 ms, and still growing. Compiling the same zipper changes the constant on that copy. The shape stays: every step toward a distant scroll copies every line, and three windows do it on every character.

The Legmacs and e approach, translated into Aloe as it is, is a subscript on the vector List already stores. len, first, and empty? are already constant time. The random access inside that vector is unused. An nth (or a focus that is an integer into one line list) makes "paint scroll row + i" an index, and an edit builds one new list while sharing the untouched line strings. That is apply-edit and (nth lines buf-row). It is not their mutable store, not flat-cache, not key coalescing, and not partial terminal writes. The index charter already refused to hide a kernel Vector inside an editor layer, and it said to send the measurement back when List lookup was the floor. This record is that floor for typing. Cheaper cons and rest are worth a spine conversation of their own; they are not sufficient, and the prototype shows why.

I would still keep that conversation out of this editor series. A List message is language law. The padding and the block check are not.

With a subscript, four windows can be rebuilt the way Legmacs rebuilds them, from the visible rows, every key. Whether that alone lands under 30 ms is not in the record. One optimized leaf is about 11 ms, and the other leaves are narrower, so four rebuilds might sit near the bar rather than twenty times over it. Item 5 then becomes what it is in e: a saving you add when a measurement says the rebuild is still too slow, on top of a miss you can afford. Today it is the only way the typing bar can pass, which is why it has to be perfect.

## What I would do with the charter

Hand a designer the Down work: doubled padding, the block check, and, if you want the slope cut in the same series, the single walk and the one-row scroll reuse. The acceptance bar for that series is the one the measurements already support. Held Down, one window and four, at the length of file.aloe, under 30 ms in the whole suite under -j 4, same bytes, after eval.rkt compiles whole.

Keep the typing bar out of that series. State it as the remaining walk, and send List lookup back to a language discussion with this record. If a designer follows the charter as written, the 30 ms typing requirement forces item 5, and the honest result is either a delicate key or the spec coming back. The charter already allows the return. I would rather make the return unnecessary than discover the key in a spec.

The charter is careful, and the boundary around the evaluator, the runner, and List is the right boundary. The part that is too much machine for the gain is the unmeasured invalidation key, asked to carry a bar the representation cannot meet on a miss.
