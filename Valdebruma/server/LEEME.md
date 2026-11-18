# Servidor dedicado de Valdebruma

- `run_server.sh` — lanzador configurable por variables de entorno (puerto, mundo, datos, dificultad).
- `valdebruma.service` — unidad systemd de ejemplo con parada ordenada.
- `Dockerfile` — imagen mínima a partir del binario exportado.

El binario del servidor se obtiene con el preset de exportación «Linux Server» o como artefacto
`valdebruma-servidor-linux` del flujo de GitHub Actions. Guía completa: `docs/SERVER_DEPLOYMENT_GUIDE.md`.
No existe un servidor público oficial: quien lo despliegue es responsable de su administración.
