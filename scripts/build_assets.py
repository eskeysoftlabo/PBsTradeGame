"""Convert the approved imagegen coin master to an alpha-preserving ESO DDS sprite.
The original art stays untouched; only delivery resolution/format are changed.
"""
from pathlib import Path
from PIL import Image, ImageDraw
from dds import encode
root = Path(__file__).resolve().parents[1]
im = Image.open(root / 'art/coin-master.png').convert('RGBA')
assert im.getchannel('A').getextrema() == (0, 255), 'Coin must have true transparency'
out = root / 'PBsTradeGame/assets/coin.dds'
out.write_bytes(encode(im.resize((128, 64), Image.Resampling.LANCZOS)))
print(out)

# White alpha masks are tinted by UI.lua. Separate directions avoid relying on
# mirrored texture coordinates, which are inconsistent across console builds.
for name,points in {
    "band_tip_right":((0,0),(0,31),(127,16)),
    "band_tip_left":((127,0),(127,31),(0,16)),
}.items():
    tip=Image.new("RGBA",(128,32),(255,255,255,0))
    ImageDraw.Draw(tip).polygon(points,fill=(255,255,255,255))
    path=root/f"PBsTradeGame/assets/{name}.dds"
    path.write_bytes(encode(tip)); print(path)
