"""Deterministic tiny facade textures and synthesized engine/horn audio.
Only required when changing the procedural prototype assets.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math, wave, struct
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'project'/'assets'
A.mkdir(parents=True,exist_ok=True)
im=Image.new('RGB',(128,128),'#eceae4');d=ImageDraw.Draw(im)
d.rectangle((0,0,127,2),fill='#ccc9c3');d.line((127,0,127,128),fill='#d8d5cf',width=2)
d.rectangle((26,27,100,106),fill='#8a9393');d.rectangle((29,29,96,101),fill='#d9ded8')
d.rectangle((33,33,60,96),fill='#47616b');d.rectangle((65,33,92,96),fill='#607a81')
d.rectangle((34,34,58,41),fill='#819497');d.rectangle((66,34,90,41),fill='#95a5a3')
d.rectangle((23,104,104,110),fill='#bbbcb5');d.line((25,111,102,111),fill='#aaa9a0',width=2)
im.save(A/'facade.png')
im=Image.new('RGB',(128,128),'#f1e3c7');d=ImageDraw.Draw(im)
d.rectangle((0,92,128,127),fill='#c6ae8e');d.rectangle((12,12,116,82),fill='#444e51')
for x in [14,48,82]:d.rectangle((x,15,x+29,79),fill='#718a8e');d.rectangle((x+2,17,x+27,23),fill='#b0c1c0')
d.rectangle((0,0,127,5),fill='#bc9b60');im.save(A/'shop.png')
rate=22050
for name,duration in [('engine',1),('horn',.6)]:
    frames=[]
    for i in range(int(rate*duration)):
        t=i/rate
        if name=='engine':
            val=(math.sin(2*math.pi*45*t)+.40*math.sin(2*math.pi*90*t)+.17*math.sin(2*math.pi*180*t))*.13
            val+=math.sin(2*math.pi*720*t)*.025*(.5+.5*math.sin(2*math.pi*90*t))
        else:
            envelope=min(1,t*35,(duration-t)*25)
            val=envelope*(math.sin(2*math.pi*330*t)+.6*math.sin(2*math.pi*415*t))*.2
        frames.append(struct.pack('<h',int(max(-1,min(1,val))*32767)))
    with wave.open(str(A/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(frames))
print('Assets created')
