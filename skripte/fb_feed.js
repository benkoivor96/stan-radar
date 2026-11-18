// StanRadar · FB grupa, skupljanje objava iz feeda (Chrome, kartica grupe s ?sorting_setting=CHRONOLOGICAL).
// UVJET: Chrome prozor mora biti ISPRED (document.hasFocus() === true), inače FB ne iscrta vrijeme objave i ID.
// Svaka objava: fokus + hover na vrijeme objave -> href otkrije ID objave, tooltip točno vrijeme. Ništa se ne klika.
// Pokretanje (ponavljati dok ne stane):  await srFbStep(8)
//   - staje sam na prvoj objavi starijoj od srFb.since ili na ID-u iz srFb.stop (zadnje poznate objave u bazi)
// Prije prvog koraka: srFb = {posts:[], seen:{}, since:'2026-11-05T13:00:00+01:00', stop:['29011971475170296']}
// Rezultat: srFb.posts = [{id, t:'MM-DD HH:MM', text}] -> Radar razvrsta (ponuda / traži / ostalo) i za ponude radi fb_share.js.
// Telefoni se u tekstu mijenjaju u [tel]; imena se ne spremaju u bazu.
window.srFb = window.srFb || {posts:[], seen:{}};
window.srFbIsTs = a => { const r=a.getBoundingClientRect(); const h=a.getAttribute('href')||''; return r.width>3 && r.width<200 && r.height>5 && !a.querySelector('img,image') && (/^\?__cft__/.test(h) || ((a.innerText||'').includes('͏') && /\/posts\/|permalink/.test(h))); };
window.srFbParseTip = tip => { const m=tip.match(/(\w+)\s(\d+),\s(\d{4})\sat\s(\d+):(\d+)\s*(AM|PM)/); if(!m) return null; const mo={January:1,February:2,March:3,April:4,May:5,June:6,July:7,August:8,September:9,October:10,November:11,December:12}[m[1]]; let h=+m[4]%12; if(m[6]==='PM') h+=12; const p=n=>String(n).padStart(2,'0'); return {t:p(mo)+'-'+p(m[2])+' '+p(h)+':'+m[5], iso:m[3]+'-'+p(mo)+'-'+p(m[2])+'T'+p(h)+':'+m[5]+':00+01:00'}; };
window.srFbStep = async function(n){
  const S = window.srFb; const sleep=ms=>new Promise(r=>setTimeout(r,ms)); const out=[];
  if (!document.hasFocus()) return ['STOP: Chrome prozor nije ispred'];
  for (let i=0;i<(n||8);i++){
    let a=null;
    for (let k=0;k<6 && !a;k++){
      a = [...document.querySelectorAll('[role=feed] a')].find(x=>srFbIsTs(x) && !x.dataset.srDone);
      if(!a){ window.scrollBy(0,1200); await sleep(2500); }
    }
    if(!a){ out.push('KRAJ feeda'); break; }
    a.dataset.srDone='1';
    a.scrollIntoView({block:'center'}); await sleep(500);
    const r=a.getBoundingClientRect(); const o={bubbles:true,clientX:r.x+4,clientY:r.y+4};
    a.focus(); a.dispatchEvent(new PointerEvent('pointerover',o)); a.dispatchEvent(new MouseEvent('mouseover',o)); a.dispatchEvent(new MouseEvent('mousemove',o));
    await sleep(1400);
    const id=((a.getAttribute('href')||'').match(/\/(?:posts|permalink)\/(\d+)/)||[])[1];
    // tooltip najbliži linku (stari tooltipi znaju ostati u DOM-u)
    const tips=[...document.querySelectorAll('[role=tooltip]')].filter(t=>t.innerText).map(t=>{const q=t.getBoundingClientRect(); return {txt:t.innerText, d:Math.abs(q.y-r.y)+Math.abs(q.x-r.x)};}).sort((x,y)=>x.d-y.d);
    const tp = srFbParseTip((tips[0]||{}).txt||'');
    a.dispatchEvent(new MouseEvent('mouseout',o)); a.blur();
    if(!id){ out.push('BEZ ID'); continue; }
    if(S.seen[id]) continue;
    if((S.stop||[]).includes(id)){ out.push('STOP poznati ID '+id); S.done=true; break; }
    if(S.since && tp && new Date(tp.iso) < new Date(S.since)){ out.push('STOP vrijeme '+tp.t); S.done=true; break; }
    let art=a; while(art && art.parentElement && art.parentElement.getAttribute('role')!=='feed') art=art.parentElement;
    const text=((art&&art.innerText)||'').replace(/(Facebook\s*)+/g,' ').replace(/(\S͏\s*){3,}/g,' ').replace(/(\+?\d[\d\s\/-]{7,}\d)/g,'[tel]').replace(/\s+/g,' ').trim().slice(0,700);
    S.seen[id]=1; S.posts.push({id, t: tp?tp.t:'?', text});
    out.push('OK '+id+' '+(tp?tp.t:'?')+' | '+text.slice(0,110));
  }
  return out;
};
