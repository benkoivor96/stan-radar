CREATE OR REPLACE FUNCTION public.puni_prolaz_pregled()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- (19.11.2026.) Za admin dio weba: zadnji nalog punog prolaza po portalu, napredak i trenutni broj aktivnih u bazi.
  select coalesce(jsonb_object_agg(i, x), '{}'::jsonb) from (
    select i, jsonb_build_object(
      'aktivnih', (select count(*) from oglasi where izvor = i and status = 'Aktivan'),
      'nalog', (select jsonb_build_object(
          'id', n.id, 'pokrenuo', n.pokrenuo, 'status', n.status,
          'zatrazeno', n.zatrazeno, 'poceto', n.poceto, 'zavrseno', n.zavrseno,
          'stranica_do', n.stranica_do,
          'stranica_gotovo', case when n.izvor = 'index' then
              greatest(0, n.poslano_do - case when n.status = 'dohvat' and cardinality(n.zahtjevi) > 0
                and not exists (select 1 from net._http_response h where h.id = n.zahtjevi[cardinality(n.zahtjevi)])
                then least(10, n.poslano_do) else 0 end)
            else (select count(*) from scrape_zahtjevi z where z.request_id = any(n.zahtjevi) and z.obradjeno) end,
          'rezultat', n.rezultat)
        from puni_prolaz_nalozi n where n.izvor = i order by n.id desc limit 1)
    ) x
    from unnest(array['index', 'oglasnik']) i
  ) t
$function$
