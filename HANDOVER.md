# Handover — Godot rewrite, resume point

Snapshot of where the SnoringCat Godot rewrite is at the time of writing.
Phase 1 (repo surgery) is complete; Phase 2 (code review) is the next work.

The original full plan, including the pre-execution research and rationale,
is at `C:\Users\lsl\.claude\plans\spicy-splashing-shamir.md` on this
machine. This file is the durable, in-project copy of the handover.

## What was done (2026-05-19)

**Phase 1 — repo surgery — COMPLETE.** All branches/URLs/archives are in
their final state on GitHub. The local working directory is still
`C:\Users\lsl\Repositories\bootstrapper2\` (cosmetic — see "Known followups").

End state on GitHub (`gh repo list SnoringCatGames`):

| Repo | Default | Status | Notes |
|---|---|---|---|
| bootstrapper | main | live | renamed from bootstrapper2; private |
| scaffolder | master | live | swapped: `master` = Godot 4 content, `godot3` branch = preserved Godot 3, `dev` / `asset-lib-v0.7.0` / tags `v0.4-v0.7` + `0.4.0` all preserved; public |
| surfacer | master | live | same shape as scaffolder; public |
| squirrel_away | master | live | swapped: `master` = Godot 4, `dev`, `godot3`; no asset-lib branch / no tags; public |
| snore_core | main | live | unchanged; private |
| surf_scaf | main | live | unchanged URLs on origin, but `.gitmodules` URL-fixed to drop `2` suffix from sibling references; private |
| scaffolder2 | main | **ARCHIVED** | read-only mirror of old new-repo content |
| surfacer2 | main | **ARCHIVED** | same |
| squirrel_away2 | main | **ARCHIVED** | same |
| exampler | main | live | untouched per decision; public Godot-3 example |

## Rollback artifacts

Mirror clones of the pre-swap old repos live at:

- `C:\tmp\sc-backup\scaffolder.git` (mirror, all refs + tags)
- `C:\tmp\sc-backup\surfacer.git` (mirror)
- `C:\tmp\sc-backup\squirrel_away.git` (mirror)

Keep these for at least one week (until ~2026-05-26). If anything goes
wrong, the old master can be restored from `<mirror>/refs/heads/master`,
and the `godot3` branch on the live repo can be deleted.

Scratch clones used during the swap live at `C:\tmp\surgery\` and
`C:\tmp\verify\`. Safe to delete anytime.

## Key decisions made during execution (beyond the original plan)

1. **`--force-with-lease` initially rejected** with "stale info" because the
   remote-tracking refs still reflected the new repo, not the old. Fix:
   `git fetch origin` immediately after `git remote set-url origin <old>`
   to populate `refs/remotes/origin/master`. Then `--force-with-lease`
   works. Pattern: when repointing origin, always fetch before
   force-pushing.
2. **`git submodule sync --recursive`** silently failed to update the actual
   `.git/modules/.../config` URLs inside the nested submodules of
   `surf_scaf`. Worked around by manually running
   `git remote set-url origin <new>` inside each nested submodule clone.
   The `.gitmodules` source of truth in git history is correct. Worth
   investigating later — possibly a Git-for-Windows / nested-submodule
   quirk.
3. **Divergent dev branches** on remote vs local. The local working tree of
   `bootstrapper2` was behind the remote (3 "Continue porting scaffolder
   logic" commits on remote `dev` that weren't local). Same for the
   `squirrel_away` submodule clone (1 commit ahead remote). Resolved by
   `git fetch && git rebase origin/dev` before pushing the URL-fix
   commits. Sanity-check pattern: always fetch first.
4. **`bootstrapper` main had its own commits** that weren't on dev (CI
   workflow tweaks, plus a previous `Merge branch 'dev'`). `dev` → `main`
   needed a real merge commit (`--no-ff`), not a fast-forward. Merge
   landed cleanly without conflicts; the porting WIP and URL fix are now
   on main as commit `31c0fd0`.
5. **Accidentally created a `main` branch on `squirrel_away`** (which uses
   `master` as default per user decision). Recovered by force-pushing
   `master` to dev's tip (`git push origin dev:master`) and deleting the
   stray `main`.
6. **`dev` → default-branch merge done before archiving the `*2` repos**
   (per a mid-session decision). Going forward `dev` and the default
   branch are integrated for surf_scaf, bootstrapper (both default `main`),
   and squirrel_away (default `master`).

## Stray local state that was preserved, not committed

- **`.local-patches/`** at the project root. Two files:
  - `godot-cpp-typed-array-debug.patch` — `git diff` of the local
    `TypedArray<T>::debug()` helper.
  - `godot-cpp-local_dev_template_instantiations.cpp` — the untracked
    companion file that forces template instantiation.
  Both are third-party (godot-cpp) edits that must NOT be pushed
  upstream. The patches are a safety net; the working tree in
  `submodules/godot-cpp/` is still dirty with the live versions and will
  survive normal git operations as long as nothing runs `git restore`
  or `git checkout` inside the godot-cpp submodule.
- **`submodules/snore_core/src/snore_core/test_snore_core_root_module.cpp`**
  — empty stub file, untracked. Left alone; either `git rm` or fill in.
- **Submodule-pointer drift inside `surf_scaf` and `squirrel_away`**
  working trees (the lowercase-m entries from `git status`). These are
  dev-branch in-flight state; left untouched.

## Known followups

Forward-looking work — including Phase 2 (review), Phase 3 (port + framework
work), Phase 4 (dynamic surfacer pathfinding), and housekeeping — is tracked
in [ROADMAP.md](ROADMAP.md).

Top items at the time of writing:

1. Rename local working directory `bootstrapper2\` → `bootstrapper\`
   (cosmetic; close Godot + IDEs first).
2. Phase 2.1 — GDExtension cross-dep architecture review.
3. Phase 2.2 — Old vs new port audit.
4. Delete `C:\tmp\sc-backup\*.git` mirrors after ~2026-05-26.

## Quick-start for the next session

```pwsh
cd C:\Users\lsl\Repositories\bootstrapper2   # (or `bootstrapper` if renamed)
git status --short --ignore-submodules=all   # expect: clean
git remote -v                                 # expect: origin=bootstrapper.git
git -C submodules/scaffolder remote -v        # expect: scaffolder (no `2`)
git -C submodules/squirrel_away remote -v     # expect: squirrel_away
git submodule status                          # all SHAs reachable
```

Then jump to Phase 2.1 above.

## Project context summary

- Multi-repo Godot rewrite project. Goal: Godot 3 → Godot 4 migration that
  also moves perf-critical logic from GDScript into C++ via GDExtension,
  restructures the app/framework layer, and (later) adds a dynamic-
  pathfinding mode to surfacer.
- The old Godot-3 repos (squirrel_away, surfacer, scaffolder) live on the
  un-suffixed names with their original content preserved on the `godot3`
  branch. `master` is now Godot 4 content.
- `bootstrapper` is the umbrella project, depending on snore_core,
  scaffolder, surfacer, surf_scaf, squirrel_away via submodules (plus
  godot, godot-cpp, googletest).
- `snore_core` and `surf_scaf` are new; they have no Godot 3 counterpart.
- `exampler` is the Godot-3-era example project; deliberately untouched.
- Active GDScript→C++ porting work happens on `dev` branches; `main`
  (or `master` for the swapped repos) is the integration trunk.
