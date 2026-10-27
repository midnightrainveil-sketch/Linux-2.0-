#!/usr/bin/env python3
"""The emoji and symbols for the picker (Super + .), from GitHub's gemoji.

    curl -LO https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json
    python3 tools/make_emoji.py emoji.json

gemoji (MIT licence, github.com/github/gemoji) gives each emoji its name,
group and a few words people search it by. Its groups are kept, in its
order, under shorter names, and a group of typed marks (dashes, quotes,
arrows, signs) is added after them, for the things a keyboard does not
have. Writes dotfiles/.config/quickshell/assets/emoji/emoji.json:

    {"groups": [{"name": "Faces", "tab": "😀", "items": [["😀", "grinning face", "grinning smile happy"], ...]}, ...]}
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DST = ROOT / "dotfiles" / ".config" / "quickshell" / "assets" / "emoji" / "emoji.json"

GROUPS = [   # gemoji's category, the picker's name for it, its tab
    ("Smileys & Emotion", "Faces", "😀"),
    ("People & Body", "People", "👋"),
    ("Animals & Nature", "Nature", "🌿"),
    ("Food & Drink", "Food", "🍞"),
    ("Travel & Places", "Travel", "🚲"),
    ("Activities", "Activities", "⚽"),
    ("Objects", "Objects", "💡"),
    ("Symbols", "Symbols", "❤️"),
    ("Flags", "Flags", "🏳️"),
]

# typed marks: what a keyboard lacks, with the words to find them by
MARKS = [
    ("—", "em dash long"), ("–", "en dash range"), ("…", "ellipsis dots"),
    ("“", "left double quote"), ("”", "right double quote"),
    ("‘", "left single quote"), ("’", "right single quote apostrophe"),
    ("«", "left guillemet quote"), ("»", "right guillemet quote"),
    ("•", "bullet"), ("·", "middle dot"), ("°", "degree"), ("′", "prime minute foot"), ("″", "double prime second inch"),
    ("±", "plus minus"), ("×", "times multiply"), ("÷", "divide"), ("≈", "approximately almost equal"),
    ("≠", "not equal"), ("≤", "less or equal"), ("≥", "greater or equal"), ("∞", "infinity"),
    ("√", "square root"), ("∑", "sum sigma"), ("∫", "integral"), ("∂", "partial"), ("∆", "delta increment"),
    ("π", "pi"), ("µ", "micro mu"), ("Ω", "ohm omega"), ("α", "alpha"), ("β", "beta"), ("γ", "gamma"),
    ("θ", "theta"), ("λ", "lambda"), ("σ", "sigma"), ("φ", "phi"),
    ("½", "half"), ("⅓", "third"), ("¼", "quarter"), ("¾", "three quarters"),
    ("¹", "superscript one"), ("²", "superscript two squared"), ("³", "superscript three cubed"),
    ("€", "euro"), ("£", "pound"), ("¥", "yen"), ("¢", "cent"), ("₹", "rupee"), ("₩", "won"), ("₿", "bitcoin"),
    ("©", "copyright"), ("®", "registered"), ("™", "trademark"), ("§", "section"), ("¶", "pilcrow paragraph"),
    ("†", "dagger"), ("‡", "double dagger"), ("№", "numero number"), ("‰", "per mille"),
    ("→", "right arrow"), ("←", "left arrow"), ("↑", "up arrow"), ("↓", "down arrow"), ("↔", "left right arrow"),
    ("⇒", "implies double arrow"), ("⇔", "if and only if"), ("↵", "return enter"), ("⌘", "command"), ("⌥", "option"),
    ("⇧", "shift"), ("⌫", "backspace erase"), ("✓", "check tick"), ("✗", "cross ballot"), ("★", "star black"),
    ("☆", "star white"), ("♪", "note music"), ("♥", "heart suit"), ("☐", "box unchecked"), ("☑", "box checked"),
    ("※", "reference mark"), ("‽", "interrobang"), ("¿", "inverted question"), ("¡", "inverted exclamation"),
    ("ß", "eszett sharp s"), ("æ", "ae ligature"), ("ø", "o slash"), ("å", "a ring"), ("é", "e acute"),
    ("è", "e grave"), ("ê", "e circumflex"), ("ñ", "n tilde"), ("ü", "u umlaut"), ("ç", "c cedilla"),
]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    db = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    by = {c: [] for c, _, _ in GROUPS}
    for e in db:
        if e.get("category") not in by:
            continue
        name = e.get("description", "")
        words = " ".join(w.replace("_", " ") for w in e.get("aliases", []) + e.get("tags", []) if w)
        by[e["category"]].append([e["emoji"], name, words])
    out = {"groups": [{"name": n, "tab": t, "items": by[c]} for c, n, t in GROUPS]}
    out["groups"].append({"name": "Marks", "tab": "¶", "items": [[m[0], m[1], ""] for m in MARKS]})
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("emoji:", DST.relative_to(ROOT), sum(len(g["items"]) for g in out["groups"]), "entries")


if __name__ == "__main__":
    main()
