import json,sys
sys.path.insert(0,"/home/claude/gen")
idx={}
def load(entries):
    idx.clear(); idx.update({e["id"]:e for w in entries for e in entries[w]})
B=lambda bg,fg,t:f'<span style="background:{bg};color:{fg};padding:2px 7px;border-radius:5px;font-weight:bold;">{t}</span>'
def card(i,pets,last=False):
    e=idx[i]
    bs=[]
    if e["ter"]: bs.append(B("#E6ECFF","#1A34A3","Terasa / vrt"))
    if pets: bs.append(B("#E3F4EA","#1E6B3E","Ljubimci OK") if e["pet"]=="D" else (B("#E3F4EA","#1E6B3E","Ljubimci po dogovoru") if e["pet"]=="P" else B("#FFF4D6","#7A5200","Ljubimci: provjeri")))
    if e["bp"]: bs.append(B("#EEF1F4","#3D4A5C","Bez provizije"))
    badges=f'<p style="margin:6px 0 10px;font-size:13px;line-height:1.6;">{" ".join(bs)}</p>' if bs else '<p style="margin:6px 0 10px;font-size:13px;"></p>'
    title=e["t"]+(f', {round(e["m"])} m²' if e["m"] else "")
    return f'''<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #DDE3EA;border-radius:12px;margin:0 0 {18 if last else 10}px;">
      <tr><td style="padding:14px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
          <td style="font-size:16px;font-weight:bold;">{title}</td>
          <td align="right" style="font-size:18px;font-weight:bold;white-space:nowrap;">{e["c"]} €</td>
        </tr></table>
        {badges}
        <a href="{e["link"]}" style="font-size:14px;font-weight:bold;color:#2447D6;text-decoration:none;">Otvori oglas &rarr;</a> <span style="font-size:12px;color:#5A6677;">&nbsp;{e["src"]}</span>
      </td></tr>
    </table>'''
def btn(url,label): return f'<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td bgcolor="#2447D6" style="background-color:#2447D6;border-radius:10px;"><a href="{url}" target="_blank" style="background-color:#2447D6;border:1px solid #2447D6;border-radius:10px;color:#FFFFFF;display:inline-block;font-family:Arial,Helvetica,sans-serif;font-size:16px;font-weight:bold;line-height:20px;padding:14px 22px;text-decoration:none;"><span style="color:#FFFFFF;">{label}</span></a></td></tr></table>'
def mail(title,h1,intro,picks,pets,more,url,total,foot,added=None):
    cards="\n    ".join(card(p,pets,k==len(picks)-1) for k,p in enumerate(picks))
    return f'''<!DOCTYPE html>
<html lang="hr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{title}</title></head>
<body style="margin:0;padding:0;background:#F4F6F8;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6F8;">
<tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;font-family:Arial,Helvetica,sans-serif;color:#0E1726;">
  <tr><td style="padding:0 4px 16px;font-size:20px;font-weight:bold;letter-spacing:-0.3px;color:#0E1726;"><span style="color:#2447D6;">&#9673;</span> StanRadar</td></tr>
  <tr><td style="background:#FFFFFF;border:1px solid #DDE3EA;border-radius:16px;padding:24px;">
    <p style="margin:0 0 6px;font-size:22px;font-weight:bold;line-height:1.25;">{h1}</p>
    <p style="margin:0 0 18px;font-size:15px;line-height:1.5;color:#4A5568;">{intro}</p>
    {cards}
    <p style="margin:0 0 14px;font-size:15px;color:#4A5568;">{more}</p>
    {added_block(added)}
    {btn(url,f"Vidi sve svoje stanove ({total})")}
  </td></tr>
  <tr><td style="padding:16px 8px;font-size:12px;line-height:1.6;color:#5A6677;">{foot}<br>Ne želiš više primati? Odgovori STOP na ovaj mail.</td></tr>
</table></td></tr></table></body></html>'''

def pl(n): return "novi stan" if n%10==1 and n%100!=11 else ("nova stana" if n%10 in (2,3,4) and n%100 not in (12,13,14) else "novih stanova")
def added_block(added):
    # added: list of dicts {t, m, c, src_new, c_new, link_new}
    if not added: return ""
    li="".join(f'<li style="margin:0 0 6px;">{a["t"]}{", "+str(round(a["m"]))+" m²" if a.get("m") else ""}: sada i na <a href="{a["link_new"]}" style="color:#2447D6;font-weight:bold;text-decoration:none;">{a["src_new"]}</a>{" ("+str(a["c_new"])+" €)" if a.get("c_new") is not None and a.get("c_new")!=a.get("c") else ""}</li>' for a in added)
    return f'<p style="margin:0 0 6px;font-size:15px;font-weight:bold;">Već poslani stanovi, sada i na drugom portalu ({len(added)})</p><ul style="margin:0 0 16px;padding-left:18px;font-size:14px;color:#4A5568;line-height:1.5;">{li}</ul>'
def subject(n_new,n_added):
    s=f"{n_new} {pl(n_new)} za tebe"
    if n_added: s+=f" · {n_added} {'dodan' if n_added%10==1 and n_added%100!=11 else 'dodana'} na drugi portal"
    return s+" · StanRadar"
