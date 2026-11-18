CREATE OR REPLACE FUNCTION public.stanradar_alarmi()
 RETURNS TABLE(izvor text, poruka text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- OGLASNIK
  select 'oglasnik', 'Oglasnik: nema uspješnog dohvata od ' ||
         coalesce(to_char(max(pocetak) at time zone 'Europe/Zagreb', 'DD.MM. HH24:MI'), 'nikad')
  from scrape_runs where izvor = 'oglasnik' and uspjeh
  having coalesce(max(pocetak), 'epoch') < now() - interval '30 minutes'
  union all
  select 'oglasnik', 'Oglasnik: ' || count(*) || ' oglasa nije provjereno dulje od 30 h'
  from oglasi
  where izvor = 'oglasnik' and status = 'Aktivan'
    and zadnji_put_vidjen < now() - interval '30 hours'
    and (aktivnost_provjerena_at is null or aktivnost_provjerena_at < now() - interval '30 hours')
  having count(*) > 0
  union all
  select 'oglasnik', 'Oglasnik: ' || count(*) || ' provjera aktivnosti zapelo (neobrađeno > 30 min)'
  from oglas_provjere where not obradjeno and napravljeno < now() - interval '30 minutes'
  having count(*) > 0
  union all
  -- OGLASNIK puni prolaz (stranice 4+, svake noći, od 18.11.)
  select 'oglasnik', 'Oglasnik: noćni puni prolaz nije prošao (zadnji ' ||
         coalesce(to_char(max(pocetak) at time zone 'Europe/Zagreb', 'DD.MM. HH24:MI'), 'nikad') || ')'
  from scrape_runs where izvor = 'oglasnik' and uspjeh and napomena ~ '^cron str ([4-9]|[1-9][0-9])$'
  having coalesce(max(pocetak), 'epoch') < now() - interval '26 hours'
  union all
  select 'oglasnik', 'Oglasnik: zadnja čitana stranica (30) nije prazna – portal ima više stranica, puni prolaz treba proširiti'
  from scrape_runs where izvor = 'oglasnik' and uspjeh and napomena = 'cron str 30' and pocetak > now() - interval '26 hours'
  having count(*) > 0
  union all
  select 'oglasnik', 'Oglasnik: ' || count(*) || ' aktivnih oglasa nema na listi portala dulje od 2 dana (baza i portal se ne slažu)'
  from oglasi
  where izvor = 'oglasnik' and status = 'Aktivan' and zadnji_put_vidjen < now() - interval '48 hours'
  having count(*) > 0
  union all
  -- INDEX
  select 'index', 'Index: nema uspješnog dohvata od ' ||
         coalesce(to_char(max(pocetak) at time zone 'Europe/Zagreb', 'DD.MM. HH24:MI'), 'nikad')
  from scrape_runs where izvor = 'index' and uspjeh
  having coalesce(max(pocetak), 'epoch') < now() - interval '30 minutes'
  union all
  select 'index', 'Index: dnevni puni prolaz nije prošao (zadnja stranica 20+ ' ||
         coalesce(to_char(max(pocetak) at time zone 'Europe/Zagreb', 'DD.MM. HH24:MI'), 'nikad') || ')'
  from scrape_runs where izvor = 'index' and uspjeh and napomena ~ '^edge str ([2-9][0-9])$'
  having coalesce(max(pocetak), 'epoch') < now() - interval '26 hours'
  union all
  select 'index', 'Index: ' || count(*) || ' oglasa nije provjereno dulje od 30 h'
  from oglasi
  where izvor = 'index' and status = 'Aktivan'
    and zadnji_put_vidjen < now() - interval '30 hours'
    and (aktivnost_provjerena_at is null or aktivnost_provjerena_at < now() - interval '30 hours')
  having count(*) > 0
  union all
  -- INDEX puni prolaz do 60 stranica i oglasi bez liste (18.11.)
  select 'index', 'Index: zadnja čitana stranica (60) nije prazna – portal ima više stranica, puni prolaz treba proširiti'
  from scrape_runs where izvor = 'index' and uspjeh and napomena = 'edge str 60' and pocetak > now() - interval '26 hours'
  having count(*) > 0
  union all
  select 'index', 'Index: ' || count(*) || ' aktivnih oglasa nema na listi portala dulje od 2 dana (baza i portal se ne slažu)'
  from oglasi
  where izvor = 'index' and status = 'Aktivan' and zadnji_put_vidjen < now() - interval '48 hours'
  having count(*) > 0
  union all
  -- ZAKAZANI POSLOVI (oba izvora)
  select split_part(j.jobname, '-', 1), 'Zakazani posao ' || j.jobname || ' je ugašen'
  from cron.job j where (j.jobname like 'oglasnik-%' or j.jobname like 'index-%') and not j.active
  union all
  select split_part(j.jobname, '-', 1), 'Zakazani posao ' || j.jobname || ' pao ' || count(*) || '× u zadnjih sat'
  from cron.job j join cron.job_run_details d on d.jobid = j.jobid
  where (j.jobname like 'oglasnik-%' or j.jobname like 'index-%') and d.status = 'failed' and d.start_time > now() - interval '1 hour'
  group by j.jobname having count(*) >= 3
$function$
