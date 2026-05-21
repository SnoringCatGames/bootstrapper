# Handover — Godot rewrite, resume point

Snapshot of where the SnoringCat Godot rewrite is at the time of writing.
Phase 1 (repo surgery), Phase 2 (code review + audit + context refresh),
and Phase 2.5 (workspace-sibling refactor) are all complete. The CI
rewrite housekeeping item is also done (2026-05-20) — every repo now
has a working `.github/workflows/ci.yml` that builds on Linux/GCC
against the workspace-sibling layout. Phase 3 (finish the port) is the
next active work.

The original full plan, including the pre-execution research and rationale,
is at `C:\Users\lsl\.claude\plans\spicy-splashing-shamir.md` on this
machine. This file is the durable, in-project copy of the handover.

## What was done (2026-05-19)

**Phase 1 — repo surgery — COMPLETE.** All branches/URLs/archives are in
their final state on GitHub. The local working directory was renamed
`bootstrapper2\` → `bootstrapper\` on 2026-05-20.

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
  upstream. They are also applied directly to `~/Repositories/godot-
  cpp/` so the live build sees them. The `.local-patches/` directory
  is the **permanent re-apply source** if godot-cpp ever needs a
  clean reclone (new machine, accidental `git restore`, branch
  switch). Kept by design — see ROADMAP housekeeping for the
  rationale (web research found no better alternative for inspecting
  godot-cpp's opaque `TypedArray` contents from a breakpoint).
- **`submodules/snore_core/src/snore_core/test_snore_core_root_module.cpp`**
  — empty stub file, untracked. Left alone; either `git rm` or fill in.
- **Submodule-pointer drift inside `surf_scaf` and `squirrel_away`**
  working trees (the lowercase-m entries from `git status`). These are
  dev-branch in-flight state; left untouched.

## Phase 2 findings summary (2026-05-19)

**2.1 — GDExtension architecture review:** The static-link/chain-register
pattern is sound and matches the Godot-4 constraint. Three risks were
flagged and all three are now resolved: (a) double-registration if any
project loaded more than one of the four in-source `.gdextension`
manifests — fixed 2026-05-20 by deleting the three redundant manifests;
(b) googletest source inclusion was gated on `sc_tests` alone, so
release builds with tests on would ship gtest in the binary — fixed
during Phase 2.5; (c) bootstrapper rebuilt surf_scaf into its own bin/
rather than reusing — fixed 2026-05-20 by switching bootstrapper to
Option B (symlink the surf_scaf artifact instead of rebuilding it).

**2.2 — Port audit:** This is a restructure, not a 1:1 translation, so
the "diff godot3:foo vs master:foo" exercise wasn't useful. Coverage
matrix landed in CLAUDE.md ("Current port state"). Headline: scaffolder
has a narrow vertical slice (~12 C++ + ~23 .gd of the ~220 godot3 source
files); surfacer has the surface-graph foundation but lacks
edge/movement calculators and pathfinding; **squirrel_away is empty**
(no .gd, no .cpp in `src/` or `addon/src/`). snore_core is wholly new
and fairly thorough. surf_scaf is intentionally just a bundle shell.

**2.3 — Context refresh (this pass):** CLAUDE.md, HANDOVER.md, ROADMAP.md
all updated to reflect 2.1/2.2 findings. Workspace CLAUDE.md unchanged —
it already flags the WIP nature.

**Decisions resolved 2026-05-20:**

1. Are the missing scaffolder systems (annotators, color_config,
   level_button/select, accordions, radial_menus, notifications, camera +
   character framework, plugger) intentionally dropped or deferred?
   **Intentionally dropped** (working assumption). The current scaffolder
   surface is effectively final for the rewrite, modulo polish and bug
   fixes. CLAUDE.md "Current port state" table updated to reflect this.
   Phase 3 no longer carries scaffolder-porting work; it starts with
   squirrel_away game logic.
2. Is bootstrapper rebuilding surf_scaf intentional? **No** — switched
   to Option B (symlink). Bootstrapper's SConstruct does not compile
   anything; it just refreshes the demo's `addons/` tree, including a
   directory symlink `demo/addons/surf_scaf/bin/` → `../surf_scaf/addon/
   bin/`. surf_scaf's own SConstruct is the single source of the
   artifact.
3. Standalone-loadable `scaffolder.gdextension` (and surfacer / snore_core
   equivalents) — **deleted.** None of them were real use cases; surf_scaf
   is the only supported loading path.

## Phase 2.5 summary (2026-05-20)

**Workspace-sibling refactor — complete.** All six repos
(snore_core, scaffolder, surfacer, surf_scaf, squirrel_away, bootstrapper)
plus the third-party deps (godot, godot-cpp, googletest) now live as
siblings under `~/Repositories/`. Each repo's build scripts look for
`../<dep>/` instead of `submodules/<dep>/`. The nested submodule trees
are gone — `.gitmodules` is empty/absent in every framework repo.

What changed concretely:

- Each framework's `SConstruct` / `build_utils.py` now adds `..` to
  `sys.path` and imports `from <sibling>.build_utils import ...`.
- Path strings `submodules/<name>/src/` → `../<name>/src/`. Resolves
  correctly when SCons is invoked from any sibling's directory.
- Error messages on missing siblings name the expected path and point
  at `scripts/bootstrap-workspace.ps1`.
- snore_core's googletest source inclusion is now gated on
  `includes_dev AND includes_tests` (was just `includes_tests` — would
  have shipped gtest into release builds).
- `~/Repositories/godot-cpp/` switched from `master` to `4.4`, with the
  local `TypedArray<T>::debug()` patch + template-instantiations file
  re-applied.
- New: `scripts/bootstrap-workspace.ps1` on bootstrapper. Idempotently
  clones every required sibling next to the workspace root.
- Per-framework README appended with a "Building" section pointing at
  the bootstrap script.

Local cleanup that landed alongside:

- Removed the stray empty `bootstrapper/godot/`, `godot-cpp/`,
  `googletest/` top-level directories that had been sitting at the
  repo root (artifacts from a prior layout).

What still needs the user's attention (one-time):

1. **`.local-patches/` decision — RESOLVED 2026-05-20.** Keep the
   directory as permanent re-apply insurance for godot-cpp. The
   `TypedArray<T>::debug()` helper it documents has no good
   alternative for inspecting opaque godot-cpp containers at a
   breakpoint (researched 2026-05-20; Godot's `godot.natvis` doesn't
   cover godot-cpp's opaque-pointer wrappers, and the proposal to
   ship a godot-cpp natvis was closed not-planned). See ROADMAP
   housekeeping for the full rationale.
2. **Build verify on 2026-05-20 — PASS.** End-to-end build works under
   the post-Option-B flow:
   `cd ~/Repositories/surf_scaf && scons sc_dev=yes sc_tests=yes` builds
   `surf_scaf/addon/bin/windows/SurfScaf.windows.template_debug.x86_64.dll`,
   then `cd ~/Repositories/bootstrapper && scons` refreshes
   `demo/addons/surf_scaf/bin/` as a directory symlink to the surf_scaf
   artifact. First pass exposed a pre-existing compile error
   (`std::unordered_map<StringName, ...>` couldn't instantiate because
   godot-cpp 4.4 dropped its internal `std::unordered_map` use and so
   no longer transitively provides a `std::hash<godot::StringName>`).
   Resolved by adding `snore_core/internal/std_hash.h` with a
   `std::hash<godot::StringName>` specialization that calls
   `StringName::hash()`, and including it from the six affected
   headers in snore_core (4) and scaffolder (2). Superseded
   2026-05-20: the six sites were converted to `godot::HashMap` and
   `std_hash.h` was deleted.
3. **Rename the local dir** `bootstrapper2/` → `bootstrapper/` — DONE
   2026-05-20.

### Housekeeping completed during 2026-05-20

In the same session, four items from the ROADMAP housekeeping list
landed:

- Deleted the three redundant `.gdextension` manifests
  (snore_core, scaffolder, surfacer) plus their `.uid` companions.
  Per-framework READMEs now document `surf_scaf` as the supported
  loading path.
- Fixed the broken `[icons]` block in `surf_scaf.gdextension` (and the
  separate-but-identical copy in `squirrel_away/addon/bin/`). The stale
  `GDExample = ".../surf_scaf2/.../SurfScafNode.svg"` placeholder is
  gone; the block is now a comment noting that no icons exist yet.
- Updated the gdext#615 comments in each framework's
  `register_gdextension_types.cpp` to also cite
  `godot-proposals#13997` (the engine proposal; gdext#615 is the
  rust-bindings tracker).
- Confirmed gtest gating fix from Phase 2.5 (`includes_dev AND
  includes_tests`) is reflected in the ROADMAP checkbox.

## Known followups

Forward-looking work — Phase 2.5 (workspace siblings), Phase 3 (port +
framework work), Phase 4 (dynamic surfacer pathfinding), and housekeeping —
is tracked in [ROADMAP.md](ROADMAP.md).

Top items at the time of writing:

1. **Phase 3 — finish the port.** Priority order per user direction
   2026-05-20: finish every *other* port and complete the cleanup /
   polishing of all known framework bits **before** porting any
   additional surfacer logic. The missing scaffolder systems were
   resolved as intentionally dropped (see decisions above), so the
   remaining Phase 3 work is: squirrel_away game logic (currently
   empty), framework setup improvements, and any open port-bug
   followups from Phase 2.2. Surfacer's remaining GDScript → C++ port
   is the last step.
2. Delete `C:\tmp\sc-backup\*.git` mirrors after ~2026-06-19 (one
   month after the Phase 1 surgery completion).
3. ~~Eventually swap `std::unordered_map<StringName, ...>` for
   `godot::HashMap` and drop `snore_core/internal/std_hash.h`.~~
   **Done 2026-05-20.** Six call sites converted to `godot::HashMap`
   and the `std_hash.h` workaround deleted. End-to-end surf_scaf build
   verified.

## Quick-start for the next session

```pwsh
cd C:\Users\lsl\Repositories\bootstrapper
git status --short                            # expect: clean
git remote -v                                 # expect: origin=bootstrapper.git
ls ..                                          # expect siblings: snore_core,
                                               # scaffolder, surfacer,
                                               # surf_scaf, squirrel_away,
                                               # godot-cpp, godot, googletest
# Build the bundle in surf_scaf (this compiles all framework sources):
cd ..\surf_scaf
scons sc_dev=yes sc_tests=yes
# Refresh bootstrapper's demo symlinks (no compile, just symlinks):
cd ..\bootstrapper
scons
```

Then jump to Phase 3 (port + framework work) in ROADMAP.md.

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
