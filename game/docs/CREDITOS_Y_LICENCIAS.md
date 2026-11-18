# Procedencia de recursos y licencias

| Recurso | Origen | Licencia / notas |
|---|---|---|
| Superviviente, Errante, Corredor, Blindado, Tanque (mallas + texturas) | Generados con **Hyper3D Rodin Gen-2.5** en esta sesión (IDs: b2accdcf…, 70dcbde7…, bf0634e7…, 549818c1…, 047b09de…) | Generación propia del usuario en Hyper3D |
| Rig humanoide de Superviviente, Errante, Corredor, Blindado | Auto-rig **three.ws** (`rig_mesh`) sobre los modelos de Hyper3D | — |
| Rig del Tanque | Auto-rig propio (`tools/asset_pipeline/autorig.py`): el auto-rig externo rechazó sus proporciones | Propio |
| Animaciones (idle, caminar, correr, ataques, golpes, muertes, levantarse, rugido) | Biblioteca de clips **CC0** de three.ws (m2m-*), retargeteados y horneados con `tools/asset_pipeline/bake_character.py` | CC0 1.0 |
| EL CAPATAZ (jefe) | Variante del modelo del Tanque (escala ×1,85, tinte y emisión propios, IA y habilidades propias) | Ver limitaciones |
| Armas (6) | **Ultimate Gun Pack — Quaternius**, aportado por el usuario; convertidas con `gun_obj_to_glb.py` | CC0 1.0 (`assets/weapons/LICENSE_Quaternius_CC0.txt`) |
| Caja misteriosa | Generada con **three.ws 3D Studio** (`forge_free`) | — |
| Escenario, máquinas, puertas, barricadas, props | Geometría procedural del proyecto (`scripts/map/map_kit.gd`) | Propio |
| Texturas del escenario (10) | Generadas por código (`tools/asset_pipeline/gen_textures.py`) | Propio |
| Logotipo e ilustración del menú | **Canva** (IA generativa + eliminación de fondo + exportación) | Diseños en la cuenta Canva del usuario |
| Iconos HUD / controles / ventajas | SVG propios (`tools/asset_pipeline/gen_icons.py`) | Propio |
| Siluetas de armas | Renderizadas desde los modelos de Quaternius | CC0 derivado |
| Tipografías Russo One y Teko | Google Fonts | SIL OFL 1.1 |
| Efectos de sonido (69) y música (5 pistas) | Sintetizados por código (`tools/audio/synth_audio.py`) | Propio, original |

Ningún recurso procede de juegos comerciales. Nombres, mapa, personajes y armas son originales.
