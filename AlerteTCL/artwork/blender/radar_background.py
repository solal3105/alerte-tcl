"""Playful location radar built from antialiased analytic shapes in linear RGB."""
import math
import numpy as np

def linear(hexcode):
    c=np.array([int(hexcode[i:i+2],16)/255 for i in (0,2,4)],dtype=np.float32)
    return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)

def build_radar(size):
    y,x=np.mgrid[0:size,0:size].astype(np.float32)
    x=(x+.5)/size-.5;y=(y+.5)/size-.5
    r=np.hypot(x,y);angle=np.arctan2(y,x)
    def inside(distance,radius):return np.clip((radius-distance)*size+.5,0,1)
    def stroke(distance,width):return np.clip((width*.5-np.abs(distance))*size+.5,0,1)
    bg=np.zeros((size,size,4),dtype=np.float32);bg[:,:,3]=1
    bg[:,:,:3]=linear('FFFFFF')
    def paint(color,alpha):
        a=np.clip(alpha,0,1)[...,None]
        bg[:,:,:3]=bg[:,:,:3]*(1-a)+color*a
    # A mint rim, lit from the upper left, frames a luminous apple-green disc.
    paint(linear('96D6BC'),np.exp(-((r-.454)/.020)**2)*.075)
    bevel=np.clip(.55+.4*(-x+y)/.65,0,1)[...,None]
    paint(linear('91EEBB')*(1-bevel)+linear('E2FFD1')*bevel,inside(r,.466))
    light=np.clip(1-np.hypot(x+.22,y-.28)/1.05,0,1)[...,None]
    paint(linear('1ED58B')*(1-light)+linear('5AF16D')*light,inside(r,.442))
    clip=inside(r,.442)
    # Three readable ripples are sufficient at icon size; keep the dial airy.
    for radius in (.19,.295,.401):
        paint(linear('D6FFE1'),stroke(r-radius,.0019)*.37*clip)
    # Broad sky-blue sweep, softened towards the tail; its tip is a light ribbon.
    heading=math.radians(68)
    trail=(heading-angle)%math.tau
    tail=np.clip((math.radians(85)-trail)/math.radians(30),0,1)
    tail=tail*tail*(3-2*tail)
    sweep=np.exp(-trail/math.radians(48))*tail
    sweep*=np.clip(r/.19,0,1)*clip
    paint(linear('03B4FB'),sweep*.87)
    along=x*math.cos(heading)+y*math.sin(heading)
    across=-x*math.sin(heading)+y*math.cos(heading)
    ray=(along>0)*inside(r,.442)
    paint(linear('A9FFEA'),np.exp(-(across/.006)**2)*ray*.18)
    paint(linear('DCFFF0'),stroke(across,.002)*ray*.7)
    # Rounded location lights echo the toy-like material of the tram.
    for px,py,rad in [(-.287,.259,.010),(.290,.215,.008)]:
        d=np.hypot(x-px,y-py)
        shadow=np.hypot(x-px,y-py+.003)
        paint(linear('008C79'),np.exp(-(shadow/.014)**2)*.13*clip)
        paint(linear('BFFFF0'),stroke(d-.023,.0015)*.67*clip)
        bead=np.clip(.5+.5*(-(x-px)+(y-py))/(rad*1.5),0,1)[...,None]
        paint(linear('9EFFE1')*(1-bead)+linear('FFFFFF')*bead,inside(d,rad)*clip)
    paint(linear('E4FFDD'),stroke(r-.442,.0012)*.55)
    return bg
