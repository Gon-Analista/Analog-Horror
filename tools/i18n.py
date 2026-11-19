"""Translations: gathers every text the game shows and keeps the catalogues
in step (gettext, which Godot reads natively).

The game is written in Spanish: the Spanish text itself is the key (msgid),
so Spanish needs no catalogue. Every other language is one file,
game/locale/<code>.po, with a translation (msgstr) under each key.

    python tools/i18n.py            # refresh messages.pot and every .po
    python tools/i18n.py --check    # list what is missing, change nothing

Where texts are found (game/scripts/**/*.gd):
    tr("...")  tr_n("...", "...", n)  TranslationServer.translate("...")
    and every string on a line marked with a "# i18n" comment (lists of
    texts translated later, like the TV's counting).

A new language: copy messages.pot to game/locale/<code>.po (fr, pt_BR...),
set "Language: <code>" and the plural rule in its header, translate every
msgstr, add "Language-Name: <its own name>" (shown in the options), run
this script, and add the file to project.godot
(internationalization/locale/translations). Missing translations fall back
to Spanish.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
LOCALE = GAME / "locale"
SKIP = ("scripts/dev/",)  # dev-only tools (tests, tours) stay as they are

STR = r'"((?:[^"\\]|\\.)*)"'
CALLS = [
    re.compile(r'(?<![\w.])tr\(\s*' + STR + r'\s*\)'),
    re.compile(r'TranslationServer\.translate\(\s*' + STR + r'\s*\)'),
]
PLURAL = re.compile(r'(?<![\w.])tr_n\(\s*' + STR + r'\s*,\s*' + STR)
ANY = re.compile(STR)


def gather():
    """[(msgid, plural or None, ["file:line", ...])], in order of appearance."""
    found = {}
    order = []
    for path in sorted((GAME / "scripts").rglob("*.gd")):
        rel = path.relative_to(GAME).as_posix()
        if rel.startswith(SKIP):
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("##")[0]
            hits = []
            for rx in CALLS:
                hits += [(m.group(1), None) for m in rx.finditer(code)]
            hits += [(m.group(1), m.group(2)) for m in PLURAL.finditer(code)]
            if "# i18n" in line:
                hits += [(m.group(1), None) for m in ANY.finditer(code.split("# i18n")[0])]
            for msgid, plural in hits:
                if msgid == "":
                    continue
                if msgid not in found:
                    found[msgid] = [plural, []]
                    order.append(msgid)
                found[msgid][1].append("%s:%d" % (rel, n))
    return [(m, found[m][0], found[m][1]) for m in order]


def parse_po(path):
    """{msgid: [msgstr, ...]} and the header lines, from a .po file."""
    entries = {}
    header = []
    if not path.exists():
        return entries, header
    cur = None
    field = None
    for raw in path.read_text(encoding="utf-8").splitlines() + [""]:
        line = raw.strip()
        if not line:
            if cur is not None:
                if cur["msgid"] == "":
                    header = cur["msgstr"][0].split("\\n")
                else:
                    entries[cur["msgid"]] = cur["msgstr"]
            cur = None
            continue
        if line.startswith("#"):
            continue
        if cur is None:
            cur = {"msgid": "", "plural": None, "msgstr": [""]}
        m = re.match(r'(msgid_plural|msgid|msgstr\[(\d+)\]|msgstr)\s+' + STR + r'$', line)
        if m:
            key, idx, text = m.group(1), m.group(2), m.group(3)
            if key == "msgid":
                field = ("msgid", None)
                cur["msgid"] = text
            elif key == "msgid_plural":
                field = ("plural", None)
                cur["plural"] = text
            else:
                i = int(idx) if idx else 0
                while len(cur["msgstr"]) <= i:
                    cur["msgstr"].append("")
                field = ("msgstr", i)
                cur["msgstr"][i] = text
        elif line.startswith('"'):
            text = re.match(STR, line).group(1)
            if field[0] == "msgstr":
                cur["msgstr"][field[1]] += text
            elif field[0] == "plural":
                cur["plural"] += text
            else:
                cur["msgid"] += text
    return entries, [h for h in header if h]


def write_catalogue(path, header, texts, translations=None):
    out = ['msgid ""', 'msgstr ""']
    out += ['"%s\\n"' % h for h in header]
    out.append("")
    for msgid, plural, where in texts:
        out.append("#: " + " ".join(where[:4]))
        out.append('msgid "%s"' % msgid)
        old = (translations or {}).get(msgid, [])
        if plural is not None:
            out.append('msgid_plural "%s"' % plural)
            for i in range(2):
                out.append('msgstr[%d] "%s"' % (i, old[i] if i < len(old) else ""))
        else:
            out.append('msgstr "%s"' % (old[0] if old else ""))
        out.append("")
    path.write_text("\n".join(out), encoding="utf-8", newline="\n")


def main():
    texts = gather()
    check = "--check" in sys.argv
    LOCALE.mkdir(exist_ok=True)
    pot_header = ["Project-Id-Version: Lost Signal - Analog Horror", "MIME-Version: 1.0",
                  "Content-Type: text/plain; charset=UTF-8", "Content-Transfer-Encoding: 8bit",
                  "Language: ", "Plural-Forms: nplurals=2; plural=(n != 1);"]
    if not check:
        write_catalogue(LOCALE / "messages.pot", pot_header, texts)
    missing_total = 0
    for po in sorted(LOCALE.glob("*.po")):
        entries, header = parse_po(po)
        missing = [m for m, p, _ in texts if not any(entries.get(m, []))]
        stale = [m for m in entries if m not in {t[0] for t in texts}]
        missing_total += len(missing)
        print("%s: %d texts, %d missing, %d no longer used" % (po.name, len(texts), len(missing), len(stale)))
        for m in missing[:40]:
            print("   missing:", m)
        if not check:
            write_catalogue(po, header or pot_header, texts, entries)
    print("%d texts in messages.pot" % len(texts))
    sys.exit(1 if check and missing_total else 0)


if __name__ == "__main__":
    main()
