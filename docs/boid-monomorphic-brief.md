# Brief — Monomorphic `Boid` (git + example + docs + editor cherry-pick)

**Status.** One-shot assignment for a **new conversation**. Not Aloe law.
Not a global checkpoint. Not editor/LSP work. Not a stack restack.

**Your job.** Create a branch **off `main`**, make `Boid` a non-generic
Float class in the example and the two law docs, commit there, then
**cherry-pick that commit** onto `experiment/2026-09-12-editor` so hover
on Boids can be tested. Then **stop**.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this file. Do not invent a different branch topology.
2. Do the git setup in §2.
3. Edit the files in §3. Run the tests in §4.
4. Commit on `fix/boid-monomorphic` only (§5).
5. Cherry-pick onto `experiment/2026-09-12-editor` (§6).
6. Stop. Report the two branch names, the commit hash, and test results.

Do not push. Do not open a PR. Do not merge `main` into editor. Do not
merge editor into `main`. Do not rebase the Gel / host / filesystem
stack. Do not `git restack`. Do not implement hover, LSP, constraints,
or `boids-generic.aloe`.

## 2. Git setup

Start from a **clean** worktree. If `git status` is not clean, **stop**
and tell the human. Do not stash editor WIP onto the Boid branch.

Current hover work lives on `experiment/2026-09-12-editor`. The Boid
change is 0.1 example-and-SPEC honesty, so it is born on `main`.

```sh
git checkout main
git checkout -b fix/boid-monomorphic
```

Use that exact branch name. Branch **from local `main`**, not from
editor, not from `origin/main` unless the human says otherwise.

If `main` is missing or checkout fails, **stop**.

## 3. Code and docs

Keep `Point` generic. Only `Boid` (and `Sim`’s flock type) go concrete.
Do not change physics, literals, `load`, `demo`, or the two
`(demo step)` lines.

### 3.1 `examples/boids.aloe`

- `(define-class (Boid T)` → `(define-class Boid`
- Fields: `(position (Point Float))`, `(velocity (Point Float))`
- Every `(Boid T)` → `Boid`
- Every `(List (Boid T))` → `(List Boid)`
- Every `(Point T)` **in Boid methods** → `(Point Float)`
- `neighbors` radius `(r T)` → `(r Float)`
- `Sim` flock `(List (Boid Float))` → `(List Boid)`

### 3.2 `SPEC.md`

Type grammar: `Boid` is monomorphic like `Sim`. Drop `(Boid Type)`.

Was:

```
Type ::= Int | Float | Bool | String | Symbol | Mirror | Signature | Sim | Math
       | (Point Type)
       | (Boid Type)
       | (List Type)
```

Now:

```
Type ::= Int | Float | Bool | String | Symbol | Mirror | Signature | Sim | Boid | Math
       | (Point Type)
       | (List Type)
```

Examples: `(List (Boid Float))` → `(List Boid)`. Keep `(Point Int)` and
`(Point Float)`.

§5.2 last bullet: keep Point generic and “Constraints (`T : Num`) are
not in 0.1.” Replace “The Boids program instantiates `T = Float`” with:
Boid is not generic; the Boids program uses `(Point Float)` and `Boid`.

Do not otherwise rewrite `SPEC.md`.

### 3.3 `docs/decisions.md`

Section **Sim and numerics (2026-09-02)** only.

Was: `Point` and `Boid` are generic. `Sim` is not. Flock is
`(List (Boid Float))`.

Now: `Point` is generic. `Boid` and `Sim` are not. Flock is
`(List Boid)`.

Keep the Int/Float / `(n float)` sentence and the rejected `Sim[T]`
paragraph.

### 3.4 Do not edit

- `aloe/*.rkt`, LSP, VS Code, `editors/`
- `CHECKPOINTS.md`, `archive/`, Gel docs, this brief
- Any test unless it still names `(Boid T)` or `(Boid Float)` as a
  **type**. Construction `(Boid new (Point new 0.0 …) …)` stays.
  Int-point construction should still be a type error against
  `(Point Float)` fields.

## 4. Tests (on `fix/boid-monomorphic`)

```sh
raco test tests
./bin/aloe --quit examples/boids.aloe
```

Hand: `./bin/aloe examples/boids.aloe` still evaluates the two
`(demo step)` forms. If tests fail, fix the Boid/docs change, not the
test suite, unless a test asserts the old type spelling.

## 5. Commit (on `fix/boid-monomorphic` only)

Stage only the files you changed for this assignment. One commit.
Message:

```
Make Boid a non-generic Float class
```

Do not commit `node_modules`, `.vsix`, or unrelated editor files.

## 6. Bring it onto the editor branch

Cherry-pick. Do not merge.

```sh
git checkout experiment/2026-09-12-editor
git cherry-pick <the-commit-on-fix/boid-monomorphic>
```

If `SPEC.md` conflicts: keep **all** editor-only SPEC text (host,
constructors, Gel, etc.). Apply only the Boid grammar / example /
§5.2 sentence from §3.2. `docs/decisions.md` and
`examples/boids.aloe` should apply cleanly.

After a successful cherry-pick:

```sh
raco test tests
./bin/aloe --quit examples/boids.aloe
```

Leave HEAD on `experiment/2026-09-12-editor` so the human can hover
Boids there. `fix/boid-monomorphic` remains the main-based branch.

If cherry-pick aborts and you cannot resolve it as above, **stop**,
leave the tree as `git cherry-pick --abort` if needed, and report.
Do not rebase editor onto `main`.

## 7. Non-goals

- `git push`, `gh`, PRs
- Merging or restacking experiment branches
- Constraints, `T : Math`, making `Point` non-generic
- Hover/LSP/VS Code code changes
- A second Boids file

## 8. Done when

- `fix/boid-monomorphic` exists, based on `main`, with one commit
- `examples/boids.aloe` has no type parameter `T` on `Boid`
- `SPEC.md` type grammar has `Boid`, not `(Boid Type)`
- `docs/decisions.md` matches
- that commit is cherry-picked onto `experiment/2026-09-12-editor`
- `raco test tests` is green on **both** branches (or you report which
  failed)
- HEAD is `experiment/2026-09-12-editor`
- nothing was pushed
