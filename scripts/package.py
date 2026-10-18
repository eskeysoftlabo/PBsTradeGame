"""Validate manifest paths (case-sensitive) and create an installable add-on ZIP."""
from pathlib import Path
import zipfile
import re
import struct
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
addon = root / "PBsTradeGame"
manifest = addon / "PBsTradeGame.txt"
console_manifest = addon / "PBsTradeGame.addon"
assert manifest.read_bytes() == console_manifest.read_bytes(), "Console and source manifests differ"
entries = []
for line in manifest.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    entries.append(line)
    path = addon / line
    assert path.is_file(), f"Missing manifest file: {line}"
    current = addon
    for part in Path(line).parts:
        assert part in [entry.name for entry in current.iterdir()], f"Case mismatch: {line}"
        current /= part
runtime = {p.relative_to(addon).as_posix() for p in addon.rglob("*")
    if p.is_file() and p.suffix.lower() in (".lua", ".xml", ".dds")
    and not any(part.startswith(".") for part in p.relative_to(addon).parts)}
assert runtime == set(entries), f"Manifest mismatch: {sorted(runtime ^ set(entries))}"
bindings = ET.parse(addon / "Bindings.xml")
# Match the working PX games' public UI actions. XML syntax alone missed a
# non-existent TOGGLE_GAME_MENU AllowAction, which prevented the client loading.
allowed = {"UI_SHORTCUT_" + suffix for suffix in (
    "PRIMARY", "NEGATIVE", "SECONDARY", "TERTIARY", "LEFT_SHOULDER", "RIGHT_SHOULDER")}
for action in bindings.findall(".//AllowAction"):
    assert action.attrib["name"] in allowed, f"Unsupported allowed action: {action.attrib['name']}"
# The D-pad must come from these events; polling ZO_DI_DPAD calls private IsKeyDown.
assert {a.attrib["inheritsBindFrom"] for a in bindings.findall(".//Action")} == {
    "UI_SHORTCUT_INPUT_" + d for d in ("LEFT", "RIGHT", "UP", "DOWN")}
assert "ZO_DI_DPAD" not in (addon / "UI.lua").read_text().split("Never query ZO_DI_DPAD")[1]
assert [layer.attrib["name"] for layer in bindings.findall("Layer")] == ["PBTradeInput"]
sizes = {"coin":(128,64),"coin_plinth":(512,128),"treasury":(2048,1024),"title_hall":(1024,512),"ember":(512,512),
    "crest":(256,256),"atlas":(1024,1024),"wood_frame":(512,256),"band_glow":(128,32),
    "band_tip_left":(128,32),"band_tip_right":(128,32),
    **{f"chapter_{i}":(1024,512) for i in range(1,6)}}
sizes.update({"hub_"+name:(512,512) for name in ("bank","market","warehouse","tavern","guildhall","ground","tree","cypress","walkway","bureau","gate")})
for path in (addon / "assets").glob("*.dds"):
    data = path.read_bytes()
    assert data[:4] == b"DDS " and data[84:88] == b"DXT5", f"Not legacy DXT5: {path.name}"
    height,width = struct.unpack_from("<II",data,12)
    levels = struct.unpack_from("<I",data,28)[0]
    assert (width,height) == sizes[path.stem]
    assert levels == max(width,height).bit_length(), f"Incomplete mip chain: {path.name}"
version = re.search(r"^## Version: (\d+\.\d+\.\d+)$", manifest.read_text(), re.M).group(1)
assert f'version = "{version}"' in (addon / "Config.lua").read_text()
# Add-on list entry: series prefix, pink colour code, version after the name (as the other PB add-ons).
assert re.search(r"^## Author: \|cFF69B4PinkBanther\|r$", manifest.read_text(), re.M), "Author must be pink: '|cFF69B4PinkBanther|r'"
assert re.search(rf"^## Title: \|cFF69B4PB's Tamriel de Trade\|r {re.escape(version)}$", manifest.read_text(), re.M), "Title must be '|cFF69B4PB's Tamriel de Trade|r <version>'"
major,minor,patch=map(int,version.split("."))
assert f"## AddOnVersion: {major*10000+minor*100+patch}" in manifest.read_text()
output = root / f"dist/PBsTradeGame-{version}.zip"
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(addon.rglob("*")):
        if path.is_file() and not path.name.startswith("."):
            archive.write(path, path.relative_to(root))
print(output)
