#!/bin/bash
# Prueba de sesión multijugador REAL: servidor dedicado sin ventana + dos clientes ENet.
# Comprueba sincronización, carrera por el mismo objeto, permisos de contenedor, rechazo de
# peticiones inválidas, reconexión y persistencia tras reiniciar el servidor.
# Uso: tests/net_session.sh [dir_salida]   (código de salida 0 = todo correcto)
cd "$(dirname "$0")/.."
OUT=${1:-/tmp/vb_net_session}
PORT=${PORT:-24711}
rm -rf "$OUT"; mkdir -p "$OUT"
G="godot --headless --path ."
start_server() { $G -- --server --port=$PORT --data="$OUT/data" --world=prueba --test-kit --hour=10 > "$OUT/server_$1.log" 2>&1 & echo $!; }
bot() { timeout 120 $G -- --bot=$1 --connect=127.0.0.1:$PORT --name=$2 ${3:+--pos=$3} > "$OUT/$4.log" 2>&1; }

SRV=$(start_server 1); sleep 4
bot duo_a Ana "" a1 & PA=$!
sleep 1.5
bot duo_b Blas "" b1 & PB=$!
wait $PA; wait $PB
bot reconnect Carla "" c1
touch "$OUT/data/prueba/stop"; wait $SRV 2>/dev/null     # parada ordenada (archivo stop)
POS_A=$(grep "BOT|Ana|FINAL" "$OUT/a1.log" | python3 -c "import sys,json; print(','.join(str(v) for v in json.loads(sys.stdin.readline().split('|',3)[3])['pos']))")
SRV=$(start_server 2); sleep 4
bot verify Ana "$POS_A" a2
bot verify Blas "" b2
kill -KILL $SRV; wait $SRV 2>/dev/null                   # corte brusco: no debe dañar los datos
SRV=$(start_server 3); sleep 4
bot verify Ana "$POS_A" a3
touch "$OUT/data/prueba/stop"; wait $SRV 2>/dev/null

python3 - "$OUT" <<'PY'
import json, sys, os, re
out = sys.argv[1]
def events(f):
    ev = []
    for line in open(os.path.join(out, f), errors="replace"):
        if line.startswith("BOT|"):
            p = line.rstrip("\n").split("|", 3)
            try: ev.append((p[2], json.loads(p[3])))
            except Exception: ev.append((p[2], p[3]))
    return ev
res = []
def add(name, ok, detail=""):
    res.append((name, ok, detail))
logs = {k: events(k + ".log") for k in ("a1", "b1", "c1", "a2", "b2", "a3")}
for k, ev in logs.items():
    add(k + ": el cliente recibió WELCOME del servidor", any(e == "WELCOME" for e, _ in ev))
    for e, d in ev:
        if e == "CHECK":
            add("%s: %s" % (k, d["t"]), bool(d["ok"]), "" if d["ok"] else json.dumps(d["d"], ensure_ascii=False)[:160])
def final(k):
    for e, d in logs[k]:
        if e == "FINAL": return d
    return None
def race(k):
    for e, d in logs[k]:
        if e == "AFTER_RACE": return d
    return {}
ga, gb = race("a1").get("galletas", 0), race("b1").get("galletas", 0)
add("carrera: el objeto soltado acaba en UN solo inventario (A=%d, B=%d, total inicial 2)" % (ga, gb), ga + gb == 2 and {ga, gb} == {1, 1} or (ga + gb == 2))
fa1, fb1, fa2, fb2 = final("a1"), final("b1"), final("a2"), final("b2")
add("fin de sesión: A y B terminaron su guion", fa1 is not None and fb1 is not None)
if fa1 and fb1:
    add("venda: salió de A y llegó a B sin duplicarse (A=%d, B=%d)" % (fa1["inv"].get("venda", 0), fb1["inv"].get("venda", 0)), fa1["inv"].get("venda", 0) == 0 and fb1["inv"].get("venda", 0) == 2)
if fa1 and fa2:
    add("persistencia: inventario de A idéntico tras reiniciar el servidor", fa1["inv"] == fa2["inv"], json.dumps([fa1["inv"], fa2["inv"]], ensure_ascii=False)[:200])
if fb1 and fb2:
    add("persistencia: inventario de B idéntico tras reiniciar el servidor", fb1["inv"] == fb2["inv"], json.dumps([fb1["inv"], fb2["inv"]], ensure_ascii=False)[:200])
errs = [l.strip() for f in os.listdir(out) if f.endswith(".log") for l in open(os.path.join(out, f), errors="replace") if "SCRIPT ERROR" in l or "ERROR:" in l and "audio" not in l.lower() and "alsa" not in l.lower()]
add("sin errores de script en servidor ni clientes", not errs, "; ".join(errs[:3])[:300])
ok = all(r[1] for r in res)
with open(os.path.join(out, "resultado.txt"), "w") as f:
    for name, good, detail in res:
        line = "%s  %s%s" % ("OK   " if good else "FALLO", name, ("  -> " + detail) if detail else "")
        print(line); f.write(line + "\n")
    f.write("\nRESULTADO: %s (%d/%d)\n" % ("CORRECTO" if ok else "CON FALLOS", sum(1 for r in res if r[1]), len(res)))
print("\nRESULTADO: %s (%d/%d)" % ("CORRECTO" if ok else "CON FALLOS", sum(1 for r in res if r[1]), len(res)))
sys.exit(0 if ok else 1)
PY
