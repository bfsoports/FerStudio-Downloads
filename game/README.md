# SECTOR ABANDONADO — proyecto Godot 4.7.2

Abrir con Godot 4.7.2 (`project.godot`). Escena principal: `scenes/main_menu/boot.tscn`.
Para jugar en PC: WASD + ratón (clic central captura el ratón), clic izquierdo dispara, derecho apunta, R recarga, E interactúa, Q cambia de arma, G granada, Espacio salta, Esc pausa. Los controles táctiles también funcionan con el ratón.

## Estructura
```
assets/      characters, zombies, weapons, props, textures, audio, ui (logo, fondos, iconos), fonts
scenes/      main_menu, gameplay
scripts/
  core/         settings, game_state (récords), audio_manager, scene_loader, boot
  player/       player (movimiento, vida, ventajas, interacción, granadas)
  weapons/      weapon_data (Resource), weapon_holder (inventario, hitscan, viewmodel), grenade
  zombies/      zombie, zombie_data, zombie_animator (LOD), zombie_pool, boss_brain, states/ (un script por estado)
  rounds/       round_manager, spawn_point
  interaction/  interactable + door, wall_weapon, mystery_box, pack_a_punch (La Forja), perk_machine, barricade
  economy/      perk_data
  map/          sector_map (layout), map_kit (materiales, lotes, props)
  effects/      fx_manager (efectos con pooling)
  ui/           ui_style (sistema visual), hud, touch_controls, menús, arsenal, derrota
  optimization/ perf_governor (resolución dinámica)
resources/   weapons, zombies, perks (*.tres de balance), configuration (navmesh, buses)
data/balance tablas de balance en JSON (generadas junto a los .tres)
tests/       pruebas automáticas (scripts, integración, estrés, visuales)
tools/       bake_navmesh.gd
docs/        documentación
```

El balance se edita en `../tools/data/gen_resources.py` (regenera `.tres` y JSON) o directamente en los `.tres` desde el inspector.
Tras cambiar el mapa: `godot --headless --path . -s tools/bake_navmesh.gd`.
