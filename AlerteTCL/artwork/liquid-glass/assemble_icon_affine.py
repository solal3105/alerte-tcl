"""Build the revised Apple document from separate projected and vector layers."""
from pathlib import Path
import json, math, shutil

ROOT = Path(__file__).resolve().parent
SRC = ROOT / 'affine'
DOC = ROOT / 'AlerteTCL_Verre_Corrige.icon'
ASSETS = DOC / 'Assets'
ASSETS.mkdir(parents=True, exist_ok=True)

def svg(name, content):
    (SRC / name).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'+content+'\n</svg>\n')

svg('Cadran.svg', '''<defs><linearGradient id="mint" x1="0" y1="0" x2=".25" y2="1"><stop stop-color="#57E891"/><stop offset="1" stop-color="#0EBB97"/></linearGradient></defs>
<circle cx="512" cy="512" r="450" fill="url(#mint)"/>''')
svg('Couronne.svg', '<circle cx="512" cy="512" r="458" fill="none" stroke="#BFFAE7" stroke-opacity=".7" stroke-width="13"/>')
svg('Balayage.svg', '''<defs><linearGradient id="sweep" x1=".85" y1=".12" x2=".5" y2=".9"><stop stop-color="#12BCF1" stop-opacity=".72"/><stop offset="1" stop-color="#12BCF1" stop-opacity="0"/></linearGradient></defs>
<path d="M512 512 L680.7 94.4 A450.4 450.4 0 0 1 952.1 605.5 Z" fill="url(#sweep)"/>
<path d="M512 512 L680.7 94.4" stroke="#D1FFED" stroke-opacity=".6" stroke-width="1.4"/>''')
svg('Anneaux.svg', '\n'.join(f'<circle cx="512" cy="512" r="{r}" fill="none" stroke="#C0FFE2" stroke-opacity=".6" stroke-width="1.3"/>' for r in (205,309,412)))
svg('Balises.svg', '''<g fill="none" stroke="#D9FFEE" stroke-opacity=".65" stroke-width="1.3"><circle cx="218" cy="247" r="21.5"/><circle cx="809" cy="292" r="21.5"/></g>
<g fill="#ECFFF4"><circle cx="218" cy="247" r="8.2"/><circle cx="809" cy="292" r="7.2"/></g>''')

def group(name, files, specular=False, translucency=None, shadow=0, blur=None):
    g = {'name':name, 'layers':[{'name':label, 'image-name':filename} for filename,label in files],
         'specular':specular, 'translucency':{'enabled':translucency is not None, 'value':translucency or 0},
         'shadow':{'kind':'neutral','opacity':shadow}}
    if blur is not None: g['blur-material'] = blur
    return g

groups = [
    group('04 Essuie-glace', [('EssuieGlace.png','Detail devant le vitrage')]),
    group('03 Vitres / verre Apple', [('Vitres.svg','Cinq vitres vectorielles du modele')], True, .32, 0, .035),
    group('02 Tram / deux caisses', [('CaisseAvant.png','Caisse avant - porcelaine et phares'),('CaisseArriere.png','Caisse arriere - remorque')]),
    group('01 Radar / couches vectorielles', [('Anneaux.svg','Trois cercles'),('Balayage.svg','Balayage cyan'),('Couronne.svg','Bord de cristal'),('Cadran.svg','Cadran vert')], False, .08),
]
assert len(groups) <= 4
doc = {'fill':{'automatic-gradient':'extended-srgb:0.90000,0.97500,0.95500,1.00000'},
       'groups':groups, 'supported-platforms':{'circles':['watchOS'],'squares':'shared'}}
for g in groups:
    for layer in g['layers']:
        f = layer['image-name']
        shutil.copy2(SRC/f, ASSETS/f)
if (SRC/'CaisseAvant_Nuit.png').exists():
    from regler_apparences import apply
    doc=apply(doc,ASSETS)
(DOC/'icon.json').write_text(json.dumps(doc, indent=2, ensure_ascii=False)+'\n')
print(DOC)
