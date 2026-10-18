"""Build Ember's ending portrait (assets/ember.dds, 512x512 DXT5 with mips) from her character sheet.

The face close-up sits in the sheet's top-left panel, so the crop is given as fractions of the
sheet and works at any resolution. Put the best sheet you have at art/ember/character-sheet.png
(or .jpg) and run:  python3 scripts/build_ember.py
"""
from pathlib import Path
import sys
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dds import encode

root = Path(__file__).resolve().parents[1]
source = next((p for p in (root / "art/ember/character-sheet.png", root / "art/ember/character-sheet.jpg") if p.exists()), None)
assert source, "art/ember/character-sheet.(png|jpg) not found"
sheet = Image.open(source).convert("RGB")
w, h = sheet.size
# Square around the face, inside the panel border and under its title strip.
box = (round(w * .0195), round(h * .049), round(w * .0195) + round(h * .410), round(h * .049) + round(h * .410))
face = sheet.crop(box)
face.save(root / "art/ember/ember_portrait.png")
portrait = face.resize((512, 512), Image.Resampling.LANCZOS).convert("RGBA")
(root / "PBsTradeGame/assets/ember.dds").write_bytes(encode(portrait))
print(f"{source.name} {w}x{h} -> crop {face.size} -> assets/ember.dds 512x512")
