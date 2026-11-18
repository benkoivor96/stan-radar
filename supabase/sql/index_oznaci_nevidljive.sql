CREATE OR REPLACE FUNCTION public.index_oznaci_nevidljive()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- Pravilo (Ivor 18.11.2026.: „moraju se poklapat uvijek”): nakon punog prolaza aktivan Index oglas
-- koji prolaz nije vidio na listi portala = Neaktivan (razlog nepoznato). Baza = portal.
-- Zaštita: zadnji puni prolaz (stranice 3+) završio prije barem 10 min, nije stariji od 26 h, nije bilo greške dohvata
-- u prolazu, i ne gasi se više od 5 % aktivnih odjednom (inače je kvar prikupljanja, ne portal).
declare
  r record;
  v_n int := 0;
  v_zadnji timestamptz;
  v_od timestamptz;
  v_akt int;
  v_kand int;
begin
  select max(pocetak) into v_zadnji from scrape_runs
   where izvor = 'index' and uspjeh and napomena ~ '^edge str ([3-9]|[1-9][0-9])$';
  if v_zadnji is null or v_zadnji > now() - interval '10 minutes' or v_zadnji < now() - interval '26 hours' then return 0; end if;
  select min(pocetak) into v_od from scrape_runs
   where izvor = 'index' and uspjeh and napomena ~ '^edge str ([3-9]|[1-9][0-9])$' and pocetak > v_zadnji - interval '1 hour';
  if exists (select 1 from scrape_runs where izvor = 'index' and not uspjeh
               and napomena ~ '^edge( str [0-9]+)?$' and pocetak >= v_od - interval '5 minutes') then
    return 0;
  end if;
  select count(*) into v_akt from oglasi where izvor = 'index' and status = 'Aktivan';
  select count(*) into v_kand from oglasi where izvor = 'index' and status = 'Aktivan' and zadnji_put_vidjen < v_od - interval '5 minutes';
  if v_kand > v_akt * 0.05 then return -v_kand; end if;
  for r in select id from oglasi
           where izvor = 'index' and status = 'Aktivan' and zadnji_put_vidjen < v_od - interval '5 minutes'
  loop
    perform oznaci_neaktivan(r.id, 'nepoznato');
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$function$
