#!/usr/bin/env python3
"""Compose original loopable biome audio. Optional build tool: numpy, scipy, ffmpeg.

Usage: python3 tools/generate_biome_audio.py --game-dir /path/to/main
Runtime uses the committed Oggs, with no Python or procedural game RNG.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile

RATE = 24000
# id, tempo, tonic MIDI, mode, lead, chord degrees, motif, soundscape description
PROFILES = [
    ('normal',96,60,'major','flute',[0,3,4,0],[0,2,4,6,4,2,1,4], '풀잎을 스치는 바람과 멀리서 지저귀는 새'),
    ('fire',100,50,'minor','pluck',[0,5,3,4],[0,0,4,3,2,4,6,4], '낮은 화산 울림과 흩어지는 불씨'),
    ('water',84,62,'major','bell',[0,5,1,4],[4,2,1,0,2,4,6,5], '밀려왔다 물러나는 물결과 물방울'),
    ('grass',92,65,'major','flute',[0,3,1,4],[0,4,2,1,4,6,5,2], '나뭇잎 바스락거림과 숲새'),
    ('electric',112,57,'dorian','pulse',[0,2,3,0],[0,4,0,6,4,2,5,3], '수정의 공명과 작은 전기 스파크'),
    ('ice',72,69,'major','bell',[0,5,3,4],[6,4,2,4,1,0,2,5], '차가운 바람과 얼음 결정의 울림'),
    ('fighting',108,50,'dorian','wood',[0,3,0,4],[0,0,2,4,3,2,1,0], '협곡 바람과 멀리 울리는 나무 타격'),
    ('poison',82,55,'minor','pluck',[0,1,5,4],[0,1,4,2,6,4,3,1], '늪의 기포와 낮게 우는 벌레'),
    ('ground',90,52,'minor','wood',[0,5,4,0],[0,4,3,1,0,2,4,6], '모래를 실은 마른 바람과 모래알'),
    ('flying',88,67,'major','flute',[0,4,5,3],[4,6,7,6,4,2,1,4], '탁 트인 절벽의 바람과 먼 새소리'),
    ('psychic',78,61,'dorian','bell',[0,2,5,3],[0,4,6,2,5,1,4,7], '유적의 잔향과 천천히 번지는 공명'),
    ('bug',104,64,'major','wood',[0,1,3,4],[0,2,0,4,2,5,4,1], '풀숲의 귀뚜라미와 가벼운 잎 마찰'),
    ('rock',86,48,'dorian','wood',[0,3,5,4],[0,4,2,0,3,4,6,2], '바위틈 바람과 드문 작은 돌 구름'),
    ('ghost',70,57,'minor','bell',[0,5,1,4],[4,1,0,6,3,2,0,4], '묘원을 감싸는 바람과 먼 종 잔향'),
    ('dragon',94,55,'dorian','flute',[0,5,3,4],[0,4,7,6,4,5,3,2], '성역 깊은 곳의 울림과 산바람'),
    ('dark',76,52,'minor','pluck',[0,3,1,0],[0,2,1,4,0,6,3,1], '밤숲의 벌레와 낮은 부엉이 울음'),
    ('steel',106,54,'dorian','pulse',[0,2,5,4],[0,4,2,6,0,3,5,4], '발전소의 낮은 진동과 금속 잔향'),
    ('fairy',90,72,'major','bell',[0,3,5,4],[0,2,4,7,6,4,5,2], '나뭇잎 사이로 번지는 반짝이는 종소리'),
]
SCALES = {'major':[0,2,4,5,7,9,11], 'minor':[0,2,3,5,7,8,10], 'dorian':[0,2,3,5,7,9,10]}

def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)

def note_in_scale(root, scale, degree):
    return root + scale[degree % 7] + 12 * (degree // 7)

def add(buffer, start, samples, gain=1., pan=0.):
    """Circular overlap-add retains tails across the loop seam."""
    left = np.sqrt((1-pan)/2)
    right = np.sqrt((1+pan)/2)
    index = (np.arange(len(samples)) + round(start*RATE)) % len(buffer)
    buffer[index,0] += gain*left*samples
    buffer[index,1] += gain*right*samples

def tone(midi, length, voice):
    t = np.arange(round(length*RATE)) / RATE
    f = hz(midi)
    phase = 2*np.pi*f*t
    if voice == 'flute':
        wave = np.sin(phase + .025*np.sin(2*np.pi*5*t)) + .18*np.sin(2*phase) + .045*np.sin(3*phase)
        envelope = np.minimum(t/.035,1)*np.minimum((length-t)/.09,1)*np.exp(-t*.7)
    elif voice == 'bell':
        wave = np.sin(phase)*np.exp(-t*3) + .32*np.sin(phase*2)*np.exp(-t*6) + .12*np.sin(phase*3)*np.exp(-t*8)
        envelope = np.minimum(t/.006,1)*np.minimum((length-t)/.08,1)
    elif voice == 'wood':
        wave = np.sin(phase)*np.exp(-t*6) + .3*np.sin(phase*3)*np.exp(-t*14)
        envelope = np.minimum(t/.004,1)*np.minimum((length-t)/.045,1)
    elif voice == 'pulse':
        wave = sum(np.sin(phase*k)/k**1.8 for k in (1,2,3,5))
        envelope = np.minimum(t/.015,1)*np.minimum((length-t)/.06,1)*np.exp(-t*2)
    elif voice == 'pad':
        wave = np.sin(phase) + .15*np.sin(phase*2) + .05*np.sin(phase*3)
        envelope = np.minimum(t/.22,1)*np.minimum((length-t)/.3,1)*.7
    else:
        wave = np.sin(phase) + .22*np.sin(phase*2) + .1*np.sin(phase*4)
        envelope = np.minimum(t/.008,1)*np.minimum((length-t)/.05,1)*np.exp(-t*3)
    return wave * np.maximum(envelope,0)

def music(profile, seed):
    key,bpm,root,mode,voice,progression,motif,_ = profile
    beat = 60/bpm
    duration = beat*64  # sixteen bars with an answering phrase
    result = np.zeros((round(duration*RATE),2))
    rng = np.random.default_rng(seed)
    scale = SCALES[mode]
    for bar in range(16):
        chord = progression[(bar//2)%4]
        start = bar*4*beat
        # Soft sustained triad, alternating arpeggio and rounded bass.
        for i,degree in enumerate([chord,chord+2,chord+4]):
            add(result,start,tone(note_in_scale(root,scale,degree),beat*4.2,'pad'),.028,[-.4,0,.4][i])
        for step in range(8):
            degree = [chord,chord+2,chord+4,chord+2][step%4]
            add(result,start+step*beat/2,tone(note_in_scale(root+12,scale,degree),beat*.7,'wood'),.047,(-1)**step*.3)
        for step in [0,2]:
            add(result,start+step*beat,tone(note_in_scale(root-12,scale,chord),beat*1.7,'pluck'),.11)
        # A motif on odd bars answers the even-bar phrase; second half varies register.
        positions = [0,.75,1.5,2.5] if voice != 'pulse' else [0,.5,1.5,2.5,3.5]
        for i,pos in enumerate(positions):
            degree = motif[(bar*3+i)%len(motif)]
            if bar%4 == 3: degree = [2,1,0,4][i%4]
            if bar >= 8 and bar%4 in [0,1]: degree += 2
            midi = note_in_scale(root+12,scale,degree)
            add(result,start+pos*beat,tone(midi,beat*(.85 if i%2 else .65),voice),.13, .12*np.sin(bar))
        # Restrained hand percussion. Ice/ghost/psychic leave more air.
        if key not in ['ice','ghost','psychic','dark'] or bar%2 == 0:
            for step in [0,2]:
                t = np.arange(round(.18*RATE))/RATE
                drum = np.sin(2*np.pi*(55*t+5*(1-np.exp(-t*30))))*np.exp(-t*25)
                add(result,start+step*beat,drum,.065)
            for step in [1,3]:
                t = np.arange(round(.09*RATE))/RATE
                tap = rng.standard_normal(len(t))*np.exp(-t*65)
                add(result,start+step*beat,tap,.025,.25)
    # Short stereo echoes wrap into the first bar, avoiding hard cut tails.
    dry = result.copy()
    result += np.roll(dry,round(beat*.75*RATE),axis=0)[:,::-1]*.17
    result += np.roll(dry,round(beat*1.5*RATE),axis=0)*.06
    return finish(result,.095,.58),duration

def noise(n, rng, low, high):
    freq = np.fft.rfftfreq(n,1/RATE)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    weight = np.minimum(1,(freq/max(low,1))**2) / np.maximum(1,(freq/high)**3)
    weight[0] = 0
    wave = np.fft.irfft(spectrum*weight,n=n)
    return wave / max(np.std(wave),1e-6)

def ambience(profile, seed):
    key,_,root,_,_,_,_,_ = profile
    duration = 32
    n = RATE*duration
    t = np.arange(n)/RATE
    rng = np.random.default_rng(seed+700)
    result = np.zeros((n,2))
    airy = noise(n,rng,140,1600)
    soft = noise(n,rng,35,240)
    rustle = noise(n,rng,1400,4200)
    swell = .55+.22*np.sin(2*np.pi*3*t/duration)+.15*np.sin(2*np.pi*7*t/duration+.6)
    if key in ['water','poison']:
        base = airy*(.4+.28*np.sin(2*np.pi*5*t/duration)) + soft*.15
    elif key in ['fire','dragon','rock']:
        base = soft*swell*.55+airy*.12*swell
    elif key in ['electric','steel','psychic']:
        base = .12*airy*swell
        for f,g in [(48,.13),(96,.055),(144,.03)]: base += g*np.sin(2*np.pi*f*t)*swell
    else:
        base = airy*swell*.22 + soft*.1 + rustle*swell*.025
    result[:,0] = base
    result[:,1] = np.roll(base,1007)*.8 + np.roll(airy,503)*.06*swell
    for i in range(14 if key in ['bug','grass','normal','dark'] else 9):
        start = (i*duration/14 + rng.uniform(0,1.5)) % duration
        pan = rng.uniform(-.65,.65)
        if key in ['normal','grass','flying']:
            # Two falling/rising whistles with silence between calls.
            length = .65
            u = np.arange(round(length*RATE))/RATE
            phase = 2*np.pi*(rng.uniform(1250,2100)*u+400*u*u)
            wave = np.sin(phase)*(np.sin(np.pi*u/length)**2)*(.55+.45*np.cos(2*np.pi*8*u))
            add(result,start,wave,.12,pan)
        elif key in ['water','poison']:
            u = np.arange(round(.25*RATE))/RATE
            wave = np.sin(2*np.pi*(800*u+700*u*u))*np.exp(-u*22)*np.minimum(u/.004,1)
            add(result,start,wave,.16,pan)
        elif key in ['fire','ground','rock','electric']:
            u = np.arange(round(.16*RATE))/RATE
            wave = rng.standard_normal(len(u))*np.exp(-u*50)*np.minimum(u/.003,1)
            add(result,start,wave,.18,pan)
        elif key in ['bug','dark']:
            u = np.arange(round(.95*RATE))/RATE
            f = 2900 if key == 'bug' else 1900
            wave = np.sin(2*np.pi*f*u)*(np.sin(2*np.pi*16*u)**12)*np.sin(np.pi*u/.95)**2
            add(result,start,wave,.12,pan)
        elif key in ['fighting','steel']:
            add(result,start,tone(root+12+(i%3)*7,.8,'wood' if key=='fighting' else 'bell'),.18,pan)
        else:
            add(result,start,tone(root+12+[0,7,12,19,24][i%5],2.5,'flute' if key=='dragon' else 'bell'),.11,pan)
    if key == 'dark':
        for start in [6,22]: add(result,start,tone(66,.8,'flute'),.16,-.4)
    if key == 'ghost':
        result += .045*np.sin(2*np.pi*196*t+1.5*np.sin(2*np.pi*2*t/duration))[:,None]*swell[:,None]
    return finish(result,.055,.38),duration

def finish(samples, rms, peak):
    samples -= np.mean(samples,axis=0)
    samples *= min(rms/np.sqrt(np.mean(samples**2)),peak/np.max(np.abs(samples)))
    return samples

def render(path, samples, directory):
    pcm = np.round(samples*32767).astype(np.int16)
    wav = directory/'source.wav'
    wavfile.write(wav,RATE,pcm)
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','4','-map_metadata','-1',str(path)],check=True)
    # Godot imports in place later; new Oggs must loop rather than use cry defaults.
    digest = hashlib.md5(('res://assets/audio/biomes/'+path.name).encode()).hexdigest()
    imported = f'res://.godot/imported/{path.name}-{digest}.oggvorbisstr'
    import_file = Path(str(path)+'.import')
    previous = import_file.read_text() if import_file.exists() else ''
    uid = re.search(r'^uid="[^"]+"$', previous, re.M)
    uid_line = uid.group(0)+'\n' if uid else ''
    import_file.write_text(f'''[remap]
importer="oggvorbisstr"
type="AudioStreamOggVorbis"
{uid_line}path="{imported}"

[deps]
source_file="res://assets/audio/biomes/{path.name}"
dest_files=["{imported}"]

[params]
loop=true
loop_offset=0
bpm=0
beat_count=0
bar_beats=4
''',encoding='utf-8')
    return dict(file=path.name,duration=len(pcm)/RATE,sample_rate=RATE,channels=2,
                peak_db=round(float(20*np.log10(np.max(np.abs(samples)))) ,2),
                rms_db=round(float(20*np.log10(np.sqrt(np.mean(samples**2)))) ,2),
                seam_delta=float(np.max(np.abs(samples[0]-samples[-1]))),
                pcm_sha256=hashlib.sha256(pcm.tobytes()).hexdigest(),sha256=hashlib.sha256(path.read_bytes()).hexdigest())

def verify(game_dir):
    output = game_dir/'assets/audio/biomes'
    manifest = json.loads((output/'manifest.json').read_text(encoding='utf-8'))
    checks = 0
    def check(ok, message):
        nonlocal checks
        checks += 1
        if not ok: raise RuntimeError(message)
    check(set(manifest['biomes']) == {p[0] for p in PROFILES},'Incomplete biome manifest')
    check(manifest['generator_sha256'] == hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'Generator provenance mismatch')
    for entry in manifest['biomes'].values():
        for kind in ['music','ambience']:
            info = entry[kind]
            path = output/info['file']
            check(hashlib.sha256(path.read_bytes()).hexdigest() == info['sha256'],'Hash mismatch: '+str(path))
            raw = subprocess.check_output(['ffmpeg','-hide_banner','-loglevel','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-'])
            samples = np.frombuffer(raw,dtype='<f4').reshape(-1,2)
            check(np.all(np.isfinite(samples)) and np.max(np.abs(samples)) < .9,'Invalid or clipped PCM: '+str(path))
            check(.03 < np.sqrt(np.mean(samples*samples)) < .12,'Unexpected loudness: '+str(path))
            check(abs(len(samples)/info['sample_rate']-info['duration']) < .1,'Unexpected duration: '+str(path))
            seam = np.max(np.abs(samples[0]-samples[-1]))
            typical = np.percentile(np.max(np.abs(np.diff(samples,axis=0)),axis=1),99.9)
            check(seam <= max(.015,typical*1.5),'Outlying discontinuity at seam: '+str(path))
    print(f'AUDIO_FILES: {checks} checks / 0 failures; 36 decoded')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-dir',type=Path,required=True)
    parser.add_argument("--verify",action="store_true",help="Verify committed Ogg hashes, decoded levels and loop seams without regenerating")
    args = parser.parse_args()
    if args.verify:
        verify(args.game_dir)
        return
    output = args.game_dir/'assets/audio/biomes'
    output.mkdir(parents=True,exist_ok=True)
    manifest = {'source':'Original project synthesis; no recordings or upstream melodies',
                'generator':'development-materials:tools/generate_biome_audio.py',
                'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'biomes':{}}
    with tempfile.TemporaryDirectory(prefix='biome-audio-') as directory:
        for i,profile in enumerate(PROFILES):
            key,bpm,root,mode,voice,_,_,description = profile
            entry = dict(seed=2300+i,bpm=bpm,bars=16,tonic_midi=root,mode=mode,lead=voice,ambience_description=description)
            for kind,compose in [('music',music),('ambience',ambience)]:
                samples,_ = compose(profile,2300+i)
                entry[kind] = render(output/f'{key}_{kind}.ogg',samples,Path(directory))
            manifest['biomes'][key] = entry
            print(key,flush=True)
    (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if __name__ == '__main__': main()
