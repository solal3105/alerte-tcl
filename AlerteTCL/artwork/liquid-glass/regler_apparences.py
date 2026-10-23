"""Explicit Apple appearance annotations and closed SVG geometry.

The default Apple fill for a stroked SVG can fill its entire closed outline in
Dark/Mono. Use real annular paths, not stroked circles, and annotate every fill.
"""
from pathlib import Path
import json, math, shutil

ROOT = Path(__file__).resolve().parent
SRC = ROOT / 'affine'

def color(hexcode, alpha=1):
    c = [int(hexcode[i:i+2], 16)/255 for i in (0,2,4)]
    return 'extended-srgb:'+','.join(f'{v:.5f}' for v in (*c,alpha))

def solid(hexcode, alpha=1): return {'solid':color(hexcode,alpha)}
def gradient(hexcode): return {'automatic-gradient':color(hexcode)}
def specialize(ob, key, values):
    ob[key+'-specializations'] = [{'appearance':a, 'value':v} for a,v in values.items()]

def circle_path(radius, reverse=False):
    r=radius; sweep=0 if reverse else 1
    return f'M{512-r:.3f} 512 A{r:.3f} {r:.3f} 0 1 {sweep} {512+r:.3f} 512 A{r:.3f} {r:.3f} 0 1 {sweep} {512-r:.3f} 512 Z'

def annulus(radius, width):
    return circle_path(radius+width/2)+' '+circle_path(radius-width/2,True)

def write_svg(assets,name,body):
    text='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'+body+'\n</svg>\n'
    (SRC/name).write_text(text)
    (assets/name).write_text(text)

def apply(doc, assets):
    # Resolve strokes to filled outlines before the platform generates variants.
    write_svg(assets,'Anneaux.svg', '\n'.join('<path d="'+annulus(r,1.65)+'" fill="#B5F6D9" fill-opacity=".55" fill-rule="evenodd"/>' for r in (205,309,412)))
    write_svg(assets,'Couronne.svg','<path d="'+annulus(458,10)+'" fill="#BFFAE7" fill-opacity=".72" fill-rule="evenodd"/>')
    write_svg(assets,'Balayage.svg','''<defs><linearGradient id="sweep" x1=".85" y1=".12" x2=".5" y2=".9"><stop stop-color="#12BCF1" stop-opacity=".72"/><stop offset="1" stop-color="#12BCF1" stop-opacity="0"/></linearGradient></defs>
<path d="M512 512 L680.7 94.4 A450.4 450.4 0 0 1 952.1 605.5 Z" fill="url(#sweep)"/>''')
    # Keep the sweep outline separate from the sweep gradient, using filled geometry.
    ring=(assets/'Anneaux.svg').read_text()
    x,y=168.7,-417.6; length=math.hypot(x,y); dx,dy=-y/length*.7,x/length*.7
    ray=f'<path d="M{512+dx} {512+dy} L{680.7+dx} {94.4+dy} L{680.7-dx} {94.4-dy} L{512-dx} {512-dy} Z" fill="#B5F6D9" fill-opacity=".55"/>'
    ring=ring.replace('</svg>',ray+'\n</svg>')
    (assets/'Anneaux.svg').write_text(ring);(SRC/'Anneaux.svg').write_text(ring)

    specialize(doc,'fill', {'dark':gradient('071D29'), 'tinted':solid('273342')})
    groups=doc['groups']
    glass=next(g for g in groups if 'Vitres' in g['name'])
    glass['blur-material']=.010
    glass['translucency']={'enabled':True,'value':.24}
    specialize(glass,'blur-material',{'dark':.008,'tinted':.004})
    specialize(glass,'translucency',{'dark':{'enabled':True,'value':.28},'tinted':{'enabled':True,'value':.12}})
    specialize(glass,'specular',{'tinted':False})
    radar=next(g for g in groups if 'Radar' in g['name'])
    radar['translucency']={'enabled':False,'value':0}
    palettes={
        'Cadran.svg': {'dark':gradient('07534F'),'tinted':solid('56616D')},
        'Couronne.svg': {'dark':solid('45C9AA',.70),'tinted':solid('C5CED8',.70)},
        'Anneaux.svg': {'dark':solid('7EDBCC',.48),'tinted':solid('D0D7E0',.50)},
        'Balayage.svg': {'dark':solid('12BBD4',.48),'tinted':solid('AFBAC6',.28)},
        'Vitres.svg': {'dark':solid('315567',.46),'tinted':solid('24394B',.48)},
    }
    for g in groups:
        for layer in g['layers']:
            filename=layer['image-name']
            if filename in palettes: specialize(layer,'fill',palettes[filename])
            if filename in ('CaisseAvant.png','CaisseArriere.png','EssuieGlace.png'):
                night=filename.replace('.png','_Nuit.png')
                shutil.copy2(SRC/night,assets/night)
                specialize(layer,'image-name',{'dark':night,'tinted':night})
    return doc

if __name__=='__main__':
    docpath=ROOT/'AlerteTCL_Verre_Corrige.icon'
    data=json.loads((docpath/'icon.json').read_text())
    data=apply(data,docpath/'Assets')
    (docpath/'icon.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
