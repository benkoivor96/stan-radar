"""StanRadar: dodaje odabrane stanove (picked.json iz pick_sb.py) na liste klijenata.
  python3 build_lista.py picked.json entries.json "06.11.2026. u 10:30"
"""
import json,re,sys,datetime as dt
P=json.load(open(sys.argv[1]))
SRC={"njuskalo":"Njuškalo","index":"Index","oglasnik":"Oglasnik","fb":"FB grupa","mp":"FB Marketplace","fb_grupa":"FB grupa","fb_marketplace":"FB Marketplace"}
def entry(r):
    pre=r["id"].split("-",1)[0]
    parts=[x.strip() for x in r["k"].split(",")]
    sub=parts[-1]; reg=parts[0]
    d=dt.datetime.fromisoformat(r["ob"].replace("Z","+00:00")).astimezone(dt.timezone(dt.timedelta(hours=1)))
    pet={"Da":"D","Po dogovoru":"P"}.get(r["lj"],"?")
    m=r["mr"]
    return dict(id=r["id"],t=f'{(r["s"] or "Stan").rstrip("+")} · {sub}',r=reg,c=r["c"],m=m,pet=pet,ter=r["t"],bp=r["b"],
        pub=f"objavljeno {d.day}.{d.month}. u {d:%H:%M}",ts=d.strftime("%Y-%m-%dT%H:%M"),nw=1,link=r["l"],src=SRC[pre])
def js(e):
    out=[]
    for k,v in e.items():
        v="null" if v is None else (json.dumps(v,ensure_ascii=False) if isinstance(v,str) else v)
        out.append(f"{k}:{v}")
    return "  {"+", ".join(out)+"}"
E={}
for who,f in [("ivor","/home/claude/stanradar-lista/index.html"),("jan","/home/claude/stanradar-lista/jan/index.html"),("filip","/home/claude/stanradar-lista/filip/index.html"),("domagoj","/home/claude/stanradar-lista/domagoj/index.html")]:
    s=open(f).read()
    s=s.replace("nw:1}","nw:0}").replace("nw:1,","nw:0,")
    ents=[entry(r) for r in P[who]]; E[who]=ents
    s=s.replace("const STANOVI = [\n","const STANOVI = [\n"+",\n".join(js(e) for e in ents)+",\n",1)
    s=re.sub(r'updated: "[^"]*"','updated: "'+sys.argv[3]+'"',s,1)
    open(f,"w").write(s)
    print(who,"novih",len(ents),"ukupno",len(re.findall(r'nw:[01]',s)),"nw1",len(re.findall(r'nw:1',s)))
json.dump(E,open(sys.argv[2],"w"),ensure_ascii=False)
