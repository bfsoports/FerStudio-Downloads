"""make_strings.py — textos de interfaz en español e inglés.

Salida: localization/strings.csv (clave, es, en), que Godot importa como traducciones.
Los textos de datos de juego (objetos, recetas, documentos…) viven en data/*.json.
Uso: python3 tools/data/make_strings.py
"""
import csv, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
S = {}


def add(key, es, en):
    assert key not in S, key
    S[key] = (es, en)


# ---- botones y menú -------------------------------------------------------------------------------
add("BTN_OK", "Aceptar", "OK")
add("BTN_CANCEL", "Cancelar", "Cancel")
add("BTN_ACCEPT", "Aceptar", "Accept")
add("BTN_DECLINE", "Rechazar", "Decline")
add("BTN_CLOSE", "Cerrar", "Close")
add("BTN_SAVE", "Guardar", "Save")
add("BTN_QUIT", "Salir", "Quit")
add("MENU_PLAY", "Jugar", "Play")
add("MENU_PROFILE", "Perfil y aspecto", "Profile and look")
add("MENU_SETTINGS", "Ajustes", "Settings")
add("MENU_LEGAL", "Créditos y legal", "Credits and legal")
add("MENU_QUIT", "Salir del juego", "Quit game")
add("MENU_PROTOCOL", "protocolo %d", "protocol %d")
add("SPLASH_LOADING", "Preparando el valle…", "Getting the valley ready…")
add("TITLE_NOTICE", "Aviso", "Notice")
add("TITLE_ERROR", "Error", "Error")
add("TITLE_REJECTED", "No se pudo entrar", "Could not join")
add("TITLE_NO_CONNECTION", "Sin conexión", "No connection")
add("TITLE_QUIT", "Salir del juego", "Quit game")
add("TITLE_GROUP_INVITE", "Invitación a un grupo", "Group invitation")
add("TITLE_TRADE", "Te ofrecen un objeto", "Item offer")
add("TEXT_QUIT", "¿Quieres cerrar Valdebruma?", "Do you want to close Valdebruma?")
add("TEXT_GROUP_INVITE", "%s te invita a su grupo. Compartiréis señales, permisos de refugio y posición en el mapa.", "%s invites you to their group. You will share marks, shelter permissions and map position.")
add("TEXT_TRADE", "%s te ofrece %d × %s.", "%s offers you %d × %s.")
# ---- carga, errores y rechazo -------------------------------------------------------------------
add("LOAD_STARTING", "Abriendo la partida…", "Opening the session…")
add("LOAD_CONNECTING", "Conectando con %s…", "Connecting to %s…")
add("LOAD_WORLD", "Cargando el valle…", "Loading the valley…")
add("LOAD_RECONNECTING", "Conexión perdida. Reintentando (%d de %d)…", "Connection lost. Retrying (%d of %d)…")
add("ERR_HOST_PORT", "No se pudo abrir el puerto %d. Puede que otra aplicación lo esté usando: prueba con otro.", "Port %d could not be opened. Another app may be using it: try a different one.")
add("ERR_WORLD_LOAD", "No se pudo cargar el mundo.", "The world could not be loaded.")
add("ERR_DROPPED", "Se perdió la conexión con el servidor.", "The connection to the server was lost.")
add("ERR_RECONNECT", "No se pudo recuperar la conexión. Tu progreso está guardado en el servidor.", "The connection could not be restored. Your progress is saved on the server.")
add("ERR_CONNECT_ADDRESS", "La dirección no es válida.", "The address is not valid.")
add("ERR_CONNECT_TIMEOUT", "El servidor no responde. Comprueba la dirección, el puerto y tu conexión.", "The server is not answering. Check the address, the port and your connection.")
add("ERR_CONNECT_CLOSED", "El servidor cerró la conexión.", "The server closed the connection.")
add("ERR_CONNECT_REFUSED", "El servidor rechazó la conexión.", "The server refused the connection.")
add("REJECT_VERSION", "Tu versión del juego no coincide con la del servidor. Actualiza el juego.", "Your game version does not match the server's. Update the game.")
add("REJECT_FULL", "El servidor está lleno.", "The server is full.")
add("REJECT_AUTH", "Ese nombre ya pertenece a otra cuenta en este servidor, o tu identidad no coincide.", "That name already belongs to another account on this server, or your identity does not match.")
add("REJECT_BANNED", "No puedes entrar en este servidor.", "You cannot join this server.")
add("REJECT_NAME", "El nombre no es válido: usa de 3 a 16 letras o números.", "The name is not valid: use 3 to 16 letters or numbers.")
add("REJECT_DUPLICATE", "Ya hay una sesión abierta con tu cuenta.", "There is already an open session with your account.")
for i, (es, en) in enumerate([
        ("El fuego seca la ropa, calienta y permite cocinar. Enciéndelo antes de que anochezca.", "Fire dries your clothes, warms you and lets you cook. Light it before nightfall."),
        ("Al Brumal le molestan la luz y el ruido: una linterna o un espantador lo mantienen a distancia.", "The Brumal dislikes light and noise: a flashlight or a rattle keeps it away."),
        ("Hierve o trata el agua antes de beberla si no quieres malestar.", "Boil or treat water before drinking it unless you want an upset stomach."),
        ("Un refugio terminado fija tu punto de reaparición y te deja descansar.", "A finished shelter sets your respawn point and lets you rest."),
        ("En grupo compartís señales, permisos de arcones y la posición en el mapa.", "In a group you share marks, chest permissions and map position."),
        ("En la bruma del Marjal necesitas mascarilla con filtro: las esporas pasan factura.", "In the Marsh mist you need a filter mask: the spores take their toll."),
        ("El tablón de la plaza de Sotoalto ofrece encargos con recompensa.", "The notice board in Sotoalto square offers jobs with rewards."),
        ("Si vas sobrecargado te cansarás antes. Guarda lo que no uses en un arcón.", "If you are overloaded you tire sooner. Store what you do not need in a chest.")], 1):
    add("TIP_%d" % i, es, en)
add("DOWN_TITLE", "Has caído rendido", "You have collapsed")
add("DOWN_TEXT", "Tus cosas quedan en un bulto donde caíste. Despertarás en tu refugio o en el campamento, cansado pero entero.", "Your things stay in a bundle where you fell. You will wake up at your shelter or at the camp, tired but in one piece.")
add("DOWN_RESPAWN", "Despertar", "Wake up")
add("BANNER_PLACE", "Lugar descubierto", "Place discovered")
add("BANNER_SECRET", "Lugar oculto descubierto", "Hidden place discovered")
add("BANNER_LEVEL", "Subes de nivel", "Level up")
add("BANNER_LEVEL_N", "Nivel %d", "Level %d")
# ---- avisos del servidor ---------------------------------------------------------------------------
add("N_ALREADY_GROUPED", "Ese jugador ya está en un grupo.", "That player is already in a group.")
add("N_BUSY", "Alguien lo está usando.", "Someone is using it.")
add("N_CHALLENGE_DONE", "Desafío completado: %s", "Challenge completed: %s")
add("N_CONTAINER_CLOSED", "El contenedor se ha cerrado.", "The container has closed.")
add("N_CONTRACT_DONE", "Encargo entregado: %s", "Job handed in: %s")
add("N_CONTRACT_LIMIT", "Ya tienes tres encargos en curso.", "You already have three jobs in progress.")
add("N_CONTRACT_MISSING", "Aún no cumples lo que pide el encargo.", "You do not meet the job's requirements yet.")
add("N_CONTRACT_READY", "Encargo listo para entregar: %s", "Job ready to hand in: %s")
add("N_CREATURE_HIT", "¡%s te ha embestido!", "%s has charged into you!")
add("N_DEPLETED", "Aquí ya no queda nada por ahora.", "Nothing left here for now.")
add("N_DOOR_BLOCKED", "Algo impide mover la puerta.", "Something is blocking the door.")
add("N_FILTER_SPENT", "El filtro de la mascarilla se ha agotado.", "The mask filter is spent.")
add("N_GONE", "Ya no está.", "It is gone.")
add("N_GROUP_FULL", "El grupo está completo.", "The group is full.")
add("N_INV_FULL", "No te cabe nada más.", "You cannot carry anything else.")
add("N_INV_FULL_DROPPED", "Sin sitio: %s se queda en el suelo.", "No room: %s was left on the ground.")
add("N_INVITE_SENT", "Invitación enviada a %s.", "Invitation sent to %s.")
add("N_LIGHT_SPENT", "La linterna se ha quedado sin pilas.", "The flashlight batteries have run out.")
add("N_LOCKED", "Está cerrado. Necesitas: %s", "It is locked. You need: %s")
add("N_NEED", "Necesitas: %s", "You need: %s")
add("N_NEED_BOARD", "Tienes que estar junto a un tablón de encargos.", "You have to be next to a notice board.")
add("N_NO_PERMISSION", "No tienes permiso de su dueño.", "You do not have the owner's permission.")
add("N_NO_ROOM", "No hay sitio suficiente.", "There is not enough room.")
add("N_NOT_EMPTY", "Vacíalo antes de desmontarlo.", "Empty it before dismantling it.")
add("N_OFFER_DONE", "%s ha aceptado tu objeto.", "%s accepted your item.")
add("N_OFFER_EXPIRED", "La oferta ya no es válida.", "The offer is no longer valid.")
add("N_OFFER_FAILED", "No se pudo completar el intercambio.", "The trade could not be completed.")
add("N_OFFER_SENT", "Oferta enviada a %s.", "Offer sent to %s.")
add("N_REFILLED", "%s recargado.", "%s refilled.")
add("N_REPORT_SENT", "Denuncia registrada. Gracias por avisar.", "Report recorded. Thank you for letting us know.")
add("N_RESPAWN_SET", "Este refugio es ahora tu punto de reaparición.", "This shelter is now your respawn point.")
add("N_SPORES_BLOCKED", "La mascarilla te protege de las esporas.", "The mask protects you from the spores.")
add("N_TOO_FAR", "Está demasiado lejos.", "It is too far away.")
add("N_TOOL_BROKEN", "%s se ha roto.", "%s has broken.")
add("N_UNLOCKED", "Cerradura abierta.", "Lock opened.")
add("N_BORDER", "El valle termina aquí: la niebla no deja pasar.", "The valley ends here: the fog will not let you through.")
add("N_MARK", "%s ha dejado una señal.", "%s left a mark.")
add("N_QUICK_MISSING", "No te queda: %s", "You have none left: %s")
add("N_BUILT", "Terminado: %s", "Finished: %s")
add("N_DISMANTLED", "Desmontado: %s", "Dismantled: %s")
for key, es, en in [
        ("UNKNOWN", "No se puede.", "That is not possible."), ("LEVEL", "Te falta nivel.", "Your level is too low."),
        ("STATION", "Necesitas estar junto a la estación adecuada.", "You need to be next to the right station."),
        ("TOOL", "Te falta la herramienta.", "You are missing the tool."), ("INGREDIENTS", "Te faltan materiales.", "You are missing materials."),
        ("ROOM", "No te cabe el resultado.", "There is no room for the result."), ("LIMIT", "Has alcanzado el límite de estructuras.", "You have reached the structure limit."),
        ("FAR", "Demasiado lejos.", "Too far away."), ("BOUNDS", "Fuera del valle.", "Outside the valley."),
        ("OVERLAP", "Choca con otra estructura.", "It overlaps another structure."), ("BLOCKED", "Aquí hay un edificio.", "There is a building here."),
        ("ROAD", "No se puede construir en el camino.", "You cannot build on the road."), ("WATER", "No se puede construir en el agua.", "You cannot build in the water."),
        ("HEIGHT", "La altura no es válida.", "The height is not valid."), ("SLOPE", "El terreno está demasiado inclinado.", "The ground is too steep."),
        ("SIGHT", "No hay línea de visión.", "There is no line of sight."), ("MATERIALS", "Te faltan materiales.", "You are missing materials.")]:
    add("WHY_" + key, es, en)
# ---- interacción ---------------------------------------------------------------------------------------
add("ACT_OPEN_DOOR", "Abrir puerta", "Open door")
add("ACT_CLOSE_DOOR", "Cerrar puerta", "Close door")
add("ACT_SEARCH", "Registrar: %s", "Search: %s")
add("ACT_PICKUP", "Recoger %s", "Pick up %s")
add("ACT_BUILD", "Terminar %s (%s)", "Finish %s (%s)")
add("ACT_REST", "Descansar", "Rest")
add("ACT_FUEL", "Echar leña", "Add firewood")
add("ACT_LIGHT_FIRE", "Encender el fuego", "Light the fire")
add("ACT_FILL_N", "Llenar botella (%d)", "Fill bottle (%d)")
add("ACT_COLLECTOR_EMPTY", "Colector vacío", "Collector is empty")
add("ACT_WORKBENCH", "Usar el banco de trabajo", "Use the workbench")
add("ACT_DISMANTLE", "Desmontar", "Dismantle")
add("ACT_DRINK", "Beber", "Drink")
add("ACT_BOARD", "Ver los encargos", "See the jobs")
add("ACT_FILL", "Llenar botella", "Fill bottle")
add("ACT_READ_NOTICE", "Leer el aviso", "Read the notice")
add("ACT_READ", "Leer: %s", "Read: %s")
add("NAME_BUNDLE", "Bulto", "Bundle")
for key, es, en in [("CAR_SEDAN", "Maletero", "Car boot"), ("CAR_SEDAN_RED", "Maletero", "Car boot"), ("CAR_VAN", "Furgoneta", "Van"), ("CARDBOARD_BOX", "Caja de cartón", "Cardboard box"),
                    ("CHEST_METAL", "Arcón metálico", "Metal chest"), ("CRATE_WOOD", "Cajón de madera", "Wooden crate"), ("DESK", "Escritorio", "Desk"), ("DRESSER", "Cómoda", "Dresser"),
                    ("DUMPSTER", "Contenedor", "Dumpster"), ("FILING_CABINET", "Archivador", "Filing cabinet"), ("FRIDGE", "Nevera", "Fridge"), ("KITCHEN_CABINET", "Armario de cocina", "Kitchen cabinet"),
                    ("LOCKER", "Taquilla", "Locker"), ("MAILBOX", "Buzón", "Mailbox"), ("MEDICINE_CABINET", "Botiquín de pared", "Medicine cabinet"), ("ROWBOAT", "Barca", "Rowboat"),
                    ("TOOLBOX", "Caja de herramientas", "Toolbox"), ("TRASH_BIN", "Papelera", "Bin"), ("WARDROBE", "Armario", "Wardrobe")]:
    add("NAME_" + key, es, en)
for i, (es, en) in enumerate([("Recolectando…", "Gathering…"), ("Fabricando…", "Crafting…"), ("Construyendo…", "Building…"), ("Desmontando…", "Dismantling…"),
                              ("Descansando…", "Resting…"), ("Llenando…", "Filling…")], 1):
    add("ACTION_%d" % i, es, en)
add("ACTION_CANCEL_KEY", "(muévete para cancelar)", "(move to cancel)")
# ---- HUD ------------------------------------------------------------------------------------------------
add("HUD_DAY", "Día %d · %s", "Day %d · %s")
add("HUD_KEYS", "E interactuar · F acción secundaria · Tab inventario · C fabricar · B construir\nM mapa · J diario · G grupo · L linterna · Intro chat · Esc menú",
    "E interact · F secondary action · Tab inventory · C craft · B build\nM map · J journal · G group · L flashlight · Enter chat · Esc menu")
add("NET_HOST", "Anfitrión · %d", "Host · %d")
add("TEMP_OK", "A gusto", "Comfortable")
add("TEMP_COOL", "Fresco", "Chilly")
add("TEMP_COLD", "Frío", "Cold")
add("TEMP_FREEZING", "Helado", "Freezing")
add("TEMP_WARM", "Calor", "Warm")
add("TEMP_HOT", "Sofocado", "Overheated")
add("COMPASS_N", "N", "N")
add("COMPASS_E", "E", "E")
add("COMPASS_S", "S", "S")
add("COMPASS_W", "O", "W")
for key, es, en in [("PRADERA", "Pradera del Collado", "Collado Meadow"), ("COLLADO", "El Collado", "El Collado"), ("ROBLEDAL", "Robledal Viejo", "Old Oakwood"),
                    ("SOTOALTO", "Sotoalto", "Sotoalto"), ("FRAGUA", "La Fragua", "La Fragua"), ("ERAS", "Las Eras", "Las Eras"), ("MARJAL", "El Marjal", "The Marsh"),
                    ("ALTO", "Alto del Repetidor", "Relay Heights"), ("BRUMA", "La Bruma", "The Mist"), ("RIBERA", "Ribera del Bruma", "Bruma Riverside")]:
    add("REGION_" + key, es, en)
add("CHAT_NEAR", "Cerca", "Nearby")
add("CHAT_GROUP", "Grupo", "Group")
add("CHAT_GLOBAL", "Global", "Global")
add("CHAT_HINT", "Escribe un mensaje…", "Type a message…")
add("CHAT_DISABLED", "Tienes el chat desactivado en Ajustes.", "You have chat turned off in Settings.")
for key, keys, touch, keys_en, touch_en in [
        ("TUT_MOVE", "Muévete con W A S D.", "Arrastra en la mitad izquierda de la pantalla para moverte.", "Move with W A S D.", "Drag on the left half of the screen to move."),
        ("TUT_LOOK", "Mueve el ratón para mirar a tu alrededor.", "Arrastra en la mitad derecha para mirar a tu alrededor.", "Move the mouse to look around.", "Drag on the right half to look around."),
        ("TUT_INTERACT", "Acércate a un objeto, una puerta o una caja y pulsa E.", "Acércate a un objeto, una puerta o una caja y toca el botón de la mano.", "Walk up to an item, a door or a box and press E.", "Walk up to an item, a door or a box and tap the hand button."),
        ("TUT_INVENTORY", "Abre el inventario con Tab.", "Abre el inventario con el botón de la mochila.", "Open the inventory with Tab.", "Open the inventory with the backpack button."),
        ("TUT_EAT", "Selecciona comida o agua y pulsa «Comer» o «Beber».", "Toca comida o agua y después «Comer» o «Beber».", "Select food or water and press “Eat” or “Drink”.", "Tap food or water, then “Eat” or “Drink”."),
        ("TUT_CRAFT", "Pulsa C para ver qué puedes fabricar.", "Toca el botón de herramientas para ver qué puedes fabricar.", "Press C to see what you can craft.", "Tap the tools button to see what you can craft."),
        ("TUT_BUILD", "Pulsa B para construir: una hoguera y un refugio son lo primero.", "Toca el botón de la casa para construir: primero una hoguera y un refugio.", "Press B to build: a campfire and a shelter come first.", "Tap the house button to build: a campfire and a shelter come first."),
        ("TUT_MAP", "Pulsa M para abrir el mapa del valle.", "Toca el botón del mapa para orientarte en el valle.", "Press M to open the valley map.", "Tap the map button to find your way around the valley.")]:
    add(key + "_KEYS", keys, keys_en)
    add(key + "_TOUCH", touch, touch_en)
add("TUT_SKIP", "Saltar", "Skip")
# ---- jugar ------------------------------------------------------------------------------------------------
add("PLAY_TITLE", "Jugar", "Play")
add("PLAY_TAB_HOST", "Crear partida", "Host a session")
add("PLAY_TAB_JOIN", "Unirse", "Join")
add("PLAY_HOST_INFO", "La partida se aloja en este dispositivo. El mundo se guarda aquí y otros jugadores de tu misma red pueden unirse con tu dirección.", "The session runs on this device. The world is saved here and other players on your network can join using your address.")
add("PLAY_WORLD", "Nombre del mundo", "World name")
add("PLAY_WORLD_HINT", "valle", "valley")
add("PLAY_WORLD_SAVED", "Mundos guardados: %s", "Saved worlds: %s")
add("PLAY_WORLD_NEW", "Se creará un mundo nuevo con ese nombre.", "A new world with that name will be created.")
add("PLAY_DIFFICULTY", "Dificultad", "Difficulty")
add("PLAY_DIFFICULTY_HINT", "Ajusta lo rápido que bajan las necesidades y lo insistentes que son las criaturas.", "Sets how fast your needs drop and how persistent the creatures are.")
add("PLAY_PORT", "Puerto", "Port")
add("PLAY_PORT_HINT", "Puerto UDP en el que se escucha a otros jugadores.", "UDP port used to listen for other players.")
add("PLAY_LAN", "Otros jugadores pueden unirse desde tu red con: %s", "Other players can join from your network with: %s")
add("PLAY_LAN_NONE", "No se detecta red local. Podrás jugar igualmente en solitario.", "No local network detected. You can still play on your own.")
add("PLAY_START", "Empezar", "Start")
add("PLAY_HOST_NAME", "Partida de %s", "%s's session")
add("PLAY_JOIN_INFO", "Introduce la dirección de un servidor dedicado o de un jugador anfitrión. No existe un servidor público oficial.", "Enter the address of a dedicated server or of a hosting player. There is no official public server.")
add("PLAY_ADDR_HINT", "Dirección (por ejemplo 192.168.1.20)", "Address (for example 192.168.1.20)")
add("PLAY_CONNECT", "Conectar", "Connect")
add("PLAY_RECENT", "Servidores recientes", "Recent servers")
add("PLAY_RECENT_NONE", "Todavía no te has unido a ningún servidor.", "You have not joined any server yet.")
add("PLAY_ADDR_BAD", "Escribe una dirección válida.", "Enter a valid address.")
# ---- perfil -------------------------------------------------------------------------------------------------
add("PROFILE_TITLE", "Perfil y aspecto", "Profile and look")
add("PROFILE_NAME", "Nombre visible", "Display name")
add("PROFILE_NAME_HINT", "Tu nombre", "Your name")
add("PROFILE_NAME_RULES", "De 3 a 16 letras, números, espacios o guiones.", "3 to 16 letters, numbers, spaces or hyphens.")
add("PROFILE_NAME_LOCKED", "No se puede cambiar durante una partida.", "It cannot be changed during a session.")
add("PROFILE_NAME_BAD", "Ese nombre no es válido.", "That name is not valid.")
add("PROFILE_SAVED", "Perfil guardado.", "Profile saved.")
add("PROFILE_JACKET", "Chaqueta", "Jacket")
add("PROFILE_HAT", "Gorro", "Hat")
add("PROFILE_LOCKED", "Se desbloquea con: %s", "Unlocked by: %s")
add("PROFILE_UNLOCK_HINT", "Los colores bloqueados se consiguen completando desafíos dentro de una partida.", "Locked colours are earned by completing challenges inside a session.")
add("PROFILE_HIDE", "Ocultar mi nombre a desconocidos", "Hide my name from strangers")
add("PROFILE_HIDE_HINT", "Solo tu grupo verá tu nombre sobre el personaje.", "Only your group will see your name above the character.")
add("PROFILE_ACCOUNT", "Identificador de cuenta", "Account identifier")
add("PROFILE_ACCOUNT_HINT", "Aleatorio y creado en este dispositivo: no contiene datos personales. Si borras los datos de la app, el servidor te tratará como un jugador nuevo.", "Random and created on this device: it holds no personal data. If you clear the app data, servers will treat you as a new player.")
# ---- ajustes ------------------------------------------------------------------------------------------------
add("SETTINGS_TITLE", "Ajustes", "Settings")
for key, es, en in [("CONTROL", "Control", "Controls"), ("AUDIO", "Sonido", "Audio"), ("VIDEO", "Gráficos", "Graphics"), ("GAME", "Juego", "Game"), ("ACCESS", "Accesibilidad", "Accessibility")]:
    add("SET_TAB_" + key, es, en)
for key, es, en, hes, hen in [
        ("SENS_H", "Sensibilidad horizontal", "Horizontal sensitivity", "", ""),
        ("SENS_V", "Sensibilidad vertical", "Vertical sensitivity", "", ""),
        ("INVERT_Y", "Invertir eje vertical", "Invert vertical axis", "", ""),
        ("TOUCH_SCALE", "Tamaño de los controles táctiles", "Touch control size", "", ""),
        ("TOUCH_OPACITY", "Opacidad de los controles táctiles", "Touch control opacity", "", ""),
        ("LEFT_HANDED", "Modo zurdo", "Left-handed mode", "Joystick a la derecha y botones de acción a la izquierda.", "Joystick on the right, action buttons on the left."),
        ("AUTO_SPRINT", "Esprintar al empujar el joystick al máximo", "Sprint when the joystick is pushed fully", "", ""),
        ("HEAD_BOB", "Balanceo de cámara al andar", "Camera bob while walking", "", ""),
        ("MASTER", "Volumen general", "Master volume", "", ""),
        ("MUSIC", "Música", "Music", "", ""),
        ("AMBIENT", "Ambiente", "Ambience", "", ""),
        ("SFX", "Efectos", "Effects", "", ""),
        ("MUTE_MUSIC", "Silenciar música", "Mute music", "", ""),
        ("MUTE_SFX", "Silenciar efectos", "Mute effects", "", ""),
        ("QUALITY", "Perfil gráfico", "Graphics preset", "Ajusta de golpe el resto de opciones.", "Sets the remaining options at once."),
        ("RENDER_SCALE", "Escala de resolución", "Resolution scale", "Menos resolución 3D = más fotogramas. La interfaz no pierde nitidez.", "Lower 3D resolution = more frames. The interface stays sharp."),
        ("VIEW_DISTANCE", "Distancia de visión (sectores)", "View distance (sectors)", "", ""),
        ("SHADOWS", "Sombras", "Shadows", "", ""),
        ("GRASS", "Densidad de hierba", "Grass density", "", ""),
        ("EFFECTS", "Efectos y partículas", "Effects and particles", "", ""),
        ("FPS_LIMIT", "Límite de fotogramas", "Frame limit", "Un límite más bajo reduce el calor y el consumo de batería.", "A lower limit reduces heat and battery use."),
        ("NORMAL_MAPS", "Relieve en materiales", "Material relief", "", ""),
        ("LANGUAGE", "Idioma", "Language", "", ""),
        ("SHOW_NAMES", "Mostrar nombres de jugadores", "Show player names", "", ""),
        ("SHOW_TEAM", "Mostrar a mi grupo en pantalla", "Show my group on screen", "", ""),
        ("CHAT", "Chat de texto", "Text chat", "Si lo desactivas no verás ni podrás enviar mensajes.", "If you turn it off you will not see or send messages."),
        ("HINTS", "Consejos y tutorial", "Tips and tutorial", "", ""),
        ("TEXT_SCALE", "Tamaño de la interfaz", "Interface size", "", ""),
        ("HIGH_CONTRAST", "Alto contraste", "High contrast", "Fondos opacos y bordes más marcados.", "Opaque backgrounds and stronger borders."),
        ("REDUCE_MOTION", "Reducir movimiento y destellos", "Reduce motion and flashes", "Quita el resplandor de los rayos y el vaivén de la cámara del menú.", "Removes lightning flashes and the menu camera sway."),
        ("NIGHT_BOOST", "Aclarar la noche", "Brighten the night", "", ""),
        ("HOLD_TO_INTERACT", "Mantener para interactuar", "Hold to interact", "Evita pulsaciones accidentales en pantalla táctil.", "Prevents accidental taps on touch screens.")]:
    add("SET_" + key, es, en)
    if hes:
        add("SETH_" + key, hes, hen)
add("SET_Q_LOW", "Bajo", "Low")
add("SET_Q_MED", "Medio", "Medium")
add("SET_Q_HIGH", "Alto", "High")
add("SET_OFF", "No", "Off")
add("SET_RESET", "Restablecer", "Reset")
add("SET_RESET_TEXT", "Se restaurarán todos los ajustes a sus valores iniciales.", "All settings will be restored to their defaults.")
add("SET_VIDEO_NOTE", "La distancia de visión y la hierba se aplican al cargar nuevas zonas.", "View distance and grass apply as new areas load.")
add("SET_GAME_NOTE", "El idioma cambia al instante en la interfaz y en los textos del juego.", "The language changes instantly in the interface and in game texts.")
add("LANG_ES", "Español", "Español")
add("LANG_EN", "English", "English")
# ---- legal, pausa, documento ---------------------------------------------------------------------
add("LEGAL_TITLE", "Créditos y legal", "Credits and legal")
add("LEGAL_TAB_CREDITS", "Créditos", "Credits")
add("LEGAL_TAB_PRIVACY", "Privacidad", "Privacy")
add("LEGAL_TAB_TERMS", "Términos", "Terms")
add("LEGAL_TAB_SUPPORT", "Soporte", "Support")
add("PAUSE_TITLE", "Menú", "Menu")
add("PAUSE_INFO", "Dificultad %s · %d de %d jugadores", "Difficulty %s · %d of %d players")
add("PAUSE_HOSTING", "Alojas esta partida. Dirección en tu red: %s · puerto %d", "You are hosting this session. Address on your network: %s · port %d")
add("PAUSE_RESUME", "Seguir jugando", "Resume")
add("PAUSE_PLAYERS", "Jugadores y grupo", "Players and group")
add("PAUSE_LEAVE", "Salir al menú", "Leave to menu")
add("PAUSE_LEAVE_TEXT", "Tu progreso queda guardado en el servidor.", "Your progress stays saved on the server.")
add("PAUSE_LEAVE_HOST", "Eres quien aloja la partida: al salir se guardará el mundo y se desconectará a los demás.", "You are hosting: leaving will save the world and disconnect everyone else.")
add("DOC_TITLE", "Documento", "Document")
add("DOC_FOUND", "Encontrado en: %s", "Found at: %s")
# ---- inventario -----------------------------------------------------------------------------------------
add("INV_TITLE", "Inventario", "Inventory")
add("INV_CONTAINER", "Contenedor", "Container")
add("INV_TAKE_ALL", "Coger todo", "Take all")
add("INV_EQUIPMENT", "Equipo puesto", "Equipped")
add("INV_BACKPACK", "Mochila · %d de %d huecos", "Backpack · %d of %d slots")
add("INV_WEIGHT", "%.1f / %.0f kg", "%.1f / %.0f kg")
add("INV_QUICK", "Accesos rápidos", "Quick slots")
add("INV_QUICK_BAD", "Solo se pueden asignar objetos que se usan o se llevan en la mano.", "Only items you can use or hold can be assigned.")
add("INV_EMPTY", "Vacío", "Empty")
add("INV_HINT", "Toca un objeto para ver qué puedes hacer con él. Para un acceso rápido, selecciónalo y toca una de las cuatro casillas.", "Tap an item to see what you can do with it. For a quick slot, select it and tap one of the four boxes.")
add("INV_HINT_CONTAINER", "Toca un objeto dos veces para pasarlo al otro lado.", "Tap an item twice to move it to the other side.")
add("INV_UNEQUIP", "Quitar", "Take off")
add("INV_TAKE", "Coger", "Take")
add("INV_TAKE_ONE", "Coger uno", "Take one")
add("INV_USE", "Usar", "Use")
add("INV_USE_FOOD", "Comer", "Eat")
add("INV_USE_DRINK", "Beber", "Drink")
add("INV_USE_MEDICAL", "Aplicar", "Apply")
add("INV_EQUIP", "Equipar", "Equip")
add("INV_STORE", "Guardar en el contenedor", "Store in container")
add("INV_DROP", "Soltar", "Drop")
add("INV_DROP_ONE", "Soltar uno", "Drop one")
add("INV_SPLIT", "Dividir el montón", "Split stack")
for key, es, en in [("CABEZA", "Cabeza", "Head"), ("CARA", "Cara", "Face"), ("TORSO", "Torso", "Torso"), ("ESPALDA", "Espalda", "Back"), ("PIERNAS", "Piernas", "Legs"),
                    ("PIES", "Pies", "Feet"), ("MANO", "Mano", "Hand")]:
    add("SLOT_" + key, es, en)
for key, es, en in [("CLOTHING", "Ropa y equipo", "Clothing and gear"), ("DRINK", "Bebida", "Drink"), ("FOOD", "Comida", "Food"), ("KEY", "Llave", "Key"),
                    ("MATERIAL", "Material", "Material"), ("MEDICAL", "Cuidados", "Care"), ("TOOL", "Herramienta", "Tool")]:
    add("CAT_" + key, es, en)
add("FACT_FOOD", "Quita %d de hambre", "Restores %d hunger")
add("FACT_WATER", "Quita %d de sed", "Restores %d thirst")
add("FACT_HEALTH", "Recupera %d de salud", "Restores %d health")
add("FACT_STAMINA", "Recupera %d de energía", "Restores %d stamina")
add("FACT_REST", "Alivia %d de cansancio", "Relieves %d fatigue")
add("FACT_TEMP", "Te calienta (%d)", "Warms you up (%d)")
add("FACT_EFFECT", "Provoca: %s", "Causes: %s")
add("FACT_CURE", "Alivia estados molestos", "Relieves bad conditions")
add("FACT_DETER", "Ahuyenta a las criaturas cercanas", "Scares off nearby creatures")
add("FACT_WARMTH", "Abrigo +%d", "Warmth +%d")
add("FACT_WET", "Repele el agua (%d %%)", "Repels water (%d%%)")
add("FACT_SLOTS", "+%d huecos de inventario", "+%d inventory slots")
add("FACT_CARRY", "+%d kg de carga", "+%d kg carry weight")
add("FACT_BOOTS", "Esprintar cansa menos", "Sprinting tires you less")
add("FACT_LIGHT", "Da luz al llevarlo en la mano", "Gives light while held")
add("FACT_FILTER", "Filtra las esporas de la bruma", "Filters the mist spores")
add("FACT_DUR", "Estado: %d de %d", "Condition: %d of %d")
add("FACT_FUEL", "Se recarga con: %s", "Refilled with: %s")
add("FACT_GIVES", "Al usarlo te deja: %s", "Using it leaves you: %s")
# ---- fabricación y construcción -----------------------------------------------------------------
add("CRAFT_TITLE", "Fabricar", "Crafting")
add("CRAFT_NEEDS", "Materiales", "Materials")
add("CRAFT_TOOL", "Herramienta: %s", "Tool: %s")
add("CRAFT_LEVEL", "Nivel %d", "Level %d")
add("CRAFT_TIME", "Tarda %.0f s", "Takes %.0f s")
add("CRAFT_GO", "Fabricar", "Craft")
for key, es, en in [("ALL", "Todo", "All"), ("COCINA", "Cocina", "Cooking"), ("SALUD", "Cuidados", "Care"), ("UTIL", "Útiles", "Tools"), ("MATERIAL", "Materiales", "Materials"), ("ROPA", "Ropa", "Clothing")]:
    add("RCAT_" + key, es, en)
add("STATION_FIRE", "Junto a una hoguera encendida", "Next to a lit campfire")
add("STATION_WORKBENCH", "En un banco de trabajo", "At a workbench")
add("STATION_NONE", "A mano, en cualquier sitio", "By hand, anywhere")
add("BUILD_TITLE", "Construir", "Building")
add("BUILD_INFO", "Colocas el armazón pagando su coste; después se termina la obra interactuando con él. Las piezas de pared, suelo y tejado encajan entre sí.", "You place the frame by paying its cost; then you finish the work by interacting with it. Wall, floor and roof pieces snap together.")
add("BUILD_FRAME", "Armazón", "Frame")
add("BUILD_COST", "Obra", "Build")
add("BUILD_PLACE", "Colocar", "Place")
add("BUILD_PLACE_HINT", "%s — E colocar · R girar · Esc cancelar", "%s — E place · R rotate · Esc cancel")
add("BUILD_PLACE_HINT_TOUCH", "%s — toca la mano para colocar", "%s — tap the hand to place")
# ---- mapa -------------------------------------------------------------------------------------------------
add("MAP_TITLE", "Mapa del valle", "Valley map")
add("MAP_INFO", "Estás en: %s\nLugares descubiertos: %d de %d", "You are in: %s\nPlaces discovered: %d of %d")
add("MAP_LEG_PLACE", "Lugar descubierto", "Discovered place")
add("MAP_LEG_GROUP", "Compañero de grupo", "Group member")
add("MAP_LEG_MARK", "Señal reciente", "Recent mark")
add("MAP_LEG_RESPAWN", "Tu punto de reaparición", "Your respawn point")
add("MAP_MARK", "Dejar una señal", "Leave a mark")
add("MAP_MARK_HINT", "Activa el botón y toca el mapa: tu grupo verá la señal durante un minuto y medio.", "Turn the button on and tap the map: your group will see the mark for a minute and a half.")
# ---- social ---------------------------------------------------------------------------------------------
add("SOCIAL_TITLE", "Jugadores y grupo", "Players and group")
add("SOCIAL_TAB_PLAYERS", "Jugadores", "Players")
add("SOCIAL_TAB_GROUP", "Mi grupo", "My group")
add("SOCIAL_TAB_EMOTES", "Gestos y señales", "Emotes and marks")
add("SOCIAL_ALONE", "Ahora mismo no hay nadie más en el valle.", "There is nobody else in the valley right now.")
add("SOCIAL_YOU", "tú", "you")
add("SOCIAL_LEVEL", "Nivel %d", "Level %d")
add("SOCIAL_IN_GROUP", "en tu grupo", "in your group")
add("SOCIAL_INVITE", "Invitar", "Invite")
add("SOCIAL_OFFER", "Ofrecer un objeto", "Offer an item")
add("SOCIAL_MUTE", "Silenciar su chat", "Mute their chat")
add("SOCIAL_REPORT", "Denunciar", "Report")
add("SOCIAL_REPORT_TEXT", "¿Por qué denuncias a %s? Se guardará en el servidor junto a sus últimos mensajes para que lo revise quien lo administra.", "Why are you reporting %s? It will be stored on the server with their latest messages for its administrator to review.")
add("SOCIAL_OFFER_PICK", "Elige qué ofrecer a %s. Tiene que estar a menos de cinco metros.", "Choose what to offer %s. They must be within five metres.")
add("SOCIAL_NO_GROUP", "No estás en ningún grupo. Crea uno e invita a otros jugadores para compartir señales, permisos de refugio y posición en el mapa.", "You are not in a group. Create one and invite other players to share marks, shelter permissions and map position.")
add("SOCIAL_CREATE", "Crear grupo", "Create group")
add("SOCIAL_OFFLINE", "desconectado", "offline")
add("SOCIAL_KICK", "Expulsar", "Remove")
add("SOCIAL_GROUP_INFO", "Hasta seis jugadores. El grupo se conserva aunque os desconectéis.", "Up to six players. The group persists even if you disconnect.")
add("SOCIAL_LEAVE", "Salir del grupo", "Leave group")
add("SOCIAL_EMOTES_INFO", "Los gestos los ven los jugadores cercanos; la señal, solo tu grupo.", "Nearby players see emotes; only your group sees the mark.")
add("SOCIAL_MARK_HERE", "Dejar una señal aquí", "Leave a mark here")
add("REPORT_CHAT", "Chat ofensivo", "Offensive chat")
add("REPORT_CHEAT", "Trampas", "Cheating")
add("REPORT_GRIEF", "Molesta a propósito", "Deliberate harassment")
add("EMOTE_WAVE", "Saludar", "Wave")
add("EMOTE_POINT", "Señalar", "Point")
add("EMOTE_SIT", "Sentarse", "Sit down")
# ---- diario ---------------------------------------------------------------------------------------------
add("JOURNAL_TITLE", "Diario", "Journal")
for key, es, en in [("PROGRESS", "Progreso", "Progress"), ("CHALLENGES", "Desafíos", "Challenges"), ("BOARD", "Encargos", "Jobs"), ("DOCS", "Documentos", "Documents"), ("PLACES", "Lugares", "Places")]:
    add("JOURNAL_TAB_" + key, es, en)
add("JOURNAL_LEVEL", "Nivel %d", "Level %d")
add("JOURNAL_XP", "%d de %d puntos de experiencia", "%d of %d experience points")
add("JOURNAL_XP_MAX", "%d puntos de experiencia · nivel máximo", "%d experience points · top level")
add("JOURNAL_PERKS", "Ventajas por nivel", "Level perks")
add("JOURNAL_PERK_AT", "Nivel %d", "Level %d")
add("JOURNAL_STATS", "Tu paso por el valle", "Your time in the valley")
add("JOURNAL_CHALLENGES", "Desafíos", "Challenges")
add("JOURNAL_ACHIEVEMENTS", "Logros", "Achievements")
add("JOURNAL_BOARD_INFO", "Los encargos se aceptan y se entregan en un tablón (hay uno en la plaza de Sotoalto). Puedes llevar tres a la vez.", "Jobs are accepted and handed in at a notice board (there is one in Sotoalto square). You can carry three at once.")
add("JOURNAL_REWARD", "Recompensa: %s", "Reward: %s")
add("JOURNAL_ACCEPT", "Aceptar", "Accept")
add("JOURNAL_TURNIN", "Entregar", "Hand in")
add("JOURNAL_ABANDON", "Abandonar", "Abandon")
add("JOURNAL_DONE", "Hecho", "Done")
add("JOURNAL_DOCS_COUNT", "Documentos leídos: %d de %d", "Documents read: %d of %d")
add("JOURNAL_DOCS_NONE", "Aún no has leído nada. Busca notas y cuadernos dentro de los edificios.", "You have not read anything yet. Look for notes and notebooks inside buildings.")
add("JOURNAL_PLACES_COUNT", "Lugares descubiertos: %d de %d", "Places discovered: %d of %d")
for key, es, en in [("DAYS", "Días en el valle", "Days in the valley"), ("PLACES", "Lugares descubiertos", "Places discovered"), ("DOCS", "Documentos leídos", "Documents read"),
                    ("DISTANCE", "Distancia recorrida", "Distance walked"), ("HARVEST", "Recolecciones", "Gatherings"), ("CRAFT", "Objetos fabricados", "Items crafted"),
                    ("BUILT", "Estructuras terminadas", "Structures finished"), ("CONTRACTS", "Encargos entregados", "Jobs handed in")]:
    add("JSTAT_" + key, es, en)


def run():
    os.makedirs(os.path.join(ROOT, "localization"), exist_ok=True)
    path = os.path.join(ROOT, "localization", "strings.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["keys", "es", "en"])
        for key in sorted(S):
            w.writerow([key, S[key][0], S[key][1]])
    print("textos:", len(S))


if __name__ == "__main__":
    run()
