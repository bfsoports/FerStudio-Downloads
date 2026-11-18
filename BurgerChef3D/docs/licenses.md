# Recursos y licencias

| Recurso | Procedencia | Licencia |
|---|---|---|
| Código GDScript, escenas, datos JSON, textos | Creado para este proyecto | Propio |
| Mira del HUD | Dibujada en código (punto claro con borde, `hud.gd`) | Propio |
| Iconos de la interfaz (`assets/ui/icons/`, 48 iconos 3D cartoon, WebP de 160 px) | Creados por FerStudio con **Canva** (generación de imagen y quitar fondo, cuenta del usuario), recortados y comprimidos con `tools/slice_icons.py` | Propio (FerStudio). Revisa los términos de Canva sobre contenido generado con IA antes de publicar |
| Fondo del menú, logotipo «Burger Chef 3D», botones JUGAR y CONTINUAR (`assets/ui/`) | Imágenes aportadas por el usuario; el texto del botón JUGAR se borró (lo pone el juego, traducible) y el fondo se amplió x2 con EDSR, con `tools/process_ui.py` | Del usuario |
| Icono de la app (`icon.png`, `assets/icons/launcher_192.png`, `adaptive_*_432.png`) | Imagen de la hamburguesa aportada por el usuario, adaptada con `tools/gen_app_icon.py` | Del usuario |
| Logotipo de FerStudio de la pantalla de carga (`assets/branding/ferstudio_logo.png`) | Aportado por el usuario (fondo quitado y reducido) | Del usuario / su empresa |
| Personajes de los clientes (`assets/characters/`): maniquí, esqueletos Minion, Rogue y Mage y sus animaciones | **KayKit Character Animations 1.1** y **KayKit Skeletons 1.1** de Kay Lousberg, preparados con `tools/gen_characters.py` | CC0 1.0, ver `assets/characters/LICENSE.txt` |
| Texturas PNG (`assets/textures`) | Generadas por `tools/gen_assets.py` | Propio |
| Audio (`assets/audio`): efectos de sonido (WAV) y música del menú (OGG) | Sintetizados por `tools/gen_assets.py` | Propio |
| Música de las partidas (`assets/audio/music_jazz.ogg`): «Smooth Instrumental Jazz Music» de Tunetank, recomprimida a OGG Vorbis (32 kHz, 48 kbps) | Pista aportada por el usuario (archivo `tunetank-smooth-instrumental-jazz-music-349777.mp3`; el número final sugiere que viene de Pixabay) | **Uso libre** según el usuario (confirmado el 7-11-2026). Guarda el comprobante de la descarga por si la tienda lo pide |
| Modelos 3D de la cocina y la sala (`assets/models/kaykit/`): comida, mostradores, fogones, campana, neveras, cajas, fregadero, mesas, sillas, tabla de cortar | **KayKit Restaurant Bits 1.0 FREE** de Kay Lousberg (www.kaylousberg.com), copiados con `tools/gen_models.py` | CC0 1.0 (dominio público), ver `assets/models/kaykit/LICENSE.txt` |
| Modelos 3D de bacon, patatas fritas y bebida (`assets/models/kenney/`) | **Food Kit 2.0** de Kenney (www.kenney.nl), copiados con `tools/gen_models.py` | CC0 1.0 (dominio público), ver `assets/models/kenney/LICENSE.txt` |
| Modelos 3D de la freidora, el dispensador de bebidas, la bandeja de servicio, la campanita, el bote de basura, la lámpara colgante y la planta (`assets/models/custom/`) | Aportados por el usuario, **generados con Tripo AI**; simplificados con `tools/optimize_models.py` (misma textura) | **Uso libre** según el usuario (confirmado el 7-11-2026; ver `assets/models/custom/ORIGEN.txt`). Guarda el comprobante del plan de Tripo |
| Modelos 3D de clientes, estructura (paredes, suelos, techo), carteles, ventanas y bombillas de las lámparas | Construidos con primitivas en código (no hay asset equivalente) | Propio |
| Fuente Fredoka Bold (`assets/fonts/Fredoka-Bold.ttf`), títulos y botones | Google Fonts (instancia estática de peso 700) | SIL Open Font License 1.1 (c) The Fredoka Project Authors; texto en `assets/fonts/OFL-Fredoka.txt` |
| Fuente Poppins Bold y Medium (`assets/fonts`) | Copiadas de las fuentes del sistema del entorno de desarrollo | SIL Open Font License 1.1 (c) The Poppins Project Authors; texto completo en `assets/fonts/OFL.txt` (se exporta con el juego y se muestra en Créditos > Ver licencias) |
| Godot Engine 4.7.2 | https://godotengine.org | MIT (+ avisos de terceros del motor) |
| Plugin «AdMob» de Poing Studios (lo instala el usuario desde la AssetLib; no va en este ZIP) | https://github.com/poingstudios/godot-admob-plugin | MIT. El SDK de Google Mobile Ads que incluye se rige por los términos de Google AdMob |

## Pendiente antes de publicar
- Texto completo de la SIL OFL 1.1: **hecho** (`assets/fonts/OFL.txt`, con la línea de copyright de Poppins). `export_presets.cfg` exporta también los `*.txt`, así que viaja dentro del APK junto con los `LICENSE.txt` de los packs.
- Avisos de licencia de Godot y de sus componentes de terceros: **hecho** en Créditos > «Ver licencias» (`Engine.get_license_text()` y `Engine.get_copyright_info()`), junto con la OFL de Poppins.
- Packs CC0 (KayKit y Kenney): la acreditación es opcional; ya aparecen en los créditos. Si se añade otro asset, registrarlo aquí con su procedencia y licencia.
- **Iconos:** el pack «Free Icon Pack» se eliminó por completo; todos los iconos son propios, hechos con Canva.
- **Modelos de Tripo y música:** el usuario confirmó que son de uso libre. No se ha podido comprobar desde aquí; conserva el comprobante (plan de Tripo y descarga de la pista) por si una tienda lo pide.
