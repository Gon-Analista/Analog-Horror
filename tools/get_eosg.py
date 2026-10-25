"""Downloads the EOSG plugin binaries (Epic Online Services for Godot,
3ddelano, release 2.3.1, Windows) into game/addons/epic-online-services-godot/bin.
The plugin scripts are in git (copied from Midgard Survivors with one
patch: EOS.Achievements renamed EOS.Achievement); the binaries are not
(36 MB).

    python tools/get_eosg.py
"""
import io
import shutil
import urllib.request
import zipfile
from pathlib import Path

URL = ("https://github.com/3ddelano/epic-online-services-godot/releases/download/2.3.1/"
       "epic-online-services-godot-windows-56238973e2cd7ac9ac99ca14f88934465f0a8997.zip")
DEST = Path(__file__).resolve().parent.parent / "game" / "addons" / "epic-online-services-godot" / "bin"


def main() -> None:
    print("downloading", URL)
    data = urllib.request.urlopen(URL).read()
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name in z.namelist():
            marker = "addons/epic-online-services-godot/bin/"
            if marker not in name or name.endswith("/"):
                continue
            out = DEST / name.split(marker, 1)[1]
            out.parent.mkdir(parents=True, exist_ok=True)
            with z.open(name) as src, open(out, "wb") as dst:
                shutil.copyfileobj(src, dst)
            print("  ", out.relative_to(DEST.parent.parent.parent))


if __name__ == "__main__":
    main()
