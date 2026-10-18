"""Render the Lua UI harness's control geometry. Not an ESO screenshot.
Pillow and a Japanese system font are needed only for this developer preview.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops

root = Path(__file__).resolve().parents[1]
font_path = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
output = root / "docs/previews"
output.mkdir(parents=True, exist_ok=True)
for name in ("opening", "ending_ember", "title", "naming", "map", "property", "battle", "tactic", "admin", "rankings", "hub", "hub_full", "hub_district", "hub_expanded", "hub_advanced", "hub_operations"):
    lines = (root / f"tests/{name}.layout").read_text().splitlines()
    _, width, height = lines.pop(0).split("\t")
    im = Image.new("RGBA", (int(width), int(height)), "#090c0b")
    for line in lines:
        kind, x, y, w, h, color, size, edge, clip, uv, align, text = line.split("\t", 11)
        x, y, w, h = map(lambda v: round(float(v)), (x, y, w, h))
        rgba = tuple(round(float(v) * 255) for v in color.split(","))
        if len(rgba) == 3:
            rgba += (255,)
        draw = ImageDraw.Draw(im)
        if kind == "box":
            layer = Image.new("RGBA", im.size)
            border = tuple(round(float(v) * 255) for v in edge.split(","))
            shape = ImageDraw.Draw(layer)
            shape.rectangle((x, y, x+w, y+h), fill=rgba)
            if border[3]:
                shape.rectangle((x, y, x+w, y+h), outline=border, width=1)
            im.alpha_composite(layer)
        elif kind == "texture":
            sprite = Image.open(root / text).convert("RGBA")
            ul, ur, ut, ub = map(float, uv.split(","))
            sprite = sprite.crop((ul*sprite.width, ut*sprite.height, ur*sprite.width, ub*sprite.height)).resize((w, h))
            sprite = ImageChops.multiply(sprite, Image.new("RGBA", sprite.size, rgba))
            cx, cy, cw, ch = map(lambda v: round(float(v)), clip.split(","))
            left, top = max(x, cx), max(y, cy)
            right, bottom = min(x+w, cx+cw), min(y+h, cy+ch)
            if right > left and bottom > top:
                im.alpha_composite(sprite.crop((left-x, top-y, right-x, bottom-y)), (left, top))
        elif kind == "text":
            font = ImageFont.truetype(font_path, int(float(size)))
            # Wrap to the native label width, but leave line clipping visible for QA.
            lines = []
            for paragraph in text.replace("\\n", "\n").split("\n"):
                part = ""
                for char in paragraph:
                    if part and draw.textlength(part+char, font=font) > w:
                        lines.append(part); part = ""
                    part += char
                lines.append(part)
            if align == "right":
                for i, text_line in enumerate(lines):
                    offset = w - draw.textlength(text_line, font=font)
                    draw.text((x + offset, y + i*(int(float(size))+3)), text_line, font=font, fill=rgba)
            elif align == "center":
                for i, text_line in enumerate(lines):
                    offset = (w - draw.textlength(text_line, font=font)) / 2
                    draw.text((x + offset, y + i*(int(float(size))+3)), text_line, font=font, fill=rgba)
            else:
                draw.multiline_text((x, y), "\n".join(lines), font=font, fill=rgba, spacing=3)
    im.convert("RGB").save(output / f"{name}.png")
    print(output / f"{name}.png")
