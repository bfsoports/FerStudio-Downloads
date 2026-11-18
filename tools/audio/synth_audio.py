#!/usr/bin/env python3
"""
SECTOR ABANDONADO - procedural sound design.
Every sound effect and music loop of the game is synthesised here from
scratch (noise, oscillators, filters, formants, envelopes): 100% original,
no samples from any other game.

Usage: synth_audio.py <sfx_out_dir> <music_out_dir>
"""
import os
import sys
import subprocess
import wave
import numpy as np
from scipy import signal

SR = 22050
MSR = 32000
rng = np.random.default_rng(2026)


# ----------------------------------------------------------------------------- utils

def t(d, sr=SR):
    return np.arange(int(d * sr)) / sr


def noise(d, sr=SR):
    return rng.uniform(-1, 1, int(d * sr))


def env_exp(d, decay, attack=0.002, sr=SR):
    x = t(d, sr)
    e = np.exp(-x / max(decay, 1e-4))
    if attack > 0:
        e *= np.clip(x / attack, 0, 1)
    return e


def lp(x, fc, sr=SR, order=2):
    b, a = signal.butter(order, min(fc / (sr / 2), 0.99), 'low')
    return signal.lfilter(b, a, x)


def hp(x, fc, sr=SR, order=2):
    b, a = signal.butter(order, min(fc / (sr / 2), 0.99), 'high')
    return signal.lfilter(b, a, x)


def bp(x, f0, q, sr=SR):
    b, a = signal.iirpeak(min(f0 / (sr / 2), 0.98), q)
    return signal.lfilter(b, a, x)


def sweep_sine(f0, f1, d, sr=SR, curve=3.0):
    x = t(d, sr)
    k = (x / d) ** (1 / curve) if curve != 1 else x / d
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def saw(f, d, sr=SR):
    ph = np.cumsum(np.broadcast_to(f, int(d * sr)) / sr) if np.ndim(f) else np.arange(int(d * sr)) * f / sr
    return 2 * (ph % 1.0) - 1


def pad(x, d, sr=SR):
    n = int(d * sr)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts, sr=SR):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset, total, sr=SR):
    out = np.zeros(int(total * sr))
    s = int(offset * sr)
    e = min(len(out), s + len(x))
    out[s:e] += x[:e - s]
    return out


def reverb(x, length=0.8, wet=0.3, sr=SR, damp=3000):
    ir = noise(length, sr) * np.exp(-t(length, sr) / (length / 5))
    ir = lp(ir, damp, sr)
    w = signal.fftconvolve(x, ir)[:len(x) + int(length * sr)]
    w /= np.max(np.abs(w)) + 1e-9
    dry = np.concatenate([x, np.zeros(len(w) - len(x))])
    return dry * (1 - wet) + w * wet * np.max(np.abs(x))


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.002, fout=0.02, sr=SR):
    x = x.copy()
    a, b = int(fin * sr), int(fout * sr)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


# ----------------------------------------------------------------------------- weapons

def gunshot(body_d, cutoff, thump_f, tail, crack=0.0, loud=1.0):
    click = hp(noise(0.006), 2500) * env_exp(0.006, 0.0015)
    body = lp(noise(body_d), cutoff) * env_exp(body_d, body_d / 4)
    body = np.tanh(body * 3.0)
    thump = sweep_sine(thump_f, thump_f * 0.35, 0.18, curve=0.5) * env_exp(0.18, 0.05)
    tl = lp(noise(tail), 1400) * env_exp(tail, tail / 4, attack=0.01) * 0.35
    parts = [pad(click, tail + 0.2) * 0.8, pad(body, tail + 0.2), pad(thump, tail + 0.2) * 0.9, at(tl, 0.02, tail + 0.2)]
    if crack > 0:
        cr = hp(noise(0.02), 4000) * env_exp(0.02, 0.004) * crack
        parts.append(pad(cr, tail + 0.2))
    x = mix(*parts)
    x = reverb(x, 0.6, 0.18)
    return fade(norm(x, 0.95 * loud), 0.0005, 0.08)


def mech_click(f=2400, d=0.05, q=8):
    x = bp(noise(d), f, q) * env_exp(d, d / 6)
    x += np.sin(2 * np.pi * f * 1.5 * t(d)) * env_exp(d, d / 8) * 0.3
    return x


def seq(events, total):
    return mix(*[at(x, o, total) for o, x in events])


def reload(kind):
    if kind == 'pistol':
        x = seq([(0.05, mech_click(1800, 0.06)), (0.55, mech_click(1500, 0.08) * 1.2), (0.9, mech_click(2600, 0.05)), (1.0, mech_click(2000, 0.07))], 1.3)
    elif kind == 'smg':
        x = seq([(0.1, mech_click(1600, 0.08)), (0.9, mech_click(1400, 0.1) * 1.2), (1.5, mech_click(2800, 0.05)), (1.6, mech_click(2100, 0.08))], 1.9)
    elif kind == 'rifle':
        x = seq([(0.1, mech_click(1500, 0.09)), (1.0, mech_click(1300, 0.11) * 1.2), (1.75, mech_click(2900, 0.05)), (1.85, mech_click(1900, 0.09))], 2.2)
    elif kind == 'lmg':
        x = seq([(0.1, mech_click(1200, 0.1)), (0.6, lp(noise(0.5), 1500) * env_exp(0.5, 0.15) * 0.4), (1.5, mech_click(1100, 0.12) * 1.3),
                 (2.6, mech_click(2400, 0.06)), (3.0, mech_click(1700, 0.1))], 3.5)
    else:  # shell
        x = seq([(0.02, mech_click(3200, 0.04)), (0.12, mech_click(1900, 0.06))], 0.35)
    return fade(norm(x, 0.7))


def pump():
    return fade(norm(seq([(0.0, mech_click(900, 0.09, 4) * 1.4), (0.18, mech_click(1300, 0.1, 4))], 0.4), 0.8))


def bolt():
    return fade(norm(seq([(0.0, mech_click(1700, 0.06)), (0.12, mech_click(1100, 0.08)), (0.35, mech_click(1400, 0.07)), (0.45, mech_click(2200, 0.05))], 0.6), 0.7))


# ----------------------------------------------------------------------------- creatures

def formant_voice(d, f0, f0_end, formants, breath=0.3, jitter=0.03, dist=2.0, vib=6.0):
    x = t(d)
    f = np.linspace(f0, f0_end, len(x)) * (1 + jitter * np.sin(2 * np.pi * vib * x + rng.uniform(0, 6)) + jitter * 0.5 * lp(noise(d), 20) * 4)
    src = saw(f, d) + breath * noise(d)
    out = np.zeros_like(src)
    for (fc, q, g) in formants:
        drift = fc * (1 + 0.08 * np.sin(2 * np.pi * 0.7 * x))
        # time-varying approx: process in 4 chunks
        chunks = np.array_split(np.arange(len(src)), 6)
        for c in chunks:
            out[c] += bp(src, float(np.mean(drift[c])), q)[c] * g
    out = np.tanh(out * dist)
    return out


def groan(seed):
    r = np.random.default_rng(seed)
    d = r.uniform(1.1, 1.9)
    f0 = r.uniform(65, 105)
    v = formant_voice(d, f0, f0 * r.uniform(0.7, 0.95), [(r.uniform(450, 650), 4, 1.0), (r.uniform(900, 1200), 5, 0.6), (2400, 6, 0.2)], breath=0.4)
    e = np.sin(np.pi * np.clip(t(d) / d, 0, 1)) ** 0.7
    return fade(norm(reverb(v * e, 0.5, 0.15), 0.8), 0.02, 0.1)


def screech(seed):
    r = np.random.default_rng(seed)
    d = r.uniform(0.6, 1.0)
    f0 = r.uniform(240, 360)
    v = formant_voice(d, f0, f0 * 1.3, [(900, 4, 1.0), (1800, 6, 0.8), (3200, 7, 0.4)], breath=0.7, jitter=0.06, dist=3.0, vib=11)
    e = env_exp(d, d / 2.5, attack=0.03)
    return fade(norm(v * e, 0.8), 0.01, 0.08)


def tank_roar():
    d = 2.2
    v = formant_voice(d, 58, 44, [(380, 3, 1.0), (750, 4, 0.7), (1500, 5, 0.3)], breath=0.5, jitter=0.05, dist=4.0, vib=4)
    sub = np.sin(2 * np.pi * np.cumsum(np.linspace(29, 22, int(d * SR))) / SR) * 0.6
    e = np.clip(t(d) / 0.25, 0, 1) * np.exp(-np.clip(t(d) - 1.4, 0, None) / 0.3)
    return fade(norm(reverb((v + sub) * e, 1.0, 0.25), 0.95), 0.02, 0.15)


def zombie_attack(seed):
    r = np.random.default_rng(seed)
    d = 0.55
    v = formant_voice(d, r.uniform(110, 150), 80, [(600, 4, 1.0), (1300, 5, 0.6)], breath=0.6, jitter=0.07, dist=3.5)
    return fade(norm(v * env_exp(d, 0.22, attack=0.02), 0.85))


def zombie_death(seed):
    r = np.random.default_rng(seed)
    d = 1.2
    v = formant_voice(d, r.uniform(120, 160), 45, [(520, 4, 1.0), (1000, 5, 0.5)], breath=0.5, dist=2.5)
    gurgle = lp(noise(d), 300) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * t(d)))) * 0.4
    return fade(norm((v + gurgle) * env_exp(d, 0.45, attack=0.01), 0.8))


def flesh_hit():
    d = 0.25
    x = lp(noise(d), 700) * env_exp(d, 0.05) + sweep_sine(160, 60, d) * env_exp(d, 0.06) * 0.8
    return fade(norm(x, 0.85))


# ----------------------------------------------------------------------------- world

def explosion(d=2.2, big=True):
    n = noise(d)
    x = t(d)
    fc = 5000 * np.exp(-x / 0.25) + 250
    out = np.zeros_like(n)
    chunks = np.array_split(np.arange(len(n)), 24)
    for c in chunks:
        out[c] = lp(n, float(np.mean(fc[c])))[c]
    out *= env_exp(d, d / 4, attack=0.003)
    sub = sweep_sine(70, 25, 0.8, curve=0.5) * env_exp(0.8, 0.3) * (1.2 if big else 0.6)
    crackle = (rng.uniform(0, 1, len(n)) > 0.997) * rng.uniform(-1, 1, len(n)) * np.exp(-x / 0.6)
    y = mix(np.tanh(out * 2.5), sub, hp(crackle, 2000) * 0.6)
    return fade(norm(reverb(y, 1.2, 0.3, damp=1800), 0.98), 0.0005, 0.2)


def thud(f=70, d=0.5, n=0.5):
    x = sweep_sine(f, f * 0.4, d, curve=0.5) * env_exp(d, d / 4) + lp(noise(d), 400) * env_exp(d, 0.06) * n
    return fade(norm(x, 0.9))


def wood_crack():
    d = 0.4
    x = bp(noise(d), 1200, 2) * env_exp(d, 0.05)
    snap = hp(noise(0.02), 3000) * env_exp(0.02, 0.004) * 0.8
    x = mix(x, snap, at(mech_click(800, 0.08, 3), 0.03, d) * 0.8)
    return fade(norm(x, 0.85))


def hammer():
    return fade(norm(mix(mech_click(1800, 0.06, 5) * 1.3, at(thud(140, 0.15, 0.3), 0.0, 0.2) * 0.6), 0.8))


def rumble(d=1.6):
    x = lp(noise(d), 350) * (np.sin(np.pi * t(d) / d) ** 0.5)
    deb = sum(at(mech_click(rng.uniform(600, 1800), 0.05, 3) * rng.uniform(0.2, 0.6), rng.uniform(0, d - 0.1), d) for _ in range(14))
    return fade(norm(x + deb, 0.85))


def whoosh(d=0.35, f0=600, f1=2500):
    n = noise(d)
    x = t(d)
    out = np.zeros_like(n)
    for c in np.array_split(np.arange(len(n)), 10):
        fc = f0 + (f1 - f0) * float(np.mean(x[c])) / d
        out[c] = bp(n, fc, 1.5)[c]
    return fade(norm(out * np.sin(np.pi * x / d), 0.5))


def tone(freqs, d, decay, kind='sine', amp=1.0):
    x = t(d)
    out = np.zeros_like(x)
    for f in np.atleast_1d(freqs):
        if kind == 'sine':
            out += np.sin(2 * np.pi * f * x)
        elif kind == 'square':
            out += np.sign(np.sin(2 * np.pi * f * x)) * 0.5
        elif kind == 'bell':
            out += np.sin(2 * np.pi * f * x) + 0.4 * np.sin(2 * np.pi * f * 2.76 * x) * np.exp(-x / (decay * 0.4))
    return out * env_exp(d, decay, attack=0.004) * amp


def arpeggio(notes, step, d_each, decay, kind='bell'):
    total = step * len(notes) + d_each
    return mix(*[at(tone(f, d_each, decay, kind), i * step, total) for i, f in enumerate(notes)])


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def stinger(chord, d=2.5, bright=1800, hit=True):
    x = t(d)
    out = np.zeros_like(x)
    for n in chord:
        f = midi(n)
        for det in (-0.4, 0.0, 0.4):
            out += saw(f * (1 + det / 100), d)
    out = lp(out, bright) * env_exp(d, d / 2.5, attack=0.03)
    if hit:
        out = mix(out, thud(55, 1.0, 0.8) * 2.0)
    return fade(norm(reverb(out, 1.5, 0.35), 0.85), 0.005, 0.3)


def glug():
    total = 0.9
    parts = []
    for i in range(5):
        f = rng.uniform(180, 300)
        b = sweep_sine(f, f * 1.8, 0.09) * env_exp(0.09, 0.03)
        parts.append(at(b, i * 0.15, total))
    return fade(norm(mix(*parts), 0.7))


def hum_rise(d=3.0):
    x = t(d)
    f = 50 + 70 * (x / d) ** 2
    hum = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    hiss = hp(noise(d), 3000) * (x / d) * 0.3
    return fade(norm((hum * 0.7 + hiss) * np.clip(x / 0.3, 0, 1), 0.8), 0.01, 0.2)


def anvil():
    return fade(norm(mix(tone([820, 1340, 2210], 1.5, 0.5, 'bell'), thud(120, 0.3, 0.6) * 0.8), 0.9))


def step(seed):
    r = np.random.default_rng(seed)
    d = 0.12
    x = lp(noise(d), r.uniform(500, 900)) * env_exp(d, 0.025) + hp(noise(d), 2500) * env_exp(d, 0.01) * 0.25
    return fade(norm(x, 0.6))


# ----------------------------------------------------------------------------- music

def music_pad(d, chords, sr=MSR, bright=900, lfo=0.07):
    x = t(d, sr)
    out = np.zeros_like(x)
    seg = d / len(chords)
    for i, ch in enumerate(chords):
        s, e = int(i * seg * sr), int((i + 1) * seg * sr)
        tt = x[s:e] - x[s]
        env = np.clip(tt / 2.0, 0, 1) * np.clip((seg - tt) / 2.0, 0, 1)
        for n in ch:
            f = midi(n)
            for det in (-0.12, 0.12):
                ph = f * (1 + det / 100) * tt
                out[s:e] += (2 * (ph % 1) - 1) * env * 0.25
    cut = bright * (1 + 0.5 * np.sin(2 * np.pi * lfo * x))
    y = np.zeros_like(out)
    for c in np.array_split(np.arange(len(out)), 60):
        y[c] = lp(out, float(np.mean(cut[c])), sr)[c]
    return y


def drum_kick(sr=MSR):
    return sweep_sine(110, 40, 0.35, sr, curve=0.4) * env_exp(0.35, 0.12, sr=sr)


def drum_tom(f, sr=MSR):
    return sweep_sine(f, f * 0.6, 0.4, sr, curve=0.6) * env_exp(0.4, 0.15, sr=sr) + lp(noise(0.4, sr), 800, sr) * env_exp(0.4, 0.04, sr=sr) * 0.3


def metal_hit(sr=MSR):
    d = 2.0
    x = t(d, sr)
    out = sum(np.sin(2 * np.pi * f * x) * np.exp(-x / r) for f, r in [(310, 1.2), (523, 0.9), (787, 0.6), (1210, 0.4)])
    return out * 0.25


def loopify(x, xfade, sr=MSR):
    n = int(xfade * sr)
    head = x[:n].copy()
    body = x[:-n].copy() if n > 0 else x
    body[:n] = body[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    return body


def place(track, x, at_s, sr=MSR, gain=1.0):
    s = int(at_s * sr)
    e = min(len(track), s + len(x))
    if s < len(track):
        track[s:e] += x[:e - s] * gain


def music_menu():
    d = 48.0
    ch = [[50, 57, 62, 65], [46, 53, 58, 62], [48, 55, 60, 63], [45, 52, 57, 61]]
    pad_ = music_pad(d + 4, ch * 2, bright=700)
    tr = pad_ * 0.8
    for i in range(0, int(d), 6):
        place(tr, metal_hit(), i + 3.0, gain=0.25)
    for i in range(0, int(d), 2):
        place(tr, drum_kick(), i, gain=0.25 if (i // 2) % 2 == 0 else 0.12)
    wind = lp(noise(d + 4, MSR), 500, MSR) * 0.15
    return norm(loopify(tr + wind, 4.0), 0.7)


def music_ambient():
    d = 44.0
    ch = [[38, 45, 50], [36, 43, 48], [41, 48, 53], [37, 44, 49]]
    tr = music_pad(d + 4, ch * 2, bright=420, lfo=0.04) * 0.9
    notes = [62, 65, 69, 67, 60, 64]
    for i, n in enumerate(range(0, int(d), 4)):
        f = midi(notes[i % len(notes)])
        place(tr, tone(f, 3.5, 1.2, 'bell', 0.25).astype(float) if False else np.sin(2 * np.pi * f * t(3.5, MSR)) * env_exp(3.5, 1.0, sr=MSR) * 0.18, n + 1.0)
    tr += lp(noise(d + 4, MSR), 300, MSR) * 0.12
    return norm(loopify(tr, 4.0), 0.6)


def music_tension():
    d = 32.0
    bpm = 96
    beat = 60 / bpm
    ch = [[38, 45, 50, 53], [38, 44, 50, 53], [36, 43, 48, 51], [37, 44, 49, 52]]
    tr = music_pad(d + 4, ch * 2, bright=650, lfo=0.12) * 0.6
    b = 0.0
    k = 0
    while b < d + 2:
        place(tr, drum_kick(), b, gain=0.55)
        if k % 4 == 2:
            place(tr, drum_tom(140), b, gain=0.35)
        if k % 8 == 7:
            place(tr, drum_tom(100), b + beat / 2, gain=0.35)
        # ostinato
        f = midi([50, 50, 53, 50, 48, 50, 55, 53][k % 8])
        o = np.sign(np.sin(2 * np.pi * f * t(beat * 0.9, MSR))) * env_exp(beat * 0.9, beat * 0.3, sr=MSR) * 0.08
        place(tr, lp(o, 1200, MSR), b)
        b += beat
        k += 1
    return norm(loopify(tr, 4.0), 0.75)


def music_boss():
    d = 32.0
    bpm = 124
    beat = 60 / bpm
    tr = music_pad(d + 4, [[38, 45, 50, 56], [36, 43, 48, 54]] * 4, bright=1100, lfo=0.25) * 0.5
    b = 0.0
    k = 0
    while b < d + 2:
        place(tr, drum_kick(), b, gain=0.7)
        if k % 2 == 1:
            place(tr, hp(noise(0.12, MSR), 3000, MSR) * env_exp(0.12, 0.03, sr=MSR), b, gain=0.25)
        if k % 4 == 3:
            place(tr, drum_tom(120), b + beat * 0.5, gain=0.5)
        f = midi([26, 26, 29, 26, 31, 29, 26, 24][k % 8])
        bass = np.tanh(saw(f, beat * 0.95, MSR) * 3) * env_exp(beat * 0.95, beat * 0.5, sr=MSR) * 0.25
        place(tr, lp(bass, 900, MSR), b)
        if k % 16 == 0:
            st = sum(saw(midi(n), 1.2, MSR) for n in (62, 65, 68)) * env_exp(1.2, 0.5, sr=MSR) * 0.12
            place(tr, lp(st, 2200, MSR), b)
        b += beat
        k += 1
    return norm(loopify(tr, 3.0), 0.8)


def ambience_city():
    d = 48.0
    x = t(d + 4, MSR)
    wind = np.zeros_like(x)
    n = noise(d + 4, MSR)
    cut = 300 + 250 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * x) * np.sin(2 * np.pi * 0.013 * x))
    for c in np.array_split(np.arange(len(n)), 80):
        wind[c] = lp(n, float(np.mean(cut[c])), MSR)[c]
    tr = wind * 0.5
    for s in (6.0, 29.0):
        sd = 9.0
        sx = t(sd, MSR)
        f = 620 + 140 * np.sin(2 * np.pi * 0.35 * sx)
        siren = np.sin(2 * np.pi * np.cumsum(f) / MSR) * np.sin(np.pi * sx / sd) * 0.05
        place(tr, lp(siren, 1500, MSR), s)
    for i in range(10):
        cr = bp(noise(0.6, MSR), rng.uniform(300, 700), 6, MSR) * env_exp(0.6, 0.25, sr=MSR) * 0.25
        place(tr, cr, rng.uniform(0, d))
    for i in range(5):
        place(tr, metal_hit() * 0.15, rng.uniform(0, d))
    return norm(loopify(tr, 4.0), 0.55)


def write_ogg(path, x, sr=MSR):
    tmp = path + '.tmp.wav'
    write_wav(tmp, x, sr)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '3', path], check=True)
    os.remove(tmp)


# ----------------------------------------------------------------------------- main

def main():
    sfx, mus = sys.argv[1], sys.argv[2]
    os.makedirs(sfx, exist_ok=True)
    os.makedirs(mus, exist_ok=True)
    S = {}
    S['shot_pistol'] = gunshot(0.12, 3600, 150, 0.55)
    S['shot_shotgun'] = gunshot(0.32, 2200, 85, 1.1, loud=1.0)
    S['shot_smg'] = gunshot(0.07, 5200, 190, 0.3)
    S['shot_rifle'] = gunshot(0.12, 4300, 115, 0.7, crack=0.4)
    S['shot_sniper'] = gunshot(0.26, 3000, 70, 1.5, crack=1.0)
    S['shot_lmg'] = gunshot(0.14, 3100, 95, 0.8, crack=0.3)
    S['reload_pistol'] = reload('pistol')
    S['reload_smg'] = reload('smg')
    S['reload_rifle'] = reload('rifle')
    S['reload_lmg'] = reload('lmg')
    S['reload_shell'] = reload('shell')
    S['pump'] = pump()
    S['bolt'] = bolt()
    S['dry_fire'] = fade(norm(mech_click(2800, 0.05), 0.5))
    S['weapon_switch'] = fade(norm(mix(whoosh(0.25, 400, 1200), at(mech_click(2000, 0.05), 0.15, 0.3)), 0.6))
    S['aim'] = whoosh(0.18, 300, 900)
    for i in range(1, 5):
        S[f'step_{i}'] = step(i)
    S['land'] = thud(90, 0.25, 0.8)
    S['jump'] = whoosh(0.25, 300, 800)
    S['player_hurt'] = fade(norm(mix(flesh_hit(), at(formant_voice(0.3, 140, 110, [(700, 4, 1.0), (1200, 5, 0.5)], dist=1.5) * env_exp(0.3, 0.12), 0.02, 0.35) * 0.6), 0.85))
    S['player_death'] = stinger([38, 41, 45], 3.0, 900)
    for i in range(1, 5):
        S[f'zombie_groan_{i}'] = groan(100 + i)
    for i in range(1, 4):
        S[f'zombie_screech_{i}'] = screech(200 + i)
        S[f'zombie_attack_{i}'] = zombie_attack(300 + i)
        S[f'zombie_death_{i}'] = zombie_death(400 + i)
    S['tank_roar'] = tank_roar()
    S['zombie_hit_player'] = flesh_hit()
    S['vault'] = whoosh(0.4, 200, 700)
    S['slam'] = fade(norm(mix(thud(50, 1.0, 1.0) * 1.2, rumble(1.0) * 0.4), 0.95))
    S['explosion'] = explosion(2.2, True)
    S['explosion_small'] = explosion(0.9, False)
    S['grenade_throw'] = whoosh(0.4, 500, 2000)
    S['grenade_beep'] = fade(tone(2400, 0.05, 0.03) * 0.6)
    S['purchase'] = fade(norm(mix(tone([1318, 1975], 0.6, 0.18, 'bell'), at(tone([2637], 0.5, 0.15, 'bell'), 0.09, 0.7)), 0.7))
    S['deny'] = fade(norm(tone([110, 117], 0.3, 0.2, 'square'), 0.5))
    S['ammo_pickup'] = fade(norm(seq([(0.0, mech_click(1500, 0.06)), (0.12, mech_click(2200, 0.05)), (0.25, mech_click(1800, 0.07))], 0.4), 0.7))
    S['weapon_take'] = fade(norm(mix(mech_click(1300, 0.1) * 1.2, at(tone([880, 1320], 0.4, 0.15, 'bell') * 0.5, 0.05, 0.5)), 0.8))
    S['door_open'] = rumble(1.8)
    S['plank_break'] = wood_crack()
    S['plank_repair'] = hammer()
    S['box_open'] = fade(norm(mix(arpeggio([midi(n) for n in (69, 72, 76, 81, 84)], 0.12, 0.8, 0.4), at(whoosh(0.6, 200, 600) * 0.5, 0, 1.4)), 0.8))
    S['box_tick'] = fade(norm(mech_click(3000, 0.03, 10), 0.4))
    S['box_reveal'] = fade(norm(mix(tone([midi(n) for n in (72, 76, 79, 84)], 1.4, 0.6, 'bell')), 0.8))
    S['box_close'] = thud(100, 0.3, 0.6)
    S['box_leave'] = stinger([45, 48, 51, 54], 2.4, 1200, hit=False)
    S['forge_start'] = hum_rise(3.4)
    S['forge_done'] = anvil()
    S['perk_drink'] = glug()
    S['perk_gain'] = fade(norm(arpeggio([midi(n) for n in (64, 67, 71, 76, 79)], 0.08, 0.6, 0.3), 0.8))
    S['round_start'] = stinger([38, 45, 50, 53], 3.0, 1300)
    S['round_end'] = stinger([45, 52, 57, 61], 2.6, 1600, hit=False)
    S['game_over'] = stinger([36, 39, 43, 46], 4.0, 900)
    S['hit_marker'] = fade(tone(3200, 0.03, 0.01) * 0.6)
    S['hit_kill'] = fade(norm(mix(tone(2600, 0.05, 0.015), thud(160, 0.12, 0.2) * 0.5), 0.7))
    S['ui_click'] = fade(tone(2000, 0.04, 0.01) * 0.5)
    S['ui_confirm'] = fade(norm(arpeggio([880, 1320], 0.07, 0.25, 0.1, 'sine'), 0.6))
    S['ui_open'] = whoosh(0.3, 300, 1500)
    for k, v in S.items():
        write_wav(os.path.join(sfx, k + '.wav'), v)
    print('sfx:', len(S))
    M = {'menu': music_menu(), 'ambient_game': music_ambient(), 'tension': music_tension(), 'boss': music_boss(), 'ambience_city': ambience_city()}
    for k, v in M.items():
        write_ogg(os.path.join(mus, k + '.ogg'), v)
    print('music:', len(M))


if __name__ == '__main__':
    main()
