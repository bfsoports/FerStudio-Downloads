#!/usr/bin/env python3
"""Generates resources/*.tres and data/balance/*.json from one balance table."""
import json, os
ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'game')

WEAPONS = [
 dict(id='pistol', display_name='P-9 VIGÍA', upgraded_name='P-9 ÚLTIMO ALIENTO', category=0, icon_name='w_pistol',
      model_path='res://assets/weapons/pistol.glb', description='Pistola semiautomática fiable.',
      damage=34.0, headshot_multiplier=3.0, fire_rate=380.0, automatic=False, mag_size=10, reserve_max=80, reload_time=1.35,
      spread_hip=1.6, spread_ads=0.25, recoil_pitch=1.6, recoil_yaw=0.5, ads_fov=58.0, max_range=55.0, falloff_start=18.0,
      fire_sound='shot_pistol', reload_sound='reload_pistol', wall_cost=0, ammo_cost=200, box_weight=0.0, in_box=False,
      view_offset=(0.16, -0.17, -0.34), ads_offset=(0.0, -0.075, -0.26), pap_damage_mult=3.2, pap_mag_mult=1.6, pap_reserve_mult=1.6,
      pap_fire_rate_mult=1.2, pap_effect='explosive', pap_tint=(1.0, 0.45, 0.15), kick_back=0.045, kick_up=7.0, switch_time=0.35, tracer_chance=0.0),
 dict(id='shotgun', display_name='ROMPEPUERTAS 12', upgraded_name='ESCUPEFUEGO 12', category=1, icon_name='w_shotgun',
      model_path='res://assets/weapons/shotgun.glb', description='Escopeta de corredera. Devastadora a corta distancia.',
      damage=26.0, headshot_multiplier=1.6, pellets=8, fire_rate=72.0, automatic=False, mag_size=6, reserve_max=42, reload_time=0.5,
      reload_per_shell=True, spread_hip=7.0, spread_ads=4.5, recoil_pitch=5.5, recoil_yaw=1.2, ads_fov=60.0, max_range=22.0, falloff_start=7.0,
      min_damage_factor=0.25, fire_sound='shot_shotgun', reload_sound='reload_shell', wall_cost=750, ammo_cost=300, box_weight=1.0,
      view_offset=(0.17, -0.2, -0.42), ads_offset=(0.0, -0.11, -0.34), pap_damage_mult=2.2, pap_mag_mult=1.35, pap_effect='incendiary',
      pap_tint=(1.0, 0.5, 0.1), kick_back=0.12, kick_up=10.0, move_speed_mult=0.95, tracer_chance=0.15),
 dict(id='smg', display_name='AVISPA MK2', upgraded_name='ENJAMBRE', category=2, icon_name='w_smg',
      model_path='res://assets/weapons/smg.glb', description='Subfusil de alta cadencia, ideal para pasillos.',
      damage=24.0, headshot_multiplier=2.2, fire_rate=820.0, automatic=True, mag_size=30, reserve_max=180, reload_time=1.9,
      spread_hip=2.6, spread_ads=0.9, recoil_pitch=0.65, recoil_yaw=0.45, ads_fov=60.0, max_range=40.0, falloff_start=14.0,
      fire_sound='shot_smg', reload_sound='reload_smg', wall_cost=1000, ammo_cost=500, box_weight=1.0,
      view_offset=(0.16, -0.19, -0.36), ads_offset=(0.0, -0.1, -0.28), pap_damage_mult=2.0, pap_effect='shock', pap_tint=(0.35, 0.8, 1.0),
      kick_back=0.025, kick_up=1.6, tracer_chance=0.3),
 dict(id='rifle', display_name='CENTINELA AR', upgraded_name='GUARDIÁN ETERNO', category=3, icon_name='w_rifle',
      model_path='res://assets/weapons/rifle.glb', description='Fusil de asalto equilibrado. Preciso y contundente.',
      damage=42.0, headshot_multiplier=2.5, fire_rate=600.0, automatic=True, mag_size=30, reserve_max=210, reload_time=2.2,
      spread_hip=2.2, spread_ads=0.35, recoil_pitch=0.95, recoil_yaw=0.4, ads_fov=50.0, max_range=80.0, falloff_start=35.0, penetration=1,
      fire_sound='shot_rifle', reload_sound='reload_rifle', wall_cost=1400, ammo_cost=700, box_weight=1.0,
      view_offset=(0.16, -0.2, -0.36), ads_offset=(0.0, -0.105, -0.27), pap_damage_mult=2.1, pap_effect='piercing', pap_tint=(0.55, 1.0, 0.3),
      kick_back=0.035, kick_up=2.2, tracer_chance=0.4),
 dict(id='sniper', display_name='HALCÓN .50', upgraded_name='OJO DEL JUICIO', category=4, icon_name='w_sniper',
      model_path='res://assets/weapons/sniper.glb', description='Rifle de cerrojo. Atraviesa filas enteras.',
      damage=260.0, headshot_multiplier=3.0, fire_rate=48.0, automatic=False, mag_size=5, reserve_max=40, reload_time=2.8,
      spread_hip=6.0, spread_ads=0.0, recoil_pitch=6.0, recoil_yaw=0.8, ads_fov=24.0, max_range=150.0, falloff_start=150.0, penetration=4,
      fire_sound='shot_sniper', reload_sound='reload_rifle', wall_cost=1500, ammo_cost=750, box_weight=0.8,
      view_offset=(0.17, -0.2, -0.46), ads_offset=(0.0, -0.13, -0.24), pap_damage_mult=2.5, pap_effect='explosive', pap_tint=(1.0, 0.35, 0.2),
      kick_back=0.14, kick_up=9.0, move_speed_mult=0.92, tracer_chance=1.0),
 dict(id='lmg', display_name='TRITURADORA M60X', upgraded_name='APOCALIPSIS', category=5, icon_name='w_lmg',
      model_path='res://assets/weapons/lmg.glb', description='Ametralladora pesada con cargador enorme.',
      damage=40.0, headshot_multiplier=2.0, fire_rate=700.0, automatic=True, mag_size=100, reserve_max=400, reload_time=3.6,
      spread_hip=3.6, spread_ads=1.2, recoil_pitch=0.8, recoil_yaw=0.6, ads_fov=55.0, max_range=75.0, falloff_start=30.0, penetration=2,
      fire_sound='shot_lmg', reload_sound='reload_lmg', wall_cost=0, ammo_cost=0, box_weight=0.7,
      view_offset=(0.17, -0.22, -0.4), ads_offset=(0.0, -0.12, -0.3), pap_damage_mult=1.9, pap_mag_mult=1.25, pap_effect='incendiary',
      pap_tint=(1.0, 0.6, 0.15), kick_back=0.04, kick_up=2.0, move_speed_mult=0.85, tracer_chance=0.5),
]

ZOMBIES = [
 dict(id='walker', display_name='Errante', model_path='res://assets/zombies/zombie_walker.glb', base_health=150.0, health_per_round=100.0,
      health_mult_after_10=1.1, walk_speed=1.15, run_speed=2.6, run_from_round=4, sprint_chance_per_round=0.07, damage=28.0,
      attack_range=1.35, attack_cooldown=1.25, points_hit=10, points_kill=60, points_headshot_bonus=40, scale=1.0, armor=0.0,
      head_height=1.55, radius=0.34, height=1.75, anim_walk='walk', anim_walk_alt='walk2', anim_run='run', anim_attack='attack',
      anim_attack_alt='attack2', anim_hit='hit', anim_death='death', anim_death_alt='death2', anim_idle='idle', anim_spawn='rise',
      groan_sound='zombie_groan', tint=(1, 1, 1)),
 dict(id='runner', display_name='Corredor', model_path='res://assets/zombies/zombie_runner.glb', base_health=110.0, health_per_round=70.0,
      health_mult_after_10=1.08, walk_speed=3.4, run_speed=5.2, run_from_round=1, sprint_chance_per_round=1.0, damage=18.0, attack_range=1.25,
      attack_cooldown=0.7, points_hit=10, points_kill=80, points_headshot_bonus=40, scale=0.98, armor=0.0, head_height=1.5, radius=0.32,
      height=1.7, anim_walk='run', anim_walk_alt='run', anim_run='run', anim_attack='attack_jab', anim_attack_alt='attack2', anim_hit='hit2',
      anim_death='death2', anim_death_alt='death', anim_idle='idle', anim_spawn='rise', groan_sound='zombie_screech', tint=(1, 1, 1), min_round=3,
      spawn_weight=0.18, spawn_weight_per_round=0.02, max_weight=0.35),
 dict(id='armored', display_name='Blindado', model_path='res://assets/zombies/zombie_armored.glb', base_health=420.0, health_per_round=180.0,
      health_mult_after_10=1.1, walk_speed=0.95, run_speed=1.6, run_from_round=8, sprint_chance_per_round=0.05, damage=34.0, attack_range=1.4,
      attack_cooldown=1.4, points_hit=10, points_kill=130, points_headshot_bonus=60, scale=1.05, armor=0.45, head_height=1.6, radius=0.38,
      height=1.85, anim_walk='walk2', anim_walk_alt='walk', anim_run='walk', anim_attack='attack2', anim_attack_alt='attack', anim_hit='hit',
      anim_death='death', anim_death_alt='death2', anim_idle='idle', anim_spawn='rise', groan_sound='zombie_groan', tint=(1, 1, 1), min_round=6,
      spawn_weight=0.08, spawn_weight_per_round=0.012, max_weight=0.2),
 dict(id='tank', display_name='Tanque', model_path='res://assets/zombies/zombie_tank.glb', base_health=2400.0, health_per_round=650.0,
      health_mult_after_10=1.1, walk_speed=1.35, run_speed=2.9, run_from_round=12, sprint_chance_per_round=0.04, damage=60.0, attack_range=2.0,
      attack_cooldown=1.9, points_hit=10, points_kill=400, points_headshot_bonus=100, scale=1.45, armor=0.25, head_height=1.5, radius=0.6,
      height=2.0, anim_walk='walk', anim_walk_alt='walk', anim_run='walk', anim_attack='attack_slam', anim_attack_alt='attack', anim_hit='hit',
      anim_death='death', anim_death_alt='death', anim_idle='idle', anim_spawn='roar', groan_sound='tank_roar', tint=(1, 1, 1), min_round=9,
      spawn_weight=0.025, spawn_weight_per_round=0.004, max_weight=0.07, max_alive=2, stagger_resist=0.85, attack_shockwave=True),
 dict(id='boss', display_name='EL CAPATAZ', model_path='res://assets/zombies/zombie_tank.glb', base_health=9000.0, health_per_round=1800.0,
      health_mult_after_10=1.0, walk_speed=1.7, run_speed=4.2, run_from_round=1, sprint_chance_per_round=0.0, damage=55.0, attack_range=2.4,
      attack_cooldown=1.6, points_hit=15, points_kill=2500, points_headshot_bonus=0, scale=1.85, armor=0.3, head_height=1.5, radius=0.8,
      height=2.0, anim_walk='walk', anim_walk_alt='walk', anim_run='run', anim_attack='attack_slam', anim_attack_alt='attack2', anim_hit='hit',
      anim_death='death', anim_death_alt='death', anim_idle='idle', anim_spawn='roar', groan_sound='tank_roar', tint=(0.62, 0.7, 0.58),
      is_boss=True, stagger_resist=1.0, attack_shockwave=True, emissive=(0.12, 0.35, 0.06)),
]

PERKS = [
 dict(id='vitality', display_name='CORAZA', description='Vida máxima +100%. Aguanta más golpes.', price=2500, icon_name='perk_vitality', color=(0.85, 0.15, 0.12)),
 dict(id='quick_reload', display_name='MANO RÁPIDA', description='Recarga un 50% más rápido.', price=3000, icon_name='perk_reload', color=(0.2, 0.85, 0.35)),
 dict(id='speed', display_name='PASO LIGERO', description='Movimiento +18% y cambio de arma veloz.', price=2000, icon_name='perk_speed', color=(0.25, 0.65, 1.0)),
 dict(id='damage', display_name='BALA HUECA', description='Todo tu daño +30%.', price=3500, icon_name='perk_damage', color=(1.0, 0.55, 0.1)),
 dict(id='regen', display_name='SEGUNDO ALIENTO', description='Regeneras antes y el doble de rápido.', price=2000, icon_name='perk_regen', color=(0.85, 0.35, 0.95)),
]

def val(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)) and not isinstance(v, bool): return repr(float(v)) if isinstance(v, float) else str(v)
    if isinstance(v, str): return '"' + v.replace('"', '\\"') + '"'
    if isinstance(v, tuple):
        if len(v) == 3 and all(isinstance(x, float) and x <= 1.0 for x in v) and False: pass
        return None
    raise TypeError(v)

COLOR_KEYS = {'pap_tint', 'tint', 'color', 'emissive'}

def write(kind, script, cls, items, folder):
    os.makedirs(os.path.join(ROOT, 'resources', folder), exist_ok=True)
    for it in items:
        lines = [f'[gd_resource type="Resource" script_class="{cls}" load_steps=2 format=3]', '',
                 f'[ext_resource type="Script" path="{script}" id="1"]', '', '[resource]', 'script = ExtResource("1")']
        for k, v in it.items():
            if isinstance(v, tuple):
                if k in COLOR_KEYS:
                    c = list(v) + [1.0] * (4 - len(v))
                    lines.append(f'{k} = Color({c[0]}, {c[1]}, {c[2]}, {c[3]})')
                else:
                    lines.append(f'{k} = Vector3({v[0]}, {v[1]}, {v[2]})')
            else:
                lines.append(f'{k} = {val(v)}')
        open(os.path.join(ROOT, 'resources', folder, it['id'] + '.tres'), 'w').write('\n'.join(lines) + '\n')
    os.makedirs(os.path.join(ROOT, 'data', 'balance'), exist_ok=True)
    json.dump(items, open(os.path.join(ROOT, 'data', 'balance', folder + '.json'), 'w'), indent=1, ensure_ascii=False)

write('weapon', 'res://scripts/weapons/weapon_data.gd', 'WeaponData', WEAPONS, 'weapons')
write('zombie', 'res://scripts/zombies/zombie_data.gd', 'ZombieData', ZOMBIES, 'zombies')
write('perk', 'res://scripts/economy/perk_data.gd', 'PerkData', PERKS, 'perks')
print('ok', len(WEAPONS), len(ZOMBIES), len(PERKS))
