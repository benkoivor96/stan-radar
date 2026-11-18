"""StanRadar: upis poslanog u Supabase (nakon što Ivor javi "poslano").

  python3 poslano.py za_poslano.txt > poslano.sql
Format ulaza: "ivor: id,id,..." / "jan: id,..."  (stari fb-/mp- ID-jevi se pretvaraju u Supabase oblik)
"Zadnje slanje" se i dalje upisuje u Notion Klijenti.
"""
import sys
NOTION = {"ivor": "40ab132a69dc813cba33e8f9dbf47705", "jan": "40db132a69dc8194aecac8d59108f1ac"}

def sb_id(i):
    p, _, r = i.partition('-')
    return {'fb': 'fb_grupa', 'mp': 'fb_marketplace'}.get(p, p) + '-' + r

vals = []
for line in open(sys.argv[1]):
    if ':' not in line: continue
    who, ids = line.split(':', 1)
    for i in ids.split(','):
        i = i.strip()
        if i: vals.append(f"('{NOTION[who.strip()]}', '{sb_id(i)}')")
print("insert into poslano (klijent_id, oglas_id, poslano_at, kanal)\n"
      "select k.id, v.oglas_id, now(), 'mail' from (values\n  " + ",\n  ".join(vals) +
      "\n) v(notion_id, oglas_id) join klijenti k on k.notion_id = v.notion_id\n"
      "on conflict do nothing returning oglas_id;")
