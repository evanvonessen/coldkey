"""Native Finder drag-to-Applications window for the downloadable installer."""

from importlib.metadata import distribution
from pathlib import Path

app = Path(defines["app"])
files = [str(app)]
symlinks = {"Applications": "/Applications"}

format = "UDZO"
background = "builtin-arrow"
window_rect = ((200, 200), (640, 340))
default_view = "icon-view"
include_icon_view_settings = True
include_list_view_settings = False
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = True
arrange_by = None
grid_spacing = 80
icon_size = 128
text_size = 14
icon_locations = {"Coldkey.app": (140, 120), "Applications": (500, 120)}


def create_hook(volume, options):
    # Retain the standard background's license without adding visible files.
    license_text = distribution("dmgbuild").read_text("licenses/LICENSE")
    if not license_text:
        raise RuntimeError("The dmgbuild background license is missing.")
    notices = Path(volume) / ".licenses"
    notices.mkdir()
    (notices / "dmgbuild.txt").write_text(license_text, encoding="utf-8")
