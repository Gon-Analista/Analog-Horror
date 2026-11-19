"""Lost Signal releases: full builds on itch.io and patches inside the game.

    python tools/release.py full [--push] [--hidden]   # the base (itch.io)
    python tools/release.py patch 0.4.1 [--push] [--force]
    python tools/release.py status
    python tools/release.py broadcast "<es>" ["<en>"] [--push]   (no text: removes it)
    (python tools/release.py [--push] is still "full".)

full: every text translated (i18n.py --check), the version stamped into the
  .exe's properties, the "Windows Desktop" preset exported into a clean
  build/itch_windows/ (exe, pck, the Epic DLLs, README.txt; nothing else,
  nothing that looks like a key) and zipped as build/LostSignal-windows.zip;
  the base kept in build/release/base/ (pck, project.godot, base.json) and
  the previous one moved to build/release/old_bases/. --push: butler push to
  nearq/lost-signal:windows (--userversion = config/version), bridges
  ("legacy" patches) for the old bases that can take one, and the new
  manifest published.
patch: exported with --export-patch against the base's pck (everything
  changed since the base: patches are cumulative), encrypted with the key in
  game/autoload/updater.gd (tools/encrypt_patch.gd), split if over 90 MB,
  sha256; in the clone of the public updates repo (build/updates/) only this
  patch and the legacy ones stay; manifest.json with the notes of
  tools/release_notes.json. --push: git commit + push (otherwise only a local
  commit). Refuses if project.godot changed since the base (--force only for
  changes with no effect at runtime); config/version never changes for a
  patch (it names the base).

Godot is $GODOT or the copy on the Desktop; butler is $BUTLER or the one the
itch app installed (already logged in: its credentials are never read or
printed here). The updates repo is pushed with plain git.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
# One build folder and one zip, replaced every time (no pile of old builds).
OUT = ROOT / "build" / "itch_windows"
TARGET = "nearq/lost-signal:windows"
PAGE = "https://nearq.itch.io/lost-signal"
PRESET = "Windows Desktop"
EXE = "LostSignal.exe"
PCK = "LostSignal.pck"
RELEASE = ROOT / "build" / "release"
BASE = RELEASE / "base"
OLD_BASES = RELEASE / "old_bases"
WORK = RELEASE / "work"
# (UPDATES_DIR: another folder, not a git clone, for local tests: nothing is committed there.)
UPDATES = Path(os.environ["UPDATES_DIR"]) if os.environ.get("UPDATES_DIR") else ROOT / "build" / "updates"
UPDATES_GIT = "https://github.com/Gon-Analista/lost-signal-updates.git"
# Windows' own certificate store for git (an antivirus scanning HTTPS, e.g.
# Avast, breaks git's bundled OpenSSL: "unable to get local issuer certificate").
GIT = ["git", "-c", "http.sslBackend=schannel"] if os.name == "nt" else ["git"]
MANIFEST_URL = "https://raw.githubusercontent.com/Gon-Analista/lost-signal-updates/main/manifest.json"
PART_SIZE = 90 * 1024 * 1024  # GitHub refuses files over 100 MB
GODOT = Path(os.environ.get("GODOT", Path.home() / "Desktop" / "Godot_v4.7.2-stable_win64.exe"))
EXPECTED = {EXE, "LostSignal.pck", "EOSSDK-Win64-Shipping.dll", "libeosg.windows.template_release.x86_64.dll",
            "xaudio2_9redist.dll", "README.txt"}
SUSPICIOUS = re.compile(r"cred|secret|token|\.env$|\.key$|\.pem$|butler", re.I)

README = """LOST SIGNAL - ANALOG HORROR (demo {version})
Online co-op analog horror, 1 to 4 players. / Terror analógico cooperativo, de 1 a 4 jugadores.

ENGLISH
- Open {exe} (keep every file in this folder together).
- Play alone, or "Create online room" and give your friends the 5-letter code (up to 4).
- Headphones recommended. The game starts in your system's language; change it in Options.
Controls
- WASD: move · Mouse: look · Shift: run · C: crouch · Space: jump
- Right click: camcorder (the Visitor can only be seen through it)
- Left click while recording: flash (drives it away; uses battery)
- F: flashlight · E: use / pick up / hide · G: drop or pass the camcorder
- V: talk (if the microphone is set to "push V") · F11: full screen · Esc: pause
If Windows SmartScreen warns you ("Windows protected your PC"), click "More info" > "Run anyway": the game is not signed.

ESPAÑOL
- Abre {exe} (todos los archivos de esta carpeta deben quedar juntos).
- Jugar solo, o "Crear sala online" y pasar el código de 5 letras a tus amigos (hasta 4).
- Auriculares recomendados. El juego arranca en el idioma de tu sistema; cámbialo en Opciones.
Controles
- WASD: moverse · Ratón: mirar · Shift: correr · C: agacharse · Espacio: saltar
- Clic derecho: videocámara (la Visita solo se ve a través de ella)
- Clic izquierdo mientras grabas: flash (la ahuyenta; gasta batería)
- F: linterna · E: usar / recoger / esconderse · G: soltar o pasar la cámara
- V: hablar (si el micrófono está en "pulsa V") · F11: pantalla completa · Esc: pausa
Si Windows SmartScreen avisa ("Windows protegió su PC"), pulsa "Más información" > "Ejecutar de todas formas": el juego no está firmado.
"""


def version() -> str:
    text = (GAME / "project.godot").read_text(encoding="utf-8")
    return re.search(r'config/version="([^"]+)"', text).group(1)


def vkey(v: str):
    """'0.1.10' > '0.1.9': by number, part by part."""
    return [int(x) if x.isdigit() else 0 for x in str(v).split(".")]


def butler() -> Path:
    if os.environ.get("BUTLER"):
        return Path(os.environ["BUTLER"])
    base = Path(os.environ.get("APPDATA", "")) / "itch" / "broth" / "butler" / "versions"
    found = sorted(base.glob("*/butler.exe"), key=lambda p: vkey(p.parent.name))
    if not found:
        sys.exit("butler not found: install it from the itch app or https://itchio.itch.io/butler and run `butler login`")
    return found[-1]


def run(cmd, **kw):
    print(">", " ".join(str(c) for c in cmd))
    return subprocess.run([str(c) for c in cmd], check=True, **kw)


def stamp(ver: str) -> None:
    """The version into the .exe's properties (export_presets.cfg)."""
    p = GAME / "export_presets.cfg"
    text = p.read_text(encoding="utf-8")
    four = ver + ".0" * (3 - ver.count("."))
    text = re.sub(r'application/file_version="[^"]*"', 'application/file_version="%s"' % four, text)
    text = re.sub(r'application/product_version="[^"]*"', 'application/product_version="%s"' % four, text)
    p.write_text(text, encoding="utf-8")


def build(ver: str) -> Path:
    run([sys.executable, "-X", "utf8", ROOT / "tools" / "i18n.py", "--check"])
    stamp(ver)
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        for old in OUT.iterdir():  # emptied, not removed (Windows may hold the folder open)
            shutil.rmtree(old) if old.is_dir() else old.unlink()
    except PermissionError:
        sys.exit("build/itch_windows is in use: close the game (LostSignal.exe) and run this again")
    run([GODOT, "--headless", "--path", GAME, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run([GODOT, "--headless", "--path", GAME, "--export-release", PRESET, OUT / EXE])
    (OUT / "README.txt").write_text(README.format(version=ver, exe=EXE), encoding="utf-8")
    # Godot leaves Windows' temp copies behind sometimes.
    for stray in OUT.glob("*~RF*.TMP"):
        stray.unlink()
    files = {p.name for p in OUT.iterdir()}
    if files != EXPECTED:
        sys.exit("unexpected build contents: extra %s, missing %s" % (sorted(files - EXPECTED), sorted(EXPECTED - files)))
    bad = [f for f in files if SUSPICIOUS.search(f)]
    if bad:
        sys.exit("refusing to ship files that look private: %s" % bad)
    for old_zip in (ROOT / "build").glob("LostSignal*-windows.zip"):
        old_zip.unlink()
    zip_path = ROOT / "build" / "LostSignal-windows.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(OUT.iterdir()):
            z.write(p, p.name)
    print("built %s (%d files) and %s" % (OUT, len(files), zip_path.name))
    return zip_path


# --- bases ----------------------------------------------------------------------------

def base_info(folder: Path) -> dict:
    p = folder / "base.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


def save_base(ver: str) -> None:
    """build/release/base: this build's pck, project.godot and what its updater
    knows; the previous base (another version) goes to old_bases/."""
    if BASE.exists():
        old = base_info(BASE).get("version")
        if old and old != ver:
            dest = OLD_BASES / old
            if dest.exists():
                shutil.rmtree(dest)
            OLD_BASES.mkdir(parents=True, exist_ok=True)
            shutil.move(str(BASE), str(dest))
            print("previous base %s -> %s" % (old, dest))
        else:
            shutil.rmtree(BASE)
    BASE.mkdir(parents=True, exist_ok=True)
    shutil.copy2(OUT / PCK, BASE / PCK)
    shutil.copy2(GAME / "project.godot", BASE / "project.godot")
    (BASE / "base.json").write_text(json.dumps({"version": ver, "parts": True, "bridge": True}, indent=2), encoding="utf-8")
    print("base %s saved in %s" % (ver, BASE))


def same_project(a: Path, b: Path, ignore_version: bool) -> bool:
    """Same settings, whatever their order: the editor rewrites project.godot
    with its sections in another order now and then (a text comparison took
    that for a change and refused the patch, 2026-11-04)."""
    def settings(p: Path) -> dict:
        out, section, key, value, depth = {}, "", None, "", 0
        for line in p.read_text(encoding="utf-8").replace("\r\n", "\n").split("\n"):
            if key is not None:  # a value over several lines
                value += "\n" + line
                depth += sum(line.count(c) for c in "{[(") - sum(line.count(c) for c in "}])")
                if depth <= 0:
                    out[(section, key)] = value.strip()
                    key = None
                continue
            stripped = line.strip()
            if not stripped or stripped.startswith(";"):
                continue
            if stripped.startswith("[") and stripped.endswith("]") and "=" not in stripped:
                section = stripped[1:-1]
                continue
            k, _, v = stripped.partition("=")
            depth = sum(v.count(c) for c in "{[(") - sum(v.count(c) for c in "}])")
            if depth > 0:
                key, value = k, v
            else:
                out[(section, k)] = v.strip()
        if ignore_version:
            out.pop(("application", "config/version"), None)
        return out
    return settings(a) == settings(b)


# --- patches --------------------------------------------------------------------------

def export_patch(against: Path, out_pck: Path) -> None:
    out_pck.parent.mkdir(parents=True, exist_ok=True)
    if out_pck.exists():
        out_pck.unlink()
    run([GODOT, "--headless", "--path", GAME, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run([GODOT, "--headless", "--path", GAME, "--export-patch", PRESET, out_pck, "--patches", against])
    if not out_pck.exists():
        sys.exit("the patch was not exported (%s)" % out_pck)


def encrypt(pck: Path, out_bin: Path) -> None:
    run([GODOT, "--headless", "--path", GAME, "--script", ROOT / "tools" / "encrypt_patch.gd", "--", pck, out_bin, GAME / "autoload" / "updater.gd"])
    if not out_bin.exists():
        sys.exit("encryption failed")


def publish_files(bin_path: Path, name: str) -> dict:
    """Copies the encrypted patch into the updates repo (in parts if it is too
    big for GitHub) and returns its manifest entry (without the version)."""
    data = bin_path.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    dest = UPDATES / "patches"
    dest.mkdir(parents=True, exist_ok=True)
    entry = {"file": "patches/%s" % name, "size": len(data), "sha256": sha}
    if len(data) > PART_SIZE:
        parts = []
        for i in range(0, len(data), PART_SIZE):
            part = "%s.%03d" % (name, i // PART_SIZE)
            (dest / part).write_bytes(data[i:i + PART_SIZE])
            parts.append("patches/%s" % part)
        entry["parts"] = parts
    else:
        (dest / name).write_bytes(data)
    return entry


def entry_files(entry: dict) -> set:
    if not entry:
        return set()
    return set(entry.get("parts") or [entry.get("file")])


def ensure_repo() -> None:
    if os.environ.get("UPDATES_DIR"):
        UPDATES.mkdir(parents=True, exist_ok=True)
        return
    if (UPDATES / ".git").exists():
        subprocess.run(GIT + ["-C", str(UPDATES), "pull", "--ff-only", "-q"])  # (an empty repo has nothing to pull)
        return
    UPDATES.parent.mkdir(parents=True, exist_ok=True)
    run(GIT + ["clone", UPDATES_GIT, UPDATES])


def read_manifest() -> dict:
    p = UPDATES / "manifest.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


def notes(limit: int = 12) -> list:
    p = ROOT / "tools" / "release_notes.json"
    data = json.loads(p.read_text(encoding="utf-8")) if p.exists() else []
    return data[:limit]


def write_manifest(m: dict) -> None:
    m["page"] = PAGE
    m["notes"] = notes()
    # Only the files the manifest points to stay in the repo.
    keep = entry_files(m.get("patch") or {})
    for entry in (m.get("legacy") or {}).values():
        keep |= entry_files(entry)
    folder = UPDATES / "patches"
    if folder.exists():
        for f in folder.iterdir():
            if "patches/" + f.name not in keep:
                f.unlink()
    (UPDATES / "manifest.json").write_text(json.dumps(m, indent=2, ensure_ascii=False), encoding="utf-8")
    print("manifest written: base %s, patch %s, legacy %s" % (m.get("base"), (m.get("patch") or {}).get("version"), sorted((m.get("legacy") or {}).keys())))


def commit(message: str, push: bool) -> None:
    if not (UPDATES / ".git").exists():
        print("(%s is not a git clone: nothing committed)" % UPDATES)
        return
    run(["git", "-C", UPDATES, "add", "-A"])
    if subprocess.run(["git", "-C", str(UPDATES), "diff", "--cached", "--quiet"]).returncode == 0:
        print("(nothing changed in the updates repo)")
        return
    run(["git", "-C", UPDATES, "commit", "-q", "-m", message])
    if push:
        run(GIT + ["-C", UPDATES, "push", "-q", "origin", "HEAD:main"])
        print("published: %s" % MANIFEST_URL)
    else:
        print("committed locally in %s (not pushed: add --push)" % UPDATES)


# --- commands -------------------------------------------------------------------------

def cmd_full(args) -> None:
    ver = version()
    if not args.manifest_only:
        build(ver)
        save_base(ver)
        if not args.push:
            return
        b = butler()
        cmd = [b, "push", OUT, TARGET, "--userversion", ver]
        if args.hidden:
            cmd.append("--hidden")  # only valid on the channel's first push
        run(cmd)
        run([b, "status", TARGET])
    elif base_info(BASE).get("version") != ver:
        sys.exit("--manifest-only: the saved base is not %s" % ver)
    # The manifest of the new base: no patch yet; bridges for the old bases
    # that understand them (and have the same project.godot but the version).
    ensure_repo()
    m = read_manifest()
    m["base"] = ver
    m["patch"] = None
    legacy = {}
    for folder in sorted(OLD_BASES.glob("*"), key=lambda p: vkey(p.name)):
        info = base_info(folder)
        if not info.get("bridge") or not (folder / PCK).exists():
            continue
        if not same_project(folder / "project.godot", GAME / "project.godot", ignore_version=True):
            print("no bridge from %s: its project.godot differs (they get the itch notice)" % folder.name)
            continue
        pck = WORK / ("legacy_%s_to_%s.pck" % (folder.name, ver))
        export_patch(folder / PCK, pck)
        binp = pck.with_suffix(".bin")
        encrypt(pck, binp)
        entry = publish_files(binp, "legacy_%s_to_%s.bin" % (folder.name, ver))
        entry["version"] = ver
        legacy[folder.name] = entry
    m["legacy"] = legacy
    write_manifest(m)
    commit("base %s" % ver, True)


def cmd_patch(args) -> None:
    ver = args.version
    info = base_info(BASE)
    if not info:
        sys.exit("no base in %s: make a full build first (release.py full)" % BASE)
    base = info["version"]
    if version() != base:
        sys.exit("config/version is %s but the base is %s: a patch never changes config/version" % (version(), base))
    if not same_project(BASE / "project.godot", GAME / "project.godot", ignore_version=False) and not args.force:
        sys.exit("project.godot changed since the base %s (autoloads, input, translations, export options...): "
                 "that needs a full build. --force only if the change has no effect at runtime." % base)
    if vkey(ver) <= vkey(base):
        sys.exit("the patch version (%s) must be newer than the base (%s)" % (ver, base))
    ensure_repo()
    m = read_manifest()
    published = (m.get("patch") or {}).get("version") if m.get("base") == base else None
    if published and vkey(ver) <= vkey(published):
        sys.exit("the patch version (%s) must be newer than the published one (%s)" % (ver, published))
    if not any(n.get("version") == ver for n in notes()):
        print("note: tools/release_notes.json has no notes for %s (the window will show none)" % ver)
    run([sys.executable, "-X", "utf8", ROOT / "tools" / "i18n.py", "--check"])
    pck = WORK / ("patch_%s.pck" % ver)
    export_patch(BASE / PCK, pck)
    binp = pck.with_suffix(".bin")
    encrypt(pck, binp)
    entry = publish_files(binp, "patch_%s.bin" % ver)
    entry["version"] = ver
    m["base"] = base
    m["patch"] = entry
    m.setdefault("legacy", {})
    write_manifest(m)
    print("patch %s: %.1f KB (pck %.1f KB)" % (ver, entry["size"] / 1024, pck.stat().st_size / 1024))
    commit("patch %s (base %s)" % (ver, base), args.push)


def cmd_status(_args) -> None:
    info = base_info(BASE)
    print("local base:", info.get("version", "(none)"), "| config/version:", version())
    for folder in sorted(OLD_BASES.glob("*"), key=lambda p: vkey(p.name)):
        print("  old base:", folder.name, base_info(folder))
    if (UPDATES / "manifest.json").exists():
        m = read_manifest()
        print("updates repo (local): base %s, patch %s, legacy %s, broadcast %s" % (
            m.get("base"), (m.get("patch") or {}).get("version"), sorted((m.get("legacy") or {}).keys()), bool(m.get("broadcast"))))
    try:
        import urllib.request
        with urllib.request.urlopen(MANIFEST_URL + "?t=%d" % int(time.time()), timeout=8) as r:
            m = json.loads(r.read().decode("utf-8"))
        print("published: base %s, patch %s" % (m.get("base"), (m.get("patch") or {}).get("version")))
    except Exception as e:  # noqa: BLE001
        print("published manifest: not reachable (%s)" % e)


def cmd_broadcast(args) -> None:
    ensure_repo()
    m = read_manifest()
    if not m:
        sys.exit("no manifest yet: publish a base first")
    if args.clear or not args.es:
        m.pop("broadcast", None)
        message = "broadcast cleared"
    else:
        m["broadcast"] = {"id": str(int(time.time())), "es": args.es, "en": args.en or args.es}
        message = "broadcast: %s" % args.es
    write_manifest(m)
    commit(message, args.push)


def main() -> None:
    import argparse
    p = argparse.ArgumentParser(description="Lost Signal releases: full builds (itch.io) and patches (in-game updates).")
    sub = p.add_subparsers(dest="cmd")
    f = sub.add_parser("full", help="full build (the base); --push: itch.io + the new manifest")
    f.add_argument("--push", action="store_true")
    f.add_argument("--hidden", action="store_true")
    f.add_argument("--manifest-only", action="store_true", help="the base is already on itch: only publish its manifest")
    pa = sub.add_parser("patch", help="a patch over the base; --push: publish it")
    pa.add_argument("version")
    pa.add_argument("--push", action="store_true")
    pa.add_argument("--force", action="store_true")
    sub.add_parser("status", help="the base and the published manifest")
    b = sub.add_parser("broadcast", help="a message from the GM (no text or --clear: removes it)")
    b.add_argument("es", nargs="?")
    b.add_argument("en", nargs="?")
    b.add_argument("--clear", action="store_true")
    b.add_argument("--push", action="store_true")
    argv = sys.argv[1:]
    if not argv or argv[0].startswith("--"):
        argv = ["full"] + argv  # (the old way: release.py [--push])
    args = p.parse_args(argv)
    {"full": cmd_full, "patch": cmd_patch, "status": cmd_status, "broadcast": cmd_broadcast}[args.cmd](args)


if __name__ == "__main__":
    main()
