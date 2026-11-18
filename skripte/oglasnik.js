// StanRadar · Oglasnik (pokreće se u Chromeu na kartici oglasnik.hr/stanovi-najam, javascript_tool).
// Novi oglasi = ID > maxId (najveći oglasnik ID u Supabaseu), Grad Zagreb, do 1200 €. Kratko traje (await je u redu).
// Pokretanje:  await srOg({maxId: 7189724}); ({status: srOgOut.status, log: srOgOut.log, n: srOgOut.og.length})
// Rezultat:   srOgOut.og.join('^') -> og.txt (ulaz za build skriptu)
// Format:     "id~cijena~m2~sobe~/Grad Zagreb/kvart/dio~dd.mm.yyyy hh:mm:ss~ljubimci(da/ne/'')~terasa(0/1)~bezProvizije(0/1)"
window.srOg = async function(opt){
  const O = window.srOgOut = {status:'run', og:[], log:[]};
  const sleep = ms => new Promise(r=>setTimeout(r,ms));
  const parse = t => [...t.matchAll(/self\.__next_f\.push\(\[1,"([\s\S]*?)"\]\)<\/script>/g)].map(m => { try { return JSON.parse('"' + m[1] + '"'); } catch(e){ return ''; } }).join('');
  try {
    const seen = new Set();
    for (let p=1; p<=(opt.maxPages||10); p++){
      const f = parse(await fetch('/stanovi-najam?page='+p).then(r=>r.text()));
      const starts = [...f.matchAll(/\{"id":(\d+),"title":"/g)];
      let novih=0, vecih=0;
      starts.forEach((s,k)=>{
        const id = +s[1]; if (id > opt.maxId) vecih++;
        if (id <= opt.maxId || seen.has(id)) return;
        const ad = f.slice(s.index, k+1<starts.length ? starts[k+1].index : s.index+15000);
        const pub = (ad.match(/"publish":"([^"]+)"/)||[])[1]; if (!pub) return;
        const loc = [...(((ad.match(/"location":\[([\s\S]*?)\]/)||[])[1])||'').matchAll(/"name":"([^"]+)"/g)].map(m=>m[1]);
        if (!loc.includes('Grad Zagreb')) return;
        const cijena = +((ad.match(/"price":\{[^}]*"value":(\d+)/)||[])[1]||0);
        if (cijena > 1200) return;
        const par = {};
        for (const m of ad.matchAll(/"value":"([^"]{0,40})","formattedText":"[^"]*","slug":"(re_[a-z_]+)"/g)) par[m[2]] = m[1];
        const opis = (((ad.match(/"description":"([\s\S]{0,4000}?)","category"/)||[])[1])||'').toLowerCase() + ' ' + (((ad.match(/"title":"([^"]*)"/)||[])[1])||'').toLowerCase();
        const iza = loc.slice(loc.indexOf('Grad Zagreb'));
        const te = (+par.re_terrace_number>0 || /teras|vrt\b|vrtom/.test(opis)) ? 1 : 0;
        const bp = /bez provizij|nema provizij|bez agencij/.test(opis) ? 1 : 0;
        seen.add(id); novih++;
        O.og.push([id, cijena||'', par.re_total_area||'', par.re_flat_room_number||'', '/'+iza.join('/'), pub, par.re_pets_allowed||'', te, bp].join('~'));
      });
      O.log.push('p'+p+': '+starts.length+' oglasa, ID>max '+vecih+', upisivih '+novih);
      if (!starts.length || vecih===0) break;
      await sleep(opt.pause||1500);
    }
    O.status='done';
  } catch(e){ O.status='error: '+e.message; }
  return O;
};
