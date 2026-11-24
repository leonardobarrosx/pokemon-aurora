from pathlib import Path
import hashlib,json
from PIL import Image

root=Path(__file__).resolve().parents[1]/'client/assets/indigo'
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
for name,meta in manifest['files'].items():
    p=root/name
    assert hashlib.sha256(p.read_bytes()).hexdigest()==meta['sha256'],name
    assert list(Image.open(p).size)==meta['size'],name
catalog=json.loads((root/'character/catalog.json').read_text(encoding='utf-8'))
layers=0
for part in catalog['parts'].values():
    for name in part['modes'].values():
        image=Image.open(root/'character'/name).convert('RGBA')
        # Every logical art pixel remains a 2x2 block after the Ruby conversion.
        small=image.resize((image.width//2,image.height//2),Image.Resampling.NEAREST)
        assert small.resize(image.size,Image.Resampling.NEAREST).tobytes()==image.tobytes(),name
        layers+=1
for sid,mon in manifest['pokemon'].items():
    if 'follower' in mon:
        w,h=mon['follower']['size'];assert w==h and w%4==0,sid
print(f'PASS: {len(manifest["files"])} assets com hashes íntegros; {len(catalog["parts"])} peças / {layers} camadas em 2x; seguidores 4x4.')
