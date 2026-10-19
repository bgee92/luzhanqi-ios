#!/usr/bin/env python3
"""Rebuild the bundled font subsets in App/Fonts.

The app bundles three open-licensed (SIL OFL 1.1) Google Fonts, cut down to the
characters it actually uses so they stay small:

  - Noto Serif SC, Black (900): Chinese piece names and headings. Subset to every
    CJK character in App/Strings.swift and RULES.zh.md, plus ASCII.
  - Ma Shan Zheng: the brush-script title and result seals only.
  - Big Shoulders Display, ExtraBold (800): English piece labels and headings, ASCII.

Re-run after adding Chinese text to Strings.swift or RULES.zh.md, or new
characters will fall back to the system font:

    python3 -m venv /tmp/fontenv && /tmp/fontenv/bin/pip install fonttools
    /tmp/fontenv/bin/python Tools/subset_fonts.py <dir with the downloaded fonts>

Source files (from https://github.com/google/fonts, under ofl/):
  notoserifsc/NotoSerifSC[wght].ttf, mashanzheng/MaShanZheng-Regular.ttf,
  bigshouldersdisplay/BigShouldersDisplay[wght].ttf
"""

import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "App" / "Fonts"
ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
BRUSH_TEXT = "陆战棋胜败和"


def used_cjk() -> str:
    text = (ROOT / "App" / "Strings.swift").read_text() + (ROOT / "RULES.zh.md").read_text()
    chars = {c for c in text if ord(c) >= 0x2E80}  # CJK, CJK punctuation and full-width forms
    return "".join(sorted(chars | set("八一")))


def rename(font: TTFont, family: str, style: str) -> None:
    """Name a static instance after its weight (the variable font's names say Thin)."""
    postscript = f"{family}-{style}".replace(" ", "")
    for record in list(font["name"].names):
        if record.nameID in (1, 2, 3, 4, 6, 16, 17):
            font["name"].removeNames(nameID=record.nameID)
    for name_id, value in {1: family, 2: "Regular", 3: postscript, 4: f"{family} {style}", 6: postscript,
                           16: family, 17: style}.items():
        font["name"].setName(value, name_id, 3, 1, 0x409)
        font["name"].setName(value, name_id, 1, 0, 0)


def build(source: pathlib.Path, out_name: str, text: str, weight: float | None = None,
          family: str | None = None, style: str | None = None) -> None:
    font = TTFont(source)
    if weight is not None and "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": weight})
        rename(font, family, style)
        font["OS/2"].usWeightClass = int(weight)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    path = OUT / out_name
    font.save(path)
    print(f"{out_name}: {len(set(text))} characters, {path.stat().st_size // 1024} KB")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = pathlib.Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    build(next(src.glob("*NotoSerifSC*.ttf")), "NotoSerifSC-Black-Subset.ttf", used_cjk() + ASCII,
          weight=900, family="Noto Serif SC", style="Black")
    build(next(src.glob("*MaShanZheng*.ttf")), "MaShanZheng-Subset.ttf", BRUSH_TEXT)
    build(next(src.glob("*BigShouldersDisplay*.ttf")), "BigShouldersDisplay-ExtraBold-Subset.ttf", ASCII,
          weight=800, family="Big Shoulders Display", style="ExtraBold")


if __name__ == "__main__":
    main()
