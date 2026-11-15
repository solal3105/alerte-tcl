"""Assemble the layer document from the format saved by Apple Icon Composer."""
from pathlib import Path
import json, shutil
ROOT=Path(__file__).resolve().parent
DOC=ROOT/'AlerteTCL_LiquidGlass.icon'
ASSETS=DOC/'Assets';ASSETS.mkdir(exist_ok=True)
def group(name,files,translucency,shadow,blur=None):
    result={'name':name,'layers':[{'image-name':f,'name':n} for f,n in files],
        'shadow':{'kind':'neutral','opacity':shadow},
        'translucency':{'enabled':True,'value':translucency}}
    if blur is not None:result['blur-material']=blur
    return result
groups=[
    group('01 Radar en verre',[('Radar.svg','Disque de localisation')],.65,.20,.12),
    group('02 Balayage bleu',[('Balayage.svg','Secteur lumineux')],.55,.06),
    group('03 Anneaux et balises',[('Anneaux.svg','Distances'),('Balises.svg','Points de localisation')],.35,.12),
    group('04 Tram opalin 3D',[('Tram_3D.png','Tram - deux caisses')],.18,.35)
]
doc={'fill':{'automatic-gradient':'extended-srgb:0.84000,0.95000,0.92000,1.00000'},
     'groups':list(reversed(groups)),'supported-platforms':{'circles':['watchOS'],'squares':'shared'}}
for g in groups:
    for layer in g['layers']:
        name=layer['image-name'];shutil.copy2(ROOT/'layers'/name,ASSETS/name)
(DOC/'icon.json').write_text(json.dumps(doc,indent=2)+'\n')
print(DOC)
