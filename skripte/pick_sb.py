"""StanRadar: odabir stanova za mail iz Supabase kandidata (ista pravila kao mail0511/pick.py).

Ulaz:  kandidati.json  = rezultat upita kandidati.sql (JSON niz)
       liste klijenata (već na listi: isti ID ili isti stan)
Izlaz: picked.json (isti oblik kao prije, za build.py / mail.py)

  python3 pick_sb.py kandidati.json [izlaz.json]
"""
import json, re, sys

import os
LISTE = {"ivor": os.environ.get("LISTA_IVOR", "/home/claude/stanradar-lista/index.html"),
         "jan": os.environ.get("LISTA_JAN", "/home/claude/stanradar-lista/jan/index.html"),
         "filip": os.environ.get("LISTA_FILIP", "/home/claude/stanradar-lista/filip/index.html"),
         "domagoj": os.environ.get("LISTA_DOMAGOJ", "/home/claude/stanradar-lista/domagoj/index.html")}
IME = {"ivor": "Ivor (test klijent)", "jan": "Jan Benko (test klijent)", "filip": "Filip", "domagoj": "Domagoj Franc"}
DOMAGOJ_KV = ("Maksimir", "Peščenica - Žitnjak", "Donja Dubrava", "Gornja Dubrava")
FILIP_KV = ("Trešnjevka - Sjever", "Trešnjevka - Jug", "Novi Zagreb - Zapad")
PRI = {"njuskalo": 0, "index": 1, "oglasnik": 2, "fb_grupa": 3, "fb_marketplace": 4}
STOP = {'zagreb', 'novi', 'zapad', 'istok', 'sjever', 'grad', 'gornji', 'donji', 'gornja', 'donja', 'okolica', 'ulica'}


def sb_id(i):
    """ID s liste (stari Notion oblik) -> Supabase oblik."""
    if '-' not in i:
        return 'njuskalo-' + i
    p, _, r = i.partition('-')
    return {'fb': 'fb_grupa', 'mp': 'fb_marketplace'}.get(p, p) + '-' + r


def load_sent(f):
    s = open(f).read(); out = []
    for m in re.finditer(r'\{id:"([^"]+)", t:"([^"]*)", r:"([^"]*)", c:(\d+), m:([\d.]+|null)', s):
        out.append(dict(id=sb_id(m[1]), t=m[2], r=m[3], c=int(m[4]), m=(round(float(m[5])) if m[5] != 'null' else None)))
    return out


norm = lambda x: re.sub(r'[^a-zčćšđž ]', '', x.lower().replace('–', '-'))
def words(k): return set(w for w in re.split(r'[\s,\-–/·]+', norm(k)) if len(w) > 3 and w not in STOP)
src = lambda r: r["id"].split("-")[0]


def same(a, b):
    if a["m"] is None or b["m"] is None: return False
    return a["c"] == b["c"] and abs(a["m"] - b["m"]) <= 1 and (not words(a["k"]) or not words(b["k"]) or bool(words(a["k"]) & words(b["k"])))


def elig(who, r):
    if r["m"] is None and r["s"] is None: return False
    if who == "ivor": return r["c"] <= 600 and r["lj"] != "Ne" and not r["k"].startswith("Zagreb - Okolica") and r["k"] != "Zagreb"
    if who == "domagoj": return 500 <= r["c"] <= 1000 and r["s"] == "3-sobni+" and r["mr"] is not None and 60 <= r["mr"] <= 80 and r["k"].startswith(DOMAGOJ_KV)  # trosoban (2 sobe + dnevni), 60-80 m2, bez ljubimca
    if who == "filip": return r["c"] <= 450 and r["k"].startswith(FILIP_KV)  # od garsonijere, bez ljubimca -> sve sobe, ljubimci nebitni
    return r["c"] <= 650 and (r["k"].startswith("Maksimir") or r["k"].startswith("Peščenica")) and r["s"] != "Garsonijera"


def main(inp, outp):
    K = json.load(open(inp))
    rows = []
    for q in K:
        m = float(q["m"]) if q["m"] is not None else None
        rows.append(dict(id=q["id"], c=q["c"], m=(round(m) if m else None), mr=m, s=q["s"], k=q["k"] or "", lj=q["lj"],
                         t=1 if q["t"] else 0, b=1 if q["b"] else 0, ob=q["ob"], l=q["l"], posl=q["posl"]))
    S = {k: load_sent(f) for k, f in LISTE.items()}
    print("na listama:", {k: len(v) for k, v in S.items()}, "kandidata:", len(rows))
    res = {}
    for who in LISTE:
        c = [r for r in rows if elig(who, r)]
        c.sort(key=lambda r: PRI.get(src(r), 9))
        keep = []; drop = []
        for r in c:
            if IME[who] in r["posl"]: drop.append((r["id"], "već poslan (Supabase)")); continue
            dup = next((x for x in keep if same(x, r)), None)
            if dup: drop.append((r["id"], "isti kao " + dup["id"])); continue
            sent = next((x for x in S[who] if x["id"] == r["id"] or (x["c"] == r["c"] and r["m"] is not None and x["m"] is not None and abs(x["m"] - r["m"]) <= 1 and (words(x["t"].split("·")[-1]) & words(r["k"].split(",")[-1])))), None)
            if sent: drop.append((r["id"], f"već na listi {sent['id']} ({sent['t']})")); continue
            keep.append(r)
        keep.sort(key=lambda r: r["ob"], reverse=True)
        res[who] = [{k: v for k, v in r.items() if k != "posl"} for r in keep]
        print(who, "keep", len(keep), "drop", len(drop))
        for d in drop: print("  -", *d)
    json.dump(res, open(outp, "w"), ensure_ascii=False, indent=0)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "picked.json")
