# bootstrapper

> **Status: rewrite in progress.** This branch (`main`) is intentionally
> minimal during active development; the real code lives on `dev`.

Umbrella project + example template for the SnoringCat Godot 4
framework rewrite. Once the rewrite stabilizes, `bootstrapper` will
be a small starter repo that copy-paste-and-edited to start a new
Godot 4 game using these frameworks.

## Branches

| Branch | Content |
|---|---|
| `main` (this) | Minimal during the rewrite — this README + [HANDOVER.md](HANDOVER.md) + [ROADMAP.md](ROADMAP.md). |
| `dev` | Active rewrite work — full submodule tree, build system, example project. |

## Where to go next

- Current Godot 4 work in progress: `git checkout dev`
- Status, decisions, rollback paths from the most recent surgery: [HANDOVER.md](HANDOVER.md)
- Forward-looking plan: [ROADMAP.md](ROADMAP.md)

## The framework ecosystem

`bootstrapper` is the umbrella for these repos:

| Repo | Role |
|---|---|
| [snore_core](https://github.com/SnoringCatGames/snore_core) | Foundational C++ library (logging, geometry, services). |
| [scaffolder](https://github.com/SnoringCatGames/scaffolder) | General game framework (screens, app lifecycle, settings, save data). |
| [surfacer](https://github.com/SnoringCatGames/surfacer) | 2D platformer character / pathfinding framework. |
| [surf_scaf](https://github.com/SnoringCatGames/surf_scaf) | Combined-bundle GDExtension of the three above (a Godot 4 workaround — see surf_scaf's README). |
| [squirrel_away](https://github.com/SnoringCatGames/squirrel_away) | Example 2D platformer game built on the frameworks. |
