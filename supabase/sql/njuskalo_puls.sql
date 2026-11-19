CREATE OR REPLACE FUNCTION public.njuskalo_puls(p_verzija text DEFAULT NULL::text, p_nalog bigint DEFAULT NULL::bigint, p_stranica integer DEFAULT NULL::integer, p_stranica_do integer DEFAULT NULL::integer, p_kraj text DEFAULT NULL::text, p_stanje text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- (19.11.2026., Ivor) Radnik za Njuškalo = ekstenzija „StanRadar Njuškalo” u Ivorovom Chromeu. Zove ovo svake minute i nakon svake stranice punog prolaza.
-- 1) bilježi puls (alarm kad radnika nema 30 min), 2) bilježi napredak naloga (p_stranica / p_stranica_do) i kraj (p_kraj: 'gotovo',
--    'captcha na str N', 'greska: …'), 3) vraća nalog koji radnik treba raditi i od koje stranice (nastavak nakon prekida ili ponavljanje).
-- p_stanje = 'captcha' → zapis u scrape_runs (alarm + brojanje captchi). Zasad otvoreno (anon), zaštita kasnije (opaska u Notionu).
declare
  n record;
begin
  insert into radnik_puls (izvor, zadnji_puls, verzija, stanje)
  values ('njuskalo', now(), left(p_verzija, 40), left(p_stanje, 200))
  on conflict (izvor) do update set zadnji_puls = now(),
    verzija = coalesce(excluded.verzija, radnik_puls.verzija),
    stanje = coalesce(excluded.stanje, radnik_puls.stanje);

  if p_stanje like 'captcha%' then
    insert into scrape_runs (izvor, primljeno, napomena, kraj, uspjeh, greska)
    values ('njuskalo', 0, 'preglednik captcha', now(), false, 'captcha');
  end if;

  if p_nalog is not null then
    update puni_prolaz_nalozi set
      poslano_do = coalesce(p_stranica, poslano_do),
      stranica_do = coalesce(p_stranica_do, stranica_do),
      zadnje_slanje = now(),
      radnik = coalesce(left(p_kraj, 200), radnik)
     where id = p_nalog and izvor = 'njuskalo' and status = 'dohvat' and radnik is null;
  end if;

  select * into n from puni_prolaz_nalozi
   where izvor = 'njuskalo' and status in ('ceka', 'dohvat') order by id limit 1;
  if not found then
    return jsonb_build_object('nalog', null);
  end if;
  if n.status = 'ceka' then
    update puni_prolaz_nalozi set status = 'dohvat', poceto = now() where id = n.id;
    return jsonb_build_object('nalog', n.id, 'od_stranice', 1);
  end if;
  if n.radnik is null then
    return jsonb_build_object('nalog', n.id, 'od_stranice', n.poslano_do + 1);
  end if;
  return jsonb_build_object('nalog', null);   -- radnik je javio kraj, baza (puni_prolaz_korak) radi provjeru
end;
$function$
