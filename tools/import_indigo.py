"""Copy verified source assets. Never alter the owner's installed game."""
from pathlib import Path
import hashlib, json, shutil, sys
from PIL import Image

source=Path(sys.argv[1] if len(sys.argv)>1 else 'C:/dev/Pokemon Anil V4.13')
root=Path(__file__).resolve().parents[1]
dest=root/'client/assets/indigo'
manifest={'source':str(source),'files':{},'pokemon':{}}
def copy(relative,target):
    p=source/'Graphics'/relative;out=dest/target
    if not p.is_file(): raise FileNotFoundError(p)
    with Image.open(p) as im: size=list(im.size)
    out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,out)
    manifest['files'][target]={'source':'Graphics/'+relative,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'size':size}
    return size
for name in ['Interior1','Exterior1','Cueva1','ExteriorSafari','InteriorLiga']:
    copy('Tilesets/'+name+'.png','source_atlases/'+name+'.png')
    im=Image.open(source/'Graphics/Tilesets'/(name+'.png')).convert('RGBA')
    (dest/'tilesets').mkdir(parents=True,exist_ok=True)
    for band,y in enumerate(range(0,im.height,4096)):
        im.crop((0,y,im.width,min(y+4096,im.height))).save(dest/'tilesets'/f'{name}-{band}.png')
(dest/'source_atlases/.gdignore').write_text('')
copy('Tilesets/Creditos.png','tilesets/Creditos.png')
for name in ['agua','Agua cueva','florAmarilla']:
    p=source/'Graphics/Autotiles'/(name+'.png')
    if p.exists():copy('Autotiles/'+name+'.png','autotiles/'+name+'.png')
mons={1:'BULBASAUR',2:'IVYSAUR',4:'CHARMANDER',5:'CHARMELEON',7:'SQUIRTLE',8:'WARTORTLE',16:'PIDGEY',19:'RATTATA',25:'PIKACHU',26:'RAICHU',41:'ZUBAT',74:'GEODUDE',95:'ONIX',129:'MAGIKARP',130:'GYARADOS',131:'LAPRAS',133:'EEVEE',134:'VAPOREON',135:'JOLTEON',136:'FLAREON',151:'MEW'}
for sid,name in mons.items():
    entry={'name':name}
    for mode,folder in [('front','Pokemon/Front'),('back','Pokemon/Back'),('follower','Characters/Followers')]:
        path=f'{folder}/{name}.png'
        if (source/'Graphics'/path).is_file():
            size=copy(path,f'pokemon/{sid}-{mode}.png')
            entry[mode]={'file':f'pokemon/{sid}-{mode}.png','size':size,'frame':size[1] if mode!='follower' else size[0]//4,'frames':size[0]//size[1] if mode!='follower' else 4}
            if mode=='follower':
                sheet=Image.open(source/'Graphics'/path).convert('RGBA');n=size[0]//4;anchors=[]
                for row in range(4):
                    for col in range(4):
                        box=sheet.crop((col*n,row*n,(col+1)*n,(row+1)*n)).getchannel('A').getbbox() or (0,0,n,n)
                        anchors.append({'center':[(box[0]+box[2])/2,(box[1]+box[3])/2],'feet':[(box[0]+box[2])/2,box[3]]})
                entry[mode]['anchors']=anchors
    manifest['pokemon'][str(sid)]=entry
for name in ['015-Fire01','016-Ice01','017-Thunder01','018-Water01','fire blast','PRAS- Hydro Pump','PRAS- Solar Beam','PRAS- Ice','PRAS- Thunderbolt']:
    if (source/'Graphics/Animations'/(name+'.png')).is_file():copy('Animations/'+name+'.png','effects/'+name+'.png')
for name in ['POKEBALL','POTION','FIRESTONE','WATERSTONE','THUNDERSTONE','MOONSTONE','ORANBERRY']:
    if (source/'Graphics/Items'/(name+'.png')).is_file():copy('Items/'+name+'.png','items/'+name+'.png')
dest.mkdir(parents=True,exist_ok=True)
(dest/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Copied {len(manifest["files"])} verified images from {source}. Source untouched.')
