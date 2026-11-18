# Publicar en la Amazon Appstore

## Dónde se verá el juego
Desde el 20 de agosto de 2025 la Amazon Appstore **solo funciona en dispositivos Amazon** (tabletas Fire y Fire TV); en móviles Android normales ya no existe. Burger Chef 3D se juega con pantalla táctil, así que el objetivo son las **tabletas Fire**. En la consola, al elegir dispositivos, **desmarca Fire TV**: el juego no se maneja con el mando de la tele y fallaría las pruebas de Amazon.

## Ya preparado en el proyecto
- Datos del estudio en el juego (Créditos y Ajustes > Privacidad y ayuda): FerStudio, Bairon Fernando Portocarrero Rodríguez, `bfsoports@gmail.com`, web, privacidad, términos y ayuda. Solo enlaza a tu web, nunca a otra tienda.
- Preset de exportación **«Amazon Appstore (Fire, APK)»**: APK con `arm64-v8a` y `armeabi-v7a` (algunas Fire son de 32 bits), Gradle (para AdMob), `min_sdk` 24, identificador `com.ferstudio.burgerchef3d`, versión 1.0.0 (código 1). El preset «Android (Google Play, AAB)» sirve para Google Play.
- Pantalla completa (modo inmersivo), interfaz que respeta los márgenes seguros y el botón Atrás de Android (pausa, cierra paneles y pide confirmación para salir).
- Anuncios que cumplen la política de Amazon: los recompensados los elige el jugador, y el intersticial sale en una pausa natural (al perder un nivel) y se puede cerrar.
- `store/amazon/`: icono 512 x 512, icono 114 x 114 e imagen promocional 1024 x 500.
- **Ficha y textos legales del juego dentro de la web de FerStudio:** ficha en https://rincondigitaloficial.com/juegos/burgerchef3d/ (descripción, características, requisitos, privacidad y datos, preguntas frecuentes), https://rincondigitaloficial.com/legal/privacidad-burger-chef-3d/ (AdMob, consentimiento, menores, permisos y derechos según la Ley 1581 de 2012, con versión en inglés) y https://rincondigitaloficial.com/legal/terminos-burger-chef-3d/ (ley aplicable: Colombia, con versión en inglés).
- `app-ads.txt` en https://rincondigitaloficial.com/app-ads.txt con el ID de editor `pub-7031306904562497` (copia en `store/app-ads.txt`).

## Lo que tienes que hacer tú (en orden)
1. **Web:** los botones del juego (privacidad, términos y ayuda) apuntan a la web de FerStudio (`Const.PRIVACY_URL`, `TERMS_URL`, `SUPPORT_URL`). En la consola de Amazon usa:
   - URL de la política de privacidad: https://rincondigitaloficial.com/legal/privacidad-burger-chef-3d/
   - Sitio web del desarrollador: https://rincondigitaloficial.com/ (tiene que ser este para que AdMob encuentre el `app-ads.txt`).
2. Configurar AdMob y cambiar a tus IDs reales (ver `docs/anuncios_admob.md`). La cuenta de AdMob está en revisión tras un bloqueo: hasta que se resuelva, el juego usa los IDs de prueba.
3. **Crear la clave de firma (keystore) de release** y ponerla en el preset de Amazon (Exportar > Keystore > Release). Guárdala con su contraseña en un sitio seguro: sin ella no podrás publicar actualizaciones.
4. Exportar el APK con el preset de Amazon y **probarlo en un móvil o, mejor, en una tableta Fire**: tutorial, un nivel completo, anuncios de prueba, pausa, botón Atrás y salir/volver a la app.
5. Hacer **capturas de pantalla** en horizontal sin la barra del editor de Godot (mínimo 3, recomendado 6-8): menú principal, cocina con la flecha del tutorial, montando una hamburguesa, la plancha cocinando, resultados con estrellas y la tienda de personalización. Comprueba en la consola los tamaños que acepta (por ejemplo 1280 x 720 o 1920 x 1080).
6. En https://developer.amazon.com/apps-and-games/console crear la app y completar:
   - **App file**: el APK. Dispositivos: tabletas Fire; desmarca Fire TV.
   - **Ficha**: textos de abajo, icono 512 y 114, capturas e imagen promocional.
   - **Clasificación de contenido**: violencia ninguna, sin contenido para adultos, sin compras dentro de la app, **sí publicidad**, sin chat ni datos del usuario compartidos con otros jugadores, sin ubicación.
   - **Privacidad del usuario (etiquetas)**: «Sí» a que la app comparte datos con terceros, por el SDK de Google AdMob: identificador de publicidad, otros identificadores del dispositivo, ubicación aproximada (por la IP), interacciones con los anuncios y diagnóstico. Finalidad: publicidad y análisis de los anuncios. El juego no recoge datos propios (todo se guarda en el dispositivo). Contrasta tus respuestas con la información de divulgación de datos de Google AdMob.
   - **URL de la política de privacidad**: la del paso 1.
   - **Público**: general (no «dirigido a niños»). Si lo marcas como dirigido a niños, Amazon aplica su política COPPA y AdMob tendría que configurarse para menores (anuncios no personalizados): pregúntame y lo cambio.

## Textos para la ficha (puedes ajustarlos)
**Título:** Burger Chef 3D

**Descripción corta (es):** Cocina, monta y sirve hamburguesas en tu propio restaurante 3D.

**Descripción (es):**
¡Ponte el delantal y abre tu hamburguesería! En Burger Chef 3D cocinas en primera persona: coge los ingredientes, pon la carne en la plancha sin que se queme, fríe las patatas, monta cada hamburguesa capa a capa y sírvela en la bandeja antes de que el cliente se canse de esperar.
- 30 niveles con objetivos y estrellas, y un modo libre sin límite de tiempo.
- 14 recetas: clásica, con queso, doble, vegetal, BLT, menús con patatas y bebida...
- Cocina de verdad: la carne se hace, se pasa y se quema; las bandejas se ensucian y hay que lavarlas.
- Tutorial paso a paso con flechas que te guían.
- Mejora tu cocina (plancha más grande, freidora doble, cocción rápida...) y decora el restaurante con colores, suelos, lámparas y plantas.
- Misiones, desafíos y logros.
- Controles táctiles cómodos, en español y en inglés.
Juego gratuito con anuncios. Un juego de FerStudio.

**Short description (en):** Cook, stack and serve burgers in your own 3D restaurant.

**Description (en):**
Put on your apron and open your burger joint! In Burger Chef 3D you cook in first person: grab the ingredients, grill the patty without burning it, fry the fries, stack each burger layer by layer and serve it on the tray before the customer runs out of patience.
- 30 levels with goals and stars, plus an endless free mode.
- 14 recipes: classic, cheeseburger, double, veggie, BLT, meals with fries and a drink...
- Real cooking: patties cook, overcook and burn; trays get dirty and must be washed.
- Step-by-step tutorial with guiding arrows.
- Upgrade your kitchen (bigger grill, double fryer, fast cooking...) and decorate the restaurant with colours, floors, lamps and plants.
- Missions, challenges and achievements.
- Comfortable touch controls, in Spanish and English.
Free game with ads. A FerStudio game.

**Palabras clave:** hamburguesas, cocina, restaurante, chef, simulador, comida rápida, 3D, burger, cooking, restaurant, simulator

**Categoría:** Juegos > Simulación (o Juegos > Casual)

**Contacto del desarrollador:** FerStudio · bfsoports@gmail.com · https://rincondigitaloficial.com/

## Datos que puede pedir Amazon y aún no tengo
- Nombre legal o de empresa para el perfil de desarrollador y los pagos, dirección y país (los pide la consola de Amazon, no el juego).
- Datos fiscales y bancarios (solo en la consola; no me los pases).
- Si quieres un teléfono o redes sociales en la ficha.
