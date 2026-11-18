# Documento de diseño — Valdebruma

## 1. Concepto

Supervivencia cooperativa en primera persona en **Valdebruma**, un valle de montaña evacuado hace
semanas porque una bruma extraña se asentó sobre el Marjal. Los jugadores llegan después: buscan
comida y agua en casas vacías, levantan refugios, se organizan en grupo y, leyendo lo que dejaron
los vecinos, descubren qué ocurrió con el agua y con la Estación del Instituto.

Tono: melancólico y sereno, nada de gore. Las criaturas asustan, embisten o aturden; nunca hay
sangre ni muerte explícita. Si el jugador cae rendido, despierta en su refugio y sus cosas quedan en
un bulto donde cayó.

Público: jugadores de móvil a partir de 12 años que disfrutan de explorar, construir y cooperar.
Sesiones de 15–40 minutos; el progreso queda guardado en el servidor.

## 2. Bucle de juego

1. **Explorar** el valle y sus 29 lugares (descubrirlos da experiencia y pistas).
2. **Rebuscar** en casas, coches, comercios y fábricas (botín por tablas y reaparición temporizada).
3. **Recolectar** bayas, setas, hierbas, fibra, madera, piedra, chatarra y agua.
4. **Cubrir necesidades**: comer, beber, abrigarse, secarse, descansar.
5. **Fabricar** herramientas, ropa, comida y medicinas (a mano, en hoguera o en banco).
6. **Construir** un campamento: hoguera, refugio (punto de reaparición), arcón, banco, colector, muros…
7. **Cooperar**: grupo de hasta 6, permisos compartidos, intercambio, señales, encargos del tablón.
8. **Avanzar**: niveles con ventajas, desafíos, logros, cosméticos y la historia de los documentos.

## 3. El valle

1 280 × 1 280 m divididos en 400 sectores de 64 m. Norte arriba en el mapa.

| Región | Carácter | Lugares (nombres reales del mundo generado) |
|---|---|---|
| Pradera / El Collado | Inicio, suave, zona segura | El Collado (campamento de llegada), Cruce del Robledal |
| Robledal | Bosque denso; territorio del Brumal | Caseta forestal, Cabaña escondida*, Mirador del Roble Gordo*, Bodega vieja* |
| Sotoalto | Pueblo abandonado | Plaza de Sotoalto (tablón), Casa Consistorial (archivo), Ultramarinos Lucero, Botica del Río, Café La Parada, Consultorio, Escuela rural, Puente de Sotoalto |
| La Fragua | Industrial | Polígono La Fragua, Taller Ardila, Conservas Sotoalto |
| Las Eras | Campos y granjas | Las Eras, Finca del Molino, Huerto de manzanos |
| El Marjal / La Bruma | Humedal con bruma de esporas (necesita mascarilla); Farol | Marjal de la Bruma, Pasarela del Marjal, Estación de bombeo, Estación Liquen (Instituto) |
| Alto | Cumbre ventosa y fría | Cantera del Alto, Repetidor del Alto* |
| Ribera | Río, vado y pesca | Vado del río, Caseta de pesca, Ermita de San Telmo |

(*) Lugares secretos: no aparecen en el mapa hasta descubrirlos.

Clima y hora: un día dura 40 minutos por defecto. Estados del tiempo con transiciones de Markov:
despejado, nublado, niebla, lluvia y tormenta (rayos lejanos). De noche baja la temperatura, el
Brumal se vuelve más activo y la linterna o el farol pasan a ser vitales.

## 4. Personaje y necesidades

| Valor | Rango | Sube con | Baja con | Efecto si está mal |
|---|---|---|---|---|
| Salud | 0–100 | Descanso, vendas, botiquín, ungüento | Embestidas, frío extremo, hambre/sed a cero, esporas | A 0: cae rendido |
| Hambre (saciedad) | 0–100 | Comida | Tiempo, esfuerzo | «Hambriento», pierde salud a 0 |
| Sed (hidratación) | 0–100 | Agua, infusión | Tiempo, calor | «Sediento», pierde salud a 0 |
| Energía | 0–100 | Parar, comer | Esprintar, nadar, escalar | No puede esprintar |
| Temperatura | −100…100 | Fuego, abrigo, techo, infusión | Noche, viento, lluvia, mojado, altura | «Frío», «Hipotermia» |
| Cansancio | 0–100 | Tiempo despierto | Descansar en refugio o saco | «Agotamiento» a 85 |
| Humedad | 0–1 | Lluvia, nadar | Fuego, techo | «Mojado» (más frío) |

16 estados temporales con icono, descripción y duración: a cubierto, abrigado, agotado, alivio,
aturdido, bien alimentado, calor, descansado, esporas, frío, hambriento, hipotermia, junto al fuego,
malestar, mojado, sediento.

Movimiento: andar 3,5 m/s, esprintar 6,2, agachado 1,6, nadar 1,7; salto, subida automática de
escalones, natación. Peso transportable 22 kg (más con mochilas); sobrecarga cansa más.

## 5. Objetos, fabricación y construcción

- **50 objetos** en 7 categorías (comida, bebida, cuidados, herramientas, ropa, materiales, llaves),
  con peso, pila, durabilidad y recarga (pilas para la linterna, filtros para la mascarilla).
- **Equipo**: cabeza, cara, torso, espalda, piernas, pies y mano. La ropa abriga y repele el agua;
  las mochilas añaden huecos y carga; en la mano se lleva linterna, farol, hachuela, martillo,
  palanca o espantador.
- **20 recetas** (cocina, cuidados, útiles, materiales, ropa) con estación (a mano, hoguera
  encendida, banco), herramienta y nivel mínimos.
- **13 estructuras**: hoguera, refugio, saco de dormir, arcón, banco de trabajo, colector de lluvia,
  poste con farol, suelo, muro, muro con ventana, puerta, tejado y valla. Se coloca un armazón
  (coste pequeño) y se termina la obra después (coste completo y herramienta). Suelos, muros y
  tejados encajan en una rejilla de 2,4 m. Permisos: privado, grupo o público. Límite por jugador y
  por mundo.

## 6. Criaturas

| Criatura | Dónde | Comportamiento | Cómo evitarla |
|---|---|---|---|
| **Brumal** — ciervo de corteza y musgo con ojos que brillan | Robledal, de noche por todo el valle | Patrulla, investiga ruidos, alerta (se encabrita), persigue y embiste (aturde, quita salud y energía), busca, se retira | Luz (linterna, farol, hoguera) y ruido (espantador) lo hacen retirarse; agacharse reduce el ruido |
| **Zarzo** — pequeño erizo de zarzas | Praderas y linderos | Forrajea, huye, se entierra si lo acorralan y sale después | Inofensivo |
| **Farol** — fuego fatuo del Marjal | Marjal y bruma | Flota, se acerca a la luz, suelta una nube de esporas si te acercas | Mascarilla con filtro |

La IA corre en el servidor con estados (reposo, patrulla, investigar, alerta, persecución, búsqueda,
retirada, regreso, recuperación, huida, enterrado, latente), percepción por vista y oído y
navegación A* sobre una rejilla de 4 m.

## 7. Progresión

- **Niveles** 1–10 por experiencia (descubrir, recolectar, fabricar, construir, encargos).
  Ventajas: +2 huecos (nivel 2), esprintar cansa un 10 % menos (4), +1 al recolectar (6),
  hambre y sed un 10 % más lentas (8).
- **15 desafíos** con recompensa de experiencia y **7 logros**; algunos desbloquean **cosméticos**
  (chaquetas y gorros teñibles).
- **8 encargos** del tablón de Sotoalto (entregas y expediciones); tres a la vez.
- **9 documentos** que cuentan la evacuación, el problema del agua y lo que hacía el Instituto.
- **Cooperación**: desafíos de grupo (descubrir yendo juntos, construir en grupo).

## 8. Multijugador

Hasta 24 jugadores por servidor. Partida alojada en un móvil/PC o servidor dedicado. Todo lo
importante lo decide el servidor (ver `NETWORKING_AND_SERVER.md`). Interacción social: grupos con
permisos, chat cercano/grupo/global con límites, silenciar, denunciar, ofrecer objetos, señales en
el mapa y gestos (saludar, señalar, sentarse).

## 9. Interfaz y controles

Pensada primero para pantalla táctil horizontal: joystick flotante a la izquierda, cámara con el
otro pulgar, botón de interacción grande que se ilumina cuando hay algo que hacer, saltar,
agacharse, esprintar (interruptor), linterna y barra de menús arriba. Todo ajustable (tamaño,
opacidad, modo zurdo, mantener para interactuar). En PC: teclado y ratón.

Pantallas: arranque, menú con escena 3D, jugar (crear/unirse), perfil, ajustes, créditos y legal,
carga, HUD, inventario con contenedor, fabricación, construcción, mapa, grupo, diario, documentos,
pausa, colapso, diálogos y avisos.

## 10. Arte y sonido

- Estilo: realismo suave de valle rural, paleta verde-ocre, bruma y luz cálida al atardecer.
- Personajes y vehículos de Hyper3D Rodin; edificios, vegetación y objetos procedurales con
  texturas PBR CC0; follaje con viento; efectos CC0 adaptados.
- Sonido sintetizado: ambientes por región (bosque, noche, pueblo, marjal, interior, industrial,
  viento, lluvia), pasos por superficie, puertas, criaturas, trueno, hoguera, interfaz y una pieza
  para el menú.

## 11. Monetización

No hay anuncios ni compras en esta versión. Si en el futuro se añaden, será con un SDK real y su
gestión de consentimiento; nunca anuncios simulados.

## 12. Fuera de alcance de 0.1.0

Vehículos conducibles, animales domésticos, estaciones del año, editor de mundos, servidores
públicos oficiales y emparejamiento.
