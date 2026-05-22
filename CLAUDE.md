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

### Double-registration risk (mitigated 2026-05-20 + hardened 2026-05-21)

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

Each module's `register_gdextension_types` also carries two layered
guards (added 2026-05-21):

1. An `are_types_registered` static flag for the intra-DLL re-entry
   case (e.g., bundled chained registration calling the same registrar
   twice).
2. A `ClassDB::class_exists("RootClass")` check for the cross-DLL
   case (another loaded extension already registered the same classes).
   If true, we log a `WARN_PRINT` naming the root class and bail out of
   the whole registration block — much friendlier than the cryptic
   per-class `ClassDB::register_class` failures we'd otherwise hit.

Both guards are defensive: the supported configuration is one
`surf_scaf.gdextension`, and the cross-DLL path shouldn't fire in
practice. If a future contributor accidentally re-introduces a
standalone manifest, the warning surfaces the mistake clearly.

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

## Consuming the framework (game-project boilerplate)

A new game project consumes the framework as a workspace sibling
(no submodules) and loads `surf_scaf.gdextension` directly. The
`surf_scaf/demo/` directory in this repo is the canonical reference.
Minimum boilerplate:

**`project.godot`** — declare two autoloads + the single extension:

```ini
[autoload]
S="*res://addons/scaffolder/src/core/s.gd"       ; framework-side
G="*res://src/<your_game>_globals.gd"            ; game-side

[native_extensions]
paths=["res://addons/surf_scaf/bin/surf_scaf.gdextension"]
```

**One `.tres` per module's settings.** Each derives from a C++
`*Settings` class — `SnoreCoreMainSettings`, `ScaffolderSettings`,
`SurfacerSettings`. Define one per game (in `demo/src/*.tres` for
reference). Required because the framework's `set_up()` takes the
full set and dispatches each one to its module by class name.

**`main.gd` skeleton** (one Node `_ready` does the wiring):

```gdscript
class_name DemoMain
extends Node

@export var snore_core_settings: SnoreCoreMainSettings
@export var scaffolder_settings: ScaffolderSettings
@export var surfacer_settings: SurfacerSettings


func _ready() -> void:
    G.snore_core = SnoreCore.get_module("SnoreCore")
    G.scaffolder = SnoreCore.get_module("Scaffolder")
    G.surfacer = SnoreCore.get_module("Surfacer")
    G.snore_core.connect(
            "all_modules_set_up_finished",
            _on_set_up_finished)
    SnoreCore.set_up([
        snore_core_settings,
        scaffolder_settings,
        surfacer_settings,
    ])


func _on_set_up_finished() -> void:
    G.snore_core_settings = G.snore_core.get_settings()
    G.scaffolder_settings = G.scaffolder.get_settings()
    G.surfacer_settings = G.surfacer.get_settings()
    # Framework is ready; do game-specific setup here.
```

**Notes on the contract.**

- `SnoreCore.set_up([...])` is fire-and-go. The framework wires
  modules in dependency order and emits
  `all_modules_set_up_finished` when all submodules' `set_up()`
  callbacks have completed. Game code should connect to that
  signal rather than assuming completion right after the
  `set_up()` call returns.
- `SnoreCore.get_module("Name")` returns the live module
  singleton; safe to cache in `G.<name>` as shown above.
- The `S` autoload (scaffolder's `s.gd`) is currently a thin
  shim. The "implement manifests" FIXME at `surf_scaf/demo/src/main.gd:5`
  tracks consolidating the multi-`.tres` setup into a single
  manifest resource — deferred until a real game (squirrel_away)
  surfaces concrete needs.

## GitHub Actions

Each of the six SnoringCat repos has a single `.github/workflows/ci.yml`
(rewritten 2026-05-20; see ROADMAP housekeeping). The workflow:

- Triggers (cost-conscious set, mirrors hopnbop_private's pattern):
  daily at 04:00 UTC via `schedule`; on `push` and `pull_request` to
  the slim default branches (`main` / `master`); plus
  `workflow_dispatch` for manual runs. **Pushes to `dev` do NOT
  trigger CI** — these repos are public so Actions minutes are
  free, but per-push noise during active porting still isn't
  worth the run-result churn. The nightly cron catches breakage
  that landed on `dev`; manual `gh workflow run ci.yml --ref dev`
  validates `dev` on demand.
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

All 6 SnoringCat framework repos are public, so cross-checkout
uses the default `actions/checkout@v4` token (the per-workflow
`GITHUB_TOKEN`); no PAT is required. (Brief history: a
`PRIVATECHECKOUTACCESSTOKEN` PAT was used while snore_core /
surf_scaf / bootstrapper were private. A 2026-05-21 org-secret
migration ran into the GitHub Free plan limitation that org
secrets don't resolve in private repos, after which the three
private repos were flipped to public — eliminating the need for
the PAT entirely.)

CI runs the gtest suite via the surf_scaf demo. Pattern:
`--headless --editor --quit` warm pass (retried up to 3x because
the extension's first-load init occasionally SEGVs cold), then
`--headless --quit-after 60 --path ./demo`. The `--quit-after 60`
is essential because main.gd defers `SnoreCore.run_tests()` to
the next frame (so Tween fixtures can mutate the scene tree).
We grep stdout for `ALL TESTS PASSED`; Godot's exit code is
unreliable because non-fatal warnings flip it.

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
