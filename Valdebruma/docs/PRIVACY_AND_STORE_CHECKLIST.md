# Privacidad y lista de comprobación para la tienda

> No es asesoría legal. Describe lo que el juego hace hoy para que quien lo publique pueda rellenar
> los formularios de la tienda y revisar los textos con un profesional. Lo marcado **PENDIENTE**
> requiere datos o decisiones del titular.

## Datos que maneja el juego (comprobado en el código)

| Dato | Dónde | Para qué | Se comparte con |
|---|---|---|---|
| Identificador de cuenta aleatorio (32 hex) y secreto (48 hex) | Dispositivo: `user://profile.json` | Reconocer al jugador en cada servidor | Servidor al que se conecta; el servidor guarda solo una huella SHA-256 con sal del secreto |
| Nombre visible | Dispositivo y servidor | Mostrarlo a otros jugadores | Jugadores de la misma partida (ocultable a desconocidos) |
| Progreso de partida (posición, inventario, construcciones, logros) | Servidor | Guardar la partida | Nadie más |
| Mensajes de chat | En tránsito; últimos 12 por jugador en memoria del servidor | Comunicación | Jugadores del canal; si hay denuncia, se escriben en `reports.log` del servidor |
| Dirección IP | Servidor (inherente a la conexión) | Conexión | No se registra en archivos por el juego |
| Ajustes | Dispositivo: `user://settings.cfg` | Preferencias | Nadie |

**No** se recogen: correo, teléfono, contactos, ubicación, cámara, micrófono, identificador de
publicidad, datos de pago. **No** hay publicidad, analítica, telemetría ni compras.

Permisos Android declarados: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` (verificado en el
APK con `aapt2 dump badging`).

## Formulario «Seguridad de los datos» (Google Play), orientativo

| Pregunta | Respuesta según el estado actual |
|---|---|
| ¿Recoge o comparte datos de usuario? | Recoge: identificadores (ID de cuenta aleatorio), contenido generado (chat, nombre). No comparte con terceros. |
| ¿Datos cifrados en tránsito? | **No** (ENet sin DTLS). PENDIENTE: activar DTLS o declarar que no. |
| ¿Puede el usuario pedir el borrado? | Sí, al administrador del servidor; borrar datos de la app elimina el identificador local. PENDIENTE: canal de contacto. |
| Publicidad | No contiene anuncios. |

## Lista de comprobación

- [x] Juego original (nombre, mapa, criaturas, interfaz, logotipo) — ver `ASSET_LICENSES.md`.
- [x] Licencias de todos los recursos incluidos documentadas.
- [x] Sin violencia gráfica ni sangre; las criaturas ahuyentan, embisten o aturden, no matan.
- [x] Sin instrucciones reales para fabricar armas o dispositivos peligrosos (las recetas son de supervivencia: vendas, cuerda, hachuela, farol…).
- [x] Política de privacidad y términos accesibles dentro del juego (borradores).
- [x] Silenciar y denunciar jugadores; ocultar el nombre a desconocidos.
- [x] Orientación horizontal, modo inmersivo, zonas seguras respetadas, tamaños táctiles ≥ 56 px.
- [x] Accesibilidad: tamaño de interfaz, alto contraste, reducir movimiento y destellos, aclarar la noche, mantener para interactuar.
- [x] Español e inglés.
- [ ] PENDIENTE — Titular, dirección de contacto y URL pública de la política de privacidad.
- [ ] PENDIENTE — Revisión legal de privacidad y términos.
- [ ] PENDIENTE — Clasificación por edades (cuestionario IARC). Elementos a declarar: interacción entre usuarios (chat sin moderación automática), criaturas que asustan levemente, sin violencia explícita.
- [ ] PENDIENTE — Almacén de claves de publicación y firma de la app por Google Play.
- [ ] PENDIENTE — Capturas y vídeo de la ficha desde un dispositivo real (las del CI son de render por software).
- [ ] PENDIENTE — Pruebas en dispositivos reales de gama baja, media y alta.
- [ ] PENDIENTE — Servidor público si se anuncia juego en línea por Internet (hoy: red local o servidor propio).
- [ ] PENDIENTE — Decidir si habrá anuncios. Si se integran, usar un SDK real con su consentimiento (UMP/GDPR) y actualizar este documento; ahora no hay ninguno y no se simulan.
