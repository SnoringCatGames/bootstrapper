import os
import shutil


def create_symlink_for_surf_scaf_addon_bin() -> None:
	"""
	Mirror surf_scaf's pre-built ``addon/bin/`` directory into the
	bootstrapper demo as a directory symlink. This consumes the
	artifact produced by surf_scaf's own SConstruct rather than
	rebuilding it here.

	Requires surf_scaf to have been built first::

	    cd ~/Repositories/surf_scaf && python -m SCons sc_dev=yes

	The symlink also covers the ``.gdextension`` manifest and the
	per-platform binary subdirectories in one shot.
	"""
	source_path = os.path.abspath("../surf_scaf/addon/bin")
	link_path = os.path.abspath("demo/addons/surf_scaf/bin")

	if not os.path.isdir(source_path):
		raise SystemExit(
			"ERROR: ../surf_scaf/addon/bin/ does not exist.\n"
			"       Build surf_scaf first:\n"
			"           cd ~/Repositories/surf_scaf && "
			"python -m SCons sc_dev=yes sc_tests=yes\n"
		)

	link_parent = os.path.dirname(link_path)
	os.makedirs(link_parent, exist_ok=True)

	# Clear any pre-existing link, real directory (from the previous
	# Option-A build pattern), or stray file.
	if os.path.islink(link_path):
		os.remove(link_path)
	elif os.path.isdir(link_path):
		shutil.rmtree(link_path)
	elif os.path.exists(link_path):
		os.remove(link_path)

	os.symlink(source_path, link_path, target_is_directory=True)
