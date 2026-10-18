"""Package untouched ImageGen masters as DDS; draw the existing code-native frame system.
ImageGen art receives format conversion/resizing only. Originals remain in art/.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math
from dds import encode
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'PBsTradeGame/assets'
def save_dds(name, image):
    (OUT/f'{name}.dds').write_bytes(encode(image))

for source,name,size in [('treasury','treasury',(2048,1024)),('merchant-crest','crest',(256,256)),('atlas','atlas',(1024,1024))]:
    save_dds(name, Image.open(ROOT/'art'/f'{source}-master.png').convert('RGBA').resize(size,Image.Resampling.LANCZOS))
im=Image.new('RGBA',(512,256))
for y in range(256):
    for x in range(512):
        grain=math.sin(y*.7+math.sin(x*.023)*3)*3+math.sin(y*.16+x*.015)*4
        im.putpixel((x,y),(int(43+grain),int(32+grain*.7),int(22+grain*.5),255))
d=ImageDraw.Draw(im)
for inset,color in [(1,'#271e14'),(3,'#91713b'),(5,'#433220'),(9,'#6e5834'),(12,'#241e16')]:
    d.rectangle((inset,inset,511-inset,255-inset),outline=color,width=2)
for x in (20,492):
    for y in (20,236):
        d.polygon([(x,y-9),(x+9,y),(x,y+9),(x-9,y)],fill='#7f673c',outline='#bea26a')
        d.ellipse((x-2,y-2,x+2,y+2),fill='#271c12')
save_dds('wood_frame',im)
print('Packaged treasury, atlas, crest, original wood frame')

# Original code-native elliptical counting plinth. Coins are layered above this surface.
im=Image.new('RGBA',(604,192))
d=ImageDraw.Draw(im)
d.ellipse((4,42,600,188),fill='#282826',outline='#615c4b',width=3)
for x in range(18,600,12):
    t=(x-302)/298
    rim=math.sqrt(max(0,1-t*t))
    y=76+rim*72
    d.line((x,y,x,y+33),fill='#44433c',width=2)
d.ellipse((4,4,600,151),fill='#55554a',outline='#948466',width=4)
d.ellipse((16,10,588,141),fill='#41453e',outline='#75684e',width=3)
d.ellipse((30,17,574,132),outline='#55584c',width=2)
# Subtle engraved rays remain original geometry, not pixels from the reference game.
for angle in range(0,360,15):
    a=math.radians(angle)
    d.line((302+251*math.cos(a),75+51*math.sin(a),302+270*math.cos(a),75+58*math.sin(a)),fill='#77715a',width=2)
save_dds('coin_plinth',im.resize((512,128),Image.Resampling.LANCZOS))
print('Built original elliptical counting plinth')

# A neutral white traveling sheen; Lua tints and moves it independently for each side.
im=Image.new('RGBA',(128,32),(255,255,255,0))
for x in range(128):
    distance=abs(x-63.5)/63.5
    alpha=int(210*max(0,1-distance)**2.8)
    for y in range(32): im.putpixel((x,y),(255,255,255,alpha))
save_dds('band_glow',im)
print('Built animated priority-band sheen')
