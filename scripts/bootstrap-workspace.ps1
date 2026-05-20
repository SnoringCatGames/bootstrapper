#!/usr/bin/env pwsh

# Clone all SnoringCat framework + third-party dependency siblings next
# to the bootstrapper repo, if not already present. Idempotent; safe to
# rerun.
#
# Layout assumption: the parent directory of bootstrapper is the
# workspace root (typically `~/Repositories/`). Each framework + third-
# party dep lives as a sibling directory there.
#
# Run from the bootstrapper repo:
#     ./scripts/bootstrap-workspace.ps1

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Locate workspace root (parent of bootstrapper).
$bootstrapper_root = Resolve-Path "$PSScriptRoot\.."
$workspace_root = Resolve-Path "$bootstrapper_root\.."

Write-Host "Workspace root: $workspace_root"
Write-Host "Bootstrapper:   $bootstrapper_root"
Write-Host ""

# Each entry: name, url, branch (or empty for default).
$siblings = @(
    @{ name = 'snore_core';    url = 'https://github.com/SnoringCatGames/snore_core';    branch = 'dev' },
    @{ name = 'scaffolder';    url = 'https://github.com/SnoringCatGames/scaffolder';    branch = 'dev' },
    @{ name = 'surfacer';      url = 'https://github.com/SnoringCatGames/surfacer';      branch = 'dev' },
    @{ name = 'surf_scaf';     url = 'https://github.com/SnoringCatGames/surf_scaf';     branch = 'dev' },
    @{ name = 'squirrel_away'; url = 'https://github.com/SnoringCatGames/squirrel_away'; branch = 'dev' },
    @{ name = 'godot-cpp';     url = 'https://github.com/godotengine/godot-cpp';         branch = '4.4' },
    @{ name = 'godot';         url = 'https://github.com/godotengine/godot';             branch = '' },
    @{ name = 'googletest';    url = 'https://github.com/google/googletest';             branch = '' }
)

$cloned = 0
$skipped = 0

foreach ($s in $siblings) {
    $target = Join-Path $workspace_root $s.name
    if (Test-Path $target) {
        Write-Host "[skip]  $($s.name) already exists at $target"
        $skipped++
        continue
    }

    $branchArg = if ($s.branch) { "--branch $($s.branch) --single-branch" } else { '' }
    $cmd = "git clone $branchArg $($s.url) `"$target`""
    Write-Host "[clone] $($s.name) ($($s.branch))"

    if ($DryRun) {
        Write-Host "        (dry-run) $cmd"
    } else {
        $args = @('clone')
        if ($s.branch) { $args += @('--branch', $s.branch, '--single-branch') }
        $args += @($s.url, $target)
        & git @args
        if ($LASTEXITCODE -ne 0) {
            throw "git clone failed for $($s.name)"
        }
    }
    $cloned++
}

Write-Host ""
Write-Host "Done. Cloned $cloned, skipped (already present) $skipped."
Write-Host ""
Write-Host "Next: cd $bootstrapper_root && scons sc_dev=yes sc_tests=yes"
