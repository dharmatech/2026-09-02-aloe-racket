# Grok's review of the frame-time spec

The user brought this review on 18 October 2026. It reviewed
`docs/design/implementation/aloemacs/frame-time/spec.md` as committed in
`9a30ec0`. Verbatim below. The designer's response is the next revision
of the spec; [`README.md`](README.md) in this folder lists what changed.

---

The spec is sound enough to implement. The three repairs match the current frame paths and the kernel, and the byte tests are the right kind. I would still change the test procedure and two cost-model sentences before a checkpoint manager slices it. Those are the places a faithful implementer can measure the wrong thing, or a missed speedup can stay green.

What holds up

I checked the three code blocks against editor.aloe, lib/text.aloe, and the kernel.

spaces and fill are ordinary doubling. Integer / is quotient, so the odd-length test is exact, and the results stay the same for a count at or below 0.

safe-cells still replaces codes 0–31 and 127 with one space. find returns (Option Int) and treats a start at the end of the string as no match, so the search from at + 1 terminates. A space is not in safe-cell-controls, so a replacement cannot create a later match. The callers you keep on safe-cells are all of them: both mode rows, the echo row, completion rows, and the search key.

safe-rows is aligned. joined-with always includes current, and with an empty separator that empty piece adds no characters. cut-rows then slices by the original row widths. List.cons prepends, so the recursive cut keeps file order.

lines-from matches focus-at then next-lines on a well-formed zipper. I walked the cases that matter: the window above the focus, below it, spanning it, and running off the end. above is nearest-first, and the fold with cons is the same reversal Text.lines already uses. below is already in file order. List.len is a vector length, so the None test does not walk the tail. The 1,018-check claim fits that geometry. move-down really does leave the text focused at the point, and focus-at of the current line returns immediately.

The tab fixture is the right correction to the earlier block check. A clean file never enters cut-rows. Putting a tab on every seventh line, at index 10, forces that path in every timed leaf.

The deep growth check is the real lock. Today’s deep pair, from §3, differs by about 3.7 ms and 4.1 ms. The one-walk variant in §7.2 differs by 1.8 ms and 1.9 ms. A bound of 1.5 ms fails both, and the good runs you measured stay near 0.2 ms.

Fix before this is sliced

The timed sessions can be the same value. §8.2 says the last page is reached “from deep” by more page-downs, and that other-window happens “before going deep.” Read as mutation of one session, the deep samples run at the last page, and the growth check compares a last-page long file with a deep short file. A correct lines-from then fails a check it should pass. The designer’s draft avoided this by copying the session before paging. The spec should say that the first screen, the deep pair, and the last page are separate session values, and that paging one must not move another. The other-window loop also needs the existing stop: if four sends never produce a 109-column leaf, report it and stop.

The tables are not one procedure. §3 times an untimed Down, then fit, record, and frame, and calls the point line 817. §8.3 puts handle-key inside the interval and uses eleven samples. §7.5 is the §8.3 interval with medians of 21. The payoff lines mix them: 23/14 ms is the §3 interval, and 11.5/6.4 ms includes the key. The gap is about a millisecond, and the direction is the same, but the normative interval is only §8.3. Label each table with what the clock covers, or a later edit will “correct” the test by moving the key back outside the sample.

§8.4 overstates the cost model. A scrolling Down’s lines-from reads only above. The sample also runs move-down, and focus-down still copies below once. At the same depth, the long file’s tail is about 1,400 lines longer than the short file’s. Your measured growth of well under 0.2 ms says that single copy is small next to the 1.5 ms bound. The sentence to fix is “a Down reads only above, so the file’s length is not in it.” The per-row walk is gone. One copy of the tail is still in the key.

The bar will not notice every miss

The product bar is 30 ms, and the spec is right not to tighten that number inside raco test. On the fixtures this series actually runs, today’s editor is already under that ceiling: about 23 ms deep at 971 lines, and about 27 ms on the last page at 2,400. So:

• Checkpoint 000’s timing tests pass with no product change. Its speedup is enforced by the human rule that an alone median above 15 ms stops the review.
• The last page has no twin at 971 lines. The old zipper walk on that page stays under 30 ms at 2,400 lines. The deep growth check is what rejects that walk, and only in 001.
• After the series lands, a later edit can slide a Down from about 9 ms back toward 25 ms and the suite stays green. The 15 ms margin is a review rule, not a test.

That matches the charter’s “do not raise 30 ms” decision. It means the permanent suite protects key-repeat, and the designed margin lives in the printed medians. I would make the checkpoint say that the implementer reports those alone medians, and that a median above 15 ms is a failed checkpoint rather than a note beside a green suite.

The sample sends handle-key. The runner sends handle-event, which for "down" checks the mouse prefix, disarms, and then takes handle-key. It also reads the terminal size on every turn. The write is the only omission §8.3 names. The mouse check is cheap. The sentence should name handle-event, or say that the sample starts at handle-key and leaves the mouse classification out.

Smaller bounds

lines-from’s None test is arithmetic: top is past the end when top > focus + (below len). That equals focus-at when len(above) is focus and the lines are contiguous from 0. The editor maintains that. Text indexed can build a zipper that does not, and then lines-from returns Some where focus-at returns None. The contract should say it applies to a well-formed zipper. The equivalence grid never builds the other kind.

§5.1’s rebuild is one full-string copy per occurrence of a control. “Costs the same with tabs as without” is true for the fixture, which has seven or eight tabs in the block. A leaf full of tabs copies the block once per tab. The old walk was also per character, and file.aloe is not that leaf. One sentence would stop a later reader from treating the table as density-independent.

Held typing stays where the charter put it. The spec is already plain about the consequence: after this series, one typed character in four windows is about 53 ms at line 817, 266 ms at the end of the 2,400-line file, and 1,137 ms at the end of 5,000 lines. The per-row walk is gone. The walk back to the other windows’ scroll rows is not.

I did not write code or change the spec.
