# Imagen mínima del servidor dedicado de Valdebruma.
# Construcción (desde la raíz del repositorio, tras exportar el servidor):
#   docker build -f Valdebruma/server/Dockerfile -t valdebruma-server .
# Ejecución:
#   docker run -d -p 24680:24680/udp -v valdebruma-datos:/datos --name valdebruma valdebruma-server
FROM debian:bookworm-slim
RUN useradd --system --create-home --home-dir /opt/valdebruma valdebruma \
 && mkdir -p /datos && chown valdebruma /datos
COPY builds/server/valdebruma_server.x86_64 /opt/valdebruma/valdebruma_server.x86_64
COPY Valdebruma/server/run_server.sh /opt/valdebruma/run_server.sh
RUN chmod +x /opt/valdebruma/*.sh /opt/valdebruma/valdebruma_server.x86_64
USER valdebruma
ENV VB_PORT=24680 VB_WORLD=valle VB_DATA=/datos
EXPOSE 24680/udp
VOLUME ["/datos"]
STOPSIGNAL SIGTERM
CMD ["/opt/valdebruma/run_server.sh"]
