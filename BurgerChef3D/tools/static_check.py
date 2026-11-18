#!/usr/bin/env python3
"""Comprobación estática del proyecto (no sustituye a abrirlo en Godot, pero detecta errores comunes sin el motor):
indentación, paréntesis, referencias entre scripts, claves de traducción, rutas res://, escenas .tscn y patrones de GDScript
que suelen fallar (inferencia de tipo con Variant). Uso: python3 tools/static_check.py"""
import glob, json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
errors, warns = [], []

def rel(p): return os.path.relpath(p, ROOT)
def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

gd_files = sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True) + glob.glob(os.path.join(ROOT, "tests", "**", "*.gd"), recursive=True))

def strip_code(line):
    """Quita cadenas y comentarios de una línea (para analizar solo el código)."""
    out, i, q = [], 0, None
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\": i += 2; continue
            if c == q: q = None
            i += 1; continue
        if c in "\"'": q = c; out.append('"'); i += 1; continue
        if c == "#": break
        out.append(c); i += 1
    return "".join(out)

# ---------------------------------------------------------------- 1) sintaxis básica
info = {}
for path in gd_files:
    text = read(path)
    lines = text.split("\n")
    depth = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    for n, raw in enumerate(lines, 1):
        if raw.strip() == "" or raw.lstrip().startswith("#"): continue
        if re.match(r"^ +\S", raw): errors.append(f"{rel(path)}:{n}: indentación con espacios")
        if re.match(r"^\t+ +\S", raw) and sum(depth.values()) == 0: errors.append(f"{rel(path)}:{n}: tabulación mezclada con espacios")
        code = strip_code(raw)
        for ch in code:
            if ch in depth: depth[ch] += 1
            elif ch in pairs:
                depth[pairs[ch]] -= 1
                if depth[pairs[ch]] < 0: errors.append(f"{rel(path)}:{n}: cierre sin apertura '{ch}'"); depth[pairs[ch]] = 0
        if re.search(r"\b(TODO|FIXME|XXX)\b|implementar después|aquí iría|pseudocódigo", raw, re.I):
            errors.append(f"{rel(path)}:{n}: marcador de código pendiente")
        if re.search(r":=\s*[\w\.]+\.get\(|:=\s*[\w\.]+\[[^\]]*\]\s*$|:=\s*(max|min|lerp|clamp|abs|floor|ceil|round|sign|snapped|wrap)\(|:=\s*[\w\.]+\.pick_random\(", code):
            warns.append(f"{rel(path)}:{n}: ':=' con valor Variant (posible 'no se puede inferir el tipo'): {raw.strip()[:90]}")
    if any(depth.values()): errors.append(f"{rel(path)}: paréntesis/llaves sin cerrar {depth}")
    # miembros de la clase
    members, cls, base = set(), None, None
    for raw in lines:
        m = re.match(r"^class_name\s+(\w+)", raw)
        if m: cls = m.group(1)
        m = re.match(r"^extends\s+(\w+)", raw)
        if m and base is None: base = m.group(1)
        m = re.match(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?func\s+(\w+)", raw)
        if m: members.add(m.group(1))
        m = re.match(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:var|const)\s+(\w+)", raw)
        if m: members.add(m.group(1))
        m = re.match(r"^signal\s+(\w+)", raw)
        if m: members.add(m.group(1))
        m = re.match(r"^enum\s+(\w+)", raw)
        if m: members.add(m.group(1))
    info[path] = {"class": cls, "base": base, "members": members}

# estructura de bloques: ':' final, bloques vacíos e indentación inesperada
BLOCK_KW = re.compile(r"^(if|elif|else|for|while|match|func|static func|class)\b")
for path in gd_files:
    prev_indent, prev_code, prev_open, prev_block = None, "", 0, False
    depth = 0
    continued = False
    for n, raw in enumerate(read(path).split("\n"), 1):
        if raw.strip() == "" or raw.lstrip().startswith("#"): continue
        indent = len(raw) - len(raw.lstrip("\t"))
        code = strip_code(raw).rstrip()
        body = code.lstrip("\t ")
        if continued:
            continued = code.endswith("\\")
            prev_block = depth == 0 and code.endswith(":")
            prev_code = code
            continue
        continued = code.endswith("\\")
        if depth == 0:
            if BLOCK_KW.match(body) or body.startswith("@onready func"):
                d0 = 0
                for ch in code:
                    if ch in "([{": d0 += 1
                    elif ch in ")]}": d0 -= 1
                if d0 == 0 and not code.endswith(":") and ":" not in code and not code.endswith("\\"):
                    errors.append(f"{rel(path)}:{n}: falta ':' al final de la línea de bloque: {body[:70]}")
            if prev_block and indent <= prev_indent:
                errors.append(f"{rel(path)}:{n}: bloque vacío tras la línea anterior")
            if prev_indent is not None and not prev_block and prev_open == 0 and indent > prev_indent and not prev_code.endswith("\\"):
                errors.append(f"{rel(path)}:{n}: indentación inesperada")
        for ch in code:
            if ch in "([{": depth += 1
            elif ch in ")]}": depth = max(0, depth - 1)
        prev_open = depth
        prev_block = depth == 0 and code.endswith(":")
        prev_indent, prev_code = indent, code

# ---------------------------------------------------------------- 2) autoloads y clases
autoloads = {}
proj = read(os.path.join(ROOT, "project.godot"))
for m in re.finditer(r'^(\w+)="\*res://([^"]+)"', proj, re.M):
    autoloads[m.group(1)] = os.path.join(ROOT, m.group(2))
by_class = {v["class"]: p for p, v in info.items() if v["class"]}
NODE_ALLOW = {"add_child", "get_tree", "queue_free", "create_tween", "name", "process_mode", "get_viewport", "connect", "is_inside_tree",
              "has_method", "get_node", "new", "free", "get_parent", "remove_child", "set_process", "get_children", "visible"}

def members_of(path, seen=None):
    seen = seen or set()
    if path in seen: return set(), True
    seen.add(path)
    v = info[path]
    out = set(v["members"])
    parent_known = False
    if v["base"] in by_class:
        sub, parent_known = members_of(by_class[v["base"]], seen)
        out |= sub
        return out, parent_known
    return out, False

for path in gd_files:
    for n, raw in enumerate(read(path).split("\n"), 1):
        code = strip_code(raw)
        for m in re.finditer(r"(?<![\w.])([A-Z]\w*)\.(\w+)", code):
            name, member = m.group(1), m.group(2)
            target = autoloads.get(name) or by_class.get(name)
            if not target or target not in info: continue
            mem, _ = members_of(target)
            if member in mem or member in NODE_ALLOW: continue
            if name in autoloads and member in ("emit", "connect"): continue
            errors.append(f"{rel(path)}:{n}: {name}.{member} no existe en {rel(target)}")

# ---------------------------------------------------------------- 3) traducciones
strings = json.load(open(os.path.join(ROOT, "resources", "i18n", "strings.json"), encoding="utf-8")) if os.path.exists(os.path.join(ROOT, "resources", "i18n", "strings.json")) else {}
for k, v in strings.items():
    if not (isinstance(v, dict) and v.get("es") and v.get("en")): errors.append(f"strings.json: '{k}' sin es/en")
used = set()
FILE_EXT = (".gd", ".json", ".tscn", ".wav", ".png", ".svg", ".ttf", ".cfg", ".tmp", ".bak", ".md", ".godot", ".glb", ".gltf", ".ogg", ".ogv", ".jpg", ".webp")
for path in gd_files:
    for raw in read(path).split("\n"):
        if raw.lstrip().startswith("#"): continue
        for s in re.findall(r'"([a-z_]+(?:\.[a-z_0-9]+)+)"', raw):
            if s.endswith(FILE_EXT) or s.startswith("res"): continue
            used.add((s, rel(path)))
        for s in re.findall(r'"((?:stat|cat|upgstat|mis\.tab|result\.reason|result\.record|rest)[._][a-z_]*)"\s*(?:\+|%)', raw):
            pass
missing = sorted({(k, f) for k, f in used if k not in strings})
for k, f in missing:
    warns.append(f"clave de traducción no encontrada: '{k}' ({f})")
# familias dinámicas
dyn = [f"stat.{s}" for s in ["burgers_made","customers_served","orders_correct","coins_earned","no_burn_shifts","perfect_burgers","recipes_unlocked","upgrades_bought","levels_completed","best_streak","patties_cooked","combos_served","stars_total","items_bought","player_level","shifts_played","three_star_levels","trays_washed"]]
dyn += [f"cat.{c}" for c in ["wall","floor","counter","tables","chairs","lamps","sign","decor"]]
dyn += [f"upgstat.{s}" for s in ["grill_slots","fryer_slots","cook_speed","prep_boards","crate_stock","patience_mult","service_points","coin_mult","look_level","recipe_pack","decor_options","wash_speed"]]
dyn += ["mis.tab_mission","mis.tab_challenge","mis.tab_achievement","result.reason_time","result.reason_failed","result.reason_quit",
        "result.record_best_orders","result.record_best_income","result.record_longest_session"]
dyn += [f"rest.stat_{s}" for s in ["burgers_made","customers_served","coins_earned","perfect_burgers","best_streak","levels_completed","upgrades_bought","shifts_played"]]
for k in dyn:
    if k not in strings: warns.append(f"clave dinámica ausente: '{k}'")

# formato de textos: nº de argumentos vs marcadores %s/%d de cada idioma
def split_top(args):
    parts, depth, cur, q = [], 0, "", None
    for ch in args:
        if q:
            cur += ch
            if ch == q: q = None
            continue
        if ch in "\"'": q = ch; cur += ch; continue
        if ch in "([{": depth += 1
        if ch in ")]}": depth -= 1
        if ch == "," and depth == 0: parts.append(cur.strip()); cur = ""; continue
        cur += ch
    if cur.strip(): parts.append(cur.strip())
    return parts
def placeholders(t): return len(re.findall(r"%[sdif]", t.replace("%%", "")))
def bracket_args(raw, start):
    """Devuelve el contenido de la lista [ ... ] que empieza en raw[start] respetando anidación y cadenas."""
    depth, q, out = 0, None, ""
    for ch in raw[start:]:
        if q:
            out += ch
            if ch == q: q = None
            continue
        if ch in "\"'": q = ch; out += ch; continue
        if ch == "[": depth += 1; 
        if ch == "]":
            depth -= 1
            if depth == 0: return out[1:]
        out += ch
    return None
for path in gd_files:
    for n, raw in enumerate(read(path).split("\n"), 1):
        for m in re.finditer(r'Loc\.t\("([^"]+)",\s*\[', raw):
            key = m.group(1)
            args = bracket_args(raw, m.end() - 1)
            if key in strings and args is not None:
                cnt = len(split_top(args))
                for lang in ("es", "en"):
                    if placeholders(strings[key][lang]) != cnt:
                        errors.append(f"{rel(path)}:{n}: '{key}' ({lang}) espera {placeholders(strings[key][lang])} argumentos y recibe {cnt}")
        for m in re.finditer(r'"text":\s*"([a-z_.]+)"(?:,\s*"args":\s*\[)?', raw):
            key = m.group(1)
            has_args = raw[m.end() - 1] == "["
            args = bracket_args(raw, m.end() - 1) if has_args else ""
            if key in strings and args is not None:
                cnt = len(split_top(args)) if has_args else 0
                for lang in ("es", "en"):
                    if placeholders(strings[key][lang]) != cnt:
                        errors.append(f"{rel(path)}:{n}: indicador '{key}' ({lang}) espera {placeholders(strings[key][lang])} argumentos y recibe {cnt}")
        for m in re.finditer(r'Loc\.t\("([^"]+)"\)', raw):
            key = m.group(1)
            if key in strings and placeholders(strings[key]["es"]) > 0:
                warns.append(f"{rel(path)}:{n}: '{key}' tiene marcadores pero se usa sin argumentos")

# ---------------------------------------------------------------- 4) rutas res://
def check_paths(path):
    for n, raw in enumerate(read(path).split("\n"), 1):
        for p in re.findall(r"res://([\w./\-]+)", raw):
            if re.search(r"res://" + re.escape(p) + r"%", raw): continue
            full = os.path.join(ROOT, p)
            if not os.path.exists(full) and not p.endswith("/"):
                errors.append(f"{rel(path)}:{n}: ruta inexistente res://{p}")
for path in gd_files + glob.glob(os.path.join(ROOT, "scenes", "**", "*.tscn"), recursive=True) + [os.path.join(ROOT, "project.godot")]:
    check_paths(path)

# ---------------------------------------------------------------- 5) escenas .tscn
for path in glob.glob(os.path.join(ROOT, "scenes", "**", "*.tscn"), recursive=True):
    text = read(path)
    ids = dict(re.findall(r'\[ext_resource[^\]]*path="res://([^"]+)"[^\]]*id="(\w+)"', text))
    ids = {v: k for k, v in ids.items()}
    for ref in set(re.findall(r'ExtResource\("(\w+)"\)', text)):
        if ref not in ids: errors.append(f"{rel(path)}: ExtResource {ref} sin definir")
    nodes = {}
    cur = None
    for line in text.split("\n"):
        m = re.match(r'\[node name="([^"]+)"(?: type="[^"]*")?(?: parent="([^"]*)")?', line)
        if m:
            name, parent = m.group(1), m.group(2)
            full = "." if parent is None else (name if parent == "." else parent + "/" + name)
            if parent is not None and parent != "." and parent not in nodes: errors.append(f"{rel(path)}: padre inexistente '{parent}' para '{name}'")
            nodes[full] = None
            cur = full
        elif line.startswith("["): cur = None
        elif cur is not None:
            m = re.match(r'script = ExtResource\("(\w+)"\)', line)
            if m: nodes[cur] = ids.get(m.group(1))
    # $Ruta de los scripts asociados
    for node, script in nodes.items():
        if not script or not script.endswith(".gd"): continue
        sp = os.path.join(ROOT, script)
        if not os.path.exists(sp): continue
        for n, raw in enumerate(read(sp).split("\n"), 1):
            for p in re.findall(r"\$([\w/]+)", strip_code(raw) if False else raw):
                full = p if node == "." else node + "/" + p
                if full not in nodes: errors.append(f"{script}:{n}: ${p} no existe en {rel(path)}")

print(f"Scripts analizados: {len(gd_files)}")
for w in warns: print("AVISO:", w)
for e in errors: print("ERROR:", e)
print(f"\n{len(errors)} errores, {len(warns)} avisos")
sys.exit(1 if errors else 0)
