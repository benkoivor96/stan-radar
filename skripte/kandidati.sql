-- StanRadar: kandidati za mail iz Supabasea (zamjenjuje čitanje iz scrape datoteke / Notiona).
-- :od = od kada (npr. zadnje slanje), :do = najveći budžet klijenata; zamijeniti prije pokretanja.
-- Vraća jedan JSON niz kompaktnih redaka; posl = imena klijenata kojima je oglas već poslan.
select coalesce(jsonb_agg(jsonb_build_object(
  'id', g.id, 'c', g.cijena, 'm', g.m2, 's', g.sobe,
  'k', g.kvart || coalesce(', ' || g.dio_kvarta, ''),
  'lj', g.ljubimci, 't', g.vrt_terasa, 'b', g.bez_provizije,
  'ob', g.objavljeno, 'l', g.link,
  'posl', (select coalesce(jsonb_agg(k.ime), '[]') from poslano p join klijenti k on k.id = p.klijent_id where p.oglas_id = g.id)
) order by g.objavljeno desc), '[]') as kandidati
from oglasi g
where g.prvi_put_vidjen >= :od
  and g.status = 'Aktivan'
  and not g.nije_novo
  and g.cijena is not null and g.cijena <= :do
  and coalesce(g.napomena, '') not like 'Sumnjivo%';
