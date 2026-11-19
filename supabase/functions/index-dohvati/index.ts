// StanRadar · Index na serveru (17.11.2026., v3)
// 1) otvori stranicu pretrage → kolačići sesije, 2) čita stranice od..do API-ja (6 s pauze),
// 3) upisuje kroz ingest_oglasi('index', ...).
// Pravilo (Ivor 17.11. 19:56): Obnovljen (nije_novo) = Index kaže da je obnovljen (renewalTime postoji). Sve ostalo je Novo;
// koliko je oglas star vidi se iz datuma objave.
// Kad je u listi postedTime = renewalTime, postedTime nije prava objava (provjereno 17.11.) → objavljeno se ne upisuje.
// v4 (18.11., Ivor): bez granice cijene (maknut priceTo=1200) – svi oglasi iz Grada Zagreba.
// v5 (18.11.): izdvojen = Index isPromoted (izdvojeni oglasi na vrhu portala).
// v6 (18.11., Ivor): upisuje se i dnevni najam (rentPriceType 2), s napomenom da je cijena po danu – baza = Index.
// v7 (19.11., Ivor): cijena_jedinica = 'dan' za dnevni najam (posebno polje, ne ide u mjesečni budžet);
//   uz svaku stranicu sprema se što je portal javio (portal_ukupno = count, na_stranici) – za provjeru potpunog prolaza.
//   Prazna stranica se bilježi (na_stranici 0), ne prekida se tiho.
const SEARCH = "https://www.index.hr/oglasi/nekretnine/najam-stanova/pretraga?searchQuery=%7B%22category%22%3A%22flats-for-rent%22%2C%22module%22%3A%22real-estate%22%7D";
const API = (p: number) => `https://www.index.hr/oglasi/api/aditem?category=flats-for-rent&includeCountyIds=056b6c84-e6f1-433f-8bdc-9b8dbb86d6fb&module=real-estate&sortOption=4&useRelevancyScoreSort=false&itemPerPage=50&page=${p}`;
const UA = "Mozilla/5.0 (compatible; StanRadar/1.0)";
const SB = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function sobe(n: unknown): string | null {
  if (typeof n !== "number") return null;
  if (n <= 0) return "Garsonijera";
  if (n === 1) return "1-sobni";
  if (n === 2) return "2-sobni";
  return "3-sobni+";
}
function red(it: any) {
  const code = String(it.code);
  const m2 = typeof it.summary?.area === "number" ? it.summary.area : null;
  const s = sobe(it.summary?.numberOfRooms);
  let cijena: number | null = typeof it.price === "number" ? Math.round(it.price) : null;
  let napomena: string | null = null;
  if (cijena !== null && cijena <= 1) { napomena = "Cijena nije navedena (na Indexu 1 €)"; cijena = null; }
  else if (cijena !== null && m2 && (cijena / m2 < 6 || m2 < 20 || m2 >= 300)) {
    napomena = "Sumnjivo: cijena/m² neobična (možda soba, cijena po osobi ili greška u oglasu)";
  }
  if (it.rentPriceType === 2) napomena = "Dnevni najam: cijena je po danu";
  const dio = it.settlementName || null, kvart = it.cityName || null;
  const objavljeno = it.postedTime && it.postedTime !== it.renewalTime ? it.postedTime : null;
  return {
    izvorni_id: code,
    link: `https://www.index.hr/oglasi/nekretnine/najam-stanova/oglas/stan/${code}`,
    naslov: [s || "Stan", dio || kvart, m2 ? `${m2} m²` : null].filter(Boolean).join(", "),
    cijena, m2, sobe: s, kvart, dio_kvarta: dio,
    objavljeno,
    obnovljeno: it.renewalTime ?? it.postedTime ?? null,
    napomena, grupa: "Index",
    nije_novo: !!it.renewalTime,
    izdvojen: it.isPromoted === true,
    cijena_jedinica: it.rentPriceType === 2 ? "dan" : "mjesec",
  };
}
async function rpc(fn: string, body: unknown) {
  const r = await fetch(`${SB}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`${fn} ${r.status}: ${t.slice(0, 200)}`);
  return t ? JSON.parse(t) : null;
}
async function oznaciStranicu(run: number, ukupno: number | null, na: number) {
  await fetch(`${SB}/rest/v1/scrape_runs?id=eq.${run}`, {
    method: "PATCH",
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify({ portal_ukupno: ukupno, na_stranici: na }),
  });
}
async function zapisiPraznu(napomena: string, ukupno: number | null) {
  await fetch(`${SB}/rest/v1/scrape_runs`, {
    method: "POST",
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify({ izvor: "index", primljeno: 0, napomena, kraj: new Date().toISOString(), uspjeh: true, portal_ukupno: ukupno, na_stranici: 0 }),
  });
}
async function zapisiGresku(greska: string, napomena: string) {
  await fetch(`${SB}/rest/v1/scrape_runs`, {
    method: "POST",
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify({ izvor: "index", primljeno: 0, napomena, kraj: new Date().toISOString(), uspjeh: false, greska }),
  });
}

Deno.serve(async (req) => {
  let od = 1, stranice = 2;
  try {
    const b = await req.json();
    if (b?.od) od = Math.max(1, Math.floor(+b.od));
    if (b?.stranice) stranice = Math.min(Math.max(1, Math.floor(+b.stranice)), 10);
  } catch { /* bez tijela */ }
  const rezultati: unknown[] = [];
  try {
    const p = await fetch(SEARCH, { headers: { "User-Agent": UA } });
    await p.text();
    // @ts-ignore Deno
    const ck = (p.headers.getSetCookie?.() ?? []).map((c: string) => c.split(";")[0]).join("; ");
    if (!ck) throw new Error(`nema kolačića (stranica ${p.status})`);
    for (let n = od; n < od + stranice; n++) {
      if (n > od) await sleep(6000);
      const r = await fetch(API(n), { headers: { "User-Agent": UA, Accept: "application/json", Referer: SEARCH, Cookie: ck } });
      if (r.status !== 200) { await r.text(); await zapisiGresku(`http ${r.status}`, `edge str ${n}`); rezultati.push({ str: n, greska: r.status }); continue; }
      const j = await r.json();
      const lista: any[] = Array.isArray(j?.data) ? j.data : [];
      const ukupno = typeof j?.count === "number" ? j.count : null;
      if (!lista.length) { await zapisiPraznu(`edge str ${n}`, ukupno); rezultati.push({ str: n, kraj: true, ukupno }); break; }
      const rows = lista.filter((it) => it?.code).map(red);
      const res = await rpc("ingest_oglasi", { p_izvor: "index", p_rows: rows, p_napomena: `edge str ${n}` });
      if (res?.run) await oznaciStranicu(res.run, ukupno, lista.length);
      rezultati.push({ str: n, primljeno: lista.length, upisano: res });
    }
  } catch (e) {
    await zapisiGresku(String(e).slice(0, 300), "edge");
    rezultati.push({ greska: String(e) });
  }
  return new Response(JSON.stringify(rezultati), { headers: { "Content-Type": "application/json" } });
});
