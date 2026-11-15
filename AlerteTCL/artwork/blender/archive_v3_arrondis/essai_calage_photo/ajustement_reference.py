"""Calibrate coherent 3D body volumes against manually measured logo contours.
No image texture is used on the model. This file only writes numeric measurements.
"""
from pathlib import Path
import numpy as np
from scipy.optimize import least_squares
from scipy.spatial import ConvexHull
import json
ROOT=Path(__file__).resolve().parent
# Visible main-coach silhouette, measured on the 1024 px original.
OUTLINE=np.array([(198,415),(239,372),(301,338),(397,295),(491,266),(583,252),
 (687,253),(754,274),(795,310),(817,371),(839,509),(852,638),(854,740),
 (840,783),(807,811),(748,830),(642,835),(498,818),(355,788),(253,756),
 (215,733),(203,703),(198,618),(194,522)])
REAR_EDGE=np.array([(185,385),(151,401),(124,422),(105,451),(98,493),(99,589),(103,655),(116,694),(146,720),(178,736)])
# X transverse; Y towards rear. Each end smoothly contracts into a rounded volume.
def surface(p,y0,y1,w0,w1,h0,h1,bottom,power=5.0):
    p=np.asarray(p,float)
    q=p/np.sum(abs(p)**power,axis=-1,keepdims=True)**(1/power)
    u,v,w=np.moveaxis(q,-1,0); t=(v+1)/2
    width=w0*(1-t)+w1*t; height=h0*(1-t)+h1*t
    taper=1-.045*((w+1)/2)**3
    return np.stack((u*width/2*taper,y0+t*(y1-y0),bottom+(w+1)/2*height),axis=-1)
P=[]
for axis in range(3):
 for sign in (-1,1):
  other=[i for i in range(3) if i!=axis]
  for a in np.linspace(-1,1,23):
   for b in np.linspace(-1,1,23):
    q=[0.,0.,0.];q[axis]=sign;q[other[0]]=a;q[other[1]]=b;P.append(q)
P=np.array(P)
# params: rear width ratio, rear height ratio, camera yaw/elevation/distance/focal-px/cx/cy,
# main height, headlight normalized height, length, rear length, end softness.
def bodies(t):
 wr,hr,ya,el,dist,f,cx,cy,h,lh,L,RL,power=t
 main=surface(P,0,L,2.3,2.3*wr,h,h*hr,.30,power)
 rear=surface(P,L+.26,L+.26+RL,2.3*wr,2.3*wr,h*hr,h*hr,.30,power)
 return main,rear

def project(pts,t):
 wr,hr,ya,el,dist,f,cx,cy,h,lh,L,RL,power=t
 ya,el=np.deg2rad([ya,el]);out=np.array([-np.sin(ya)*np.cos(el),-np.cos(ya)*np.cos(el),np.sin(el)])
 right=np.array([np.cos(ya),-np.sin(ya),0]);up=np.cross(out,right)
 q=pts-np.array([0,L*.28,1.5]);z=dist-q@out
 return np.stack([cx+f*(q@right)/z,cy-f*(q@up)/z],axis=-1)

def distance(points,hull):
 a=hull; b=np.roll(hull,-1,axis=0);v=b-a
 q=points[:,None,:]-a[None,:,:]
 tt=np.clip(np.sum(q*v,axis=-1)/np.sum(v*v,axis=-1),0,1)
 return np.sqrt(np.min(np.sum((q-tt[:,:,None]*v)**2,axis=-1),axis=1))

def err(t):
 main,rear=bodies(t);mp=project(main,t);rp=project(rear,t)
 mh=mp[ConvexHull(mp).vertices];rh=rp[ConvexHull(rp).vertices]
 wr,hr,ya,el,dist,f,cx,cy,h,lh,L,RL,power=t
 lamps=surface([[-.68,-1,lh],[.68,-1,lh]],0,L,2.3,2.3*wr,h,h*hr,.30,power)
 e=list(distance(OUTLINE,mh))
 e.extend(distance(REAR_EDGE,rh))
 e.extend(((project(lamps,t)-np.array([[525,708],[810,705]]))*1.5).ravel())
 # Prefer compact but coherent lengths and mild geometric taper over arbitrary warping.
 e.extend([(wr-.86)*20,(hr-.84)*20,(L-3.3)*5,(RL-2.54)*5,(power-5)*2])
 return e
bounds=([.72,.67,14,0,4.8,550,350,300,2.3,-.72,2.5,1.1,3.6],
        [1.,1.,48,26,15,2500,850,780,3.3,-.30,4.,2.9,7.0])
x=[.85,.82,32,10,8.5,1650,580,620,2.85,-.55,3.3,2.2,5]
r=least_squares(err,x,bounds=bounds,max_nfev=450,diff_step=.001,ftol=1e-7)
names=['rear_width_ratio','rear_height_ratio','yaw','elevation','distance','focal_px','cx','cy','height','lamp_v','length','rear_length','power']
data=dict(zip(names,r.x)); data['contour_rms_px']=float(np.sqrt(np.mean(np.array(err(r.x)[:len(OUTLINE)+len(REAR_EDGE)])**2)))
(ROOT/'reference_calibree.json').write_text(json.dumps(data,indent=2))
print(json.dumps(data,indent=2))
# Geometry-only diagnostic vector plot; the actual photo is never painted on the mesh.
main,rear=bodies(r.x)
paths=[]
for mesh,color in [(rear,'#aaaaaa'),(main,'#444444')]:
 pts=project(mesh,r.x);hull=pts[ConvexHull(pts).vertices]
 d='M '+' L '.join(f'{x:.2f},{y:.2f}' for x,y in hull)+' Z'
 paths.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2"/>')
for x,y in np.vstack((OUTLINE,REAR_EDGE)):
 paths.append(f'<circle cx="{x}" cy="{y}" r="3" fill="#e34"/>')
(ROOT/'calage_contours.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="white"/>'+''.join(paths)+'</svg>')
