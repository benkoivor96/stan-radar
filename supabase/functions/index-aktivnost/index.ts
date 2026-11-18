// StanRadar · Index provjera aktivnosti (17.11.2026., v2)
// Kandidati: aktivni Index oglasi koji 26 h nisu viđeni na portalu. Za svaki: /oglasi/api/aditem/single-ad.
// Ugasen (negativno): 404 → razlog uklonjeno; 200 + status 3 („Ovaj oglas je prodan!”, provjereno 17.11.) → iznajmljeno.
// 200 + status 1 = aktivan (npr. cijena iznad 1200 € – u redu, ne označava se). Ostalo = nepoznato, ne označava se.
// Neaktivan nakon dvije uzastopne negativne provjere (u bazi, index_aktivnost_upisi).
// probno=true: ništa ne upisuje.
// v3 (18.11.): iz detalja se upisuje i prava prva objava (postedTime) kad je u bazi prazna (index_objava_upisi).
const SEARCH = "https://www.index.hr/oglasi/nekretnine/najam-stanova/pretraga?searchQuery=%7B%22category%22%3A%22flats-for-rent%22%2C%22module%22%3A%22real-estate%22%7D";
const UA = "Mozilla/5.0 (compatible; StanRadar/1.0)";
const SB = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
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

Deno.serve(async (req) => {
  let n = 10, probno = false;
  try { const b = await req.json(); if (b?.n) n = Math.min(Math.max(1, +b.n), 30); probno = b?.probno === true; } catch { /* */ }
  const out: unknown[] = [];
  try {
    const kand: { id: string; izvorni_id: string }[] = await rpc("index_aktivnost_kandidati", { p_n: n });
    if (!kand.length) return new Response(JSON.stringify({ kandidata: 0 }), { headers: { "Content-Type": "application/json" } });
    const p = await fetch(SEARCH, { headers: { "User-Agent": UA } });
    await p.text();
    // @ts-ignore Deno
    const ck = (p.headers.getSetCookie?.() ?? []).map((c: string) => c.split(";")[0]).join("; ");
    if (!ck) throw new Error(`nema kolačića (stranica ${p.status})`);
    for (let i = 0; i < kand.length; i++) {
      if (i > 0) await sleep(4000);
      const k = kand[i];
      let aktivan: boolean | null = null, http = 0, greska: string | null = null, st: unknown = null, razlog = "uklonjeno";
      try {
        const r = await fetch(`https://www.index.hr/oglasi/api/aditem/single-ad?code=${encodeURIComponent(k.izvorni_id)}&format=1`,
          { headers: { "User-Agent": UA, Accept: "application/json", Referer: SEARCH, Cookie: ck } });
        http = r.status;
        const t = await r.text();
        if (r.status === 404) { aktivan = false; razlog = "uklonjeno"; }
        else if (r.status === 200) {
          const j = JSON.parse(t);
          const d = Array.isArray(j?.data) ? j.data[0] : j?.data;
          st = d?.status ?? j?.redirectData?.status ?? null;
          if (!probno && d?.postedTime) await rpc("index_objava_upisi", { p_oglas_id: k.id, p_objavljeno: d.postedTime });
          if (st === 1) aktivan = true;
          else if (st === 3) { aktivan = false; razlog = "iznajmljeno"; greska = "status 3"; }
          else greska = `status ${JSON.stringify(st)}`;
        } else greska = `http ${r.status}`;
      } catch (e) { greska = String(e).slice(0, 200); }
      const res = probno ? "probno" : await rpc("index_aktivnost_upisi", { p_oglas_id: k.id, p_aktivan: aktivan, p_http: http, p_greska: greska, p_razlog: razlog });
      out.push({ id: k.id, http, status: st, aktivan, razlog: aktivan === false ? razlog : null, greska, res });
    }
  } catch (e) { out.push({ greska: String(e) }); }
  return new Response(JSON.stringify(out), { headers: { "Content-Type": "application/json" } });
});
