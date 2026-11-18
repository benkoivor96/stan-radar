import sys
CSS='''  .b.srcs{background:#fff;border:1px solid var(--line);color:var(--ink)}
  .b.nsrc{background:#EDE7FF;color:#4C2BB0}
  .alts{border-top:1px dashed var(--line);padding-top:8px}
  .alts summary{cursor:pointer;font-size:14px;font-weight:600;color:var(--accent);list-style:none;min-height:32px;display:flex;align-items:center;gap:6px}
  .alts summary::-webkit-details-marker{display:none}
  .alts summary::after{content:"▾";font-size:12px}
  .alts[open] summary::after{content:"▴"}
  .alts ul{list-style:none;margin:6px 0 0;padding:0;display:grid;gap:6px}
  .alts li{display:flex;justify-content:space-between;gap:10px;font-size:14px;flex-wrap:wrap}
  .alts li a{font-weight:600;text-decoration:none}
  .alts li span{color:var(--muted)}
'''
OLD_BADGES='''        ${s.nw ? '<span class="b new">Novo</span>' : ""}'''
NEW_BADGES='''        ${s.nw ? '<span class="b new">Novo</span>' : ""}
        ${s.nsrc && !s.nw ? '<span class="b nsrc">Novi izvor</span>' : ""}
        ${srcs(s).length > 1 ? srcs(s).map(x => `<span class="b srcs">${esc(x)}</span>`).join("") : ""}'''
OLD_NOTE='''      ${s.note ? `<p class="note">${esc(s.note)}</p>` : ""}'''
NEW_NOTE='''      ${s.note ? `<p class="note">${esc(s.note)}</p>` : ""}
      ${priceDiff(s) ? `<p class="note">${esc(priceDiff(s))}</p>` : ""}'''
OLD_FOOTEND='''        </a>
      </div>
    </article>`;'''
NEW_FOOTEND='''        </a>
      </div>
      ${(s.alt && s.alt.length) ? `<details class="alts"><summary>Ostali izvori (${s.alt.length})</summary><ul>${s.alt.map(a => `<li><a href="${esc(a.link)}" target="_blank" rel="noopener">${esc(a.src)} &rarr;</a><span>${a.c != null ? a.c + " € · " : ""}${esc(a.pub || "")}${a.nw ? " · novo" : ""}</span></li>`).join("")}</ul></details>` : ""}
    </article>`;'''
HELPERS='''
function srcs(s){ const out = [s.src || "Njuškalo"]; (s.alt || []).forEach(a => { if (!out.includes(a.src)) out.push(a.src); }); return out; }
function priceDiff(s){ const d = (s.alt || []).filter(a => a.c != null && s.c != null && a.c !== s.c); return d.length ? d.map(a => `Na ${a.src}: ${a.c} €`).join(" · ") + ` (${s.src || "Njuškalo"}: ${s.c} €)` : ""; }

function render(){'''
for f in sys.argv[1:]:
    s=open(f).read()
    if 'class="alts"' in s: print(f,'already'); continue
    s=s.replace("</style>",CSS+"</style>",1)
    for a,b in [(OLD_BADGES,NEW_BADGES),(OLD_NOTE,NEW_NOTE),(OLD_FOOTEND,NEW_FOOTEND),("\nfunction render(){",HELPERS)]:
        assert a in s,(f,a[:40]); s=s.replace(a,b,1)
    s=s.replace('state.f === "new" ? s.nw :','state.f === "new" ? (s.nw || s.nsrc) :')
    s=s.replace('$("#sNew").textContent = STANOVI.filter(s => s.nw).length;','$("#sNew").textContent = STANOVI.filter(s => s.nw).length;\nconst nSrc = STANOVI.filter(s => s.nsrc && !s.nw).length; if (nSrc) document.querySelector("#sNew").nextElementSibling.textContent = `novih od zadnjeg maila · ${nSrc} na novom portalu`;')
    open(f,'w').write(s); print(f,'ok')
