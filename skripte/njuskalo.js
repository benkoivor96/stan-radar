// StanRadar · Njuškalo (pokreće se u Chromeu na kartici njuskalo.hr, javascript_tool).
// Novi oglasi = ID > maxId (najveći njuskalo ID u Supabaseu); lista se čita dok ima oglasa objavljenih od `since`.
// Pokretanje (u pozadini, jer traje > 45 s):  srNj({maxId: 52166839, since: '2026-11-05T11:00:00Z'}); 'pokrenuto'
// Praćenje:  ({status: srNjOut.status, log: srNjOut.log, n: srNjOut.raw.length})
// Rezultat:  srNjOut.raw.join('^') -> nj_raw.txt ;  srNjOut.det.join('^') -> nj_det.txt  (ulaz za build skriptu)
// Format:    raw "id~cijena~m2~Lokacija~MMDDHHMM(UTC)" ; det "id~sobe~ljubimci(D/N/P/'')~terasa(0/1)~bezProvizije(0/1)"
// VAŽNO: dok radi, ne otvarati drugu stranicu u istoj kartici (prekida posao).
window.srNj = async function(opt){
  const O = window.srNjOut = {status:'run', raw:[], det:[], log:[]};
  const sleep = ms => new Promise(r=>setTimeout(r,ms));
  const st = h => { const i=h.indexOf('__INITIAL_STATE__=')+18, e=h.indexOf('</script>',i); return JSON.parse(h.slice(i,e).trim().replace(/;\s*\(function[\s\S]*$/,'').replace(/;\s*$/,'')); };
  const base = '/iznajmljivanje-stanova/zagreb?price%5Bmax%5D=1200&sort=new';
  try {
    const nova = new Map();
    for (let p=1; p<=(opt.maxPages||30); p++){
      const s = st(await fetch(base+'&page='+p).then(r=>r.text()));
      const L = s.browseListingsStore.pageData.regularListings||[];
      let n=0;
      for (const r of L){ if (r.id>opt.maxId && !nova.has(r.id)){ nova.set(r.id,r); n++; } }
      const svjezi = L.filter(r=>new Date(r.createdAt)>=new Date(opt.since)).length;
      O.log.push('p'+p+': '+L.length+' oglasa, '+n+' novih, svježih '+svjezi);
      if (!L.length || svjezi===0) break;
      await sleep(opt.pause||1500);
    }
    for (const [id,r] of nova){
      const ab = Object.fromEntries((r.abstracts||[]).map(a=>[a.caption||a.value.split(':')[0], a.value]));
      const loc = ab['Lokacija'] || '';
      const m2 = ((r.abstracts||[]).map(a=>a.value).join(' ').match(/površina:\s*([\d.,]+)\s*m2/i)||[])[1];
      const price = (r.priceFormatted||'').replace(/[^\d]/g,'');
      const c = new Date(r.createdAt); const z=n=>String(n).padStart(2,'0');
      const ca = z(c.getUTCMonth()+1)+z(c.getUTCDate())+z(c.getUTCHours())+z(c.getUTCMinutes());
      O.raw.push([id, price, (m2||'').replace(',','.'), loc, ca].join('~'));
      const h = await fetch(r.url).then(x=>x.text());
      const i=h.indexOf('__INITIAL_STATE__=')+18, raw=h.slice(i, h.indexOf('</script>',i));
      const sobe = (raw.match(/"label":"Broj soba","value":"([^"]+)"/)||[])[1]||'';
      const txt = ((raw.match(/"detailDescriptionBox":\{"text":"((?:[^"\\]|\\.)*)"/)||[])[1]||'').toLowerCase() + ' ' + (r.title||'').toLowerCase();
      let lj='';
      if (/bez (kućnih )?ljubimac|ljubimci (nisu|ni)|nisu dozvoljeni ljubimci|ne primamo ljubim|no pets/.test(txt)) lj='N';
      else if (/ljubim\w* (su )?(dozvoljen|dobrodošl|ok)|pet friendly|ljubimci da/.test(txt)) lj='D';
      else if (/ljubim\w*[^.]{0,30}po dogovoru|po dogovoru[^.]{0,30}ljubim/.test(txt)) lj='P';
      const hb = raw.indexOf('highlightedDetailsBox');
      const te = /teras|vrt\b|vrtom|okućnic/.test(txt + ' ' + raw.slice(hb, hb+1500).toLowerCase()) ? 1 : 0;
      const bp = /bez provizij|bez agencijsk|nema provizij|ne naplaćuje se provizij/.test(txt) ? 1 : 0;
      O.det.push([id, sobe, lj, te, bp].join('~'));
      await sleep(opt.pause||1500);
    }
    O.status='done';
  } catch(e){ O.status='error: '+e.message; }
  return O;
};
