CREATE OR REPLACE FUNCTION public.oglasnik_obradi()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  z record;
  r record;
  v_rows jsonb;
  v_res jsonb;
  v_out jsonb := '[]'::jsonb;
  v_prag bigint;
  v_run bigint;
  v_ukupno int;
  v_na int;
begin
  -- Pravila (Ivor 17.11.): 1) sve što vidiš, upiši. Broj oglasa se dodjeljuje pri izradi i ne mijenja se obnovom.
  -- Nepoznat oglas čiji je broj <= najvećem broju koji smo imali prije 1 dan = obnovljen stari (nije_novo, ne ide u mail).
  select coalesce(max(izvorni_id::bigint), 0) into v_prag
    from oglasi where izvor = 'oglasnik' and izvorni_id ~ '^\d+$' and prvi_put_vidjen < now() - interval '1 day';
  for z in select * from scrape_zahtjevi where izvor = 'oglasnik' and not obradjeno order by id loop
    select status_code, content, error_msg, timed_out into r from net._http_response where id = z.request_id;
    if not found then
      if z.napravljeno < now() - interval '10 minutes' then
        update scrape_zahtjevi set obradjeno = true, rezultat = jsonb_build_object('greska', 'odgovor nikad nije stigao') where id = z.id;
        insert into scrape_runs (izvor, primljeno, napomena, kraj, uspjeh, greska)
        values ('oglasnik', 0, 'cron str ' || z.stranica, now(), false, 'odgovor nikad nije stigao');
      end if;
      continue;
    end if;
    if r.status_code is distinct from 200 or r.content is null then
      update scrape_zahtjevi set obradjeno = true, rezultat = jsonb_build_object('greska', coalesce(r.error_msg, 'http ' || r.status_code)) where id = z.id;
      insert into scrape_runs (izvor, primljeno, napomena, kraj, uspjeh, greska)
      values ('oglasnik', 0, 'cron str ' || z.stranica, now(), false, coalesce(r.error_msg, 'http ' || r.status_code));
      continue;
    end if;
    -- (19.11.2026., Ivor 1A) što je portal javio: ukupno oglasa na listi i koliko ih je na ovoj stranici (prije filtra Zagreb)
    v_ukupno := (regexp_match(r.content, '\\"total\\":(\d+)'))[1]::int;
    v_na := (select count(*) from regexp_matches(r.content, '\\"sort_date\\":\d', 'g'));
    v_rows := oglasnik_parse(r.content);
    if jsonb_array_length(v_rows) = 0 then
      update scrape_zahtjevi set obradjeno = true, rezultat = jsonb_build_object('greska', 'parser nije nasao oglase') where id = z.id;
      -- stranica bez oglasa iz Zagreba: uspjeh ako portal na njoj ima oglase ili je stranica iza kraja liste
      -- (19.11.: prazna stranica iza kraja = kraj liste, ne greška; inače prazna/neispravna stranica)
      insert into scrape_runs (izvor, primljeno, napomena, kraj, uspjeh, greska, portal_ukupno, na_stranici)
      values ('oglasnik', 0, 'cron str ' || z.stranica, now(),
              v_na > 0 or z.stranica > ceil(v_ukupno / 100.0),
              case when v_na > 0 or z.stranica > ceil(v_ukupno / 100.0) then null else 'parser nije nasao oglase' end, v_ukupno, v_na);
      continue;
    end if;
    select coalesce(jsonb_agg(e || jsonb_build_object(
             'obnovljeno', coalesce(e->'obnovljeno', e->'objavljeno'),
             'nije_novo', (e->>'izvorni_id')::bigint <= v_prag)), '[]'::jsonb)
      into v_rows from jsonb_array_elements(v_rows) e;
    v_res := ingest_oglasi('oglasnik', v_rows, 'cron str ' || z.stranica);
    update scrape_runs set portal_ukupno = v_ukupno, na_stranici = v_na where id = (v_res->>'run')::bigint;
    update scrape_zahtjevi set obradjeno = true, rezultat = v_res where id = z.id;
    v_out := v_out || jsonb_build_array(v_res);
  end loop;
  delete from scrape_zahtjevi where obradjeno and napravljeno < now() - interval '7 days';
  return v_out;
end;
$function$
