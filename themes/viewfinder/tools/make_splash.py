#!/usr/bin/env python3
"""The pictures of the start-up and shut-down page (system/plymouth), drawn
for a 1800 px tall screen (the G14); page.script fits them to others.

    python3 tools/make_splash.py

White on transparent, in the shell's typeface: the viewfinder's corner
marks, the focusing mark, the heading and the words under it.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BOX = Path(__file__).resolve().parents[1]
OUT = BOX / "system/plymouth"
FONT = BOX / "home/.local/share/fonts/viewfinder/JetBrainsMono-Regular.ttf"
INK = (242, 239, 237, 255)
K = 1.5                                   # the G14 draws at 1.5


def text(name, words, size, tracking):
    font = ImageFont.truetype(str(FONT), int(size * K))
    gap = tracking * K
    widths = [font.getlength(ch) for ch in words]
    w = int(sum(widths) + gap * (len(words) - 1)) + 4
    h = int(size * K * 1.5)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = 2
    for ch, cw in zip(words, widths):
        d.text((x, h * 0.12), ch, font=font, fill=INK)
        x += cw + gap
    im.save(OUT / name)


def corner(name, arm, weight, flip_x, flip_y):
    a, t = int(arm * K), int(weight * K)
    im = Image.new("RGBA", (a, a), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, a - 1, t - 1], fill=INK)
    d.rectangle([0, 0, t - 1, a - 1], fill=INK)
    if flip_x:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if flip_y:
        im = im.transpose(Image.FLIP_TOP_BOTTOM)
    im.save(OUT / name)


def focus_mark():
    w, h, a, t = int(132 * K), int(108 * K), int(26 * K), int(3 * K)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x0, y0, sx, sy in [(0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)]:
        d.rectangle(sorted([x0, x0 + sx * (a - 1)])[:1] + sorted([y0, y0 + sy * (t - 1)])[:1]
                    + sorted([x0, x0 + sx * (a - 1)])[1:] + sorted([y0, y0 + sy * (t - 1)])[1:], fill=INK)
        d.rectangle(sorted([x0, x0 + sx * (t - 1)])[:1] + sorted([y0, y0 + sy * (a - 1)])[:1]
                    + sorted([x0, x0 + sx * (t - 1)])[1:] + sorted([y0, y0 + sy * (a - 1)])[1:], fill=INK)
    c, l = int(10 * K), int(2 * K)
    d.rectangle([w // 2 - c, h // 2 - l // 2, w // 2 + c, h // 2 + l // 2], fill=INK)
    d.rectangle([w // 2 - l // 2, h // 2 - c, w // 2 + l // 2, h // 2 + c], fill=INK)
    im.save(OUT / "mark.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    corner("corner-tl.png", 34, 3, False, False)
    corner("corner-tr.png", 34, 3, True, False)
    corner("corner-bl.png", 34, 3, False, True)
    corner("corner-br.png", 34, 3, True, True)
    focus_mark()
    text("heading.png", "VIEWFINDER", 22, 7)
    text("line-boot.png", "STARTING UP", 14, 3)
    text("line-shutdown.png", "SHUTTING DOWN", 14, 3)
    text("line-reboot.png", "RESTARTING", 14, 3)
    text("line-updates.png", "UPDATING", 14, 3)
    text("prompt.png", "PASSPHRASE", 14, 3)
    Image.new("RGBA", (int(300 * K), 2), INK).save(OUT / "rule.png")
    b = Image.new("RGBA", (int(10 * K), int(10 * K)), (0, 0, 0, 0))
    ImageDraw.Draw(b).ellipse([0, 0, b.width - 1, b.height - 1], fill=INK)
    b.save(OUT / "bullet.png")


if __name__ == "__main__":
    main()
