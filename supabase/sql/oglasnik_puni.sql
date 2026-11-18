CREATE OR REPLACE FUNCTION public.oglasnik_puni(p_od integer, p_do integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- Puni prolaz Oglasnika (18.11.2026.): šalje zahtjeve za stranice p_od..p_do (najviše 10 po pozivu).
-- Obrađuje ih postojeći oglasnik_obradi (isti parser i ingest kao stranice 1–3).
declare
  p int;
  v_req bigint;
begin
  if p_od < 1 or p_do < p_od or p_do - p_od > 9 or p_do > 60 then
    raise exception 'stranice moraju biti 1-60, najvise 10 po pozivu';
  end if;
  for p in p_od..p_do loop
    select net.http_get(
      url := 'https://www.oglasnik.hr/stanovi-najam?page=' || p,
      headers := '{"User-Agent":"StanRadar/1.0"}'::jsonb,
      timeout_milliseconds := 20000
    ) into v_req;
    insert into scrape_zahtjevi (izvor, stranica, request_id) values ('oglasnik', p, v_req);
  end loop;
  return p_do - p_od + 1;
end;
$function$
