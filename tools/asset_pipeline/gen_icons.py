#!/usr/bin/env python3
"""
SECTOR ABANDONADO - HUD / control / perk icon set (SVG, 128x128).
One consistent visual language: bone-white glyphs (#F0EBDD), 10px strokes,
rounded caps, no text. Colour is applied in-game via modulate / badges.
"""
import os, sys

OUT = sys.argv[1]
W = '#F0EBDD'
S = f'stroke="{W}" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" fill="none"'
F = f'fill="{W}"'

ICONS = {
 'health': f'<path d="M64 22 v84 M22 64 h84" {S} stroke-width="22"/>',
 'ammo': f'<g {F}><path d="M30 104 V52 q0-22 12-30 q12 8 12 30 V104z"/><path d="M58 104 V52 q0-22 12-30 q12 8 12 30 V104z"/><path d="M86 104 V52 q0-22 12-30 q12 8 12 30 V104z"/></g>',
 'points': f'<circle cx="64" cy="64" r="40" {S}/><path d="M64 40 v48 M50 52 q0-10 14-10 q14 0 14 10 q0 10-14 12 q-14 2-14 12 q0 10 14 10 q14 0 14-10" {S} stroke-width="8"/>',
 'skull': f'<path {F} d="M64 16c-26 0-44 18-44 42 0 14 6 24 14 30v18h60V88c8-6 14-16 14-30 0-24-18-42-44-42z"/><circle cx="46" cy="60" r="11" fill="#141612"/><circle cx="82" cy="60" r="11" fill="#141612"/><path d="M58 82 l6-10 l6 10z" fill="#141612"/><path d="M52 106v-10M64 106v-10M76 106v-10" stroke="#141612" stroke-width="5"/>',
 'grenade': f'<ellipse cx="62" cy="76" rx="30" ry="34" {F}/><rect x="50" y="28" width="26" height="16" rx="3" {F}/><path d="M76 36 q20-6 26 10" {S} stroke-width="7"/><path d="M40 70h44M40 88h44M62 46v62" stroke="#141612" stroke-width="5"/>',
 'interact': f'<path {F} d="M48 112 c-12-12-24-30-24-40 0-6 8-8 12-2l8 12V30c0-6 10-6 10 0v30-34c0-6 10-6 10 0v34-28c0-6 10-6 10 0v30-22c0-6 10-6 10 0v44c0 18-6 30-14 38z"/>',
 'reload': f'<path d="M98 54 A36 36 0 1 0 98 78" {S}/><path d="M104 30 v28 h-28" {S}/>',
 'jump': f'<path d="M30 74 L64 40 L98 74" {S} stroke-width="14"/><path d="M30 104 L64 70 L98 104" {S} stroke-width="14" opacity="0.6"/>',
 'aim': f'<circle cx="64" cy="64" r="34" {S} stroke-width="8"/><path d="M64 14v28M64 86v28M14 64h28M86 64h28" {S} stroke-width="8"/><circle cx="64" cy="64" r="6" {F}/>',
 'fire': f'<circle cx="64" cy="64" r="12" {F}/><path d="M64 16v22M64 90v22M16 64h22M90 64h22M30 30l14 14M84 84l14 14M98 30l-14 14M44 84l-14 14" {S} stroke-width="9"/>',
 'switch': f'<path d="M24 46h70M80 30l18 16-18 16" {S}/><path d="M104 84H34M48 68l-18 16 18 16" {S}/>',
 'pause': f'<rect x="34" y="26" width="20" height="76" rx="4" {F}/><rect x="74" y="26" width="20" height="76" rx="4" {F}/>',
 'repair': f'<path d="M30 98 L74 54" {S} stroke-width="14"/><path {F} d="M60 26h40l8 10-8 10h-12v18l-12 12-12-12V46H60z"/>',
 'door': f'<path d="M34 112V22h52v90" {S}/><path d="M22 112h84" {S}/><circle cx="74" cy="68" r="6" {F}/>',
 'mystery': f'<rect x="18" y="52" width="92" height="56" rx="6" {S}/><path d="M18 52 l12-22h68l12 22" {S}/><path d="M52 70 q0-10 12-10 q12 0 12 10 q0 8-12 10v6" {S} stroke-width="8"/><circle cx="64" cy="98" r="4" {F}/>',
 'forge': f'<path {F} d="M22 54h70c0 10 8 18 18 18v8H84l-6 14h14v10H38V94h14l-6-14c-14 0-24-12-24-26z"/><path d="M60 14 l-10 22 h14 l-8 18" stroke="#7DFF40" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
 'sprint': f'<path d="M30 40l20 24-20 24M60 40l20 24-20 24M90 40l20 24-20 24" {S}/>',
 'settings': f'<circle cx="64" cy="64" r="16" {S}/><path d="M64 14v16M64 98v16M14 64h16M98 64h16M29 29l11 11M88 88l11 11M99 29l-11 11M40 88l-11 11" {S} stroke-width="12"/><circle cx="64" cy="64" r="34" {S}/>',
 'trophy': f'<path d="M40 22h48v26c0 16-10 28-24 28s-24-12-24-28z" {F}/><path d="M40 32H24c0 16 8 24 18 24M88 32h16c0 16-8 24-18 24" {S} stroke-width="8"/><path d="M64 76v18M44 108h40M50 96h28" {S}/>',
 'back': f'<path d="M80 26 L42 64 L80 102" {S} stroke-width="14"/>',
 'play': f'<path {F} d="M40 24 L106 64 L40 104z"/>',
 'exit': f'<path d="M54 24H28v80h26" {S}/><path d="M50 64h56M86 44l20 20-20 20" {S}/>',
 'credits': f'<circle cx="64" cy="42" r="18" {S}/><path d="M28 108c0-22 16-36 36-36s36 14 36 36" {S}/>',
 'clock': f'<circle cx="64" cy="66" r="42" {S}/><path d="M64 40v28l18 12" {S}/>',
 'target': f'<circle cx="64" cy="64" r="44" {S} stroke-width="8"/><circle cx="64" cy="64" r="24" {S} stroke-width="8"/><circle cx="64" cy="64" r="7" {F}/>',
 'speaker': f'<path {F} d="M20 50h22l28-22v72L42 78H20z"/><path d="M84 46q12 18 0 36M96 34q22 30 0 60" {S} stroke-width="8"/>',
 'music': f'<path d="M50 96V30l50-10v62" {S}/><circle cx="38" cy="96" r="14" {F}/><circle cx="88" cy="84" r="14" {F}/>',
 'hand_touch': f'<circle cx="64" cy="64" r="44" {S} stroke-width="8" stroke-dasharray="14 10"/><circle cx="64" cy="64" r="16" {F}/>',
 # perks (glyph only, badge colour added in-game)
 'perk_vitality': f'<path {F} d="M64 14 L104 30 V60 c0 26-16 44-40 54 c-24-10-40-28-40-54 V30z"/><path d="M64 40v40M44 60h40" stroke="#141612" stroke-width="12" stroke-linecap="round"/>',
 'perk_reload': f'<path d="M96 52 A34 34 0 1 0 96 80" {S} stroke-width="11"/><path d="M102 28v28H74" {S} stroke-width="11"/><path d="M62 40 l-10 26 h14 l-8 22" {S} stroke-width="8"/>',
 'perk_speed': f'<path {F} d="M70 10 L30 70 h28 L48 118 L98 52 H70z"/>',
 'perk_damage': f'<path {F} d="M54 112V58q0-30 10-42q10 12 10 42v54z"/><path d="M30 46 q-8 20 8 34 M98 46 q8 20-8 34 M40 28 q-14 10-12 26 M88 28 q14 10 12 26" {S} stroke-width="7"/>',
 'perk_regen': f'<path {F} d="M64 108 C20 76 14 54 22 38 c8-16 30-20 42 0 c12-20 34-16 42 0 c8 16 2 38-42 70z"/><path d="M64 46v36M46 64h36" stroke="#141612" stroke-width="10" stroke-linecap="round"/>',
}

STRIP = '''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="16" viewBox="0 0 64 16">
<rect width="64" height="16" fill="#E08A1A"/><path d="M0 16 L16 0 H32 L16 16z M32 16 L48 0 H64 L48 16z" fill="#141612"/></svg>'''

os.makedirs(OUT, exist_ok=True)
for name, body in ICONS.items():
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{body}</svg>'
    open(os.path.join(OUT, name + '.svg'), 'w').write(svg)
open(os.path.join(OUT, 'hazard_strip.svg'), 'w').write(STRIP)
print('icons:', len(ICONS) + 1)
