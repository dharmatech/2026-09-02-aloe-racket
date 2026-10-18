# Grok's review of the brief and the charter

Two replies from Grok, brought by the user on 2026-10-18. The first
reviews [`summary.md`](summary.md), the frame-time charter, and the
evaluator compile-limit brief as committed in `11d42d0`. The second
reviews the revision committed in `432057c`. What each changed is in the
"Review, 2026-10-18" section of `summary.md`. Text is verbatim; the
section titles Grok used are rendered as headings.

---

## First reply

The split is the right one, and the documents agree with each other and with the measurement record. I would hand off the spine brief and the frame-time charter. I would not hand the frame-time spec to an implementer until the evaluator compiles whole.

I did not re-run the eleven-commit bisect. I checked the record against the tree and against itself. aloe/eval.rkt is 1,910 lines. examples/aloemacs/file.aloe is 2,370 lines. The three source pins in the brief are real: tests/checkpoint-17.rkt rejects a [(map) and [(fold) case, tests/checkpoint-88.rkt rejects host-receiver-invoke-method, and tests/checkpoint-115.rkt requires split-lines and rejects starts-with?. The piece table adds up. The slope in the summary is about 3 ms per thousand lines with the limit raised and about 5 ms without. The charter's numbers match that record. Leaving List and the runner out of the editor series is the right boundary, and it does not collide with the host-runner record.

### The spine brief

The cause it names is specific enough to act on. One commit, 0e20fae, moved all three medians by about 20 percent, and the commits on either side of it did not. Recompiling only eval.rkt above the limit brings the three medians back to 2.6, 22.8, and 14.1 ms. type.rkt is also over the limit and is correctly left out, because driver-prepare! keeps the checker outside the timed interval.

The two locks can be met together. Mirror and signature support, printing, and the load cache are on the order of 700 of those 1,910 lines, which is more than the quarter the remaining body has to lose to fit under 8,000 terms. The cut that can fail is Mirror invoking back into dispatch. The brief already says to name one indirection or pick a different cut. If the cold cut does not reach 8,000, the manager should send the brief back rather than separate eval-expr from make-list-value.

The guard proves the compile mode, not that the hot path stayed in one module. A bad cut passes PLT_CS_COMPILE_LIMIT=8000 and stays slow. The brief's before-and-after run of tests/aloemacs/window-pictures.rkt is the check that matters. The checkpoint's completion section has to require those three medians. A note in the manager's summary is not enough.

The Index charter did not forbid a faster cons and rest. It forbade a kernel Vector and said to send that measurement back. Parking the cheaper List steps outside both of these documents is still right. They change what aloe/eval.rkt does, and this editor series is not the place.

### The charter

Held Down is in reach without a kernel change. With the evaluator fixed, the wide case at 2,400 lines is 27.2 ms alone, which is under 30 ms and has almost no room for the -j 4 spread that has been failing this test all week. Padding and the block check are what create the margin. Requiring the bar to pass in the whole suite, with the margin written down, is the right lesson from the rerun-alone habit.

Typing is not in reach on the evidence in the folder. The acceptance bar requires one typed character, deep, in four windows, on a fixture as long as file.aloe, under 30 ms. The best measured result is 46 ms at 971 lines and 88 ms at 5,000 lines, and both of those include the List change the charter forbids. The evaluator fix alone leaves that case at 141 ms. Doubling spaces and skipping clean safe-cells walks do not touch the cost that dominates it: each unselected leaf walks from the cursor back to scroll 0, and each step copies the whole line list.

So §5.1 item 5, rows that survive an edit which does not touch the lines they show, is the typing plan. It was not prototyped. Items 1 and 2 are the Down plan. The 30 ms number should stay, because key repeat does not move. If a correct invalidation key cannot be stated, the spec comes back here. §3.1 already forbids a key that can paint stale rows, and §4.3 already forbids quietly moving the cost into List. The designer should not raise the bar and should not treat 46 ms as the gap at file.aloe's length. That 46 ms is the short fixture. The long-file row in the summary is 88 ms, and file.aloe sits between them, with a more expensive copy on every step of the same walk.

The spec can be written before the spine checkpoint lands. A frame-time implementer cannot honestly meet a timing bar on today's eval.rkt.

## Second reply

The revision lands the last review. Commit 432057c is fit to hand off. I did not re-run the new probe. The new rows sit on the slope the record already had, so I believe them.

Editor-only, with the evaluator compiled whole, a held Down at 2,400 lines is 14.7 ms in four windows and 10.6 ms in one. That is the margin the 30 ms bar needed. A typed character at that length goes from 244 ms to 214 ms. The saving is about 30 ms at every length they measured, and the rest still grows with the file. That is a shorter leaf build sitting on top of the same unselected-leaf walk. The 46 ms and 88 ms figures stay labeled as the runs that included the List change.

The brief now says to send it back if the cold code cannot get the hot module under 8,000 terms, and not to split eval-expr away from make-list-value. The window-pictures comparison is required in verification and acceptance, against the slow build and against the same tree with only eval.rkt rebuilt above the limit. The Index wording now says that charter forbade a kernel Vector, and did not decide cheaper cons and rest. The charter tells the designer that Down is items 1 and 2, that typing is item 5, that the number to close is 214 ms at 2,400 lines, and that the spec comes back here if no correct invalidation key can be stated. No frame-time checkpoint goes to an implementer until the evaluator compiles whole. The README says the same thing.

One acceptance clause is tighter than the gap it sits on. The first-screen median only moves from 3.2 ms to 2.6 ms. Requiring every median, including that one, to be strictly below the slow build can fail a good split. The wide and one-deep gaps are about 5 ms and 3.5 ms. Those two have to land with the raised-limit reference. The tolerance the checkpoint writes should be a small part of that gap, so a build that only recovers half the speed fails.

Item 5 is still unprototyped, and it is the whole typing plan. The new numbers make it a plausible bet. One window at 2,400 lines is already 10.6 ms, because there is no second leaf to walk. If unselected rows can be kept when the edit did not touch the lines they show, four-window typing should fall near that cost rather than near 214 ms. The key still has to be stated so a changed line cannot match. The 30 ms bar stays.
