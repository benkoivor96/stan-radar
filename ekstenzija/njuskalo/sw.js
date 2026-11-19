// StanRadar Njuškalo · radnik u Ivorovom Chromeu (19.11.2026.)
// Server ne može čitati Njuškalo (Radware: zahtjevi koji nisu iz preglednika idu na captchu), pa listu čita ovaj Chrome,
// u jednoj prikvačenoj kartici njuskalo.hr, istim putem kao kad je otvoriš sam (podaci iz __INITIAL_STATE__ stranice).
//  · svake minute: puls bazi (njuskalo_puls) → ako postoji nalog (raspored 03/15 h ili gumb „Puni prolaz” na webu), puni prolaz
//  · svakih 5 min: brzi krug = stranice 1–2 (najnovije), novi oglasi + detalji (sobe, ljubimci, terasa, provizija), polako
//  · captcha: odmah stane, javi bazi (alarm na webu), crveni „!” na ikoni; klik na ikonu otvori karticu da je riješiš ručno.
// Ništa se ne skriva ni ne zaobilazi. Ključ baze nije u kodu: čita se jednom s javne stranice StanRadara.

const VERZIJA = '1.0.0';
const SB = 'https://kmrohlnmqlobugixppxh.supabase.co';
const WEB = 'https://stan-radar.ivorbenko.workers.dev/';
const LISTA = 'https://www.njuskalo.hr/iznajmljivanje-stanova/zagreb?sort=new';
const PAUZA = 2000;            // ms između stranica liste
const PAUZA_DETALJ = 2500;     // ms između stranica oglasa
const DETALJA_PO_KRUGU = 5;
const DETALJA_DNEVNO = 150;

let radi = false;              // brzi krug i puni prolaz nikad istovremeno
const sleep = ms => new Promise(r => setTimeout(r, ms));

chrome.runtime.onInstalled.addListener(postavi);
chrome.runtime.onStartup.addListener(postavi);
function postavi() {
  chrome.alarms.create('puls', { periodInMinutes: 1, delayInMinutes: 0.1 });
  chrome.alarms.create('brzi', { periodInMinutes: 5, delayInMinutes: 0.5 });
}
chrome.alarms.onAlarm.addListener(a => {
  if (a.name === 'puls') puls();
  else if (a.name === 'brzi') brzi();
});
// klik na ikonu: pokaži karticu Njuškala (npr. da ručno riješiš captchu)
chrome.action.onClicked.addListener(async () => {
  const id = await kartica();
  await chrome.tabs.update(id, { active: true });
});

/* ---------- baza ---------- */
async function kljuc() {
  const s = await chrome.storage.local.get('kljuc');
  if (s.kljuc) return s.kljuc;
  const h = await (await fetch(WEB, { cache: 'no-store' })).text();
  const k = (h.match(/SB_KEY\s*=\s*"([^"]+)"/) || [])[1];
  if (!k) throw new Error('ne mogu pročitati ključ sa stranice StanRadara');
  await chrome.storage.local.set({ kljuc: k });
  return k;
}
async function rpc(fn, body) {
  const k = await kljuc();
  const r = await fetch(`${SB}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { apikey: k, Authorization: 'Bearer ' + k, 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {})
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`${fn} ${r.status}: ${t.slice(0, 200)}`);
  return t ? JSON.parse(t) : null;
}

/* ---------- kartica njuskalo.hr ---------- */
async function kartica() {
  const s = await chrome.storage.session.get('tabId');
  if (s.tabId) {
    try { const t = await chrome.tabs.get(s.tabId); if (t) return t.id; } catch (e) { /* zatvorena */ }
  }
  const t = await chrome.tabs.create({ url: LISTA, pinned: true, active: false });
  await chrome.storage.session.set({ tabId: t.id });
  for (let i = 0; i < 30; i++) {
    await sleep(1000);
    const x = await chrome.tabs.get(t.id);
    if (x.status === 'complete') break;
  }
  return t.id;
}
async function uKartici(tabId, func, args) {
  const t = await chrome.tabs.get(tabId);
  if (!/^https:\/\/(www\.)?njuskalo\.hr\//.test(t.url || '')) return { captcha: true };  // kartica je na captchi ili drugdje
  const [r] = await chrome.scripting.executeScript({ target: { tabId }, world: 'MAIN', func, args });
  return r && r.result;
}

/* ---------- funkcije koje se izvršavaju u kartici Njuškala (moraju biti samostalne) ---------- */
async function citajListu(p) {
  const res = await fetch('/iznajmljivanje-stanova/zagreb?sort=new&page=' + p, { credentials: 'include' });
  if (/perfdrive|validate/.test(res.url)) return { captcha: true };
  const h = await res.text();
  const i = h.indexOf('__INITIAL_STATE__=');
  if (i < 0) return /perfdrive|captcha/i.test(h) ? { captcha: true } : { greska: 'nema __INITIAL_STATE__ na str ' + p };
  const e = h.indexOf('</script>', i);
  const s = JSON.parse(h.slice(i + 18, e).trim().replace(/;\s*\(function[\s\S]*$/, '').replace(/;\s*$/, ''));
  const d = s.browseListingsStore && s.browseListingsStore.pageData;
  if (!d) return { greska: 'nema pageData na str ' + p };
  const sobeIz = t => {
    t = (t || '').toLowerCase();
    if (/garsonij|garsonjer|studio/.test(t)) return 'Garsonijera';
    if (/\b(jednosob|1[ -]?sob|1-soban|1s\b)/.test(t)) return '1-sobni';
    if (/\b(dvosob|2[ -]?sob|2s\b|dvoiposob|2[.,]5[ -]?sob)/.test(t)) return '2-sobni';
    if (/\b(trosob|troiposob|četverosob|cetverosob|petosob|[3-9][ -]?sob|[3-9]s\b)/.test(t)) return '3-sobni+';
    return null;
  };
  const rows = (d.regularListings || []).map(r => {
    const ab = r.abstracts || [];
    const loc = (ab.find(a => a.caption === 'Lokacija') || {}).value || '';
    const m2s = ((ab.map(a => a.value).join(' ').match(/površina:\s*([\d.,]+)\s*m2/i) || [])[1] || '').replace('.', '').replace(',', '.');
    const m = m2s ? parseFloat(m2s) : null;
    const c = parseInt((r.priceFormatted || '').replace(/[^\d]/g, ''), 10);
    const cc = isNaN(c) ? null : c;
    const k = loc.indexOf(',');
    const kv = (k < 0 ? loc : loc.slice(0, k)).trim() || null, dio = k < 0 ? null : (loc.slice(k + 1).trim() || null);
    const so = sobeIz(r.title);
    let nap = null;
    if (cc == null || cc <= 1) nap = 'Cijena nije navedena';
    else if (m && (cc / m < 6 || m < 20 || m >= 300)) nap = 'Sumnjivo: cijena/m² neobična (možda soba, cijena po osobi ili greška u oglasu)';
    return {
      izvorni_id: String(r.id), link: 'https://www.njuskalo.hr/nekretnine/stan-oglas-' + r.id,
      naslov: [so ? so.replace('+', '') : 'Stan', dio || kv || 'Zagreb', m ? Math.round(m) + ' m²' : null].filter(Boolean).join(', '),
      cijena: cc && cc > 1 ? cc : null, m2: m, sobe: so, kvart: kv, dio_kvarta: dio,
      obnovljeno: r.createdAt || null, napomena: nap, grupa: 'Njuškalo', izdvojen: r.isPromoted === true
    };
  });
  return { total: d.listingsCount, pages: d.totalPageCount, rows };
}

async function citajDetalj(id) {
  const res = await fetch('/nekretnine/stan-oglas-' + id, { credentials: 'include' });
  if (/perfdrive|validate/.test(res.url)) return { captcha: true };
  if (res.status === 404 || res.status === 410) return { izvorni_id: String(id), nema: true };
  const h = await res.text();
  const i = h.indexOf('__INITIAL_STATE__=');
  if (i < 0) return /perfdrive|captcha/i.test(h) ? { captcha: true } : { izvorni_id: String(id), nema: true };
  const raw = h.slice(i, h.indexOf('</script>', i));
  const sr = ((raw.match(/"label":"Broj soba","value":"([^"]+)"/) || [])[1] || '').toLowerCase();
  let sobe = null;
  if (/garsonij|garsonjer/.test(sr)) sobe = 'Garsonijera';
  else if (/^(1|jedno)/.test(sr)) sobe = '1-sobni';
  else if (/^(2|dvo)/.test(sr)) sobe = '2-sobni';
  else if (/^([3-9]|tro|četvero|cetvero|pet)/.test(sr)) sobe = '3-sobni+';
  const txt = ((raw.match(/"detailDescriptionBox":\{"text":"((?:[^"\\]|\\.)*)"/) || [])[1] || '').toLowerCase();
  let lj = null;
  if (/bez (kućnih )?ljubimac|ljubimci (nisu|ni)|nisu dozvoljeni ljubimci|ne primamo ljubim|no pets/.test(txt)) lj = 'Ne';
  else if (/ljubim\w* (su )?(dozvoljen|dobrodošl|ok)|pet friendly|ljubimci da/.test(txt)) lj = 'Da';
  else if (/ljubim\w*[^.]{0,30}po dogovoru|po dogovoru[^.]{0,30}ljubim/.test(txt)) lj = 'Po dogovoru';
  const hb = raw.indexOf('highlightedDetailsBox');
  const te = /teras|vrt\b|vrtom|okućnic/.test(txt + ' ' + (hb >= 0 ? raw.slice(hb, hb + 1500).toLowerCase() : ''));
  const bp = /bez provizij|bez agencijsk|nema provizij|ne naplaćuje se provizij/.test(txt) || /najmoprimac ne plaća agencijsku proviziju/i.test(raw);
  return { izvorni_id: String(id), sobe, ljubimci: lj, vrt_terasa: te, bez_provizije: bp };
}

/* ---------- stanje na ikoni ---------- */
async function znak(tekst, boja, naslov) {
  await chrome.action.setBadgeText({ text: tekst });
  if (boja) await chrome.action.setBadgeBackgroundColor({ color: boja });
  await chrome.action.setTitle({ title: 'StanRadar Njuškalo · ' + naslov });
}
async function captcha(gdje, nalog) {
  await znak('!', '#C81E1E', 'captcha (' + gdje + ') – klikni ikonu i riješi je ručno');
  await rpc('njuskalo_puls', { p_verzija: VERZIJA, p_stanje: 'captcha: ' + gdje, p_nalog: nalog || null, p_kraj: nalog ? 'captcha na ' + gdje : null });
}
const vrijeme = () => new Date().toLocaleTimeString('hr-HR', { hour: '2-digit', minute: '2-digit' });

/* ---------- puls i puni prolaz ---------- */
async function puls() {
  try {
    const r = await rpc('njuskalo_puls', { p_verzija: VERZIJA });
    if (r && r.nalog && !radi) await puniProlaz(r.nalog, r.od_stranice || 1);
  } catch (e) {
    await znak('ERR', '#B7791F', 'greška: ' + String(e.message || e).slice(0, 120));
  }
}

async function upisi(rows, p, total) {
  return rpc('njuskalo_upis_stranice', { p_rows: rows, p_napomena: 'preglednik str ' + p, p_portal_ukupno: total, p_na_stranici: rows.length });
}

async function puniProlaz(nalog, od) {
  radi = true;
  try {
    await znak('…', '#2447D6', 'puni prolaz od stranice ' + od);
    const tab = await kartica();
    let p = od, pages = null;
    for (;;) {
      const r = await uKartici(tab, citajListu, [p]);
      if (!r || r.captcha) { await captcha('str ' + p, nalog); return; }
      if (r.greska) { await rpc('njuskalo_puls', { p_verzija: VERZIJA, p_nalog: nalog, p_kraj: 'greska: ' + r.greska }); await znak('ERR', '#B7791F', r.greska); return; }
      pages = r.pages;
      if (r.rows.length) await upisi(r.rows, p, r.total);
      await rpc('njuskalo_puls', { p_verzija: VERZIJA, p_nalog: nalog, p_stranica: p, p_stranica_do: pages });
      await znak('…', '#2447D6', `puni prolaz: stranica ${p} / ${pages}`);
      if (!r.rows.length || p >= pages) break;
      p++;
      await sleep(PAUZA);
    }
    // oglasi objavljeni ili podignuti dok je prolaz trajao: još jednom stranice 1–2
    for (const q of [1, 2]) {
      await sleep(PAUZA);
      const r = await uKartici(tab, citajListu, [q]);
      if (!r || r.captcha) { await captcha('str ' + q, nalog); return; }
      if (r.rows && r.rows.length) await upisi(r.rows, q, r.total);
    }
    await rpc('njuskalo_puls', { p_verzija: VERZIJA, p_nalog: nalog, p_kraj: 'gotovo', p_stanje: 'ok ' + vrijeme() });
    await znak('', null, 'zadnji puni prolaz ' + vrijeme());
  } catch (e) {
    await znak('ERR', '#B7791F', 'greška: ' + String(e.message || e).slice(0, 120));
    try { await rpc('njuskalo_puls', { p_verzija: VERZIJA, p_nalog: nalog, p_kraj: 'greska: ' + String(e.message || e).slice(0, 150) }); } catch (x) { /* nema veze s bazom */ }
  } finally {
    radi = false;
  }
}

/* ---------- brzi krug (svakih 5 min) ---------- */
async function brzi() {
  if (radi) return;
  radi = true;
  try {
    const tab = await kartica();
    let total = null;
    for (const p of [1, 2]) {
      const r = await uKartici(tab, citajListu, [p]);
      if (!r || r.captcha) { await captcha('brzi krug str ' + p); return; }
      if (r.greska) throw new Error(r.greska);
      total = r.total;
      const res = r.rows.length ? await upisi(r.rows, p, total) : null;
      if (!res || !res.novih) break;     // na prvoj stranici nema novih → druga ne treba
      await sleep(PAUZA);
    }
    // detalji: novi oglasi prvi, stari polako (najviše DETALJA_DNEVNO dnevno)
    const danas = new Date().toISOString().slice(0, 10);
    const s = await chrome.storage.local.get('detalji');
    const brojac = s.detalji && s.detalji.dan === danas ? s.detalji.n : 0;
    const koliko = Math.min(DETALJA_PO_KRUGU, DETALJA_DNEVNO - brojac);
    if (koliko > 0) {
      const ids = await rpc('njuskalo_za_detalje', { p_n: koliko });
      const out = [];
      for (const id of ids || []) {
        await sleep(PAUZA_DETALJ);
        const d = await uKartici(tab, citajDetalj, [id]);
        if (!d || d.captcha) { if (out.length) await rpc('njuskalo_upis_detalja', { p_rows: out }); await captcha('detalj ' + id); return; }
        out.push(d);
      }
      if (out.length) await rpc('njuskalo_upis_detalja', { p_rows: out });
      await chrome.storage.local.set({ detalji: { dan: danas, n: brojac + out.length } });
    }
    await rpc('njuskalo_puls', { p_verzija: VERZIJA, p_stanje: 'ok ' + vrijeme() + (total ? ' · portal ' + total : '') });
    await znak('', null, 'zadnji krug ' + vrijeme() + (total ? ' · portal ' + total : ''));
  } catch (e) {
    await znak('ERR', '#B7791F', 'greška: ' + String(e.message || e).slice(0, 120));
    try { await rpc('njuskalo_puls', { p_verzija: VERZIJA, p_stanje: 'greska: ' + String(e.message || e).slice(0, 150) }); } catch (x) { /* nema veze s bazom */ }
  } finally {
    radi = false;
  }
}
