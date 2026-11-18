# Anuncios (Google AdMob)

## Qué hay en el juego
| Anuncio | Dónde | Regla |
|---|---|---|
| Recompensado «Segunda oportunidad» | Al ir a perder un nivel de campaña | +45 s si se acabó el tiempo, o se perdonan los fallos. Una vez por turno. Solo si hay un anuncio cargado. |
| Recompensado «x2 monedas» | Pantalla de resultados al ganar un nivel o terminar el modo libre | Suma lo ganado en el turno (mín. 20, máx. 400). Una vez por resultado. |
| Recompensado «Monedas gratis» | Botón verde con el regalo, bajo las monedas del menú principal | 40 + 5 por nivel de chef. Espera de 10 min entre regalos (se guarda). |
| Intersticial | Al pulsar Reintentar o Menú tras perder un nivel | Cada 2 derrotas como mínimo, con 2 min entre anuncios y nunca en los 3 primeros turnos ni en el tutorial. |

Todo se ajusta en `resources/data/ads_config.json` sin tocar código. El código está en `scripts/ads/ads_manager.gd` (autoload `Ads`).

Durante un anuncio el sonido del juego se silencia y la partida no abre el menú de pausa (aunque Android mande la app a segundo plano).

## Modo de prueba (como está ahora)
`use_test_ids: true` usa los **IDs de prueba oficiales de Google**: salen anuncios marcados «Test Ad», no generan dinero y no ponen en riesgo tu cuenta. Así debe quedarse mientras pruebas.

- En el **editor o el ordenador** (sin el plugin) aparece una ventana «ANUNCIO DE PRUEBA (simulado)» para probar las recompensas. Solo existe en ejecuciones de depuración: una exportación de release sin el plugin no muestra ningún anuncio ni ningún botón de anuncio.
- En el **móvil con el plugin instalado** salen los anuncios de prueba reales de Google.

## Instalar el plugin (una vez)
Hecho para el plugin **«AdMob» de Poing Studios** (v5, requiere Godot 4.5 o superior).
1. En Godot: pestaña **AssetLib** > busca «AdMob», editor **poing.studios** > Descargar > Instalar.
2. **Proyecto > Configuración del proyecto > Plugins**: activa AdMob.
3. **Proyecto > Instalar plantilla de compilación de Android** (Android Build Template).
4. En el móvil (editor de Godot para Android): instala la app **GABE (Godot Android Build Environment)**, ábrela, pestaña *Rootfs* > *Install Rootfs* (necesita internet). Sin GABE el editor de Android no puede hacer exportaciones con Gradle, y el plugin las necesita.
5. Los dos presets de `export_presets.cfg` ya tienen **Use Gradle Build** activado, `min_sdk` 24 y el permiso de internet.
6. **Proyecto > Configuración del proyecto > AdMob > General > Android**: marca *Enabled* y pon el **App ID**. Mientras pruebas, usa el de prueba de Google: `ca-app-pub-3940256099942544~3347511713`.

El juego busca las clases del plugin por su nombre al arrancar. Si el plugin no está, o alguna clase cambia de nombre en otra versión, el juego sigue funcionando sin anuncios: no se rompe nada. **No se ha probado todavía con el plugin instalado en un móvil real**. Si al exportar no salen anuncios, mira el registro (`adb logcat` o el depurador remoto) y compara los nombres de clase con la documentación del plugin: https://poingstudios.github.io/godot-admob-plugin/latest

## Cuando tengas tus IDs de AdMob
1. En https://admob.google.com crea la app (Android) y dos bloques de anuncios: **Bonificado** (rewarded) e **Intersticial**.
2. En `ads_config.json`: pon `rewarded_id` e `interstitial_id` (contienen `/`) y `android_app_id` (contiene `~`, solo como referencia). Después pon **`use_test_ids: false`**.
3. Pon tu App ID real en Configuración del proyecto > AdMob (paso 6 de arriba).
4. **No pulses tus propios anuncios reales.** Para probar con tus IDs, registra tu móvil como dispositivo de prueba en AdMob (Configuración > Dispositivos de prueba).
5. En AdMob:
   - **Controles de bloqueo > Clasificación de contenido máxima: G** (apto para todos). La política de privacidad del juego lo afirma.
   - **Privacidad y mensajes**: crea el mensaje de consentimiento (RGPD) para el EEE y el Reino Unido. El juego lo pide al arrancar si hace falta.
   - **App-ads.txt**: va en la raíz de la web de FerStudio, https://rincondigitaloficial.com/app-ads.txt (`pub-7031306904562497`), y sirve para todos los juegos del estudio. En AdMob y en Amazon, pon https://rincondigitaloficial.com/ como sitio web del desarrollador.
   - Cuando el juego esté publicado, **vincula la app con su ficha de la tienda** (AdMob > Configuración de la app > Tiendas de aplicaciones). AdMob admite apps de la Amazon Appstore.

## Ojo con Amazon Fire
Las tabletas Fire no tienen los servicios de Google Play. El SDK de anuncios de Google funciona sin ellos porque va incluido en el APK, pero desarrolladores han informado de que **en Fire a veces llegan muy pocos anuncios** («no fill»). Además, Amazon rechaza las apps que llevan a los usuarios a otra tienda, y algunos anuncios de AdMob enlazan a Google Play. Si Amazon lo marca en la revisión, la alternativa es una red de anuncios compatible con Fire (por ejemplo, el SDK de anuncios de Amazon). El juego está preparado para cambiar de red tocando solo `ads_manager.gd`.
