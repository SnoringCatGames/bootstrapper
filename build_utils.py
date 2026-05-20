import os


def create_symlink_for_surf_scaf_extension_manifest() -> None:
    source_path = os.path.abspath(
        "../surf_scaf/addon/bin/surf_scaf.gdextension"
    )
    link_path = os.path.abspath("demo/addons/surf_scaf/bin/surf_scaf.gdextension")

    # Ensure the destination directory exists.
    link_dir = os.path.dirname(link_path)
    os.makedirs(link_dir, exist_ok=True)

    if os.path.exists(link_path):
        os.remove(link_path)
    os.symlink(source_path, link_path, target_is_directory=False)
