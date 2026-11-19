CREATE OR REPLACE FUNCTION public.oglasnik_oznaci_nevidljive()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- Pravilo (Ivor 18.11.2026.: „moraju se poklapat uvijek”): nakon punog prolaza aktivan Oglasnik oglas
-- koji prolaz nije vidio na listi portala = Neaktivan (razlog nepoznato). Baza = portal.
-- Zaštita (19.11., nalaz 1A): gasi se samo nakon izričito potpunog prolaza (puni_prolaz_stanje: sve potrebne stranice
-- po broju koji javlja portal uspješno dohvaćene); inače ništa. Uz to: ne više od 5 % aktivnih odjednom.
declare
  r record;
  v_n int := 0;
  v jsonb := puni_prolaz_stanje('oglasnik');
  v_od timestamptz;
begin
  if not coalesce((v->>'potpun')::boolean, false) then return 0; end if;
  v_od := (v->>'od')::timestamptz;
  if (v->>'kandidata')::int > (v->>'aktivnih')::int * 0.05 then return -(v->>'kandidata')::int; end if;
  for r in select id from oglasi
           where izvor = 'oglasnik' and status = 'Aktivan' and zadnji_put_vidjen < v_od - interval '5 minutes'
  loop
    perform oznaci_neaktivan(r.id, 'nepoznato');
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$function$
