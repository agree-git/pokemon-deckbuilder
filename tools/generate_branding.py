#!/usr/bin/env python3
"""Draw the original expedition emblem and boot screen (Pillow required)."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

NAVY = '#09141e'
INK = '#102734'
GOLD = '#e7c785'
CREAM = '#f4edd7'


def emblem():
    image = Image.new('RGBA', (128, 128))
    d = ImageDraw.Draw(image)
    # Three stepped cards form the expedition badge; all geometry is original.
    d.polygon([(18, 26), (40, 18), (45, 21), (68, 93), (65, 99), (43, 107), (38, 104), (14, 32)], fill=INK)
    d.polygon([(20, 29), (39, 23), (62, 93), (43, 100)], fill='#547b77')
    d.polygon([(87, 18), (110, 26), (114, 32), (90, 104), (85, 107), (63, 99), (60, 93), (82, 21)], fill=INK)
    d.polygon([(89, 23), (108, 29), (85, 100), (66, 93)], fill='#a78e59')
    d.polygon([(38, 13), (90, 13), (97, 20), (97, 107), (90, 114), (38, 114), (31, 107), (31, 20)], fill=INK)
    d.polygon([(40, 18), (88, 18), (92, 22), (92, 104), (88, 109), (40, 109), (36, 104), (36, 22)], fill=GOLD)
    d.rectangle((41, 23, 86, 104), fill='#25434a')
    # A bright compass point, a capture ball and a short route at the foot.
    d.polygon([(64, 26), (72, 40), (64, 37), (56, 40)], fill=CREAM)
    d.polygon([(64, 30), (64, 37), (56, 40)], fill='#bba05e')
    outline = [(52, 43), (76, 43), (76, 46), (84, 46), (84, 53), (88, 53), (88, 75), (84, 75), (84, 82), (76, 82), (76, 86), (52, 86), (52, 82), (44, 82), (44, 75), (40, 75), (40, 53), (44, 53), (44, 46), (52, 46)]
    d.polygon(outline, fill=INK)
    d.polygon([(53, 48), (75, 48), (75, 51), (80, 51), (80, 56), (83, 56), (83, 61), (45, 61), (45, 56), (48, 56), (48, 51), (53, 51)], fill='#e16b58')
    d.rectangle((52, 51, 60, 54), fill='#f5ab82')
    d.polygon([(45, 67), (83, 67), (83, 73), (80, 73), (80, 78), (75, 78), (75, 81), (53, 81), (53, 78), (48, 78), (48, 73), (45, 73)], fill=CREAM)
    d.rectangle((56, 56, 72, 73), fill=INK)
    d.rectangle((60, 60, 68, 69), fill=CREAM)
    d.rectangle((63, 91, 66, 94), fill=GOLD)
    d.rectangle((58, 95, 63, 97), fill=GOLD)
    d.rectangle((55, 98, 59, 100), fill=GOLD)
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-dir', type=Path, required=True)
    args = parser.parse_args()
    game = args.game_dir.resolve()
    output = game / 'assets/branding'
    output.mkdir(parents=True, exist_ok=True)
    icon = emblem().resize((512, 512), Image.Resampling.NEAREST)
    icon.save(output / 'expedition.png', optimize=True)
    # Store explicit nearest-neighbor frames, including crisp Explorer small sizes.
    sizes = [16, 32, 48, 64, 128, 256]
    frames = [icon.resize((s, s), Image.Resampling.NEAREST) for s in sizes]
    frames[-1].save(output / 'expedition.ico', sizes=[(s, s) for s in sizes], append_images=frames[:-1])
    splash = Image.new('RGB', (1920, 1080), NAVY)
    d = ImageDraw.Draw(splash)
    # Quiet horizon and a dotted path: the logo remains legible while loading.
    d.polygon([(0, 794), (260, 666), (445, 754), (700, 610), (938, 760), (1170, 636), (1440, 746), (1710, 630), (1920, 734), (1920, 1080), (0, 1080)], fill='#10242c')
    d.polygon([(0, 910), (325, 800), (596, 902), (870, 772), (1150, 905), (1508, 788), (1920, 934), (1920, 1080), (0, 1080)], fill='#142e34')
    for x, y in [(290, 235), (1550, 284), (1428, 152), (438, 378), (1640, 462)]:
        d.rectangle((x-3, y-3, x+3, y+3), fill='#65817b')
    for y in range(890, 1080, 35):
        x = 960 + int((y-890) * .26)
        d.rectangle((x-3, y, x+3, y+10), fill='#41605a')
    splash.paste(icon, (704, 122), icon)
    font_path = str(game / 'assets/fonts/NotoSansKR.ttf')
    def text(value, y, size, color, weight=500):
        font = ImageFont.truetype(font_path, size)
        font.set_variation_by_axes([weight])
        # Baseline-independent bbox centering for both Latin and Korean.
        box = d.textbbox((0, 0), value, font=font)
        d.text(((1920-(box[2]-box[0]))/2-box[0], y-box[1]), value, fill=color, font=font)
    text('포켓몬 원정대', 648, 86, GOLD, 750)
    text('P O K É M O N   E X P E D I T I O N', 774, 26, '#a6beb6')
    d.line((884, 844, 1036, 844), fill='#65817b', width=2)
    text('새로운 동료, 새로운 여정', 878, 25, '#b7c9bf')
    splash.save(output / 'boot_splash.png', optimize=True)
    print('Generated original 512px emblem, six-size ICO and 1920x1080 boot screen')


if __name__ == '__main__':
    main()
