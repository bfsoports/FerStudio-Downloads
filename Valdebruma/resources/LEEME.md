# resources/

Los recursos de juego de Valdebruma no se guardan como `.tres` editados a mano, sino como datos
y guiones reproducibles:

- Objetos, recetas, botín, estructuras, criaturas, efectos, documentos, progresión: `data/*.json`
  (generados por `tools/data/make_data.py`).
- Materiales: `assets/materials/*.tres`, generados desde `data/materials.json` por
  `tools/godot/build_materials.gd`.
- Tema de la interfaz: construido en código por `scripts/ui/ui_kit.gd`.
- Ajustes: `autoload/config.gd` (se guardan en `user://settings.cfg`).

Esta carpeta queda reservada para recursos editados en el editor de Godot si en el futuro se necesitan.
