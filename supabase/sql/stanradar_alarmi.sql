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
  select 'index', 'Index: ' || count(*) || ' oglasa nije provjereno dulje od 30 h'
  from oglasi
  where izvor = 'index' and status = 'Aktivan'
    and zadnji_put_vidjen < now() - interval '30 hours'
    and (aktivnost_provjerena_at is null or aktivnost_provjerena_at < now() - interval '30 hours')
  having count(*) > 0
  union all
  select 'index', 'Index: ' || count(*) || ' aktivnih oglasa nema na listi portala dulje od 2 dana (baza i portal se ne slažu)'
  from oglasi
  where izvor = 'index' and status = 'Aktivan' and zadnji_put_vidjen < now() - interval '48 hours'
  having count(*) > 0
  union all
  -- PUNI PROLAZ (19.11.: nalozi puni_prolaz_nalozi, raspored 03 i 15 h + gumb na webu)
  select i, initcap(i) || ': nema završenog punog prolaza od ' ||
         coalesce(to_char(max(n.zavrseno) at time zone 'Europe/Zagreb', 'DD.MM. HH24:MI'), 'nikad')
  from unnest(array['oglasnik', 'index']) i
  left join puni_prolaz_nalozi n on n.izvor = i and n.status in ('gotovo', 'greska')
  group by i having coalesce(max(n.zavrseno), 'epoch') < now() - interval '14 hours'
  union all
  select n.izvor, initcap(n.izvor) || ': zadnji puni prolaz (' || to_char(n.zavrseno at time zone 'Europe/Zagreb', 'DD.MM. HH24:MI') ||
         ') nije potpun, neaktivni se ne označavaju (' || coalesce(n.rezultat->>'razlog', 'nepoznato') || ')'
  from (select distinct on (x.izvor) x.* from puni_prolaz_nalozi x where x.status in ('gotovo', 'greska') order by x.izvor, x.id desc) n
  where not coalesce((n.rezultat->>'potpun')::boolean, false)
  union all
  select n.izvor, initcap(n.izvor) || ': ' || (n.rezultat->>'napomena')
  from (select distinct on (x.izvor) x.* from puni_prolaz_nalozi x where x.status = 'gotovo' order by x.izvor, x.id desc) n
  where (n.rezultat->>'napomena') like '%5 \% aktivnih%'
  union all
  -- ZAKAZANI POSLOVI (oba izvora)
  select case when j.jobname like 'puni-prolaz-%' then 'oba' else split_part(j.jobname, '-', 1) end, 'Zakazani posao ' || j.jobname || ' je ugašen'
  from cron.job j where (j.jobname like 'oglasnik-%' or j.jobname like 'index-%' or j.jobname like 'puni-prolaz-%') and not j.active
  union all
  select case when j.jobname like 'puni-prolaz-%' then 'oba' else split_part(j.jobname, '-', 1) end, 'Zakazani posao ' || j.jobname || ' pao ' || count(*) || '× u zadnjih sat'
  from cron.job j join cron.job_run_details d on d.jobid = j.jobid
  where (j.jobname like 'oglasnik-%' or j.jobname like 'index-%' or j.jobname like 'puni-prolaz-%') and d.status = 'failed' and d.start_time > now() - interval '1 hour'
  group by j.jobname having count(*) >= 3
$function$
