"""Синтез звуков приложения (без внешних файлов)."""
import sys, os, wave
import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "sounds"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.004, decay=6.0):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t * decay)


def bell(freq, dur, decay=4.5, vol=1.0):
    t = t_(dur)
    parts = [(1.0, 1.0), (2.0, 0.5), (2.76, 0.35), (5.4, 0.18), (8.93, 0.08)]
    s = sum(a * np.sin(2 * np.pi * freq * m * t) * np.exp(-t * decay * (0.6 + 0.4 * m)) for m, a in parts)
    s *= np.minimum(1.0, t / 0.003)
    return vol * s / 2.2


def saw(freq, dur, vol=1.0, attack=0.02, release=0.2):
    t = t_(dur)
    s = np.zeros_like(t)
    for k in range(1, 9):
        s += np.sin(2 * np.pi * freq * k * t) / k
    e = np.minimum(1.0, t / attack) * np.minimum(1.0, np.maximum(0.0, (dur - t) / release))
    return vol * s * e * 0.5


def lowpass(x, k):
    return np.convolve(x, np.ones(max(1, int(k))) / max(1, int(k)), mode="same")


def noise(dur, vol=1.0):
    return vol * rng.uniform(-1, 1, int(SR * dur))


def place(base, x, at):
    i = int(SR * at)
    n = min(len(x), len(base) - i)
    if n > 0:
        base[i:i + n] += x[:n]
    return base


def canvas(dur):
    return np.zeros(int(SR * dur))


def reverb(x, delays=(0.045, 0.083, 0.131), gains=(0.35, 0.25, 0.18)):
    y = x.copy()
    for d, g in zip(delays, gains):
        k = int(SR * d)
        y[k:] += g * x[:-k]
    return y


def save(name, x, peak=0.9):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1.0
    x = x * (peak / m)
    n = int(SR * 0.025)
    x[-n:] *= np.linspace(1, 0, n)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


NOTE = {"C4": 261.63, "E4": 329.63, "G4": 392.0, "C5": 523.25, "E5": 659.25, "G5": 783.99, "B5": 987.77,
        "C6": 1046.5, "E6": 1318.5, "G6": 1568.0}

tick = np.zeros(int(SR * 0.05)); t = t_(0.05)
tick += np.sin(2 * np.pi * 2300 * t) * np.exp(-t * 150) + 0.35 * np.sin(2 * np.pi * 4600 * t) * np.exp(-t * 220)
tick[:int(SR * 0.002)] += noise(0.002, 0.8)
save("tick", tick, 0.55)

heavy = np.zeros(int(SR * 0.11)); t = t_(0.11)
heavy += np.sin(2 * np.pi * 1150 * t) * np.exp(-t * 55) + 0.7 * np.sin(2 * np.pi * 230 * t) * np.exp(-t * 38)
heavy += 0.4 * np.sin(2 * np.pi * 2900 * t) * np.exp(-t * 120)
heavy[:int(SR * 0.003)] += noise(0.003, 0.9)
save("tick_heavy", heavy, 0.8)

d = 1.2; n = int(SR * d); w = noise(d); sweep = np.zeros(n)
for i, win in enumerate(np.linspace(40, 4, 24)):
    a, b = int(i * n / 24), int((i + 1) * n / 24)
    sweep[a:b] = lowpass(w, win)[a:b]
amp = np.sin(np.pi * np.clip(np.arange(n) / SR / d, 0, 1)) ** 1.6
whoosh = sweep * amp * 3.0 + 0.25 * np.sin(2 * np.pi * np.cumsum(np.linspace(180, 900, n)) / SR) * amp
save("whoosh", whoosh, 0.7)

o = canvas(0.8); th = np.arange(int(SR * 0.4)) / SR
place(o, np.sin(2 * np.pi * 85 * th) * np.exp(-th * 11) * 1.2, 0.0)
for at in (0.0, 0.1):
    c = np.arange(int(SR * 0.05)) / SR
    place(o, (np.sin(2 * np.pi * 3100 * c) + 0.5 * np.sin(2 * np.pi * 5200 * c)) * np.exp(-c * 90) * 0.7, at)
for f, at in ((880, 0.16), (1320, 0.2), (1760, 0.24)):
    place(o, bell(f, 0.55, 5.0, 0.5), at)
save("open", reverb(o), 0.85)


def arp(notes, step, ring, vol=1.0):
    c = canvas(step * len(notes) + ring)
    for i, nn in enumerate(notes):
        place(c, bell(NOTE[nn], ring, 4.0, vol), i * step)
    return c


save("win_common", reverb(arp(["E5", "B5"], 0.12, 0.8)), 0.8)
save("win_uncommon", reverb(arp(["C5", "E5", "G5"], 0.1, 0.9)), 0.85)
r = arp(["C5", "E5", "G5", "C6"], 0.09, 1.0)
for i in range(7):
    place(r, bell(2600 + 380 * i, 0.4, 9.0, 0.35), 0.28 + 0.045 * i)
save("win_rare", reverb(r), 0.9)

e = canvas(2.4)
for i, nn in enumerate(["C5", "E5", "G5", "C6", "E6"]):
    place(e, bell(NOTE[nn], 1.3, 3.2, 1.0), i * 0.085)
place(e, saw(NOTE["C4"], 1.4, 0.35, 0.03, 0.8) + saw(NOTE["E4"], 1.4, 0.3, 0.03, 0.8) + saw(NOTE["G4"], 1.4, 0.3, 0.03, 0.8), 0.42)
bo = np.arange(int(SR * 0.6)) / SR
place(e, np.sin(2 * np.pi * 70 * bo) * np.exp(-bo * 6) * 0.9, 0.4)
for i in range(14):
    place(e, bell(2400 + rng.uniform(0, 3500), 0.5, 10.0, 0.3), 0.5 + 0.07 * i)
save("win_epic", reverb(e, (0.06, 0.11, 0.19), (0.38, 0.3, 0.22)), 0.92)

L = canvas(3.6); bo = np.arange(int(SR * 1.0)) / SR
place(L, np.sin(2 * np.pi * 55 * bo) * np.exp(-bo * 3.5) * 1.3 + 0.4 * lowpass(noise(1.0), 60) * np.exp(-bo * 5), 0.0)
for notes, at, dur in ((["C4", "E4", "G4"], 0.15, 1.0), (["E4", "G4", "C5"], 0.75, 0.9), (["G4", "C5", "E5"], 1.35, 2.0)):
    for nn in notes:
        place(L, saw(NOTE[nn], dur, 0.4, 0.04, 0.5), at)
        place(L, saw(NOTE[nn] * 2, dur, 0.18, 0.06, 0.5), at)
for i, nn in enumerate(["C5", "E5", "G5", "C6", "E6", "G6", "C6", "E6"]):
    place(L, bell(NOTE[nn], 1.6, 2.8, 0.9), 0.2 + i * 0.1)
for i in range(46):
    place(L, bell(2200 + rng.uniform(0, 4200), 0.35, 12.0, 0.45), 0.6 + i * 0.045 + rng.uniform(0, 0.02))
save("win_legendary", reverb(L, (0.07, 0.13, 0.23, 0.37), (0.4, 0.32, 0.25, 0.18)), 0.95)

coin = canvas(0.6)
place(coin, bell(2093, 0.4, 7.0, 1.0), 0.0)
place(coin, bell(3136, 0.45, 6.0, 0.9), 0.07)
save("coin", reverb(coin, (0.03, 0.06), (0.2, 0.1)), 0.8)

er = canvas(0.34)
for f, at in ((220, 0.0), (165, 0.14)):
    tt = t_(0.18)
    place(er, np.sign(np.sin(2 * np.pi * f * tt)) * 0.4 * env(len(tt), 0.003, 9.0) + np.sin(2 * np.pi * f * tt) * 0.3 * env(len(tt), 0.003, 9.0), at)
save("error", lowpass(er, 3), 0.7)

n = int(SR * 1.0)
ph = 2 * np.pi * np.cumsum(np.linspace(180, 1400, n)) / SR
con = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)) * (np.minimum(1, np.arange(n) / (SR * 0.05)) * np.exp(-np.maximum(0, np.arange(n) / SR - 0.5) * 6))
con *= np.linspace(0.3, 1.0, n)
place(con, bell(NOTE["C6"], 0.6, 4.5, 0.9), 0.5)
place(con, bell(NOTE["G6"], 0.6, 5.0, 0.6), 0.58)
save("connect", reverb(con, (0.04, 0.09), (0.28, 0.18)), 0.85)

n = int(SR * 0.7)
ph = 2 * np.pi * np.cumsum(np.linspace(950, 160, n)) / SR
dis = (np.sin(ph) + 0.3 * np.sin(2 * ph)) * np.exp(-np.arange(n) / SR * 4.0)
th = np.arange(int(SR * 0.3)) / SR
place(dis, np.sin(2 * np.pi * 75 * th) * np.exp(-th * 14) * 0.8, 0.0)
save("disconnect", dis, 0.8)

tp = np.zeros(int(SR * 0.03)); t = t_(0.03)
tp += np.sin(2 * np.pi * 1400 * t) * np.exp(-t * 180)
save("tap", tp, 0.35)
print("sounds ok")
