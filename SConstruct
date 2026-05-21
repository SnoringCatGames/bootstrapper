#!/usr/bin/env python
"""
Bootstrapper SConstruct.

This SConstruct does NOT compile anything. Bootstrapper consumes the
pre-built surf_scaf shared library produced by surf_scaf's own
SConstruct. Build surf_scaf first:

    cd ~/Repositories/surf_scaf && python -m SCons sc_dev=yes sc_tests=yes

Then run ``scons`` from this directory to refresh the demo project's
``addons/`` tree (recreates GDScript symlinks into each framework's
``addon/`` and a single directory symlink to ``surf_scaf/addon/bin/``
so the demo loads the artifact surf_scaf just built).
"""
import os
import sys

# Workspace-sibling layout: framework deps live next to bootstrapper
# at ~/Repositories/<name>/, not nested under submodules/. See
# ROADMAP.md Phase 2.5 and CLAUDE.md for the rationale.
sys.path.insert(0, os.path.abspath(".."))

from snore_core.build_utils import (
	create_submodule_addons_symlinks,
	default_addon_dir_name as snore_core_addon_dir_name,
)
from scaffolder.build_utils import (
	default_addon_dir_name as scaffolder_addon_dir_name,
)
from surfacer.build_utils import (
	default_addon_dir_name as surfacer_addon_dir_name,
)
from surf_scaf.build_utils import (
	default_addon_dir_name as surf_scaf_addon_dir_name,
)
from squirrel_away.build_utils import (
	default_addon_dir_name as squirrel_away_addon_dir_name,
)
from build_utils import (
	create_symlink_for_surf_scaf_addon_bin,
)

create_submodule_addons_symlinks(snore_core_addon_dir_name, False)
create_submodule_addons_symlinks(scaffolder_addon_dir_name, False)
create_submodule_addons_symlinks(surfacer_addon_dir_name, False)
create_submodule_addons_symlinks(surf_scaf_addon_dir_name, False)
create_submodule_addons_symlinks(squirrel_away_addon_dir_name, False)

create_symlink_for_surf_scaf_addon_bin()
