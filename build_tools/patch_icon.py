"""Patch Godot's Windows release template with the project's Touareg icon."""
import sys, io
from pathlib import Path
import lief
from PIL import Image
src, dst = map(Path, sys.argv[1:3])
image = Image.open(Path(__file__).resolve().parents[1] / 'project/assets/icon.png')
pe = lief.PE.parse(str(src))
for old in list(pe.resources_manager.icons):
    size = old.width or 256
    data = io.BytesIO()
    image.resize((size, size), Image.Resampling.LANCZOS).save(data, format='ICO', sizes=[(size, size)])
    icon = lief.PE.ResourceIcon.from_serialization(data.getvalue())
    icon.id = old.id
    pe.resources_manager.change_icon(old, icon)
config = lief.PE.Builder.config_t()
config.resources = True
builder = lief.PE.Builder(pe, config)
builder.build()
builder.write(str(dst))
