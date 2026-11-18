import json
from collections import Counter
TODAY="2026-11-05"
def sobe(s):
    if not s: return None
    s=s.lower()
    if s.startswith("garson"): return "Garsonijera"
    n=s.split("-")[0].split(",")[0].strip()
    return {"1":"1-sobni","2":"2-sobni"}.get(n,"3-sobni+") if n.isdigit() else None
def utc(t): return f"2026-{t[:2]}-{t[2:4]}T{t[4:6]}:{t[6:8]}:00Z"
def sus(p,m):
    if p is None or p<=1: return "Cijena nije navedena"
    if m and (p/m<6 or m<20 or m>=300): return "Sumnjivo: cijena/m² neobična (možda soba, cijena po osobi ili greška u oglasu)"
def num(x):
    if not x: return None
    v=float(x); return int(v) if v==int(v) else v
def naslov(sb,sub,m): return f"{(sb or 'Stan').rstrip('+')}, {sub}" + (f", {round(m)} m²" if m else "")
def page(iz,idn,link,p,m,sb,kv,sub,obj,lj=None,te=0,bp=0,note=None):
    pr={"Naslov":naslov(sb,sub,m),"Izvor":iz,"ID oglasa":idn,"Link":link,"Kvart":kv,"Status":"Aktivan",
        "date:Objavljeno:start":obj,"date:Objavljeno:is_datetime":1,"date:Zadnji put viđeno:start":TODAY,"Ljubimci":lj or "Ne piše"}
    if p and p>1: pr["Cijena (€)"]=p
    if m: pr["m²"]=m
    if sb: pr["Sobe"]=sb
    if te: pr["Vrt/terasa"]="__YES__"
    if bp: pr["Bez provizije"]="__YES__"
    n=sus(p,m)
    if note: n=f"{n}. {note}" if n and note not in (n or "") else (n or note)
    if n: pr["Opis"]=n
    return {"properties":pr}
LJ={"D":"Da","N":"Ne","P":"Po dogovoru","":None,"da":"Da","ne":"Ne"}
pages=[]
det={r.split("~")[0]:r.split("~") for r in open("nj_det.txt").read().strip().split("^")}
for r in open("nj_raw.txt").read().strip().split("^"):
    i,p,m,loc,ca=r.split("~"); d=det[i]
    p=num(p); m=num(m)
    parts=[x.strip() for x in loc.split(",")]
    kv=parts[0] if len(parts)<2 or parts[1].lower()==parts[0].lower() else f"{parts[0]}, {parts[1]}"
    pages.append(page("Njuškalo",f"njuskalo-{i}",f"https://www.njuskalo.hr/nekretnine/stan-oglas-{i}",p,m,sobe(d[1]),kv,parts[-1],utc(ca),LJ[d[2]],int(d[3]),int(d[4])))
for r in open("og.txt").read().strip().split("^"):
    i,p,m,ro,loc,t,lj,te,bp=r.split("~")
    p=num(p); m=num(m)
    parts=[x for x in loc.split("/") if x][1:]
    if len(parts)==2 and parts[1].lower()==parts[0].lower(): parts=parts[:1]
    kv=", ".join(parts); sub=parts[-1]
    dd,mm,rest=t.split(".",2); yy,hm=rest.split(" ")
    obj=f"{yy}-{mm}-{dd}T{hm}+01:00"
    pages.append(page("Oglasnik",f"oglasnik-{i}",f"https://www.oglasnik.hr/stanovi-najam/stan-oglas-{i}",p,m,sobe(ro),kv,sub,obj,LJ.get(lj),int(te),int(bp)))
ex=set(open("existing_ix.txt").read().strip().split(","))
fl={a:int(b) for a,b in (x.split(":") for x in open("ix_flags.txt").read().strip().split(","))}
ROOM={0:"Garsonijera",1:"1-sobni",2:"2-sobni"}
for r in open("ix.txt").read().strip().split("^"):
    c,p,m,ro,city,st,t,rpt=r.split("~")
    if c in ex: continue
    p=num(p); m=num(m)
    sb=ROOM.get(int(ro),"3-sobni+") if ro!="" else None
    kv=city if st.lower()==city.lower() else f"{city}, {st}"
    f=fl.get(c,0)
    note=None if rpt in ("1","") else "Možda dnevni najam (Index: vrsta cijene)"
    pages.append(page("Index",f"index-{c}",f"https://www.index.hr/oglasi/nekretnine/najam-stanova/oglas/stan/{c}",p,m,sb,kv,st,utc(t),"Da" if f&2 else None,1 if f&4 else 0,1 if f&1 else 0,note))
for fn,iz in (("fb1.tsv","FB Stanovi Zagreb - NAJAM"),("fb2.tsv","FB ZAGREB - Iznajmljivanje Stanova")):
    for l in open(fn):
        if not l.strip(): continue
        pid,link,sb,kv,m2,cij,lj,te,bp,t,opis=[x.strip() for x in l.rstrip("\n").split("\t")]
        m=num(m2); c=num(cij)
        sub=kv.split(", ")[-1] if kv else "Zagreb"
        pr={"Naslov":naslov(sb or None,sub,m),"Izvor":iz,"ID oglasa":f"fb-{pid}","Link":link,"Kvart":kv or "Zagreb","Status":"Aktivan",
            "date:Objavljeno:start":f"2026-{t[:5]}T{t[6:]}:00+01:00","date:Objavljeno:is_datetime":1,"date:Zadnji put viđeno:start":TODAY,"Ljubimci":lj,"Opis":opis}
        if c: pr["Cijena (€)"]=c
        if m: pr["m²"]=m
        if sb: pr["Sobe"]=sb
        if te=="1": pr["Vrt/terasa"]="__YES__"
        if bp=="1": pr["Bez provizije"]="__YES__"
        pages.append({"properties":pr})
ids=[p["properties"]["ID oglasa"] for p in pages]
print(Counter(p["properties"]["Izvor"] for p in pages), len(pages), len(set(ids)))
for p in pages:
    o=p["properties"].get("Opis","")
    if o.startswith(("Sumnjivo","Cijena nije")) and not p["properties"]["Izvor"].startswith("FB"): print(p["properties"]["ID oglasa"],p["properties"].get("Cijena (€)"),p["properties"].get("m²"),o[:30])
json.dump(pages,open("all.json","w"),ensure_ascii=False)
for k in range(0,len(pages),50):
    json.dump(pages[k:k+50],open(f"b{k//50}.json","w"),ensure_ascii=False,separators=(",",":"))
