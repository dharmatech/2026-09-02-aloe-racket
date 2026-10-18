# Grok's review of the record and the sketch

Two replies from Grok, brought by the user on 2026-10-17 after
[`summary.md`](summary.md) and [`end-state-sketch.md`](end-state-sketch.md)
were written. The first reviews both files. The second answers Claude's
reply to the first, which is summarized in the "Review, 2026-10-17"
section of `summary.md`. Text is verbatim; the section titles Grok used
are rendered as headings.

---

## First reply

Keep the typed host boundary. I re-ran the probes that this rests on, and the part I would not sign is the editor loop.

The boundary is the nominal host descriptor, injected onto the driver base, with Int, Bool, String, and (List String) as the crossing types. AloemacsSession carrying (Fs H) is the part worth protecting. An import of a Racket module cannot do the job of call-with-tty-term-receiver: that procedure puts the terminal into raw mode and restores it on the way out, including when the program raises. A binding cannot wrap the rest of the program in that extent. The sketch is right to reject an FFI, a (require ...) inside Aloe, a Deno-style flag, and a second host declaration written in the program.

What is major is narrower than the host model. The grant path can change while aloemacs-run.rkt still owns the loop. Moving that loop into Aloe is a separate bet, and it is the bet I would not take on the evidence in this folder.

### Where the sketch is right

The awkwardness is the missing entry point. ./bin/aloe injects nothing, so examples/aloemacs/main.aloe fails with unbound symbol: fs-host before it runs. The same is true of Gel and term. Each real program then grows a hand-written runner. That is a wiring problem.

The manifest is already the declaration. examples/aloemacs/aloe-hosts.rktd names fs-host, the language server reads it as data, and host-queries spec §6.9 reserved a later factory clause for a runner. Putting the same information in an Aloe form would give you two sources of truth, one of them carrying host/racket/... paths in language source. Tests inject a double and then load the file. A declaration that grants, rather than one that is satisfied by whatever is already injected, fights that idiom. I would not add one.

The checker hang is real, and it is a language bug whether or not the loop ever moves. I ran recursion-hang.rkt. The class is accepted. ((Loop new 1) run 3) does not return. The stack is check-method-body! to infer-instance-send to the if thunk and back into check-method-body!, with no record that this body is already being checked. Fs and AloemacsSession are both generic classes written with (fields ...), so any recursive method on either of them hits the same walk. Gel missed it only because GelMain is not generic.

The tail-call shape is also real, as far as a small loop goes. At 10,000 iterations the tail probe retained about 0.03 MB after a collection. The non-tail probe, which adds + 0 around the recursive send, peaked about 10 MB higher and only gave that back when the loop returned. No stack overflow either way. Racket CS is putting those frames on the heap. That matches the sketch, and it matches the evaluator: the send clause of eval-expr ends in lookup-message, apply-method ends in eval-expr, and send-to-bool tail-calls the chosen thunk.

### Where I disagree

The original reason for a Racket loop is not dead. Loop charter §4.9 picked the runner so that stack overflow would not be the lifetime limit of an editing session. The measurement shows that a tail-position send does not overflow, and that a send which is not in tail position does not overflow either. It retains on the order of a kilobyte per iteration until the loop returns. For an editor, the loop returning is quitting. A later edit that logs after the recursive send, or a wrapper around eval-expr for source locations, turns a session into a silent retention with no error.

Nothing in SPEC.md promises this. let and if are tail calls today because of how eval.rkt is written. The only parameterize and dynamic-wind in that file are on load, which is why this loop survives. That is an accident of the interpreter, and the 50-key run in loop-cost.rkt cannot see it. Fifty iterations of a kilobyte is noise next to a frame. The stack probe and the cost probe never run the same program: one is a toy Looper, the other is fifty editor keys. The natural run.aloe was not measured at all. Variant B is the contorted encoding, a step function plus an explicit-constructors class, chosen because the natural one hangs.

I would want proper tail calls stated for send, let, if, and case, with a language-suite test that a large tail recursion stays flat and that the non-tail form is allowed to grow. A comment in run.aloe, or a test that reads the source of run.aloe, does not catch someone wrapping eval-expr. Until that exists I would leave the editor loop in Racket. The Racket let loop cannot lose its constant space by accident.

The cycle guard is the right fix, and "a set or a memo" is not yet a fix. A memo written after check-method-body! returns does not stop the first walk. The recursive send happens while that walk is still on the stack. The check has to assume the method's annotated return type for this instantiation, then keep checking the outer body. A later send at the same instantiation can reuse the finished result. A send at a different instantiation must not. (Loop new 1) recursing into (Loop new "nope") is the case that makes a method-only set unsound. I would also reject the tempting wrong fix, which is to give the loop class explicit constructors so the body is checked once at definition. loop-cost.rkt already shows that result: under a rigid H, handle-event dies with unknown message: kind, because kind is a message on the concrete host.

This fix should not wait inside the runner charter. The runner charter has a dozen open questions, and this bug is already under Fs.

The sample run.aloe does not typecheck on this tree. SPEC.md §11 copies out of a loaded file only the names that file itself defines. main.aloe defines aloemacs-editor and nothing else. AloemacsSession is defined in file.aloe. The cost probe says so and works around it by loading file.aloe at the prompt. The end-state program loads main.aloe only and then writes (fields (session (AloemacsSession H))). That name is not in scope.

The same program also decides the failed-visit question the notes leave open. On None it starts the loop on the original editor, so a bad path becomes an untitled session and does call Term. Today aloemacs-run.rkt raises cannot visit path after enabling the alternate screen and before any columns, write, or read-event, and file-runner.rkt pins the zero Term calls. Both are coherent. The sketch should not show one of them as the picture while calling the choice open.

The test shim is thinner in the sketch than it would be in the tree. Production loads run.aloe, and run.aloe reads (args list). A test that today passes a path into run-aloemacs-with-hosts has to inject an args receiver too, or the visit never sees the path. The end-state says tests inject a scripted term and an fs double. That is one host short of the program it just wrote.

A factory column in the shared manifest turns the editor off until the reader changes. entry? in aloe/host-manifest.rkt requires exactly four elements. Spec §6.3 lists a fifth element as a broken manifest, and a broken manifest counts as absent for every document in the folder. One factory clause on the run.aloe row makes main.aloe, file.aloe, and editor.aloe all lose fs-host. Hover goes back to the unbound-symbol failure this work just cured. "The server ignores the extra element" is the destination. The current reader does the opposite, and host-queries §6.9 says a later grammar is outside this spec. The charter lock, that a later clause must not change what an existing four-element row means, is still the right compatibility rule. The reader amendment has to land before aloe-hosts.rktd grows a clause, in the same change as the spec amendment. The server must be forbidden to call a factory, not merely have that listed as a non-goal.

bin/aloe does not become the only runner. Aloemacs still needs the alternate-screen and mouse bracket in Racket. I agree with keeping those bytes there. They are written to the terminal port inside with-term, so the scripted frame stream never sees them. Writing them from Aloe with (term write ...) puts them in that stream. A generic reset inside the TTY module is the wrong home while Gel and Aloemacs want different modes.

The file that remains is the factory plus run-aloemacs-with-hosts. Production will grant through the manifest. Tests will grant by injecting doubles and loading run.aloe. Those are still two grant paths. The current bug is that those two paths already disagree: the runner injects term, the manifest lists fs-host only. Collapsing them onto one manifest does not collapse the test shim. Something has to say, in one place, which names a given entry file requires, so the shim and the row cannot drift apart again.

An args host is a costume. The crossing type already exists, so it does not enlarge SPEC.md §14. Argv is still data rather than authority. I would look once at the runner binding a (List String) before load, and use a host only if that second injection mechanism is worse. I would not reopen the boundary over it.

Deleting term-run.rkt makes the original complaint worse for a one-off file. That runner is already "any file, with a terminal." After it is gone, a scratch program needs its own manifest row or it does not run. The payoff is Aloemacs and Gel, which need more than one host and, in Aloemacs's case, a teardown policy. I would keep the small runners until a scratch convention actually exists. "Delete them in the last checkpoint" is how that convention gets forgotten.

The REPL question has the same shape. A row whose factory holds the TTY should run the file and exit. A REPL with a disk should be a row of plain constructors and no terminal extent. One --quit rule will make one of those two feel broken. read inside with-term sees tui-term key structs, so "drop into the REPL with the hosts still up" is not a harmless default.

### What I would do with it

Fix the checker on its own. The rule to lock is: on re-entry of the same method at the same instantiation, assume the annotated return type; a different instantiation is checked on its own; the outer body is still checked against the annotation. The five-line Loop program is the test, plus one program that recurses at a second instantiation.

Separately, if a tail-position send is going to carry a session, make that a tested evaluator rule. That test is what the loop spec was reaching for.

Take the manifest runner only if you want the grant path cleaned up, and write the charter so that aloemacs-run.rkt still owns the loop. Gel can move first, because its loop is already Aloe. Amend the host-queries reader in the same series, before any manifest in the tree grows a fifth element. Leave term-run.rkt until the scratch-file answer is real.

Leave the Aloemacs loop where it is until the tail-call rule is in the language suite. The two changes share a file today, which is why the sketch draws them as one road. They do not have to ship as one road. The grant path removes the repeated runners. The loop move is the major change, and the folder does not yet justify it.

---

## Second reply

Claude's reply is right, and the 20,000-key result holds. I re-ran it on the real session: the same step that sends ensure-visible, record-pictures, frame, and handle-event, then a tail self-send.

| Form | Heap after GC | Peak while running | Median, first and last thousand |
|---|---|---|---|
| Tail | +0.28 MB | +8.42 MB | 0.94 ms, 0.94 ms |
| Non-tail | +0.36 MB | +44.75 MB, about 2.3 KB per pending key | 0.95 ms, 0.95 ms |

That matches Claude's table. The non-tail form returns to the same heap and the same per-key time, so a latency bar cannot see it. I withdraw the objection that only the toy had been shown flat. The natural spelling is still the one that hangs the checker. Its steady state cannot differ: the extra ((AloemacsRun new next) loop) allocates the receiver before the tail send, and that allocation does not accumulate.

The combined order is the one I would follow. Cycle guard on its own, first. Then the tail-call sentence in SPEC.md and a language-suite test. Then the manifest runner, with the reader change before any manifest grows a fifth element, Gel first, the small runners kept, and aloemacs-run.rkt still owning the loop. The Aloemacs loop charter comes after those, with a memory bar as a precondition. The two gates are small spine work. Gel's loop is already this shape: (self loop step) sits in the else arm of if, inside the lets, in gel/main.aloe. The sentence is owed because of that, and the editor should wait for the test because a long session is where the silent retention matters.

### What I would lock inside those gates

The cycle guard needs one more clause than same-instantiation assumption. I ran (Loop new (List of (self h))). The class is accepted, and the send diverges through the same check-method-body! walk. Take the error, not a depth bound. While a method is being checked, a send of that same method at a different instantiation is a type error. The same instantiation assumes the annotated return type and keeps checking the outer body. A finished check can be reused. A depth bound walks a divergent check for several increasingly large types and then reports an arbitrary limit. The editor loop and a recursive method on Fs are both same-instantiation recursion, so the error does not get in their way. A later program that truly needs a finite jump to another instantiation can have a more precise rule then.

The tail-call test should not be a fixed custodian ceiling. Both forms above finish within a third of a megabyte of where they started, so a check after the loop returns passes the broken one. The baseline before the loop was about 81 MB here. A ceiling tight enough to kill the non-tail run and spare the tail run moves when that baseline moves. Sample the peak while the loop is still running. Assert that the tail peak stays within a small bound and that the non-tail peak grows by at least about a kilobyte per iteration. Keep a custodian limit only as a rail against a runaway. The program under test can be a non-generic class with no host, so the test does not depend on tui-term or on the cycle guard.

The sentence in SPEC.md should name the positions. A send in tail position when it is the body of a method, the body of a let, the taken arm of if, or the taken arm of case. Evaluating a receiver or an argument is not. cond follows if. That is the whole promise the editor loop needs.

### The two design points

I concede the args host. A (List String) bound by hand is a second injection mechanism, and section 14 has one. A one-method host with a double is the uniform choice. It is still a designer's question only in the spelling.

The shim should read the entry file's manifest row and inject the test's doubles under exactly those binding names, failing when the sets differ. It should read names only. It must not call a factory and it must not load the TTY module. Then one row is the contract for production and for the suite, which is the drift that already happened with term.

The two factual corrections, the file.aloe load and the visit question, belong in the sketch when you want that file touched. I would not treat Claude's reply as a reason to open either charter yet.
