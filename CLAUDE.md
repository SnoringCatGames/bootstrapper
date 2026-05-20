# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this
repository or its sibling SnoringCat framework repos.

For the most recent operational status of the rewrite, see
[HANDOVER.md](HANDOVER.md). For the forward plan, see
[ROADMAP.md](ROADMAP.md). This file describes longer-lived
conventions; the other two cover what just happened and what's next.

## Project overview

`bootstrapper` is the umbrella + example template for the SnoringCat
Godot 4 framework rewrite. The rewrite migrates an older Godot 3
GDScript codebase to Godot 4 with performance-critical logic moved
into C++ via GDExtension. **The rewrite is a work in progress** and
the `main`/`master` branches across the ecosystem are intentionally
minimal during this period — actual code lives on `dev`.

Long-term, `bootstrapper` is the starter repo to copy-paste-and-edit
when starting a new Godot 4 game that uses these frameworks.

## Repo ecosystem

| Repo | Role | Default branch |
|---|---|---|
| [snore_core](https://github.com/SnoringCatGames/snore_core) | Foundational C++ library (services, geometry, log, time). | main |
| [scaffolder](https://github.com/SnoringCatGames/scaffolder) | General-purpose game framework (screens, app lifecycle, settings, save data). | master |
| [surfacer](https://github.com/SnoringCatGames/surfacer) | 2D platformer character + pathfinding framework. | master |
| [surf_scaf](https://github.com/SnoringCatGames/surf_scaf) | Combined-bundle GDExtension (Godot 4 workaround — see note below). | main |
| [squirrel_away](https://github.com/SnoringCatGames/squirrel_away) | Example 2D platformer game built on the frameworks. | master |
| `bootstrapper` (this repo) | Umbrella + template. | main |

Build-time dependency graph:

```
snore_core   ──┬─→ scaffolder ──┐
               ├─→ surfacer  ───┼─→ surf_scaf ──→ squirrel_away
               └────────────────┘                 (GDScript only)
                          ↓
                      bootstrapper (umbrella; loads surf_scaf only)
```

### Why `surf_scaf` exists

Godot 4 currently does not support one GDExtension depending on
another GDExtension's classes — the engine literally errors with
`"Unimplemented yet"` when a child extension's class inherits from
a parent extension's class. Tracked in
[gdext#615](https://github.com/godot-rust/gdext/issues/615) and
[godot-proposals#13997](https://github.com/godotengine/godot-proposals/issues/13997)
(both open as of 2026-05). The workaround: bundle all interdependent
extensions into one binary. `surf_scaf` IS that binary — it compiles
snore_core + scaffolder + surfacer + its own code into a single
`.so/.dll` and registers all the classes from one entry point. The
bootstrapper demo loads only `surf_scaf.gdextension`; the individual
`.gdextension` files exist in source for standalone use cases but
aren't loaded.

Real-world peers using the same bundling pattern: Kehom/GDExtensionPack,
LimboAI, godot-jolt.

## Branch model

| Branch | Purpose |
|---|---|
| `main` / `master` (default) | Intentionally minimal during the rewrite — README only, plus HANDOVER+ROADMAP on bootstrapper. |
| `dev` | Active rewrite work — full source tree. **Active work happens here.** |
| `godot3` (scaffolder, surfacer, squirrel_away only) | Preserved pre-rewrite Godot 3 GDScript content. |
| `asset-lib-v0.7.0` (scaffolder, surfacer only) | Pinned reference for the Godot Asset Library entry. |

When the rewrite stabilizes, expect `dev` to merge into the default
branch and the "minimal default" period to end. This is meaningful
for any future task that touches workflows, automation, or
docs — the default-branch view will fill in over time.

## Build system

- **SCons** is the build tool. Each framework has its own `SConstruct`
  that invokes shared helpers in `submodules/snore_core/build_utils.py`.
- Build flags: `sc_dev`, `sc_tests`, `sc_ci`, `sc_zip`. `sc_tests=yes`
  defines `SC_TESTS_ENABLED` and pulls in googletest.
- **Static linking** is the model — each downstream framework compiles
  its upstream sources into its own binary (so `scaffolder.so` contains
  snore_core's compiled code, etc.). No runtime cross-extension DLL
  deps.
- Bootstrapper's `demo/` project loads only `surf_scaf.gdextension`.

## Repository layout (current)

Currently each framework has its upstreams + godot-cpp + godot +
googletest as nested git submodules. This means snore_core, godot-cpp,
godot, and googletest each get cloned multiple times across the tree.
**This is on the roadmap to change** — see ROADMAP Phase 2.5
(workspace-level siblings). Until then, expect deep nesting and
duplication.

## GitHub Actions

Workflows live in each repo's `.github/workflows/` on `dev` (and
historically on the default branch — they've been removed from the
slim default branches during the rewrite). Several are known to fail
right now (Godot 3 era assumptions, references to the archived
`*2`-suffixed URLs, etc.). The audit + fix is on the roadmap.
**Don't be alarmed by red CI** during the rewrite.

## Commit / push conventions

- **Default branch is slim. Work goes on `dev`.** Land active changes
  on `dev`; rebase or fast-forward as needed.
- **Land on default (`main`/`master`) only the artifacts that should
  be visible to drive-by visitors** — README, HANDOVER, ROADMAP, doc
  files. Use `git cherry-pick <sha>` from dev to keep histories
  separate.
- **Submodule bumps in bootstrapper** follow upstream pushes (per the
  workspace-level Repositories CLAUDE.md). This will go away once
  Phase 2.5 of ROADMAP ships.
- **Force-push** to any branch needs explicit user confirmation. The
  default branch in particular is public-facing for scaffolder /
  surfacer / squirrel_away.
- **`git submodule sync --recursive`** has been observed to silently
  fail to propagate URL changes in this repo's specific layout (see
  HANDOVER.md decision #2). When changing submodule URLs, also
  manually run `git -C submodules/<x> remote set-url origin <new>`
  on each affected nested clone.

## Project goals (north stars)

1. Godot 3 → Godot 4 across all SnoringCat game projects.
2. Move performance-critical logic from GDScript into C++ via GDExtension.
3. Restructure the app/framework setup (per-project layout,
   init/teardown, service wiring, settings/save plumbing).
4. Add a dynamic-pathfinding mode to surfacer (no preparse of static
   level into platform graph).

## See also

- [HANDOVER.md](HANDOVER.md) — recent surgery status, decisions
  made during execution, rollback paths, stray local state.
- [ROADMAP.md](ROADMAP.md) — forward plan organized by phases:
  current code review (2.1, 2.2), workspace-sibling refactor (2.5),
  port finish (3), new features (4), housekeeping.
- Workspace-level guidance: `~/Repositories/CLAUDE.md`.
- User-level guidance: `~/.claude/CLAUDE.md`.
