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

## Current port state (snapshot, 2026-05-19)

The rewrite is at "vertical slice partly landed" stage, not "code parity
with Godot 3 minus polish." Phase 2 audit findings:

| Repo | What's there | What's missing |
|---|---|---|
| `snore_core` | ~30 prod + ~30 test classes. Services (annotations, canvas_layer, log, time), time helpers (debouncer/interval/stopwatch/throttler/timeout/tween/time_tracker), geometry, circular_buffer, module framework. | Nothing — new repo, no godot3 baseline to port from. |
| `scaffolder` | 12 C++ prod + 23 GDScript shim files. Module/shell/settings/level/game_session/audio_service/in_game_settings, screen system, 6 screens + ~9 widgets. | **Most of the godot3 ~220-file surface area**: annotator framework, color_config, level_button/level_select, accordions, radial_menus, notifications, info_panel, camera framework, character framework, plugger asset editor, half of utils. **Intentionally dropped 2026-05-20** (working assumption). The current scaffolder surface is effectively final for the rewrite, modulo polish and bug fixes. |
| `surfacer` | ~25 prod classes. Surface graph foundations (surface/chunk/finder/parser/store/graph, tile_map_surface_parser), agent layer, annotations, movement_profile/settings. | Edge/movement calculators (jump, walk, climb, fall trajectories), platform-graph builder, pathfinding A*/edge-cost layer. ROADMAP Phase 3 acknowledges this as the biggest remaining lift. |
| `surf_scaf` | 1 file — just the bundle entry point. | Nothing of its own; it's intentionally a shell. |
| `squirrel_away` | **Empty.** Top-level scaffolding exists but `src/` and `addon/src/` have no `.gd` or `.cpp` files. | The entire godot3 game (cat, squirrel, levels, tilemaps, configs) hasn't been re-introduced yet. No dogfood-able example game today. |

If a future task asks "how do I use feature X from the framework", first
check whether X is actually implemented yet. The godot3 branches on
scaffolder/surfacer/squirrel_away preserve the reference impl.

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
  that invokes shared helpers in `snore_core/build_utils.py` (a
  workspace sibling, post-Phase 2.5).
- Build flags: `sc_dev`, `sc_tests`, `sc_ci`, `sc_zip`. `sc_tests=yes`
  defines `SC_TESTS_ENABLED` and pulls in googletest sources.
- **Static linking** is the model — each downstream framework compiles
  its upstream sources into its own binary (so `scaffolder.so` contains
  snore_core's compiled code, etc.). No runtime cross-extension DLL
  deps.
- Bootstrapper's `demo/` project loads only `surf_scaf.gdextension`,
  and bootstrapper's `SConstruct` does **not** compile anything — it
  just refreshes the demo's `addons/` tree with symlinks: per-framework
  GDScript symlinks into each `addon/`, plus a single directory symlink
  for `demo/addons/surf_scaf/bin/` → `../surf_scaf/addon/bin/`. The
  shared library is built by surf_scaf's own SConstruct. Workflow:

  ```
  cd ~/Repositories/surf_scaf && scons sc_dev=yes sc_tests=yes
  cd ~/Repositories/bootstrapper && scons   # refresh symlinks
  ```

  Once the symlinks are in place, future surf_scaf rebuilds are
  visible through the symlink without re-running bootstrapper's scons.

### Double-registration risk (mitigated 2026-05-20)

Originally the framework carried four `.gdextension` manifests in source
— `snore_core.gdextension`, `scaffolder.gdextension`,
`surfacer.gdextension`, `surf_scaf.gdextension`. Only
`surf_scaf.gdextension` is loaded by the demo, and that is the supported
configuration. If a downstream project loaded two of these at once, both
entry points would call their statically-linked copy of
`SnoreCore::register_gdextension_types`, and Godot's
`ClassDB::register_class<>` would abort on the duplicate.

The three standalone manifests (snore_core / scaffolder / surfacer) were
deleted on 2026-05-20 to close this hole; each framework's README now
documents `surf_scaf` as the supported loading path. The only manifest
shipped is `surf_scaf/addon/bin/surf_scaf.gdextension`.

### Test source wiring (fixed 2026-05-20)

`set_up()` in `snore_core/build_utils.py` gates googletest source
inclusion on `env["includes_dev"] AND env["includes_tests"]`. Earlier
the gate was `includes_tests` alone, which would have shipped gtest
source into a release-mode artifact via `sc_tests=yes sc_dev=no`.
Fixed during the Phase 2.5 workspace-sibling refactor; if you ever
loosen this gate again, prefer keeping the AND.

## Repository layout

**Workspace-sibling layout** (since 2026-05-20, ROADMAP Phase 2.5 done):

```
~/Repositories/
├── bootstrapper/   (this repo — umbrella + demo)
├── snore_core/
├── scaffolder/
├── surfacer/
├── surf_scaf/
├── squirrel_away/
├── godot-cpp/      (4.4 branch, with local TypedArray::debug patch)
├── godot/          (master, kept for the user's own custom-build work)
└── googletest/
```

Each repo's build scripts look for `../<dep>/` relative to wherever
SCons is invoked. `.gitmodules` is empty/absent in every framework
repo. Cross-framework edits happen inline at the workspace level — no
SHA bumping, no submodule pointer maintenance.

**Fresh-machine setup:** clone bootstrapper, run
`scripts/bootstrap-workspace.ps1`. The script idempotently clones every
required sibling next to the workspace root.

**Historical note:** until Phase 2.5 landed, each framework had its
upstreams + godot-cpp + godot + googletest as nested git submodules.
This produced multi-GB redundant clones (5+ copies of godot-cpp/godot
across the tree) and forced N× SHA bumping. The flat sibling layout
replaces that.

## GitHub Actions

Each of the six SnoringCat repos has a single `.github/workflows/ci.yml`
(rewritten 2026-05-20; see ROADMAP housekeeping). The workflow:

- Triggers on `push` / `pull_request` to `dev` / `main` / `master`,
  plus `workflow_dispatch` for manual runs.
- Runs on `ubuntu-latest`. Single platform / arch / target for now
  (Linux x86_64 debug). The multi-platform matrix is deliberately
  not part of the rewrite — add back selectively when there's a real
  consumer.
- Reconstructs the workspace-sibling layout in the runner by
  checking out each required sibling into the workspace root (the
  current repo at `<this>/`, frameworks at `<sibling>/`, godot-cpp
  at `godot-cpp/`, googletest at `googletest/`). Each framework's
  build_utils.py expects `../<dep>/` paths; this layout makes them
  resolve.
- Builds via `scons sc_ci=yes sc_dev=yes sc_tests=yes`. The
  `sc_ci=yes` flag is essential — `debug_utils.h`'s `DEBUG_BREAK`
  macro otherwise expands to `__builtin_debugtrap`, which is
  Clang/MSVC-only (the runner uses GCC).

Private-repo cross-checkout uses the per-repo
`PRIVATECHECKOUTACCESSTOKEN` secret (a fine-grained PAT with
read-only Contents access to the 4 private SnoringCat repos:
snore_core, surf_scaf, squirrel_away, bootstrapper). The PAT is
set independently on each repo that needs it — there's no
org-level secret today. **Rotating the PAT is a per-repo
operation**, so prefer creating one token with access to all
4 repos and setting it on each. A followup in ROADMAP tracks
migrating to an org-level secret.

The workflow does NOT run tests (the gtest suite lives in the demo
project and needs a Godot binary). Build-only CI catches
compilation regressions, which is what most matters during the
rewrite. The "add real test running" followup is in ROADMAP.

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
