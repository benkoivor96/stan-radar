CREATE OR REPLACE FUNCTION public.puni_prolaz_stanje(p_izvor text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- (19.11.2026., Ivor: nalaz 1A) Je li zadnji noćni puni prolaz izričito POTPUN. Samo tada se smiju gasiti oglasi koje prolaz nije vidio.
-- Potpun = 1) portal je javio koliko oglasa ima na listi (Index count, Oglasnik total),
--          2) svaka stranica od 1 do zadnje potrebne (ukupno / oglasa po stranici) ima u prolazu uspješan dohvat na kojem portal ima oglase
--             (pala, prazna ili nejasna stranica = nije potpun),
--          3) Index: prolaz je vidio barem onoliko aktivnih oglasa koliko portal javlja (inače je nešto propušteno).
--             Oglasnik javlja ukupno za cijelu Hrvatsku, a mi spremamo samo Zagreb, pa se 3) za njega ne može provjeriti.
declare
  v_pref text := case p_izvor when 'index' then 'edge' when 'oglasnik' then 'cron' end;
  v_min int := case p_izvor when 'index' then 3 else 4 end;        -- stranice koje dohvaća samo noćni prolaz
  v_po int := case p_izvor when 'index' then 50 else 100 end;      -- oglasa po stranici
  v_max int := case p_izvor when 'index' then 60 else 30 end;      -- do koje stranice prolaz čita
  v_zadnji timestamptz; v_od timestamptz; v_do timestamptz;
  v_ukupno int; v_treba int; v_fale int[]; v_akt int; v_vidjeno int;
  v_razlog text;
begin
  if v_pref is null then raise exception 'nepoznat izvor %', p_izvor; end if;

  select max(pocetak) into v_zadnji from scrape_runs
   where izvor = p_izvor and uspjeh and pocetak > now() - interval '30 hours'
     and (regexp_match(napomena, '^' || v_pref || ' str (\d+)$'))[1]::int >= v_min;
  if v_zadnji is null or v_zadnji < now() - interval '26 hours' then
    return jsonb_build_object('potpun', false, 'razlog', 'nema noćnog prolaza u zadnjih 26 h');
  end if;
  if v_zadnji > now() - interval '10 minutes' then
    return jsonb_build_object('potpun', false, 'razlog', 'prolaz još traje');
  end if;
  select min(pocetak) into v_od from scrape_runs
   where izvor = p_izvor and uspjeh and pocetak > v_zadnji - interval '1 hour'
     and (regexp_match(napomena, '^' || v_pref || ' str (\d+)$'))[1]::int >= v_min;
  v_do := v_zadnji + interval '10 minutes';

  -- stranice prolaza (uz stranice 1–3 iz redovnog dohvata svakih 5 min u istom razdoblju)
  select max(portal_ukupno) into v_ukupno from scrape_runs
   where izvor = p_izvor and pocetak between v_od - interval '10 minutes' and v_do and portal_ukupno is not null;
  if v_ukupno is null then
    v_razlog := 'portal nije javio broj oglasa';
  else
    v_treba := greatest(1, ceil(v_ukupno::numeric / v_po)::int);
    if v_treba > v_max then
      v_razlog := 'portal ima ' || v_treba || ' stranica, prolaz čita do ' || v_max;
    else
      select coalesce(array_agg(g order by g), '{}') into v_fale
        from generate_series(1, v_treba) g
       where not exists (
         select 1 from scrape_runs s
          where s.izvor = p_izvor and s.uspjeh and coalesce(s.na_stranici, 0) > 0
            and s.pocetak between v_od - interval '10 minutes' and v_do
            and s.napomena = v_pref || ' str ' || g);
      if cardinality(v_fale) > 0 then
        v_razlog := 'stranice bez uspješnog dohvata: ' || array_to_string(v_fale, ', ');
      end if;
    end if;
  end if;

  select count(*), count(*) filter (where zadnji_put_vidjen >= v_od - interval '5 minutes')
    into v_akt, v_vidjeno from oglasi where izvor = p_izvor and status = 'Aktivan';
  if v_razlog is null and p_izvor = 'index' and v_vidjeno < v_ukupno then
    v_razlog := 'prolaz je vidio ' || v_vidjeno || ' od ' || v_ukupno || ' oglasa koje portal javlja';
  end if;

  return jsonb_build_object('potpun', v_razlog is null, 'razlog', v_razlog,
    'od', v_od, 'do', v_do, 'portal_ukupno', v_ukupno, 'stranica_treba', v_treba,
    'aktivnih', v_akt, 'vidjeno', v_vidjeno, 'kandidata', v_akt - v_vidjeno);
end;
$function$
