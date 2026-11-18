CREATE OR REPLACE FUNCTION public.oglasnik_oznaci_nevidljive()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- Pravilo (Ivor 18.11.2026.): aktivan Oglasnik oglas koji 48 h nije na listi portala = Neaktivan (razlog nepoznato).
-- Radi samo ako je puni prolaz (stranice 4+) u zadnjih 26 h prošao i nijedna njegova stranica nije pala,
-- da kvar prikupljanja ne pogasi oglase. Vrati li se oglas na listu, ingest_oglasi ga vrati u Aktivan.
declare
  r record;
  v_n int := 0;
begin
  if not exists (select 1 from scrape_runs where izvor = 'oglasnik' and uspjeh
                   and napomena ~ '^cron str ([4-9]|[1-9][0-9])$' and pocetak > now() - interval '26 hours') then
    return 0;
  end if;
  if exists (select 1 from scrape_runs where izvor = 'oglasnik' and not uspjeh
               and napomena ~ '^cron str ([4-9]|[1-9][0-9])$' and pocetak > now() - interval '26 hours'
               and coalesce(greska, '') <> 'parser nije nasao oglase') then
    return 0;
  end if;
  for r in select id from oglasi
           where izvor = 'oglasnik' and status = 'Aktivan' and zadnji_put_vidjen < now() - interval '48 hours'
  loop
    perform oznaci_neaktivan(r.id, 'nepoznato');
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$function$
