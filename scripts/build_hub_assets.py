"""Package original imagegen PNGs into legacy DXT5, preserving transparent alpha."""
from pathlib import Path
from PIL import Image
from dds import encode
root = Path(__file__).resolve().parents[1]
for name in ('bank','market','warehouse','tavern','guildhall','ground','tree','cypress','walkway','bureau','gate'):
    source=root/'art/hub'/f'hub_{name}.png'
    im=Image.open(source).convert('RGBA')
    assert im.getchannel('A').getextrema()==(0,255), f'Missing alpha: {name}'
    im=im.resize((512,512),Image.Resampling.LANCZOS)
    (root/'PBsTradeGame/assets'/f'hub_{name}.dds').write_bytes(encode(im))
    print(name)
