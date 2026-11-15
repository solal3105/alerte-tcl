"""Antialiased radar dial built entirely from analytic shapes in linear RGB."""
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
    wash=np.clip((y+.5)*.8+.1,0,1)[...,None]
    bg[:,:,:3]=linear('EDF6F3')*(1-wash)+linear('FFFFFF')*wash
    def paint(color,alpha):
        a=np.clip(alpha,0,1)[...,None]
        bg[:,:,:3]=bg[:,:,:3]*(1-a)+color*a
    # A narrow bevel seats the radar disc into the pale icon canvas.
    paint(linear('54796F'),np.exp(-((r-.459)/.019)**2)*.16)
    bevel=np.clip(.55+.4*(-x+y)/.65,0,1)[...,None]
    paint(linear('52CBA4')*(1-bevel)+linear('D5FFF0')*bevel,inside(r,.464))
    light=np.clip(.5+.6*(-x+y),0,1)[...,None]
    paint(linear('064D48')*(1-light)+linear('149F73')*light,inside(r,.446))
    clip=inside(r,.442)
    # Fine concentric range rings and understated compass axes.
    for radius in (.10,.19,.28,.37,.432):
        paint(linear('8AFFD7'),stroke(r-radius,.00105)*.28*clip)
    for axis in (x,y):
        paint(linear('75DDBD'),stroke(axis,.0007)*.2*clip)
    for i in range(60):
        a=i*math.tau/60
        along=x*math.cos(a)+y*math.sin(a)
        across=-x*math.sin(a)+y*math.cos(a)
        major=i%5==0
        mask=stroke(across,.001 if major else .0007)
        mask*=np.clip((along-(.417 if major else .425))*size,0,1)
        mask*=np.clip((.437-along)*size,0,1)
        paint(linear('B5FFE6'),mask*(.62 if major else .30))
    # A continuous cyan scan with a crisp leading edge and a fading trail.
    heading=math.radians(52)
    trail=(heading-angle)%math.tau
    sweep=np.exp(-trail/math.radians(27))*(trail<math.radians(94))
    sweep*=np.clip(r/.27,0,1)*clip
    paint(linear('34EDCC'),sweep*.53)
    along=x*math.cos(heading)+y*math.sin(heading)
    across=-x*math.sin(heading)+y*math.cos(heading)
    ray=(along>0)*inside(r,.431)
    paint(linear('57F8DF'),np.exp(-(across/.009)**2)*ray*.2)
    paint(linear('CDFFF5'),stroke(across,.0016)*ray*.84)
    # Two distinct position echoes with clean cores and soft pulse halos.
    for px,py,rad in [(-.274,.272,.0085),(.263,.240,.0065)]:
        d=np.hypot(x-px,y-py)
        paint(linear('8EFFD6'),np.exp(-(d/.025)**2)*.22*clip)
        paint(linear('71FFC9'),stroke(d-.020,.0012)*.6*clip)
        paint(linear('CFFFF0'),inside(d,rad)*clip)
        paint(linear('FFFFFF'),inside(d,rad*.43)*clip)
    paint(linear('A1FFDB'),stroke(r-.446,.0012)*.65)
    return bg
