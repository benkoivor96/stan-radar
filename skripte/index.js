// StanRadar · Index (pokreće se u Chromeu na kartici index.hr/oglasi, javascript_tool).
// Oglasi objavljeni od `since` (zadnji scrape), Grad Zagreb, do 1200 €. Oznake iz filtriranih upita.
// Pokretanje (u pozadini, 6 s pauze zbog limita):  srIx({since: '2026-11-05T12:00:00Z'}); 'pokrenuto'
// Praćenje:  ({status: srIxOut.status, log: srIxOut.log, n: srIxOut.ix.length})
// Rezultat:  srIxOut.ix.join('^') -> ix.txt ;  Object.entries(srIxOut.flags).map(([c,f])=>c+':'+f).join(',') -> ix_flags.txt
//            existing_ix.txt može biti prazan (Supabase upis sam preskače postojeće ID-jeve).
// Format:    ix "code~cijena~m2~sobe(0=garsonijera)~kvart~dio kvarta~MMDDHHMM(UTC)~rentPriceType" ; flags bit 1 bez provizije, 2 ljubimci, 4 terasa/vrt
// VAŽNO: prva stranica ima izdvojene (starije) oglase, zato se staje tek od 2. stranice bez svježih.
window.srIx = async function(opt){
  const O = window.srIxOut = {status:'run', ix:[], flags:{}, log:[]};
  const sleep = ms => new Promise(r=>setTimeout(r,ms));
  const API = '/oglasi/api/aditem?category=flats-for-rent&module=real-estate&sortOption=4&itemPerPage=50&priceTo=1200';
  const get = async (u) => { for (let k=0;k<4;k++){ const r = await fetch(u); if (r.status===429){ await sleep(15000); continue; } return r.json(); } throw new Error('429'); };
  const z = n=>String(n).padStart(2,'0');
  try {
    const since = new Date(opt.since); const codes = new Set(); let pages = 0;
    for (let p=1; p<=(opt.maxPages||20); p++){
      const j = await get(API+'&page='+p); pages = p;
      const L = j.data||[]; let svjezi=0;
      for (const a of L){
        const t = new Date(a.postedTime); if (t < since) continue; svjezi++;
        if (a.countyName!=='Grad Zagreb' || codes.has(a.code)) continue;
        codes.add(a.code);
        const ts = z(t.getUTCMonth()+1)+z(t.getUTCDate())+z(t.getUTCHours())+z(t.getUTCMinutes());
        const s = a.summary||{};
        O.ix.push([a.code, a.price??'', s.area??'', s.numberOfRooms??'', a.cityName||'', a.settlementName||'', ts, a.rentPriceType??''].join('~'));
      }
      O.log.push('p'+p+': '+L.length+', svježih '+svjezi+', Zagreb ukupno '+codes.size);
      if (!L.length || (p>1 && svjezi===0)) break;
      await sleep(opt.pause||6000);
    }
    const F = [['noCommission',1],['petsAllowed',2],['terrace',4],['garden',4]];
    for (const [f,bit] of F){
      for (let p=1; p<=pages; p++){
        await sleep(opt.pause||6000);
        const j = await get(API+'&'+f+'=true&page='+p);
        for (const a of (j.data||[])) if (codes.has(a.code)) O.flags[a.code] = (O.flags[a.code]||0) | bit;
        if (!(j.data||[]).length || (p>1 && new Date((j.data||[]).slice(-1)[0].postedTime) < since)) break;
      }
      O.log.push('filter '+f+' gotov');
    }
    O.status='done';
  } catch(e){ O.status='error: '+e.message; }
  return O;
};
