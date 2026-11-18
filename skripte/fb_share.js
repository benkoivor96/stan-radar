// StanRadar · FB link objave preko Share -> Copy link (pravilo: link SAMO ovako, nikad like/komentar/kontakt).
// Za svaku PONUDU iz srFb.posts: navigate na https://www.facebook.com/groups/<grupa>/posts/<id>/ pa jedan browser_batch:
//   1. js:  srShPrep()            -> 'FOC <id> | tekst objave'   (baci grešku ako Share nije u fokusu -> batch staje)
//   2. key: space                  (otvara Share izbornik; Return ponekad ne radi, promijenjeno 09.11.)
//   3. wait 2 s
//   4. js:  srShCopy()             -> 'CF'                         (baci grešku ako Copy link nije u fokusu)
//   5. key: Return                 (kopira link)
//   6. wait 1 s
//   7. js:  srTA()                 -> 'TA'                         (privremeni textarea u fokusu)
//   8. key: cmd+v
//   9. js:  srRead()               -> 'OK https://www.facebook.com/groups/<grupa>/permalink/<id>/'  (MISMATCH = ne upisivati)
// Helperi se nakon svake navigacije moraju ponovno učitati (ovaj blok). Testirano 06.11. 00:15 (najamzagreb).
// 09.11.: tekst duži od ~900 znakova čitati u dva dijela (cijena je često na kraju). Navigate na sljedeću objavu može biti ZADNJI korak batcha (nakon srRead), pa je jedna objava = jedan poziv.
// Ako fb_feed.js kaže da prozor nije ispred iako je, klik na običan tekst stranice (npr. broj članova grupe) vrati fokus.
// Iz teksta Radar ručno izvlači: sobe, kvart, m², cijenu, ljubimce, terasu, proviziju -> red u fbN.tsv:
//   id \t link \t sobe \t kvart \t m2 \t cijena \t ljubimci \t terasa(0/1) \t bezProvizije(0/1) \t MM-DD HH:MM \t kratki opis (bez imena i telefona)
window.srShPrep = () => {
  const d=[...document.querySelectorAll('[role=dialog]')].pop()||document;
  const el=[...d.querySelectorAll('[aria-label]')].find(e=>/^(Share|Send this to friends)/i.test(e.getAttribute('aria-label')) && e.getBoundingClientRect().width>0);
  window.srId=(location.pathname.match(/(?:posts|permalink)\/(\d+)/)||[])[1];
  if(!el) throw new Error('NEMA SHARE gumba');
  el.scrollIntoView({block:'center'}); el.focus();
  if(document.activeElement!==el) throw new Error('SHARE nije u fokusu');
  const t=(d.innerText||'').replace(/(Facebook\s*)+/g,' ').replace(/(\S͏\s*){3,}/g,' ').replace(/(\+?\d[\d\s\/-]{7,}\d)/g,'[tel]').replace(/\s+/g,' ');
  return 'FOC '+window.srId+' | '+t.slice(0,900);
};
window.srShCopy = () => {
  const e=[...document.querySelectorAll('[role=button],[role=menuitem],[role=link]')].filter(x=>x.innerText && x.innerText.trim()==='Copy link' && x.getBoundingClientRect().width>0).pop();
  if(!e) throw new Error('NEMA Copy link');
  e.focus(); if(document.activeElement!==e) throw new Error('Copy link nije u fokusu'); return 'CF';
};
window.srTA = () => { let ta=document.getElementById('sr-paste'); if(ta) ta.remove(); ta=document.createElement('textarea'); ta.id='sr-paste'; ta.style.cssText='position:fixed;top:5px;left:5px;width:300px;height:40px;z-index:2147483647'; document.body.appendChild(ta); ta.focus(); if(document.activeElement!==ta) throw new Error('textarea nije u fokusu'); return 'TA'; };
window.srRead = () => { const ta=document.getElementById('sr-paste'); const v=((ta&&ta.value)||'').trim().replace(/[?&].*$/,''); if(ta) ta.remove(); return (window.srId && v.includes(window.srId) ? 'OK ' : 'MISMATCH ')+v; };
