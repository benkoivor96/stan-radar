"""StanRadar -> Supabase: pretvorba scrape redaka u retke tablice oglasi i SQL za upis.

Scrape i dalje slaze retke u obliku {"properties": {...}} (Naslov, Izvor, ID oglasa, ...).
Ovdje se pretvaraju u Supabase oblik po istim pravilima kao funkcija sync_notion,
tako da novi retci izgledaju isto kao preneseni iz Notiona.

Upotreba:
  python3 sb.py rows  all.json  > rows.json     # samo pretvorba (provjera)
  python3 sb.py sql   all.json  > insert.sql    # SQL za upis (insert, postojeci: samo zadnji_put_vidjen)
  python3 sb.py ids   all.json                  # popis ID-jeva za provjeru u bazi
"""
import json, sys

IZVOR = {"Njuškalo": "njuskalo", "Index": "index", "Oglasnik": "oglasnik", "FB Marketplace": "fb_marketplace"}
PFX = {"fb": "fb_grupa", "mp": "fb_marketplace"}
SOBE = {"Garsonijera", "1-sobni", "2-sobni", "3-sobni+"}
LJ = {"Da", "Ne", "Po dogovoru", "Ne piše"}
STATUS = {"Aktivan", "Poslano klijentima", "Iznajmljeno", "Nestao"}
COLS = ["id", "izvor", "izvorni_id", "link", "naslov", "cijena", "m2", "sobe", "kvart", "dio_kvarta", "ljubimci",
        "vrt_terasa", "bez_provizije", "objavljeno", "status", "napomena", "grupa"]


def to_row(q):
    idn = (q.get("ID oglasa") or "").strip()
    pfx, _, rest = idn.partition("-")
    if not rest:
        raise ValueError(f"ID bez prefiksa: {idn!r}")
    izvor = PFX.get(pfx, pfx)
    exp = IZVOR.get(q.get("Izvor"), "fb_grupa")
    if izvor != exp:
        raise ValueError(f"{idn}: prefiks {izvor} ne odgovara izvoru {q.get('Izvor')}")
    kv = q.get("Kvart") or ""
    kvart, sep, dio = kv.partition(",")
    c = q.get("Cijena (€)")
    m = q.get("m²")
    return {
        "id": f"{izvor}-{rest}",
        "izvor": izvor,
        "izvorni_id": rest,
        "link": q.get("Link"),
        "naslov": q.get("Naslov"),
        "cijena": round(c) if isinstance(c, (int, float)) and 0 <= c <= 100000 else None,
        "m2": m if isinstance(m, (int, float)) and 0 < m < 100000 else None,
        "sobe": q.get("Sobe") if q.get("Sobe") in SOBE else None,
        "kvart": kvart.strip() or None,
        "dio_kvarta": (dio.strip() or None) if sep else None,
        "ljubimci": q.get("Ljubimci") if q.get("Ljubimci") in LJ else "Ne piše",
        "vrt_terasa": q.get("Vrt/terasa") in (True, "__YES__"),
        "bez_provizije": q.get("Bez provizije") in (True, "__YES__"),
        "objavljeno": q.get("date:Objavljeno:start"),
        "status": q.get("Status") if q.get("Status") in STATUS else "Aktivan",
        "napomena": q.get("Opis"),
        "grupa": q.get("Izvor"),
    }


def rows_from(path):
    pages = json.load(open(path))
    rows = [to_row(p["properties"]) for p in pages]
    ids = [r["id"] for r in rows]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        raise ValueError(f"isti ID vise puta: {sorted(dup)}")
    return rows


def lit(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def insert_sql(rows):
    vals = ",\n".join("(" + ", ".join(lit(r[c]) for c in COLS) + ")" for r in rows)
    return (f"insert into oglasi as g ({', '.join(COLS)})\nvalues\n{vals}\n"
            "on conflict (id) do update set zadnji_put_vidjen = now()\n"
            "returning (xmax = 0) as novi;")


if __name__ == "__main__":
    cmd, path = sys.argv[1], sys.argv[2]
    rows = rows_from(path)
    if cmd == "rows":
        json.dump(rows, sys.stdout, ensure_ascii=False, indent=0)
    elif cmd == "sql":
        print(insert_sql(rows))
    elif cmd == "ids":
        print(",".join("'" + r["id"] + "'" for r in rows))
