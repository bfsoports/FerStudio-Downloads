"""synth.py — sonido de Valdebruma sintetizado por código (sin muestras de terceros).

Genera en assets/audio/*.ogg (Vorbis) todos los sonidos que usa AudioDirector:
  ambientes en bucle (bosque de día, noche, pueblo, marjal, interior, industrial, viento, lluvia),
  hoguera, música del menú, pasos por superficie (3 variantes), puertas, contenedores, interfaz,
  herramientas, golpes, trueno y criaturas. Los bucles llevan su .import con loop=true.
Requiere: numpy, scipy y ffmpeg con libvorbis.
Uso: python3 tools/audio/synth.py [nombre …]   (sin nombres: todos)
"""
import os, sys, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 44100
REG = {}
LOOPS = set()


def snd(name, loop=False):
    def deco(fn):
        REG[name] = fn
        if loop:
            LOOPS.add(name)
        return fn
    return deco


# ---------------------------------------------------------------- utilidades
def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def white(n, rng):
    return rng.standard_normal(n)


def pink(n, rng):
    w = rng.standard_normal(n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, w) * 6.0


def brown(n, rng):
    x = np.cumsum(rng.standard_normal(n))
    x = signal.sosfilt(signal.butter(1, 20, "hp", fs=SR, output="sos"), x)
    return x / (np.abs(x).max() + 1e-9)


def filt(x, kind, f, order=2):
    if kind == "bp":
        f = (max(10, f[0]), min(SR / 2 - 100, f[1]))
    else:
        f = min(SR / 2 - 100, max(10, f))
    sos = signal.butter(order, f, {"lp": "lowpass", "hp": "highpass", "bp": "bandpass"}[kind], fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def env_exp(n, decay, attack=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / max(decay, 1e-4))
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return e * a


def env_ar(n, attack, release_start, release):
    t = np.arange(n) / SR
    e = np.clip(t / max(attack, 1e-5), 0, 1)
    e *= np.where(t > release_start, np.exp(-(t - release_start) / max(release, 1e-4)), 1.0)
    return e


def place(dst, src, at):
    i = int(at * SR)
    if i >= len(dst):
        return
    j = min(len(dst), i + len(src))
    dst[i:j] += src[: j - i]


def bell(freq, sec, rng=None, bright=1.0):
    t = t_axis(sec)
    out = np.zeros_like(t)
    for ratio, amp, dec in ((1.0, 1.0, 1.2), (2.76, 0.35 * bright, 0.5), (5.4, 0.15 * bright, 0.25), (2.0, 0.25, 0.8)):
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (dec * sec / 1.5))
    return out * np.clip(t / 0.003, 0, 1)


def pluck(freq, sec):
    """Cuerda pulsada (Karplus-Strong) con cuerpo suave."""
    n = int(sec * SR)
    period = max(2, int(SR / freq))
    rng = np.random.default_rng(int(freq * 10))
    buf = rng.uniform(-1, 1, period)
    buf = filt(np.tile(buf, 3), "lp", 3500)[-period:]
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.996 * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * np.clip(np.arange(n) / (0.002 * SR), 0, 1)


def reverb(x, sec=2.2, wet=0.3, seed=1, stereo=False, tone=5000):
    rng = np.random.default_rng(seed)
    n = int(sec * SR)
    chans = []
    for c in range(2 if stereo else 1):
        ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (sec / 6.5))
        ir = filt(ir, "lp", tone)
        ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        src = x[:, c] if x.ndim == 2 else x
        r = signal.fftconvolve(src, ir)[: len(src)]
        chans.append((1 - wet) * src + wet * r)
    return np.stack(chans, 1) if stereo else chans[0]


def pad_end(x, sec):
    return np.concatenate([x, np.zeros(int(sec * SR))]) if x.ndim == 1 else np.concatenate([x, np.zeros((int(sec * SR), x.shape[1]))])


def loopify(x, fade=1.5):
    """Funde la cola sobre el principio: el bucle no tiene salto."""
    f = int(fade * SR)
    body = x[:-f].copy()
    tail = x[-f:]
    ramp = np.linspace(0, 1, f)
    if x.ndim == 2:
        ramp = ramp[:, None]
    body[:f] = body[:f] * ramp + tail * (1 - ramp)
    return body


def stereoize(l, r=None, width=1.0):
    if r is None:
        r = l
    return np.stack([l, r], 1)


def pan(x, p):
    """p en [-1, 1] → estéreo de potencia constante."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], 1)


def chirp(f0, f1, sec, shape=1.0):
    t = t_axis(sec)
    k = (t / sec) ** shape
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


# ---------------------------------------------------------------- guardado
IMPORT_LOOP = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"

[params]

loop=true
loop_offset=0.0
bpm=0.0
beat_count=0
bar_beats=4
"""


def save(name, x, peak=0.89, rms_db=None, quality=4):
    x = np.nan_to_num(np.asarray(x, dtype=np.float64))
    if rms_db is not None:
        rms = np.sqrt(np.mean(x ** 2)) + 1e-12
        x = x * (10 ** (rms_db / 20) / rms)
        p = np.abs(x).max()
        if p > 0.97:                     # limitador suave para que los picos no saturen
            x = np.tanh(x / 0.97 * 1.2) * 0.97 / np.tanh(1.2)
    else:
        x = x * (peak / (np.abs(x).max() + 1e-12))
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wavfile.write(tmp.name, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
        path = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.unlink(tmp.name)
    imp = path + ".import"
    if name in LOOPS:
        open(imp, "w").write(IMPORT_LOOP)
    elif os.path.exists(imp) and "loop=true" in open(imp).read():
        os.unlink(imp)
    return path


# ================================================================ interfaz
@snd("ui_click")
def ui_click(rng):
    n = int(0.06 * SR)
    x = filt(white(n, rng), "bp", (1800, 6000)) * env_exp(n, 0.004)
    x += 0.5 * np.sin(2 * np.pi * 1450 * t_axis(0.06)) * env_exp(n, 0.012)
    return x


@snd("pickup")
def pickup(rng):
    a = chirp(620, 680, 0.09) * env_exp(int(0.09 * SR), 0.05, 0.004)
    b = chirp(930, 990, 0.16) * env_exp(int(0.16 * SR), 0.07, 0.004)
    x = np.zeros(int(0.32 * SR))
    place(x, a * 0.7, 0.0)
    place(x, b * 0.6, 0.07)
    n = len(x)
    x += 0.25 * filt(white(n, rng), "bp", (2500, 7000)) * env_exp(n, 0.06)
    return reverb(x, 0.8, 0.18, 3)


@snd("discover")
def discover(rng):
    x = np.zeros(int(2.6 * SR))
    for i, f in enumerate((523.25, 659.25, 783.99, 987.77)):
        place(x, bell(f, 1.8) * (0.8 - i * 0.1), i * 0.11)
    return reverb(x, 2.6, 0.32, 5)


@snd("level_up")
def level_up(rng):
    x = np.zeros(int(3.2 * SR))
    for i, f in enumerate((392.0, 523.25, 659.25, 783.99, 1046.5)):
        place(x, bell(f, 2.0, bright=1.3) * 0.75, i * 0.09)
    n = len(x)
    shimmer = filt(white(n, rng), "bp", (5000, 11000)) * env_ar(n, 0.4, 0.6, 0.6) * 0.12
    return reverb(x + shimmer, 3.0, 0.35, 7)


@snd("unlock")
def unlock(rng):
    x = np.zeros(int(0.5 * SR))
    for at, f in ((0.0, 2600), (0.16, 1700)):
        n = int(0.12 * SR)
        click = filt(white(n, rng), "bp", (f * 0.6, f * 1.8)) * env_exp(n, 0.006)
        click += 0.4 * np.sin(2 * np.pi * f * t_axis(0.12)) * env_exp(n, 0.03)
        place(x, click, at)
    return reverb(x, 0.6, 0.15, 9)


@snd("ping")
def ping(rng):
    x = np.zeros(int(1.4 * SR))
    for k, at in enumerate((0.0, 0.22)):
        t = t_axis(0.9)
        tone = (np.sin(2 * np.pi * 1318.5 * t) + 0.4 * np.sin(2 * np.pi * 1975.5 * t)) * env_exp(len(t), 0.18, 0.003)
        place(x, tone * (1.0 if k == 0 else 0.45), at)
    return reverb(x, 1.6, 0.3, 11)


# ================================================================ construcción y herramientas
def thunk(rng, f0=150, sec=0.4, bright=1200):
    n = int(sec * SR)
    t = t_axis(sec)
    body = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.6 * np.exp(-t / 0.02))) / SR) * env_exp(n, 0.07, 0.001)
    noise = filt(white(n, rng), "bp", (200, bright)) * env_exp(n, 0.03, 0.0005)
    return body * 0.9 + noise * 0.7


@snd("build_place")
def build_place(rng):
    x = thunk(rng, 140, 0.45)
    n = len(x)
    x += 0.3 * filt(white(n, rng), "bp", (1500, 5000)) * env_exp(n, 0.05) * (np.arange(n) > 0.02 * SR)
    return reverb(x, 0.9, 0.18, 13, tone=3000)


@snd("build_done")
def build_done(rng):
    x = np.zeros(int(2.6 * SR))
    for i, at in enumerate((0.0, 0.32, 0.64)):
        place(x, thunk(rng, 170 + i * 8, 0.35, 2500) * 0.8, at)
    for i, f in enumerate((659.25, 783.99, 1046.5)):
        place(x, bell(f, 1.4) * 0.35, 1.0 + i * 0.1)
    return reverb(x, 1.6, 0.22, 15)


@snd("tool_hit")
def tool_hit(rng):
    n = int(0.35 * SR)
    x = filt(white(n, rng), "bp", (350, 3500)) * env_exp(n, 0.025, 0.0005)
    x += 0.8 * np.sin(2 * np.pi * 190 * t_axis(0.35)) * env_exp(n, 0.06)
    x += 0.25 * filt(white(n, rng), "bp", (4000, 9000)) * env_exp(n, 0.01)
    return reverb(x, 0.7, 0.15, 17, tone=3500)


@snd("hit")
def hit(rng):
    n = int(0.6 * SR)
    t = t_axis(0.6)
    thump = np.sin(2 * np.pi * np.cumsum(70 + 90 * np.exp(-t / 0.03)) / SR) * env_exp(n, 0.12, 0.002)
    whoosh = filt(white(n, rng), "bp", (300, 2000)) * env_ar(n, 0.04, 0.08, 0.08) * 0.5
    return thump + whoosh


@snd("rattle")
def rattle(rng):
    x = np.zeros(int(1.1 * SR))
    times = np.sort(rng.uniform(0, 0.8, 26))
    for at in times:
        f = rng.uniform(2200, 4800)
        n = int(0.08 * SR)
        c = filt(white(n, rng), "bp", (f * 0.7, f * 1.3)) * env_exp(n, 0.008)
        c += 0.5 * np.sin(2 * np.pi * f * t_axis(0.08)) * env_exp(n, 0.02)
        place(x, c * rng.uniform(0.4, 1.0), at)
    return reverb(x, 0.8, 0.2, 19)


@snd("thunder")
def thunder(rng):
    sec = 7.0
    n = int(sec * SR)
    t = t_axis(sec)
    rumble = filt(brown(n, rng), "lp", 140, 4)
    rolls = np.zeros(n)
    for at in np.sort(rng.uniform(0.15, 3.5, 7)):
        onset = np.clip((t - at) / rng.uniform(0.08, 0.25), 0, 1) ** 2      # sin chasquidos al empezar cada retumbo
        rolls += np.exp(-np.maximum(t - at, 0) / rng.uniform(0.4, 1.4)) * onset * rng.uniform(0.4, 1.0)
    rumble *= rolls * env_ar(n, 0.08, 4.0, 1.2)
    crack = filt(white(n, rng), "bp", (700, 5000)) * env_exp(n, 0.09, 0.004) * 0.5
    return reverb(rumble * 1.6 + crack, 3.0, 0.35, 21, tone=2000)


# ================================================================ puertas y contenedores
def creak(rng, sec, f0, f1, bright=2200):
    n = int(sec * SR)
    t = t_axis(sec)
    f = f0 + (f1 - f0) * (0.5 - 0.5 * np.cos(np.pi * t / sec)) + 18 * np.sin(2 * np.pi * 7 * t)
    pulses = (np.sin(2 * np.pi * np.cumsum(f) / SR) > 0.93).astype(float)
    x = filt(pulses * (0.6 + 0.4 * rng.random(n)), "bp", (f0 * 0.8, bright))
    return x * env_ar(n, 0.06, sec * 0.7, sec * 0.15)


@snd("door_open")
def door_open(rng):
    x = np.zeros(int(1.3 * SR))
    place(x, thunk(rng, 900, 0.08, 6000) * 0.4, 0.0)     # picaporte
    place(x, creak(rng, 0.9, 260, 420), 0.06)
    return reverb(x, 1.2, 0.25, 23, tone=3000)


@snd("door_close")
def door_close(rng):
    x = np.zeros(int(0.9 * SR))
    place(x, creak(rng, 0.35, 380, 300) * 0.6, 0.0)
    place(x, thunk(rng, 110, 0.4, 1600), 0.3)
    place(x, thunk(rng, 1100, 0.06, 7000) * 0.35, 0.33)
    return reverb(x, 1.2, 0.25, 25, tone=2500)


@snd("container_open")
def container_open(rng):
    x = np.zeros(int(0.9 * SR))
    place(x, creak(rng, 0.45, 420, 600, 3000) * 0.7, 0.0)
    n = int(0.5 * SR)
    place(x, filt(white(n, rng), "bp", (1500, 6000)) * env_ar(n, 0.03, 0.1, 0.12) * 0.35, 0.3)
    return reverb(x, 0.8, 0.2, 27)


@snd("container_close")
def container_close(rng):
    x = np.zeros(int(0.6 * SR))
    place(x, thunk(rng, 160, 0.35, 2000), 0.02)
    return reverb(x, 0.7, 0.2, 29, tone=2500)


# ================================================================ pasos
def step(surface, rng):
    sec = 0.32
    n = int(sec * SR)
    t = t_axis(sec)
    if surface == "dirt":
        x = filt(white(n, rng), "bp", (90, 500)) * env_exp(n, 0.035, 0.004) * 1.2
        x += filt(white(n, rng), "bp", (1500, 5000)) * env_exp(n, 0.025, 0.006) * 0.25
    elif surface == "grass":
        x = filt(white(n, rng), "bp", (1400, 7000)) * env_ar(n, 0.02, 0.05, 0.05) * 0.6
        x += filt(white(n, rng), "bp", (80, 400)) * env_exp(n, 0.03, 0.004) * 0.7
    elif surface == "leaves":
        x = filt(white(n, rng), "bp", (100, 450)) * env_exp(n, 0.03, 0.004) * 0.6
        for at in np.sort(rng.uniform(0.0, 0.14, 22)):
            m = int(0.012 * SR)
            place(x, filt(white(m, rng), "bp", (2000, 8000)) * env_exp(m, 0.002) * rng.uniform(0.3, 1.0), at)
    elif surface == "road":
        x = filt(white(n, rng), "bp", (400, 3200)) * env_exp(n, 0.018, 0.001) * 0.9
        x += filt(white(n, rng), "bp", (3000, 9000)) * env_exp(n, 0.006) * 0.35
    elif surface == "rock":
        x = filt(white(n, rng), "bp", (500, 4000)) * env_exp(n, 0.015, 0.001) * 0.8
        x += 0.25 * np.sin(2 * np.pi * rng.uniform(1100, 1500) * t) * env_exp(n, 0.03)
    elif surface == "water":
        x = filt(white(n, rng), "bp", (350, 3000)) * env_ar(n, 0.01, 0.04, 0.09)
        for at in np.sort(rng.uniform(0.03, 0.2, 5)):
            m = int(0.05 * SR)
            place(x, chirp(rng.uniform(400, 700), rng.uniform(900, 1500), 0.05, 0.6) * env_exp(m, 0.012) * 0.3, at)
    else:  # wood
        x = 0.8 * np.sin(2 * np.pi * rng.uniform(150, 190) * t) * env_exp(n, 0.04, 0.001)
        x += 0.35 * np.sin(2 * np.pi * rng.uniform(380, 460) * t) * env_exp(n, 0.025)
        x += filt(white(n, rng), "bp", (300, 2500)) * env_exp(n, 0.012, 0.0005) * 0.6
    return x


for _surf in ("dirt", "grass", "leaves", "road", "rock", "water", "wood"):
    for _i in (1, 2, 3):
        REG["step_%s_%d" % (_surf, _i)] = (lambda s: (lambda rng: step(s, rng)))(_surf)


# ================================================================ criaturas
@snd("brumal_alert")
def brumal_alert(rng):
    sec = 1.6
    n = int(sec * SR)
    t = t_axis(sec)
    huff = filt(white(n, rng), "bp", (180, 1100)) * env_ar(n, 0.03, 0.18, 0.12)
    f = 72 + 6 * np.sin(2 * np.pi * 5.5 * t) + rng.standard_normal(n).cumsum() * 0.002
    growl = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 23 * t)))
    growl = filt(growl, "lp", 700) * env_ar(n, 0.15, 0.9, 0.3)
    x = np.zeros(n)
    place(x, huff[: int(0.5 * SR)] * 1.2, 0.0)
    x += growl * 0.8
    return reverb(x, 2.4, 0.3, 31, tone=2500)


@snd("brumal_call")
def brumal_call(rng):
    sec = 3.4
    n = int(sec * SR)
    t = t_axis(sec)
    f = 54 + 8 * np.sin(np.pi * t / sec)
    v = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) + signal.sawtooth(2 * np.pi * np.cumsum(f * 1.06) / SR)
    sweep = 250 + 650 * np.sin(np.pi * t / sec) ** 2
    out = np.zeros(n)
    blk = 2048
    for i in range(0, n, blk):
        seg = v[max(0, i - 256): i + blk]
        y = filt(seg, "lp", float(sweep[min(i, n - 1)]))
        out[i: i + blk] = y[-len(out[i: i + blk]):]
    breath = filt(white(n, rng), "bp", (300, 1500)) * 0.15
    x = (out * 0.5 + breath) * env_ar(n, 0.6, sec * 0.65, 0.5)
    return reverb(x, 4.0, 0.45, 33, tone=2200)


@snd("farol_puff")
def farol_puff(rng):
    sec = 1.6
    n = int(sec * SR)
    t = t_axis(sec)
    whoosh = np.zeros(n)
    w = white(n, rng)
    for i in range(0, n, 2048):
        f = 700 + 2600 * (i / n)
        seg = filt(w[max(0, i - 512): i + 2048], "bp", (f * 0.6, f * 1.4))
        whoosh[i: i + 2048] = seg[-len(whoosh[i: i + 2048]):]
    whoosh *= env_ar(n, 0.12, 0.3, 0.35)
    sparkle = np.zeros(n)
    for at in np.sort(rng.uniform(0.1, 1.0, 14)):
        place(sparkle, np.sin(2 * np.pi * rng.uniform(3000, 6500) * t_axis(0.12)) * env_exp(int(0.12 * SR), 0.03) * 0.25, at)
    return reverb(whoosh + sparkle, 2.0, 0.35, 35)


@snd("zarzo_squeak")
def zarzo_squeak(rng):
    x = np.zeros(int(0.7 * SR))
    for k, at in enumerate((0.0, 0.13, 0.24)):
        sec = 0.08 + 0.02 * k
        c = chirp(2100 + 200 * k, 3400 - 150 * k, sec, 0.7) * np.hanning(int(sec * SR))
        c += 0.3 * filt(white(len(c), rng), "bp", (3000, 7000)) * np.hanning(len(c))
        place(x, c, at)
    return reverb(x, 0.6, 0.12, 37)


# ================================================================ bucles: hoguera y ambientes
@snd("fire_loop", loop=True)
def fire_loop(rng):
    sec = 14.0
    n = int(sec * SR)
    base = filt(brown(n, rng), "lp", 320) * 0.6 + filt(pink(n, rng), "bp", (400, 2500)) * 0.05
    base *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.3 * t_axis(sec))
    x = base.copy()
    for at in np.sort(rng.uniform(0, sec - 0.1, int(sec * 9))):
        m = int(rng.uniform(0.004, 0.02) * SR)
        place(x, filt(white(m, rng), "bp", (1500, 7000)) * env_exp(m, 0.003) * rng.uniform(0.2, 1.0) ** 2 * 1.2, at)
    for at in rng.uniform(0, sec - 0.2, 6):
        m = int(0.08 * SR)
        place(x, filt(white(m, rng), "bp", (300, 2000)) * env_exp(m, 0.012) * 1.2, at)
    return loopify(x, 1.5)


def bed(sec, rng, wind=0.3, wind_band=(150, 1100)):
    n = int(sec * SR)
    l = filt(pink(n, rng), "bp", wind_band)
    r = filt(pink(n, rng), "bp", wind_band)
    t = t_axis(sec)
    g = 0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * t + rng.uniform(0, 6)) * np.sin(2 * np.pi * 0.013 * t + 1.0)
    return np.stack([l * g, r * g], 1) * wind


def bird(rng):
    """Canto corto: secuencia de sílabas con barrido y armónico."""
    kind = rng.integers(0, 3)
    out = []
    for s in range(rng.integers(2, 6)):
        sec = rng.uniform(0.05, 0.14)
        f0 = rng.uniform(2200, 4200)
        f1 = f0 * rng.uniform(0.75, 1.35) if kind != 2 else f0
        c = chirp(f0, f1, sec, rng.uniform(0.5, 2.0))
        if kind == 2:
            c *= 0.5 + 0.5 * np.sin(2 * np.pi * 38 * t_axis(sec))
        c = (c + 0.2 * chirp(f0 * 2, f1 * 2, sec)) * np.hanning(len(c))
        out.append(c)
        out.append(np.zeros(int(rng.uniform(0.03, 0.12) * SR)))
    return np.concatenate(out)


@snd("amb_forest_day", loop=True)
def amb_forest_day(rng):
    sec = 46.0
    x = bed(sec, rng, 0.35, (180, 1400))
    for at in np.sort(rng.uniform(0, sec - 2, 34)):
        b = bird(rng) * rng.uniform(0.08, 0.3)
        b = reverb(b, 1.4, 0.35, int(at * 100))
        x[int(at * SR): int(at * SR) + len(b)] += pan(b, rng.uniform(-0.9, 0.9))[: len(x) - int(at * SR)]
    return loopify(x, 2.0)


@snd("amb_night", loop=True)
def amb_night(rng):
    sec = 46.0
    n = int(sec * SR)
    t = t_axis(sec)
    x = bed(sec, rng, 0.2, (120, 800))
    for k in range(3):                       # grillos: tren de pulsos a ~4,4 kHz
        f = rng.uniform(4100, 4800)
        rate = rng.uniform(2.2, 3.4)
        gate = ((np.sin(2 * np.pi * rate * t + rng.uniform(0, 6)) > 0.2) * (np.sin(2 * np.pi * 30 * t) > 0)).astype(float)
        gate = filt(gate, "lp", 300)
        c = np.sin(2 * np.pi * f * t) * gate * rng.uniform(0.012, 0.025)
        x += pan(c, rng.uniform(-0.8, 0.8))
    for at in rng.uniform(2, sec - 4, 4):    # búho lejano
        h = np.zeros(int(1.6 * SR))
        for dt in (0.0, 0.45, 0.62):
            ht = t_axis(0.35)
            place(h, np.sin(2 * np.pi * (390 - 30 * ht / 0.35) * ht) * np.hanning(len(ht)) * 0.18, dt)
        h = reverb(h, 2.5, 0.5, int(at * 10))
        x[int(at * SR): int(at * SR) + len(h)] += pan(h, rng.uniform(-0.7, 0.7))[: n - int(at * SR)]
    return loopify(x, 2.0)


@snd("amb_town", loop=True)
def amb_town(rng):
    sec = 46.0
    n = int(sec * SR)
    x = bed(sec, rng, 0.38, (250, 1800))
    whistle = filt(pink(n, rng), "bp", (700, 760), 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t_axis(sec)))
    x += pan(whistle * 0.25, 0.3)
    for at in rng.uniform(1, sec - 3, 5):    # postigos y maderas que crujen
        c = reverb(creak(rng, rng.uniform(0.4, 0.9), rng.uniform(250, 420), rng.uniform(300, 520)) * 0.25, 1.5, 0.4, int(at))
        x[int(at * SR): int(at * SR) + len(c)] += pan(c, rng.uniform(-0.9, 0.9))[: n - int(at * SR)]
    for at in rng.uniform(1, sec - 4, 3):    # campanillas de viento lejanas
        ch = np.zeros(int(3 * SR))
        for k in range(rng.integers(3, 6)):
            place(ch, bell(rng.choice([1046.5, 1174.7, 1318.5, 1568.0]), 1.6) * 0.06, rng.uniform(0, 1.2))
        ch = reverb(ch, 2.0, 0.4, int(at * 7))
        x[int(at * SR): int(at * SR) + len(ch)] += pan(ch, rng.uniform(-0.6, 0.6))[: n - int(at * SR)]
    return loopify(x, 2.0)


@snd("amb_marsh", loop=True)
def amb_marsh(rng):
    sec = 46.0
    n = int(sec * SR)
    t = t_axis(sec)
    x = bed(sec, rng, 0.18, (120, 900))
    lap = filt(brown(n, rng), "bp", (90, 500)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.25 * t))
    x += stereoize(lap * 0.3, np.roll(lap, 5000) * 0.3)
    for at in np.sort(rng.uniform(0, sec - 1, 70)):   # ranas: croar pulsado
        f = rng.uniform(140, 320)
        pulses = rng.integers(2, 6)
        c = np.zeros(int(0.5 * SR))
        for k in range(pulses):
            ct = t_axis(0.05)
            place(c, signal.sawtooth(2 * np.pi * f * ct) * np.hanning(len(ct)), k * 0.07)
        c = filt(c, "bp", (f * 0.8, f * 6)) * rng.uniform(0.05, 0.16)
        x[int(at * SR): int(at * SR) + len(c)] += pan(c, rng.uniform(-0.9, 0.9))[: n - int(at * SR)]
    for at in rng.uniform(0, sec - 1, 16):            # burbujas
        b = chirp(rng.uniform(300, 500), rng.uniform(900, 1600), 0.06, 0.5) * np.hanning(int(0.06 * SR)) * 0.08
        x[int(at * SR): int(at * SR) + len(b)] += pan(b, rng.uniform(-0.5, 0.5))[: n - int(at * SR)]
    insects = np.sin(2 * np.pi * 620 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.3 * t)) * 0.01
    x += stereoize(insects)
    return loopify(x, 2.0)


@snd("amb_interior", loop=True)
def amb_interior(rng):
    sec = 34.0
    n = int(sec * SR)
    room = filt(pink(n, rng), "lp", 420) * 0.12
    x = stereoize(room, np.roll(room, 3000))
    for at in rng.uniform(1, sec - 2, 4):
        c = reverb(creak(rng, rng.uniform(0.3, 0.7), rng.uniform(200, 320), rng.uniform(240, 360)) * 0.2, 1.0, 0.45, int(at * 3))
        x[int(at * SR): int(at * SR) + len(c)] += pan(c, rng.uniform(-0.8, 0.8))[: n - int(at * SR)]
    for at in np.arange(2.0, sec - 1, rng.uniform(3.5, 5.0)):     # gota que cae
        d = chirp(1800, 900, 0.03, 0.5) * np.hanning(int(0.03 * SR)) * 0.08
        d = reverb(d, 1.0, 0.5, int(at * 13))
        x[int(at * SR): int(at * SR) + len(d)] += pan(d, -0.4)[: n - int(at * SR)]
    return loopify(x, 2.0)


@snd("amb_industrial", loop=True)
def amb_industrial(rng):
    sec = 40.0
    n = int(sec * SR)
    t = t_axis(sec)
    hum = sum(np.sin(2 * np.pi * 50 * k * t + k) / k for k in range(1, 6)) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.12 * t))
    hum = filt(hum, "lp", 400) * 0.08
    x = bed(sec, rng, 0.25, (200, 1500)) + stereoize(hum)
    for at in rng.uniform(1, sec - 3, 6):     # golpes metálicos lejanos
        m = int(0.5 * SR)
        f = rng.uniform(300, 900)
        k = (np.sin(2 * np.pi * f * t_axis(0.5)) + 0.6 * np.sin(2 * np.pi * f * 2.7 * t_axis(0.5))) * env_exp(m, 0.12, 0.002)
        k = reverb(k * 0.18, 3.0, 0.6, int(at * 17))
        x[int(at * SR): int(at * SR) + len(k)] += pan(k, rng.uniform(-0.9, 0.9))[: n - int(at * SR)]
    return loopify(x, 2.0)


@snd("amb_wind", loop=True)
def amb_wind(rng):
    sec = 36.0
    n = int(sec * SR)
    t = t_axis(sec)
    out = []
    for c in range(2):
        w = pink(n, rng)
        g = 0.4 + 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t + c)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.023 * t + 2 * c))
        low = filt(w, "bp", (120, 700)) * g
        high = filt(w, "bp", (900, 2600)) * g ** 2 * 0.35
        out.append(low + high)
    return loopify(np.stack(out, 1), 2.5)


@snd("amb_rain", loop=True)
def amb_rain(rng):
    sec = 30.0
    n = int(sec * SR)
    chans = []
    for c in range(2):
        hiss = filt(pink(n, rng), "bp", (700, 9000)) * 0.5
        drops = np.zeros(n)
        idx = rng.integers(0, n - 400, int(sec * 260))
        for i in idx:
            m = 300
            drops[i:i + m] += rng.uniform(0.1, 0.5) * np.exp(-np.arange(m) / 40.0) * rng.choice([-1, 1])
        drops = filt(drops, "bp", (1200, 8000))
        chans.append(hiss + drops * 0.6 + filt(brown(n, rng), "lp", 200) * 0.15)
    return loopify(np.stack(chans, 1), 2.0)


# ================================================================ música del menú
@snd("music_menu", loop=True)
def music_menu(rng):
    bpm = 64.0
    beat = 60.0 / bpm
    bars = 16
    sec = bars * 4 * beat
    n = int(sec * SR)
    t = t_axis(sec)
    # La menor modal: Am — F — C — G (dos vueltas), con bajo y colchón
    prog = [(57, [57, 60, 64, 69]), (53, [53, 57, 60, 65]), (48, [55, 60, 64, 67]), (55, [55, 59, 62, 67])]
    pad = np.zeros((n, 2))
    bass = np.zeros(n)
    for b in range(bars):
        root, notes = prog[(b // 2) % 4]
        start = b * 4 * beat
        dur = 4 * beat
        m = int(dur * SR) + int(1.5 * SR)
        tt = np.arange(m) / SR
        e = np.clip(tt / 1.2, 0, 1) * np.where(tt > dur, np.exp(-(tt - dur) / 0.6), 1.0)
        for k, note in enumerate(notes):
            f = 440 * 2 ** ((note - 69) / 12)
            v = (signal.sawtooth(2 * np.pi * f * 0.998 * tt) + signal.sawtooth(2 * np.pi * f * 1.003 * tt)) * 0.5
            v = filt(v, "lp", 900 + 300 * (k == 3)) * e * 0.05
            i = int(start * SR)
            j = min(n, i + m)
            pad[i:j] += pan(v[: j - i], -0.5 + k / 3)
        f = 440 * 2 ** ((root - 12 - 69) / 12)
        v = np.sin(2 * np.pi * f * tt) * e * 0.12
        i = int(start * SR)
        j = min(n, i + m)
        bass[i:j] += v[: j - i]
    # melodía pulsada (pentatónica de La menor), escasa
    scale = [69, 72, 74, 76, 79, 81]
    mel = np.zeros((n, 2))
    pattern = [0, None, 2, 3, None, 2, 1, None, 4, 3, None, 2, 0, None, None, None]
    for b in range(bars):
        if b % 4 == 3:
            continue
        for s in range(0, 8):
            step_i = (b * 8 + s) % len(pattern)
            if pattern[step_i] is None or rng.random() < 0.25:
                continue
            note = scale[(pattern[step_i] + (b // 4)) % len(scale)]
            f = 440 * 2 ** ((note - 69) / 12)
            p = pluck(f, 2.2) * 0.22
            at = b * 4 * beat + s * beat / 2
            i = int(at * SR)
            j = min(n, i + len(p))
            mel[i:j] += pan(p[: j - i], rng.uniform(-0.4, 0.4))
    air = stereoize(filt(pink(n, rng), "bp", (2000, 7000)) * 0.004, filt(pink(n, rng), "bp", (2000, 7000)) * 0.004)
    mix = pad + stereoize(bass) + reverb(mel, 3.5, 0.45, 41, stereo=True) + air
    mix = reverb(mix, 4.0, 0.25, 43, stereo=True, tone=6000)
    return loopify(pad_end(mix, 0.0), 3.0)


# ================================================================
RMS = {"amb_": -24.0, "fire_loop": -22.0, "music_menu": -21.0}
QUIET_PEAK = {"step_": 0.6, "ui_click": 0.5}


def run(names):
    todo = names or sorted(REG)
    for i, name in enumerate(todo):
        rng = np.random.default_rng(abs(hash(name)) % (2 ** 31) if False else sum(map(ord, name)) * 7919)
        x = REG[name](rng)
        rms = next((v for k, v in RMS.items() if name.startswith(k)), None)
        peak = next((v for k, v in QUIET_PEAK.items() if name.startswith(k)), 0.89)
        path = save(name, x, peak=peak, rms_db=rms, quality=5 if name == "music_menu" else 3)
        dur = len(x) / SR
        print("%-18s %5.1f s  %6.1f KB%s" % (name, dur, os.path.getsize(path) / 1024, "  (bucle)" if name in LOOPS else ""))


if __name__ == "__main__":
    run(sys.argv[1:])
