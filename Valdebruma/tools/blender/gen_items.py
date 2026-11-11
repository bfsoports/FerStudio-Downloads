"""gen_items.py — modelos de los objetos de inventario de Valdebruma.

Ejecutar: blender -b --python tools/blender/gen_items.py
Salida: assets/models/items/<id>.glb (un modelo por ID de data/items.json).
Colores mediante tinte de vértice sobre materiales neutros (item_paint, item_cloth...),
así todos los objetos comparten muy pocos materiales.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
import vb

ITEMS = {}


def item(fn):
    ITEMS[fn.__name__] = fn
    return fn


def P():
    return vb.Parts()


W = (1, 1, 1, 1)


def can(p, r, h, col, band=None, c=(0, 0, 0)):
    p.lathe([(r * 0.92, 0), (r, 0.006), (r, h - 0.006), (r * 0.92, h)], "item_paint", seg=14, c=c, tint=col, close=False)
    if band:
        p.lathe([(r + 0.001, h * 0.3), (r + 0.001, h * 0.62)], "item_paint", seg=14, c=c, tint=band, close=False)
    p.cyl((c[0], c[1], c[2] + h - 0.003), r * 0.92, 0.004, "item_metal", seg=14)
    p.cyl((c[0], c[1], c[2] + 0.002), r * 0.92, 0.004, "item_metal", seg=14)


def bottle(p, liquid=None, c=(0, 0, 0), cap=(0.2, 0.3, 0.6, 1)):
    prof = [(0.0, 0.0), (0.036, 0.0), (0.04, 0.01), (0.04, 0.15), (0.03, 0.19), (0.014, 0.215), (0.014, 0.245)]
    p.lathe(prof, "item_glass", seg=12, c=c, close=False)
    if liquid:
        p.lathe([(0.0, 0.004), (0.035, 0.004), (0.036, 0.13), (0.0, 0.13)], "item_paint", seg=10, c=c, tint=liquid, close=False)
    p.cyl((c[0], c[1], c[2] + 0.252), 0.017, 0.022, "item_paint", seg=10, tint=cap)


@item
def lata_legumbres():
    p = P(); can(p, 0.038, 0.11, (0.72, 0.16, 0.12, 1), (0.9, 0.85, 0.7, 1)); return p


@item
def lata_melocoton():
    p = P(); can(p, 0.042, 0.085, (0.95, 0.62, 0.2, 1), (0.95, 0.9, 0.8, 1)); return p


@item
def conserva_pescado():
    p = P()
    p.box((0, 0, 0.012), (0.105, 0.065, 0.024), "item_paint", tint=(0.16, 0.3, 0.46, 1))
    p.box((0, 0, 0.0245), (0.09, 0.05, 0.002), "item_paint", tint=(0.92, 0.88, 0.72, 1))
    p.lathe([(0.008, 0), (0.011, 0.002), (0.008, 0.004)], "item_metal", seg=8, c=(0.035, 0, 0.026), close=False)
    return p


@item
def galletas():
    p = P()
    p.box((0, 0, 0.025), (0.14, 0.06, 0.05), "item_paint", tint=(0.82, 0.62, 0.3, 1))
    p.box((0, 0, 0.025), (0.06, 0.062, 0.052), "item_paint", tint=(0.6, 0.2, 0.15, 1))
    return p


@item
def barrita():
    p = P()
    p.box((0, 0, 0.009), (0.12, 0.035, 0.018), "item_paint", tint=(0.2, 0.42, 0.26, 1))
    for sx in (-1, 1):
        p.box((sx * 0.066, 0, 0.009), (0.012, 0.038, 0.003), "item_metal")
    return p


@item
def bayas():
    p = P(); rnd = random.Random(1)
    for i in range(11):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(0, 0.03)
        p.sphere((math.cos(a) * r, math.sin(a) * r, 0.012 + rnd.uniform(0, 0.02)), 0.011, "item_paint", seg=7, rings=5, tint=(0.25, 0.16, 0.42, 1))
    p.box((0.02, 0.01, 0.036), (0.05, 0.028, 0.002), "item_paint", tint=(0.25, 0.45, 0.2, 1), rot=(10, 12, 30))
    return p


def mushroom(p, c, s, cap):
    p.push(c, (0, 0, 0), (s, s, s))
    p.lathe([(0.012, 0.0), (0.011, 0.045), (0.008, 0.055)], "item_paint", seg=7, tint=(0.88, 0.84, 0.74, 1), close=False)
    p.lathe([(0.0, 0.05), (0.04, 0.048), (0.045, 0.056), (0.036, 0.072), (0.016, 0.082), (0.0, 0.084)], "item_paint", seg=9, tint=cap, close=False)
    p.pop()


@item
def setas():
    p = P()
    mushroom(p, (0, 0, 0), 1.0, (0.56, 0.32, 0.18, 1)); mushroom(p, (0.05, 0.02, 0), 0.75, (0.6, 0.36, 0.2, 1)); mushroom(p, (-0.03, 0.045, 0), 0.6, (0.52, 0.3, 0.16, 1))
    return p


@item
def setas_asadas():
    p = P()
    p.tube([(-0.11, 0, 0.02), (0.11, 0, 0.02)], 0.004, "item_wood", seg=5)
    for k, x in enumerate((-0.05, 0.0, 0.05)):
        p.lathe([(0.0, -0.012), (0.03, -0.01), (0.032, 0.0), (0.02, 0.012), (0.0, 0.014)], "item_paint", seg=8, c=(x, 0, 0.02), rot=(0, 90 + k * 20, 0), tint=(0.36, 0.22, 0.12, 1), close=False)
    return p


@item
def manzana():
    p = P()
    p.sphere((0, 0, 0.035), 0.036, "item_paint", seg=10, rings=7, scale=(1, 1, 0.92), tint=(0.72, 0.2, 0.14, 1))
    p.tube([(0, 0, 0.066), (0.006, 0, 0.082)], 0.003, "item_wood", seg=4)
    return p


@item
def guiso():
    p = P()
    p.lathe([(0.03, 0.0), (0.06, 0.015), (0.075, 0.05), (0.07, 0.05), (0.057, 0.02), (0.03, 0.008)], "item_metal", seg=12, close=False)
    p.cyl((0, 0, 0.04), 0.066, 0.004, "item_paint", seg=12, tint=(0.5, 0.28, 0.12, 1))
    p.tube([(0.02, 0.01, 0.045), (0.11, 0.06, 0.075)], 0.005, "item_metal", seg=5)
    return p


@item
def refresco():
    p = P(); can(p, 0.033, 0.12, (0.2, 0.55, 0.62, 1), (0.95, 0.95, 0.9, 1)); return p


@item
def botella_vacia():
    p = P(); bottle(p); return p


@item
def agua_turbia():
    p = P(); bottle(p, (0.42, 0.4, 0.26, 1), cap=(0.5, 0.4, 0.2, 1)); return p


@item
def agua_potable():
    p = P(); bottle(p, (0.45, 0.72, 0.9, 1)); return p


@item
def infusion():
    p = P()
    p.lathe([(0.0, 0.0), (0.034, 0.0), (0.04, 0.085), (0.036, 0.085), (0.031, 0.008)], "item_paint", seg=12, tint=(0.85, 0.82, 0.74, 1), close=False)
    p.cyl((0, 0, 0.07), 0.035, 0.003, "item_paint", seg=12, tint=(0.4, 0.5, 0.2, 1))
    p.tube([(0.04, 0, 0.07), (0.066, 0, 0.06), (0.066, 0, 0.03), (0.038, 0, 0.02)], 0.006, "item_paint", seg=5, tint=(0.85, 0.82, 0.74, 1))
    return p


@item
def venda():
    p = P()
    p.lathe([(0.012, 0.0), (0.03, 0.0), (0.03, 0.05), (0.012, 0.05)], "item_cloth", seg=12, tint=(1.6, 1.6, 1.5, 1), close=False)
    p.box((0.045, 0, 0.025), (0.035, 0.002, 0.05), "item_cloth", tint=(1.6, 1.6, 1.5, 1))
    return p


@item
def botiquin():
    p = P()
    p.box((0, 0, 0.05), (0.22, 0.09, 0.14), "item_paint", tint=(0.16, 0.42, 0.26, 1))
    p.box((0, -0.046, 0.05), (0.06, 0.002, 0.018), "item_paint", tint=(0.95, 0.95, 0.92, 1))
    p.box((0, -0.046, 0.05), (0.018, 0.002, 0.06), "item_paint", tint=(0.95, 0.95, 0.92, 1))
    p.tube([(-0.04, 0, 0.12), (-0.04, 0, 0.14), (0.04, 0, 0.14), (0.04, 0, 0.12)], 0.006, "item_dark", seg=5)
    return p


@item
def pastillas():
    p = P()
    p.lathe([(0.0, 0), (0.02, 0), (0.021, 0.05), (0.014, 0.056)], "item_paint", seg=10, tint=(0.9, 0.55, 0.15, 1), close=False)
    p.cyl((0, 0, 0.062), 0.016, 0.014, "item_paint", seg=10, tint=W)
    p.lathe([(0.0212, 0.012), (0.0212, 0.04)], "item_paint", seg=10, tint=W, close=False)
    return p


@item
def unguento():
    p = P()
    p.lathe([(0.0, 0), (0.03, 0), (0.032, 0.03), (0.03, 0.034)], "item_glass", seg=12, close=False)
    p.lathe([(0.0, 0.003), (0.028, 0.003), (0.029, 0.026), (0.0, 0.026)], "item_paint", seg=10, tint=(0.55, 0.62, 0.3, 1), close=False)
    p.cyl((0, 0, 0.04), 0.033, 0.012, "item_metal", seg=12)
    return p


@item
def filtro():
    p = P()
    p.lathe([(0.02, 0), (0.042, 0.004), (0.042, 0.035), (0.03, 0.04), (0.018, 0.04), (0.018, 0.052)], "item_dark", seg=12)
    for z in (0.012, 0.022):
        p.lathe([(0.0425, z - 0.003), (0.0445, z), (0.0425, z + 0.003)], "item_paint", seg=12, tint=(0.75, 0.6, 0.2, 1), close=False)
    return p


@item
def palo():
    p = P(); rnd = random.Random(2)
    for k in range(3):
        y = (k - 1) * 0.02
        p.tube([(-0.3, y, 0.012 + k * 0.004), (0.0, y + rnd.uniform(-0.01, 0.01), 0.014), (0.3, y + rnd.uniform(-0.02, 0.02), 0.012)], [0.011, 0.012, 0.008], "bark_oak", seg=5)
    return p


@item
def tablon():
    p = P()
    p.box((0, 0, 0.012), (0.9, 0.12, 0.024), "item_wood")
    p.box((0.02, 0.02, 0.036), (0.86, 0.12, 0.024), "item_wood", rot=(0, 0, 3))
    return p


@item
def piedra():
    p = P()
    p.sphere((0, 0, 0.035), 0.05, "rock_boulder", seg=7, rings=5, scale=(1.2, 0.9, 0.7), rot=(0, 10, 20))
    p.sphere((0.07, 0.03, 0.022), 0.03, "rock_boulder", seg=6, rings=4, scale=(1.1, 1, 0.75))
    return p


@item
def fibra():
    p = P(); rnd = random.Random(3)
    for k in range(9):
        y = rnd.uniform(-0.02, 0.02)
        p.tube([(-0.18, y * 2.2, 0.008), (0, y, 0.012 + rnd.uniform(0, 0.012)), (0.18, y * 2.5, 0.008)], 0.004, "item_paint", seg=3, tint=(0.62, 0.66, 0.34, 1))
    p.lathe([(0.026, -0.008), (0.026, 0.008)], "item_paint", seg=8, c=(0, 0, 0.014), rot=(0, 90, 0), tint=(0.45, 0.36, 0.2, 1), close=False)
    return p


@item
def cuerda():
    p = P()
    for k in range(4):
        pts = [(math.cos(a) * (0.085 - k * 0.004), math.sin(a) * (0.085 - k * 0.004), 0.012 + k * 0.016) for a in [i * 2 * math.pi / 14 for i in range(15)]]
        p.tube(pts, 0.009, "item_paint", seg=5, tint=(0.66, 0.54, 0.34, 1), cap=False)
    return p


@item
def tela():
    p = P()
    for k in range(3):
        p.box((0, 0, 0.012 + k * 0.022), (0.2 - k * 0.01, 0.15 - k * 0.006, 0.02), "item_cloth", tint=(1.2, 1.0, 0.8, 1), rot=(0, 0, k * 3))
    return p


@item
def chatarra():
    p = P()
    p.box((0, 0, 0.006), (0.18, 0.12, 0.004), "metal_rust", rot=(0, 4, 10))
    p.box((0.03, 0.02, 0.03), (0.12, 0.004, 0.06), "metal_rust", rot=(14, 0, 30))
    p.lathe([(0.012, 0), (0.04, 0), (0.04, 0.012), (0.012, 0.012)], "item_metal", seg=8, c=(-0.05, 0.02, 0.01), close=False)
    p.tube([(-0.02, -0.06, 0.01), (0.1, -0.05, 0.016)], 0.008, "metal_rust", seg=5)
    return p


@item
def clavos():
    p = P()
    p.box((0, 0, 0.02), (0.08, 0.055, 0.04), "item_paint", tint=(0.62, 0.48, 0.32, 1))
    for k in range(4):
        p.tube([(0.06 + k * 0.012, -0.02 + k * 0.008, 0.003), (0.06 + k * 0.012 + 0.03, 0.02, 0.003)], 0.002, "item_metal", seg=4)
    return p


@item
def cinta():
    p = P()
    p.lathe([(0.03, 0.0), (0.052, 0.0), (0.052, 0.045), (0.03, 0.045)], "item_paint", seg=14, tint=(0.52, 0.54, 0.56, 1))
    p.lathe([(0.03, 0.045), (0.03, 0.0)], "item_paint", seg=14, tint=(0.62, 0.5, 0.34, 1), close=False)
    return p


@item
def lona():
    p = P()
    p.cyl((0, 0, 0.06), 0.06, 0.4, "item_cloth", seg=10, rot=(0, 90, 0), tint=(0.5, 0.7, 0.45, 1))
    for x in (-0.12, 0.12):
        p.lathe([(0.062, -0.012), (0.062, 0.012)], "item_dark", seg=10, c=(x, 0, 0.06), rot=(0, 90, 0), close=False)
    return p


@item
def hierbas():
    p = P(); rnd = random.Random(5)
    for k in range(7):
        y = rnd.uniform(-0.02, 0.02)
        p.tube([(-0.1, y, 0.008), (0.04, y * 1.5, 0.014), (0.13, y * 3 + rnd.uniform(-0.02, 0.02), 0.012)], 0.003, "item_paint", seg=3, tint=(0.35, 0.5, 0.28, 1))
        p.sphere((0.13, y * 3, 0.016), 0.012, "item_paint", seg=5, rings=4, tint=(0.9, 0.88, 0.76, 1), scale=(1.4, 1, 0.6))
    p.lathe([(0.02, -0.005), (0.02, 0.005)], "item_paint", seg=7, c=(-0.06, 0, 0.012), rot=(0, 90, 0), tint=(0.6, 0.5, 0.3, 1), close=False)
    return p


@item
def pilas():
    p = P()
    for k in (0, 1):
        p.cyl((0, k * 0.03, 0.013), 0.013, 0.045, "item_paint", seg=10, rot=(0, 90, 0), tint=(0.15, 0.15, 0.16, 1))
        p.cyl((0.014, k * 0.03, 0.013), 0.0135, 0.016, "item_paint", seg=10, rot=(0, 90, 0), tint=(0.8, 0.5, 0.15, 1))
        p.cyl((0.026, k * 0.03, 0.013), 0.005, 0.006, "item_metal", seg=6, rot=(0, 90, 0))
    return p


@item
def liquen():
    p = P()
    p.lathe([(0.0, 0), (0.035, 0), (0.037, 0.07), (0.03, 0.078)], "item_glass", seg=12, close=False)
    p.cyl((0, 0, 0.085), 0.032, 0.014, "item_metal", seg=12)
    for k in range(4):
        a = k * 1.57
        p.sphere((math.cos(a) * 0.012, math.sin(a) * 0.012, 0.018 + k * 0.008), 0.016, "lichen_glow", seg=6, rings=4, scale=(1, 1, 0.6))
    return p


@item
def hachuela():
    p = P()
    p.tube([(0, 0, 0.012), (0.3, 0, 0.012), (0.34, 0, 0.016)], [0.014, 0.013, 0.015], "item_wood", seg=6)
    p.push((0.02, 0, 0.012), (90, 0, 0))
    p.prism([(-0.035, -0.02), (0.035, -0.014), (0.035, 0.03), (0.0, 0.085), (-0.055, 0.09), (-0.03, 0.03)], -0.012, 0.012, "item_metal")
    p.pop()
    return p


@item
def martillo():
    p = P()
    p.tube([(0, 0, 0.014), (0.28, 0, 0.014)], [0.012, 0.014], "item_wood", seg=6)
    p.box((0.0, 0, 0.014), (0.03, 0.09, 0.03), "item_metal")
    p.box((0.0, -0.055, 0.014), (0.022, 0.025, 0.022), "item_metal", rot=(0, 0, 0))
    return p


@item
def palanca():
    p = P()
    p.tube([(-0.32, 0, 0.012), (0.26, 0, 0.012), (0.31, 0, 0.03), (0.33, 0, 0.07)], 0.011, "item_paint", seg=6, tint=(0.5, 0.12, 0.1, 1))
    p.box((-0.33, 0, 0.01), (0.04, 0.026, 0.006), "item_paint", tint=(0.5, 0.12, 0.1, 1), rot=(0, 12, 0))
    return p


@item
def linterna():
    p = P()
    p.lathe([(0.0, 0), (0.017, 0), (0.017, 0.12), (0.028, 0.14), (0.028, 0.175)], "item_dark", seg=12, rot=(0, 90, 0), c=(-0.09, 0, 0.028), close=False)
    p.cyl((0.086, 0, 0.028), 0.026, 0.004, "lamp_glass", seg=12, rot=(0, 90, 0))
    p.box((-0.01, 0, 0.047), (0.03, 0.012, 0.006), "item_paint", tint=(0.8, 0.2, 0.15, 1))
    return p


@item
def farol():
    p = P()
    p.lathe([(0.0, 0), (0.05, 0), (0.055, 0.03), (0.035, 0.045)], "item_metal", seg=10)
    p.lathe([(0.033, 0.045), (0.045, 0.09), (0.033, 0.14)], "item_glass", seg=10, close=False)
    p.sphere((0, 0, 0.085), 0.016, "lamp_glass", seg=6, rings=5)
    p.lathe([(0.035, 0.14), (0.045, 0.15), (0.02, 0.175), (0.0, 0.18)], "item_metal", seg=10, close=False)
    p.tube([(-0.05, 0, 0.14), (-0.055, 0, 0.2), (0, 0, 0.235), (0.055, 0, 0.2), (0.05, 0, 0.14)], 0.003, "item_dark", seg=4, cap=False)
    return p


@item
def espantador():
    p = P()
    p.tube([(0, 0, 0.02), (0.26, 0, 0.02)], 0.011, "item_wood", seg=6)
    can(p, 0.035, 0.09, (0.6, 0.6, 0.58, 1), c=(0.27, 0, -0.02))
    can(p, 0.03, 0.07, (0.72, 0.3, 0.2, 1), c=(0.2, 0.05, -0.012))
    p.tube([(0.24, 0, 0.03), (0.2, 0.05, 0.06)], 0.002, "item_paint", seg=3, tint=(0.6, 0.5, 0.3, 1))
    return p


@item
def brujula():
    p = P()
    p.lathe([(0.0, 0), (0.036, 0), (0.038, 0.012), (0.034, 0.016)], "item_paint", seg=14, tint=(0.72, 0.56, 0.26, 1), close=False)
    p.cyl((0, 0, 0.012), 0.033, 0.003, "item_paint", seg=14, tint=(0.92, 0.9, 0.82, 1))
    p.box((0.012, 0, 0.0145), (0.026, 0.006, 0.001), "item_paint", tint=(0.75, 0.12, 0.1, 1))
    p.box((-0.012, 0, 0.0145), (0.026, 0.006, 0.001), "item_dark")
    p.cyl((0, 0, 0.017), 0.034, 0.002, "item_glass", seg=14)
    return p


def key(p, col):
    p.lathe([(0.012, -0.002), (0.02, -0.002), (0.02, 0.002), (0.012, 0.002)], "item_paint", seg=10, tint=col)
    p.box((0.045, 0, 0), (0.055, 0.007, 0.004), "item_paint", tint=col)
    for x in (0.055, 0.066):
        p.box((x, -0.007, 0), (0.006, 0.01, 0.004), "item_paint", tint=col)


@item
def llave_estacion():
    p = P()
    p.box((0, 0, 0.003), (0.085, 0.054, 0.004), "item_paint", tint=(0.9, 0.9, 0.92, 1))
    p.box((0, 0.012, 0.0055), (0.07, 0.016, 0.001), "item_paint", tint=(0.1, 0.2, 0.36, 1))
    p.box((-0.02, -0.012, 0.0055), (0.02, 0.014, 0.001), "item_paint", tint=(0.8, 0.65, 0.2, 1))
    return p


@item
def llave_archivo():
    p = P(); p.push((0, 0, 0.004)); key(p, (0.72, 0.56, 0.26, 1)); p.pop(); return p


@item
def gorro_lana():
    p = P()
    p.lathe([(0.095, 0.0), (0.1, 0.03), (0.092, 0.035), (0.09, 0.08), (0.06, 0.13), (0.0, 0.15)], "item_cloth", seg=12, tint=(1.3, 0.5, 0.35, 1), close=False)
    p.sphere((0, 0, 0.16), 0.03, "item_cloth", seg=7, rings=5, tint=(1.6, 1.5, 1.3, 1))
    return p


def folded(p, col, collar=None):
    p.box((0, 0, 0.03), (0.34, 0.26, 0.06), "item_cloth", tint=col)
    p.box((0, 0.02, 0.075), (0.3, 0.2, 0.03), "item_cloth", tint=col, rot=(0, 0, 2))
    if collar:
        p.box((0, 0.1, 0.1), (0.16, 0.05, 0.03), "item_cloth", tint=collar)
        p.box((0, 0.0, 0.092), (0.012, 0.18, 0.004), "item_dark")


@item
def chaqueta_campo():
    p = P(); folded(p, (0.55, 0.62, 0.4, 1), (0.4, 0.46, 0.3, 1)); return p


@item
def impermeable():
    p = P(); folded(p, (1.6, 1.25, 0.3, 1), (1.3, 1.0, 0.25, 1)); return p


@item
def pantalon_monte():
    p = P()
    p.box((0, 0, 0.025), (0.3, 0.2, 0.05), "item_cloth", tint=(0.6, 0.52, 0.4, 1))
    p.box((0, 0, 0.065), (0.28, 0.19, 0.03), "item_cloth", tint=(0.6, 0.52, 0.4, 1), rot=(0, 0, -3))
    p.box((0, -0.09, 0.082), (0.28, 0.02, 0.006), "item_dark")
    return p


@item
def botas_monte():
    p = P()
    for sx in (-1, 1):
        p.push((sx * 0.07, 0, 0), (0, 0, sx * 6))
        p.box((0, -0.03, 0.012), (0.1, 0.28, 0.024), "item_dark")
        p.box((0, -0.07, 0.05), (0.095, 0.17, 0.06), "leather_brown")
        p.lathe([(0.046, 0.02), (0.05, 0.1), (0.054, 0.2)], "leather_brown", seg=9, c=(0, 0.06, 0.02), close=False)
        p.pop()
    return p


def backpack(p, w, h, d, col):
    p.box((0, 0, h / 2), (w, d, h), "item_cloth", tint=col)
    p.box((0, -d / 2 - 0.02, h * 0.3), (w * 0.7, 0.05, h * 0.4), "item_cloth", tint=tuple(c * 0.85 for c in col[:3]) + (1,))
    p.box((0, -0.01, h + 0.012), (w * 1.02, d * 1.05, 0.03), "item_cloth", tint=tuple(c * 0.8 for c in col[:3]) + (1,))
    for sx in (-1, 1):
        p.box((sx * w * 0.28, d / 2 + 0.012, h * 0.5), (0.045, 0.02, h * 0.85), "item_dark")
    p.tube([(-0.04, 0, h + 0.025), (-0.03, 0, h + 0.07), (0.03, 0, h + 0.07), (0.04, 0, h + 0.025)], 0.008, "item_dark", seg=5)


@item
def mochila_pequena():
    p = P(); backpack(p, 0.28, 0.36, 0.14, (0.5, 0.56, 0.62, 1)); return p


@item
def mochila_grande():
    p = P(); backpack(p, 0.34, 0.56, 0.2, (0.48, 0.58, 0.36, 1))
    p.cyl((0, 0, 0.63), 0.07, 0.36, "item_cloth", seg=9, rot=(0, 90, 0), tint=(0.7, 0.45, 0.3, 1))
    for sx in (-1, 1):
        p.box((sx * 0.19, 0, 0.2), (0.05, 0.14, 0.2), "item_cloth", tint=(0.4, 0.5, 0.3, 1))
    return p


@item
def mascarilla():
    p = P()
    p.sphere((0, 0, 0.05), 0.07, "item_dark", seg=10, rings=7, scale=(1, 0.75, 0.85))
    for sx in (-1, 1):
        p.lathe([(0.02, 0), (0.042, 0.004), (0.042, 0.03), (0.03, 0.035)], "item_paint", seg=10, c=(sx * 0.07, -0.02, 0.04), rot=(90, 0, sx * 35), tint=(0.75, 0.6, 0.2, 1))
    p.tube([(-0.065, 0.02, 0.07), (-0.08, 0.12, 0.08), (0.08, 0.12, 0.08), (0.065, 0.02, 0.07)], 0.006, "item_dark", seg=4, cap=False)
    return p


def run():
    vb.reset()
    n = 0
    for name, fn in ITEMS.items():
        p = fn()
        ob = p.build(name, bevel=0.0, ao=True, ao_dist=0.05, ao_strength=0.55, ao_samples=10, smooth=50, ground=0.0)
        vb.export([ob], "items/" + name)
        n += 1
        vb.clear_objects()
    print("ITEMS", n, " ".join(ITEMS.keys()))


if __name__ == "__main__":
    run()
