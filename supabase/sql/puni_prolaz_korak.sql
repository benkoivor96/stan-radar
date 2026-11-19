CREATE OR REPLACE FUNCTION public.puni_prolaz_korak()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- (19.11.2026., Ivor) Vodi naloge punog prolaza (puni_prolaz_nalozi), pg_cron svake minute. Isti put za raspored (03 i 15 h) i gumb na webu.
-- 1) dohvat svih stranica liste portala (Index: index-dohvati po 10 stranica, jedna serija za drugom; Oglasnik: lista Grad Zagreb,
--    stranice obrađuje oglasnik_obradi kao i inače; Njuškalo: čita ga radnik = ekstenzija u Chromeu, koja nalog preuzima kroz
--    njuskalo_puls i javi kraj — baza ovdje samo čeka), 2) provjera potpunosti (puni_prolaz_provjera),
-- 3) gašenje (razlog nepoznato), nikad ako prolaz nije potpun ili ako bi se ugasilo više od 5 % aktivnih:
--    a) viđeno TOČNO = broj s portala (ništa nije preskočeno) → odmah se gase aktivni koje ovaj prolaz nije vidio, baza = portal
--       (Ivor 19.11.: „ne možemo nakon prolaza imat 1142 a portal 1135”);
--    b) inače aktivan oglas koji NI OVAJ NI PRETHODNI potpuni prolaz nije vidio (prethodni u zadnjih 36 h),
--    Prolaz koji nije potpun ponavlja stranice koje fale (Index od prve koja fali, Oglasnik sve) najviše 2 puta
--    (npr. 19.11. Supabase je jednoj seriji vratio 400 „Project not specified”).
-- 4) rezultat: portal / baza / viđeno / novi / obnovljeni / promjene / ugašeni.
declare
  n record;
  v_out jsonb := '[]'::jsonb;
  v_po int; v_max int; v_uk int; v_do int; v_k int; v_req bigint; v_auth text; p int;
  v_reqs bigint[];
  v_st jsonb; v_od timestamptz; v_prev timestamptz; v_kand int; v_ug int; v_nap text; r record; v_fali int;
begin
  for n in select * from puni_prolaz_nalozi where status in ('ceka', 'dohvat') order by id loop
    v_po := case n.izvor when 'index' then 50 else 100 end;
    v_max := case n.izvor when 'index' then 60 else 20 end;

    -- Njuškalo: nalog preuzima radnik (njuskalo_puls); ako ga nitko ne preuzme 30 min → greška, ništa se ne gasi
    if n.izvor = 'njuskalo' and n.status = 'ceka' then
      if n.zatrazeno < now() - interval '30 minutes' then
        update puni_prolaz_nalozi set status = 'greska', zavrseno = now(),
          rezultat = jsonb_build_object('potpun', false, 'razlog', 'radnik nije preuzeo nalog u 30 min (Chrome s ekstenzijom nije otvoren)')
         where id = n.id;
      end if;
      continue;
    end if;

    if n.status = 'ceka' then
      continue when exists (select 1 from puni_prolaz_nalozi x where x.izvor = n.izvor and x.status = 'dohvat');
      select portal_ukupno into v_uk from scrape_runs
       where izvor = n.izvor and portal_ukupno is not null order by pocetak desc limit 1;
      v_do := least(v_max, ceil(coalesce(v_uk, v_max * v_po)::numeric / v_po)::int + 1);  -- +1 stranica zalihe
      update puni_prolaz_nalozi set status = 'dohvat', poceto = now(), stranica_do = v_do where id = n.id;
      select * into n from puni_prolaz_nalozi where id = n.id;
    end if;

    if n.poceto < now() - interval '45 minutes' then
      update puni_prolaz_nalozi set status = 'greska', zavrseno = now(),
        rezultat = jsonb_build_object('potpun', false, 'razlog', 'prolaz traje dulje od 45 min') where id = n.id;
      continue;
    end if;

    -- 1) DOHVAT
    if n.izvor = 'njuskalo' then
      continue when n.radnik is null;   -- radnik još čita
      if n.radnik <> 'gotovo' then        -- captcha ili greška kod radnika: prolaz nije potpun, ništa se ne gasi
        update puni_prolaz_nalozi set status = 'greska', zavrseno = now(),
          rezultat = jsonb_build_object('potpun', false, 'razlog', 'radnik: ' || n.radnik) where id = n.id;
        continue;
      end if;
    elsif n.izvor = 'oglasnik' then
      if n.poslano_do < n.stranica_do then
        v_reqs := '{}';
        for p in 1..n.stranica_do loop
          select net.http_get(
            url := 'https://www.oglasnik.hr/stanovi-najam?f%5B4%5D%5B7442%5D=true&page=' || p,
            headers := '{"User-Agent":"StanRadar/1.0"}'::jsonb,
            timeout_milliseconds := 20000) into v_req;
          insert into scrape_zahtjevi (izvor, stranica, request_id) values ('oglasnik', p, v_req);
          v_reqs := v_reqs || v_req;
        end loop;
        update puni_prolaz_nalozi set poslano_do = n.stranica_do, zahtjevi = v_reqs, zadnje_slanje = now() where id = n.id;
        continue;
      end if;
      -- čeka da oglasnik_obradi (svakih 5 min) obradi sve stranice ovog prolaza
      continue when exists (select 1 from scrape_zahtjevi where request_id = any(n.zahtjevi) and not obradjeno);
    else
      -- prethodna serija još radi (najviše 4 min)
      continue when cardinality(n.zahtjevi) > 0
        and not exists (select 1 from net._http_response where id = n.zahtjevi[cardinality(n.zahtjevi)])
        and n.zadnje_slanje > now() - interval '4 minutes';
      if n.poslano_do < n.stranica_do then
        -- ključ za poziv funkcije uzima se iz postojećeg zakazanog posla index-dohvati (ključ nije u kodu)
        select substring(command from 'Bearer ([A-Za-z0-9._-]+)') into v_auth from cron.job where jobname = 'index-dohvati';
        v_k := least(10, n.stranica_do - n.poslano_do);
        select net.http_post(
          url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
          headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_auth),
          body := jsonb_build_object('od', n.poslano_do + 1, 'stranice', v_k),
          timeout_milliseconds := 150000) into v_req;
        update puni_prolaz_nalozi set poslano_do = n.poslano_do + v_k, zahtjevi = zahtjevi || v_req, zadnje_slanje = now()
         where id = n.id;
        continue;
      end if;
    end if;

    -- 2) PROVJERA
    v_od := n.poceto - interval '1 minute';
    v_st := puni_prolaz_provjera(n.izvor, v_od, now());
    if not (v_st->>'potpun')::boolean and n.ponovljeno < 2 and (v_st->>'razlog') not like 'portal ima %' then
      v_fali := (regexp_match(v_st->>'razlog', 'dohvata: (\d+)'))[1]::int;
      update puni_prolaz_nalozi set ponovljeno = ponovljeno + 1, radnik = null,
        poslano_do = case when n.izvor in ('index', 'njuskalo') then coalesce(v_fali, 1) - 1 else 0 end
       where id = n.id;
      continue;
    end if;

    -- 3) GAŠENJE (dva uzastopna potpuna prolaza)
    v_ug := 0; v_nap := null;
    select (x.rezultat->>'od')::timestamptz into v_prev from puni_prolaz_nalozi x
     where x.izvor = n.izvor and x.status = 'gotovo' and (x.rezultat->>'potpun')::boolean and x.id < n.id
     order by x.id desc limit 1;
    if (v_st->>'potpun')::boolean and (v_st->>'vidjeno')::int = (v_st->>'portal_ukupno')::int then
      v_prev := v_od;  -- a) brojke se točno poklapaju: gasi se sve što ovaj prolaz nije vidio
    end if;
    if not (v_st->>'potpun')::boolean then
      v_nap := 'prolaz nije potpun – ništa se ne gasi';
    elsif v_prev is null or v_prev < now() - interval '36 hours' then
      v_nap := 'nema prethodnog potpunog prolaza u 36 h – gasi se tek nakon sljedećeg';
    else
      select count(*) into v_kand from oglasi
       where izvor = n.izvor and status = 'Aktivan' and zadnji_put_vidjen < v_prev;
      if v_kand > (v_st->>'aktivnih')::int * 0.05 then
        v_nap := v_kand || ' kandidata je više od 5 % aktivnih – ništa se ne gasi';
      else
        for r in select id from oglasi
                  where izvor = n.izvor and status = 'Aktivan' and zadnji_put_vidjen < v_prev loop
          perform oznaci_neaktivan(r.id, 'nepoznato');
          v_ug := v_ug + 1;
        end loop;
      end if;
    end if;

    -- 4) REZULTAT
    v_st := v_st || jsonb_build_object(
      'ugaseno', v_ug, 'napomena', v_nap, 'prethodni_od', v_prev,
      'aktivnih_sada', (select count(*) from oglasi where izvor = n.izvor and status = 'Aktivan'),
      'novih', (select count(*) from oglas_dogadaji where tip = 'novi_oglas' and at >= v_od and oglas_id like n.izvor || '-%'),
      'obnovljenih', (select count(*) from oglas_dogadaji where tip = 'obnovljen' and at >= v_od and oglas_id like n.izvor || '-%'),
      'promjena_cijene', (select count(*) from oglas_dogadaji where tip = 'promjena_cijene' and at >= v_od and oglas_id like n.izvor || '-%'),
      'promjena_polja', (select count(*) from oglas_dogadaji where tip = 'promjena_polja' and at >= v_od and oglas_id like n.izvor || '-%'),
      'ponovo_aktivnih', (select count(*) from oglas_dogadaji where tip = 'ponovo_aktivan' and at >= v_od and oglas_id like n.izvor || '-%'));
    update puni_prolaz_nalozi set status = 'gotovo', zavrseno = now(), rezultat = v_st where id = n.id;
    v_out := v_out || jsonb_build_array(jsonb_build_object('nalog', n.id, 'izvor', n.izvor) || v_st);
  end loop;
  return v_out;
end;
$function$
