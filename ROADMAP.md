# Roadmap

Forward-looking plan for the SnoringCat Godot rewrite (`bootstrapper` and
its submodules). For "what just happened / how to resume", see
[HANDOVER.md](HANDOVER.md).

## Project goals (north stars)

1. **Godot 3 → Godot 4** across all SnoringCat game projects.
2. **Move performance-critical logic from GDScript into C++ via GDExtension.**
   Build system is SCons, with each submodule producing its own
   `.gdextension` and downstream extensions chain-registering upstreams.
3. **Restructure the app/framework setup** (per-project layout, init/teardown,
   service wiring, settings/save plumbing).
4. **Add a dynamic-pathfinding mode to surfacer** that supports dynamically-
   constructed levels without preparsing a static level into a platform
   graph.

## Now (Phase 3 — finish the port, ship the framework)

Phase 2 (assess) **complete as of 2026-05-19**. Phase 2.5 (workspace-
sibling refactor) **complete as of 2026-05-20**. Findings + decisions
landed in HANDOVER.md ("Phase 2 findings summary", "Phase 2.5 summary")
and CLAUDE.md ("Current port state" + build-system caveats).

The next active phase is Phase 3 (see below).

## Phase 2 (assess the current state — DONE 2026-05-19)

Original phase intent: code review of what landed during the WIP
porting before the long pause. No new code; findings + coverage matrix.

### 2.1 — GDExtension cross-dep architecture review

Read in this order and take notes inline:

- [ ] `SConstruct` — umbrella build orchestration.
- [ ] `submodules/snore_core/build_utils.py` — shared SCons helper (defines
  `pre_setup`, `post_setup`, `set_up`, `create_submodule_addons_symlinks`,
  the `sc_tests`/`sc_dev`/`sc_ci`/`sc_zip` flags, `is_setup_for_self`).
- [ ] Each submodule's `SConstruct` + `build_utils.py` (snore_core,
  scaffolder, surfacer, surf_scaf).
- [ ] Each submodule's `src/register_gdextension_types.cpp` (registration
  chain; references godot-rust/gdext#615).
- [ ] Each `addon/bin/<name>.gdextension` manifest.
- [ ] `submodules/snore_core/src/snore_core/snore_core_submodule.h` +
  `snore_core_root_module.h` + `snore_core_main_module.h` (the "submodule"
  abstraction inside each extension).
- [ ] `build_utils.py::create_symlink_for_surf_scaf_extension_manifest`
  (demo-time wiring).

What to flag:

- [ ] Is `register_gdextension_types` idempotent? Bootstrapper → surf_scaf
  (which already registers snore_core + scaffolder + surfacer) vs any
  direct-to-scaffolder path could double-register.
- [ ] Symbol visibility: confirm `GDE_EXPORT` is only on the per-extension
  entry symbol, not inner-lib `register_gdextension_types` (they're
  statically linked into each `.so/.dll`, not exported across boundaries).
- [ ] SCons globbing duplication: does `set_up(..., is_setup_for_self=False)`
  ever cause two consumers to glob the same upstream `src/**/*.cpp`? Single-
  binary-per-consumer sidesteps this today but it's fragile.
- [ ] Test wiring: `sc_tests=yes` defines `SC_TESTS_ENABLED` and pulls in
  googletest. Verify tests link only into dev builds, not shipped libs.

External research targets:

- [ ] `godot-cpp` docs on `entry_symbol` and multi-extension projects.
- [ ] godot-rust/gdext#615 — cross-extension symbol exports in 4.x current
  status.
- [ ] Search: "godot 4 multiple gdextension shared types",
  "godot-cpp register_class deduplication".
- [ ] Diff against `godot-cpp-template` (already cloned at
  `C:\Users\lsl\Repositories\godot-cpp-template`).
- [ ] SCons multi-target builds for shared dep trees (`VariantDir`,
  `Repository`).

Deliverable: architectural notes + concrete recommendations.

### 2.2 — Old vs new port audit

Skip deep surfacer review (lots still to port). Focus on scaffolder,
snore_core, squirrel_away.

Strategy:

- [ ] Side-by-side clone the freshly-created `godot3` branches to a
  separate dir tree (e.g. `C:\tmp\godot3\<repo>`) for easy `diff`.
- [ ] For `scaffolder`: enumerate every class file under old
  `addon/src/`/`src/` (GDScript), then locate the counterpart in new
  `submodules/scaffolder/src/scaffolder/*.{cpp,h}` (C++) or
  `submodules/scaffolder/addon/**/*.gd` (GDScript shim). Build coverage
  matrix: `class_name | godot3_path | godot4_cpp_path | godot4_gd_path |
  status`. Status ∈ {ported, partial, missing, GDScript-stayed}.
- [ ] For each "partial"/"ported" row: `git diff godot3:<file>
  master:<counterpart>` for changed defaults, removed signals, renamed
  methods, missing edge cases.
- [ ] For `snore_core`: same matrix. Highest porting-bug risk; most
  thoroughly ported. Focus: `geometry.cpp`, `annotations_service.cpp`,
  `log_service.cpp`, `circular_buffer.cpp`, `canvas_layer_service.cpp`
  (each has `test_*.h` — tests are the spec).
- [ ] For `squirrel_away`: stays GDScript. Question is "does the new
  GDScript still match the old gameplay semantics given that
  snore_core/scaffolder/surfacer signatures changed?" Read each
  `submodules/squirrel_away/addon/src/*.gd`, diff against old, verify
  each cross-call into now-C++ APIs.
- [ ] `surfacer`: skim only; note obvious gaps without deep-diving.

Deliverable:

1. Architectural notes from 2.1.
2. Coverage matrices per repo.
3. Porting-bug log (per-class, with old vs new line refs).
4. "Stayed in GDScript" list with rationale.

### 2.3 — Architecture audit + persistent-context refresh

After 2.1 and 2.2 produce their findings, do one pass that synthesizes
them into the persistent context Claude Code reads on every future
session. The goal: anyone (or any future-Claude) starting work on this
ecosystem reads the right docs and gets the current mental model
without needing to re-derive it.

Tasks:

- [ ] Take the 2.1 + 2.2 findings and update the
  authoritative project doc — `bootstrapper/CLAUDE.md` — to reflect
  any architectural truths that surfaced (e.g., changes in the
  dependency graph, build-system patterns, gotchas).
- [ ] Update HANDOVER.md if any of the "Known followups" or
  "Decisions made during execution" sections turn out to be wrong
  or outdated.
- [ ] Update the workspace-level guide (`~/Repositories/CLAUDE.md`,
  symlink-tracked into claude-config) if the entry there needs more
  detail or any of the assertions need correction.
- [ ] Decide whether any reusable behavior belongs as a custom
  skill under `~/Repositories/claude-config/skills/<name>/` (e.g., a
  "bump-framework-submodule" helper analogous to
  `bump-platform-submodule` for hopnbop). Land it if so.
- [ ] Once the workspace-sibling refactor (2.5) lands, all of the
  above need another pass — the architecture changes meaningfully
  enough to invalidate prior docs.

Deliverable: a one-screen summary in the response (and in HANDOVER)
of what changed, what's now wrong in old docs, what was fixed up.

## Phase 2.5 — Architectural restructure: workspace-level siblings (DONE 2026-05-20)

**Status: complete.** All six SnoringCat repos + the third-party deps
(godot, godot-cpp, googletest) now live as workspace siblings under
`~/Repositories/`. Each framework's `SConstruct` + `build_utils.py`
references `../<dep>/` instead of `submodules/<dep>/`. `.gitmodules`
is empty/absent in every framework repo. New
`scripts/bootstrap-workspace.ps1` on bootstrapper clones every required
sibling idempotently. See HANDOVER.md "Phase 2.5 summary" for details.

The remainder of this section is the original rationale, kept for
traceability.

Currently each framework (snore_core, scaffolder, surfacer, surf_scaf,
squirrel_away) has its upstreams AND godot-cpp + godot + googletest as
nested git submodules. Inside bootstrapper, that means godot-cpp, godot,
and googletest each get cloned ~5–8 times (once per framework). Add
duplication of snore_core / scaffolder / surfacer inside their downstream
frameworks. And every new game made from bootstrapper repeats the same
mass duplication. The cost is enormous: deep nesting, painful atomic
cross-repo edits, multi-GB redundant clones (godot engine source is
huge), N× SHA bumping when anything moves.

**Recommended layout: workspace-level siblings for everything.**

```
~/Repositories/
├── snore_core/      (cloned once)
├── scaffolder/      (cloned once)
├── surfacer/        (cloned once)
├── surf_scaf/       (cloned once)
├── squirrel_away/   (cloned once)
├── godot-cpp/       (cloned once)
├── godot/           (cloned once — kept; the user has a reason)
├── googletest/      (cloned once)
├── bootstrapper/    (cloned once — example/template, no submodules)
├── game1/           (a real game — no submodules)
└── game2/           (another game — no submodules)
```

One copy of each dependency per machine. Each framework + game asserts
the expected siblings exist at build time. Edits to a framework are
seen by every downstream game on next build, no SHA bumps. New-machine
setup is a small bootstrap script that clones each sibling.

This is the standard layout for solo C++ devs with multiple projects
sharing the same in-house frameworks. The cost — losing pinned per-game
SHAs — doesn't matter here because the user isn't shipping versioned
framework releases.

### Background — why surf_scaf must remain a bundled extension

Researched 2026-05-19, confirmed against current Godot 4 master.

- Godot 4 cannot let one GDExtension depend on another GDExtension's
  classes. The engine prints `ERR_PRINT("Unimplemented yet")` in
  `core/extension/gdextension.cpp::_register_extension_class_internal()`
  when a child class's parent resolves to another extension.
- `gdext#615` and `godot-proposals#13997` are both still **open** with
  no shipped resolution; resolution depends on multi-quarter Godot-core
  work tied to the C#-on-GDExtension migration.
- `submodules/surf_scaf/README.md` already documents the rationale.
- Real-world peers (Kehom/GDExtensionPack, LimboAI, godot-jolt) all use
  the single-bundled-extension pattern.

Don't try to "un-bundle" surf_scaf. The architectural concern here is
purely the build-system / git-layout layer underneath, not the GDExtension
boundary.

### Tasks

- [ ] Audit references to nested submodule paths across the
  ecosystem. Grep each framework for `submodules/snore_core`,
  `submodules/scaffolder`, `submodules/surfacer`, `submodules/godot-cpp`,
  `submodules/godot`, `submodules/googletest` in `SConstruct`,
  `build_utils.py`, `.gdextension` manifests, asset paths.
- [ ] Update each framework's `SConstruct` / `build_utils.py` to look
  for `../<dep>/` instead of `submodules/<dep>/`.
- [ ] Add build-time assertions: clear error messages naming each
  expected sibling path and how to clone it.
- [ ] Remove all `[submodule "..."]` entries from each framework's
  `.gitmodules`. After this, each framework's `.gitmodules` is either
  empty or doesn't exist.
- [ ] Add a `scripts/bootstrap-workspace.ps1` (probably owned by
  bootstrapper) that clones every required sibling next to the current
  dir if it's not already present. Idempotent. Invoked once per new
  developer machine.
- [ ] Update each framework's README to document the workspace-sibling
  layout (point at bootstrapper's bootstrap script).
- [ ] Verify build still works end-to-end from inside bootstrapper.
- [ ] Update bootstrapper's HANDOVER.md once the layout change ships.

### Notes

- **`godot` submodule stays** — user has a reason to keep full Godot
  engine source (custom editor builds, templates, etc.). It joins the
  workspace-sibling pool like the others.
- **Why not monorepo?** scaffolder + surfacer are public with godot-3-era
  Godot Asset Library entries (asset-lib-v0.7.0 branch preserved on each).
  snore_core / surf_scaf / squirrel_away / bootstrapper are private. Mixed
  visibility blocks monorepo.
- **What bootstrapper becomes:** small example/template repo. Holds
  the bootstrap script, the demo project, and maybe a top-level
  `SConstruct` that wraps building all frameworks. No submodules.
- **What new games become:** small repos with their own game code +
  the same expectation that frameworks live as workspace siblings. Made
  by copy-pasting bootstrapper.
- **Workflow:** cd into any repo at workspace root, single editor window
  opens the whole tree (or open the parent dir). Cross-framework edits
  happen inline. Commits go to each repo independently. Bootstrapper
  doesn't need bump-pointer commits any more.
- **New-machine setup:** clone bootstrapper, run
  `scripts/bootstrap-workspace.ps1`. Script clones every sibling repo
  (snore_core, scaffolder, surfacer, surf_scaf, squirrel_away,
  godot-cpp, godot, googletest) at the workspace level.
- **Existing-machine migration:** the SnoringCat sibling repos already
  exist at `~/Repositories/` for the swapped ones (scaffolder, surfacer,
  squirrel_away) — they were re-created by the Phase 1 surgery. The
  new-only ones (snore_core, surf_scaf) and the third-party deps
  (godot-cpp, godot, googletest) need to be cloned out from their
  current nested locations into workspace siblings before doing the
  build-system rewrite.

## Next (Phase 3 — finish the port, ship the framework)

**Priority direction (set 2026-05-20):** finish every *other* port and
all cleanup / polishing of the known framework bits **before** taking
on any additional surfacer porting work. Surfacer is the biggest
remaining lift; it lands last.

**Scope decision (2026-05-20):** the missing scaffolder systems
(annotators, color_config, level_button/select, accordions,
radial_menus, notifications, camera + character framework, plugger)
are **intentionally dropped** as a working assumption. The current
scaffolder surface is effectively final for the rewrite, modulo
polish and bug fixes. Revisit if a squirrel_away port reveals a
genuine missing dependency.

- [ ] Build out squirrel_away game logic. Currently empty (no .gd or
  .cpp in `src/` or `addon/src/` on dev). Re-port from the godot3
  branch, adapted to the new framework signatures. **This is the
  first Phase 3 task.**
- [ ] App/framework setup improvements. Specifics TBD; revisit after
  the squirrel_away porting pass makes the current state legible.
- [ ] Land any port bugs surfaced during the above work (functional
  diffs vs the godot3 branch).
- [ ] Resolve architectural recommendations from Phase 2.1 (e.g.,
  registration idempotency guard if needed) inline with the work
  above.
- [ ] **Then, finally:** finish surfacer GDScript → C++ port. The
  surface-graph foundation is in place; edge/movement calculators
  and pathfinding are not. Note: if a squirrel_away port surfaces a
  genuine dependency on a dropped scaffolder system (e.g., the camera
  framework), revisit the drop decision before continuing surfacer
  work.

## Later (Phase 4 — new features)

- [ ] **Dynamic-pathfinding mode in surfacer**. Pathfinding that works on
  dynamically-built levels without preparsing the level into a static
  platform graph. Design spike + prototype + integration. This is the
  one feature the user explicitly called out as a motivation for the
  rewrite.

## Housekeeping (do whenever it fits)

Items in **bold** below were surfaced by the Phase 2.1 architecture review.

- [x] **Switch `std::unordered_map<StringName, ...>` to `godot::HashMap`**
  across the framework. Done 2026-05-20. Six sites converted
  (`canvas_layer_service`, `snore_core_main_module`,
  `snore_core_root_module`, `time/stopwatch` in snore_core;
  `screen_service`, `audio_service` in scaffolder). Iteration sites
  updated from `std::pair<const K, V>` to `KeyValue<K, V>` (with
  `.first`/`.second` → `.key`/`.value`), `.count()` → `.has()`,
  `.empty()` → `.is_empty()`, `.emplace()` → `.insert()`. The
  `snore_core/internal/std_hash.h` workaround header is deleted.
  Note: the non-`StringName`-keyed `std::unordered_map<int, ...>`
  declarations in `time/time_service.h` and the
  `std::unordered_map<std::string, std::string>` static caches in
  `screen_service` / `audio_service` are intentionally left alone
  (they're not blocked by the missing hash and are out of scope of
  the original blocker).

- [x] **Delete the redundant `.gdextension` manifests** —
  `snore_core/addon/bin/snore_core.gdextension`,
  `scaffolder/addon/bin/scaffolder.gdextension`,
  `surfacer/addon/bin/surfacer.gdextension`. The demo only loads
  `surf_scaf.gdextension`; the other three were double-registration
  footguns. Per-framework READMEs now document that `surf_scaf` is the
  supported loading path. Done 2026-05-20.
- [x] **Gate googletest source inclusion** on
  `env["includes_dev"] AND env["includes_tests"]` in
  `snore_core/build_utils.py::set_up`. Landed during Phase 2.5
  workspace-sibling refactor (2026-05-20).
- [x] **Fix the broken `[icons]` blocks** in the `.gdextension` manifests.
  Three of the four manifests were deleted outright; the surviving
  `surf_scaf.gdextension` (and its copy in `squirrel_away/addon/bin/`)
  had its placeholder `GDExample` / `surf_scaf2` paths replaced with a
  comment explaining that no icons are designed yet. Done 2026-05-20.
- [x] **Update the gdext#615 comments** in
  `register_gdextension_types.cpp` to also cite
  `godot-proposals#13997` (the engine proposal for cross-extension class
  inheritance; gdext#615 is the rust-bindings tracker). Updated in
  surf_scaf, scaffolder, and surfacer. Done 2026-05-20.
- [x] **Decide bootstrapper's relationship to surf_scaf's artifact**:
  symlink (Option B). Bootstrapper's SConstruct no longer compiles
  anything; it just refreshes the demo's `addons/` tree, with
  `demo/addons/surf_scaf/bin/` symlinked as a directory to
  `../surf_scaf/addon/bin/`. Single source of truth for the artifact.
  Workflow: `cd surf_scaf && scons sc_dev=yes` builds the bundle, then
  bootstrapper's scons refreshes symlinks. Done 2026-05-20.
- [x] Rename local working directory
  `C:\Users\lsl\Repositories\bootstrapper2\` → `bootstrapper\`. Done
  2026-05-20.
- [ ] Delete `C:\tmp\sc-backup\*.git` mirrors after ~2026-06-19 if no
  rollback was needed (one month from Phase 1 surgery completion;
  pushed out from the original 2026-05-26 per user direction).
- [x] Archive `scaffolder-bootstrap` repo (last commit 2021-12-13;
  predated the current bootstrapper project by ~4 years and wasn't
  referenced anywhere in the active codebase). Done 2026-05-20 via
  `gh repo archive`.
- [x] **Audit + rewrite the GitHub Actions across all six SnoringCat
  repos.** Done 2026-05-20. Each repo's two LLM-generated workflows
  (`builds.yml` + `tests.yml`, ~640 lines combined per repo with a
  multi-platform release matrix that nothing consumed) were replaced
  with a single `ci.yml` (~70-110 lines per repo). The new workflow:
  triggers on `schedule` (daily 04:00 UTC), `push` /
  `pull_request` to the slim default branches (`main` / `master`),
  plus `workflow_dispatch` for manual runs — explicitly NOT on push
  to `dev`, to avoid burning private-repo CI minutes on every
  commit during active porting work. Runs on `ubuntu-latest`;
  checks out the full workspace-sibling layout (frameworks +
  godot-cpp@4.4 + googletest) into the runner workspace root;
  builds via `scons sc_ci=yes sc_dev=yes sc_tests=yes`. The
  `sc_ci=yes` flag is important — `debug_utils.h`'s `DEBUG_BREAK`
  macro otherwise expands to `__builtin_debugtrap` (Clang/MSVC-only)
  which GCC rejects. The dead `.github/actions/sign/` Mac-signing
  action was deleted from every repo. Followups inline below.

  Surfaced bugs in the framework (fixed during the rewrite, since the
  new Linux/GCC CI is stricter than the local Windows/MSVC build):

  - snore_core `log_service.cpp`: ternary returning
    `Vector2` vs `Vector2i` (different types).
  - snore_core `snore_core_main_module.cpp`: `Node.hpp` include with
    wrong case (worked on NTFS, fails on ext4).
  - snore_core `snore_core_root_module.h::set_up_base`: non-const
    `Ref<>&` parameter rejected when bound to an rvalue.
  - scaffolder `scaffolder_module.h`: `Ref<GameSession> session`
    member with only a forward declaration — Ref<> destructor
    instantiation needs the complete type.
  - scaffolder `scaffolder_module.cpp`: two ternaries returning
    `Ref<PackedScene>` vs `Ref<Resource>`.

  Followups (not blocking, future improvements):

  - [x] **Cache SCons compiled objects.** Done 2026-05-20. Each
    ci.yml sets `SCONS_CACHE=$GITHUB_WORKSPACE/.scons-cache` and
    `actions/cache@v4`s that directory. godot-cpp's SConstruct
    natively reads `SCONS_CACHE` and calls `CacheDir(...)` +
    `Decider("MD5")`, giving content-addressed caching of every
    compile output. The framework's SConstruct inherits the same
    env, so framework objects get cached too (no `build_utils.py`
    code change needed — turns out the "tier-2 framework cache"
    falls out for free).
    Cache key: `scons-v3-${runner.os}-gcc${gcc_version}-${godot_cpp_sha}-${github.sha}`,
    with a 3-step restore-keys ladder. The `v3-` prefix is the
    manual escape hatch (bump to v4 to force-evict; v1 and v2
    were earlier broken iterations that cached the wrong paths).
    **Measured speedup:** cold 10 min 32 sec → warm 9 sec
    (validated on snore_core). The 6-repo nightly steady-state
    cost dropped from ~60 min to ~1.5-4 min depending on what
    changed.
    Worth knowing: SCons cache saves the final shared library
    too, not just intermediates — a warm "rebuild" of an
    unchanged source tree is literally "Retrieved
    libSnoreCore.*.so from cache" in ~150 ms.
  - [ ] Add actual test running. Today the workflow only builds; it
    doesn't launch Godot against the demo project to run the gtest
    suite. Doing so cleanly needs a pre-built Godot binary (don't
    rebuild from source in CI). The simplest path is downloading
    a Godot 4 stable release via the godotengine.org URL into a
    workspace `godot/bin/` and pointing the demo at it.
  - [x] **Opt actions/checkout into Node 24.** Done 2026-05-20.
    Each ci.yml's build job sets
    `env: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true`, which moves
    every Node-20-based action onto Node 24 ahead of the June
    2026 forced switch. Silences the deprecation annotation that
    was firing on every run.
  - [ ] Move the per-repo `PRIVATECHECKOUTACCESSTOKEN` secrets to an
    organization-level secret so token rotation is a single
    operation (today a fresh PAT must be set on each of 4 private
    repos). Was discovered during the rewrite because surf_scaf's
    per-repo PAT was stale and broke its CI's snore_core checkout.
- [x] **Decide what to do with `.local-patches/`** — kept as permanent
  local insurance (decision 2026-05-20). Background: the patch adds a
  `TypedArray<T>::debug()` helper to godot-cpp so MSVC can inspect
  array contents at a breakpoint. Web research (2026-05-20) found no
  better alternative: Godot's engine `godot.natvis` covers Variant /
  Array / String, but Godot-cpp's `Array` and `TypedArray<T>` are
  opaque-pointer wrappers whose internal layout doesn't match what the
  engine's natvis dereferences. A custom natvis for godot-cpp's
  opaque types is theoretically possible (`reinterpret_cast<void**>
  (opaque)` style, like `godot::String` in the engine natvis) but
  would be non-trivial to write and maintain. godot-proposals#10605
  (ship natvis in godot-cpp) was closed as not-planned. Forum
  consensus: no good answer. The patches stay as the pragmatic
  approach. Future option: write the custom natvis for godot-cpp
  opaque types as a one-time investment.

## Out of scope

- `exampler` (deliberately untouched; Godot-3-era example).
- `hopnbop_private` and `snoringcat-platform` (separate active project).
- Reviving the `scaffolder-bootstrap` repo (if it stays in the org, treat
  as historical).
