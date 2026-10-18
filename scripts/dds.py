"""Legacy BC3/DXT5 DDS encoder with a complete mip chain for ESO."""
from io import BytesIO
import struct

from PIL import Image


def encode(image: Image.Image) -> bytes:
    image = image.convert("RGBA")
    levels = max(image.width, image.height).bit_length()
    payloads = []
    for level in range(levels):
        width = max(1, image.width >> level)
        height = max(1, image.height >> level)
        buffer = BytesIO()
        image.resize((width, height), Image.Resampling.LANCZOS).save(
            buffer, format="DDS", pixel_format="DXT5"
        )
        payloads.append(buffer.getvalue())

    header = bytearray(payloads[0][:128])
    struct.pack_into("<I", header, 8, struct.unpack_from("<I", header, 8)[0] | 0x20000)
    struct.pack_into("<I", header, 20, len(payloads[0]) - 128)
    struct.pack_into("<I", header, 28, levels)
    struct.pack_into("<I", header, 88, 0)
    struct.pack_into("<I", header, 108, 0x1000 | 0x8 | 0x400000)
    result = bytes(header) + b"".join(level[128:] for level in payloads)
    assert result[:4] == b"DDS " and result[84:88] == b"DXT5"
    return result
