"""Package an already exported Windows game. Run from any working directory."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
root = Path(__file__).resolve().parents[1]
out = root / 'release'; out.mkdir(exist_ok=True)
archive = out / 'GTA_Tiraspol_Windows_v0.3.0.zip'
files = ['GTA_Tiraspol.exe', 'GTA_Tiraspol.pck', 'Touareg.ico', 'Create_Desktop_Shortcut.vbs', 'README.md', 'LICENSE']
with ZipFile(archive, 'w', ZIP_DEFLATED, compresslevel=9) as z:
    for name in files:
        z.write(root/name, 'GTA Tiraspol/'+name)
    for folder in ['licenses', 'project', 'build_tools', 'docs']:
        for p in sorted((root/folder).rglob('*')):
            if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts:
                z.write(p, 'GTA Tiraspol/'+p.relative_to(root).as_posix())
(out/'SHA256SUMS.txt').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
print(archive, archive.stat().st_size)
