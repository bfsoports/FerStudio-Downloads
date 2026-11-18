# Guía de despliegue del servidor dedicado

El servidor es el mismo proyecto de Godot ejecutado sin ventana con `--server`. Es la única autoridad
de la partida: valida movimiento, interacciones, inventario, fabricación, construcción, criaturas y
progreso, y guarda el mundo en disco.

> No existe un servidor público oficial. Lo aquí descrito se ha probado en local (Linux x86_64);
> desplegarlo en Internet y administrarlo es responsabilidad de quien lo haga.

## 1. Obtener el binario

- Artefacto `valdebruma-servidor-linux` del flujo de GitHub Actions, o
- `godot --headless --path . --export-release "Linux Server" ../builds/server/valdebruma_server.x86_64`, o
- sin exportar: `godot --headless --path /ruta/Valdebruma -- --server …` (requiere Godot 4.7.2 y `--import` previo).

## 2. Arrancar

```bash
VB_PORT=24680 VB_WORLD=valle VB_DATA=/var/lib/valdebruma VB_DIFFICULTY=normal server/run_server.sh
```

| Variable | Argumento | Por defecto | Significado |
|---|---|---|---|
| `VB_PORT` | `--port` | 24680 | Puerto UDP (ENet) |
| `VB_WORLD` | `--world` | valle | Nombre del mundo (carpeta de datos) |
| `VB_DATA` | `--data` | `server/datos` | Carpeta de guardado |
| `VB_DIFFICULTY` | `--difficulty` | normal | tranquilo, normal o exigente |
| `VB_DAY_LENGTH` | `--day-length` | 2400 | Segundos de un día de juego (mín. 60) |
| `VB_NAME` | `--name` | Valdebruma | Nombre visible del servidor |

Otros argumentos útiles para pruebas: `--hour=10` (hora inicial), `--test-kit` (equipo de prueba al
entrar), `--exit-after=N` (cerrar tras N segundos).

### systemd

`server/valdebruma.service` es una unidad de ejemplo: crea el usuario `valdebruma`, copia el binario
y `run_server.sh` a `/opt/valdebruma`, ajusta rutas y ejecuta `systemctl enable --now valdebruma`.

### Docker

```bash
docker build -f Valdebruma/server/Dockerfile -t valdebruma-server .
docker run -d -p 24680:24680/udp -v valdebruma-datos:/datos --name valdebruma valdebruma-server
```

## 3. Red

- Abre el puerto **UDP** elegido en el cortafuegos y, si hace falta, en el router (NAT).
- Capacidad: 24 jugadores por servidor (`Protocol.MAX_PLAYERS`). Consumo medido en local: ver
  `PERFORMANCE_REPORT.md`.
- El tráfico no va cifrado (ENet sin DTLS). No envía datos personales, pero si lo expones en Internet
  considera un túnel o VPN. Añadir DTLS está en la lista de pendientes.

## 4. Datos y copias

```
<VB_DATA>/<mundo>/
  world.json            estado del mundo (estructuras, contenedores, puertas, recolección, grupos, clima…)
  players/<cuenta>.json estado de cada jugador
  accounts.json         nombre ↔ cuenta (huella SHA-256 con sal del secreto del dispositivo)
  reports.log           denuncias de jugadores con sus últimos mensajes
  anomalies.log         peticiones rechazadas sospechosas (velocidad, alcance, exceso de peticiones)
```

Cada archivo se escribe de forma atómica (temporal → renombrado) con suma SHA-256 y dos copias
rotatorias (`.bak1`, `.bak2`). Si uno está dañado se aparta como `.corrupt-<fecha>` y se usa la copia.
Haz copias de la carpeta con el servidor parado o tras una parada ordenada.

## 5. Parar

- **Ordenada:** crea `<VB_DATA>/<mundo>/stop`. El servidor guarda y termina en menos de un segundo
  (es lo que hace `ExecStop` en la unidad systemd).
- **SIGTERM / corte:** el mundo se guarda cada 15 s si hay cambios y al salir el último jugador; la
  prueba `tests/net_session.sh` comprueba que un `kill -KILL` no daña los datos.

## 6. Moderación

- Las denuncias quedan en `reports.log` con los 8 primeros caracteres de la cuenta. Para bloquear o
  desbloquear una cuenta (con el servidor parado):

  ```bash
  valdebruma_server.x86_64 --headless -- --admin=list  --world=valle --data=/var/lib/valdebruma
  valdebruma_server.x86_64 --headless -- --admin=ban   --account=1a2b3c4d --world=valle --data=/var/lib/valdebruma
  valdebruma_server.x86_64 --headless -- --admin=unban --account=1a2b3c4d --world=valle --data=/var/lib/valdebruma
  ```

  La orden reescribe `accounts.json` con su suma de control y sus copias; no lo edites a mano.
  Una cuenta bloqueada recibe «No puedes entrar en este servidor».
- El chat se limita a 140 caracteres y un mensaje cada 1,2 s por jugador; el global se puede
  desactivar (`options.global_chat`).

## 7. Actualizar

Cliente y servidor deben compartir `Protocol.VERSION` (3 en esta versión). Si cambia, actualiza
ambos a la vez; el servidor rechaza clientes de otra versión con un mensaje claro.
