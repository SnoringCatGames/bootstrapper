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

## Now (Phase 2 — assess the current state)

Code review of what landed during the WIP porting before the long pause.
Doesn't write new code; produces findings + a coverage matrix.

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

## Next (Phase 3 — finish the port, ship the framework)

Order is flexible and depends on Phase 2 findings.

- [ ] Finish surfacer GDScript → C++ port (acknowledged as the biggest
  remaining lift).
- [ ] Land any specific port bugs surfaced by the Phase 2.2 audit.
- [ ] Resolve architectural recommendations from Phase 2.1 (e.g.,
  registration idempotency guard if needed).
- [ ] App/framework setup improvements (specifics TBD; revisit after
  Phase 2 makes the current state legible).

## Later (Phase 4 — new features)

- [ ] **Dynamic-pathfinding mode in surfacer**. Pathfinding that works on
  dynamically-built levels without preparsing the level into a static
  platform graph. Design spike + prototype + integration. This is the
  one feature the user explicitly called out as a motivation for the
  rewrite.

## Housekeeping (do whenever it fits)

- [ ] Rename local working directory
  `C:\Users\lsl\Repositories\bootstrapper2\` → `bootstrapper\`. Cosmetic.
  Close Godot + IDEs first.
- [ ] Resolve in-flight submodule pointer drift on `dev` (the lowercase-m
  entries inside `surf_scaf` and `squirrel_away`). When the dev-branch
  porting work is at a checkpoint, land a "Bump submodule pointers"
  commit.
- [ ] Delete `C:\tmp\sc-backup\*.git` mirrors after ~2026-05-26 if no
  rollback was needed.
- [ ] Decide fate of `scaffolder-bootstrap` repo (shows up in the org
  list but wasn't part of the recent surgery; possibly obsolete).
- [ ] Investigate the `git submodule sync --recursive` no-op observed
  during the Phase 1 URL-fix (see HANDOVER.md decision #2). Worth
  understanding for future submodule URL changes.
- [ ] Decide what to do with `.local-patches/godot-cpp-typed-array-debug.patch`
  long-term. Either upstream the `TypedArray<T>::debug()` helper to
  godot-cpp, or accept it as a permanent local-only patch.
- [ ] Empty file `submodules/snore_core/src/snore_core/test_snore_core_root_module.cpp`
  — `git rm` or fill in.

## Out of scope

- `exampler` (deliberately untouched; Godot-3-era example).
- `hopnbop_private` and `snoringcat-platform` (separate active project).
- Reviving the `scaffolder-bootstrap` repo (if it stays in the org, treat
  as historical).
