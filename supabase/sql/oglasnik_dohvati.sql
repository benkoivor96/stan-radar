CREATE OR REPLACE FUNCTION public.oglasnik_dohvati(p_stranice integer DEFAULT 3)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  p int;
  v_req bigint;
begin
  if p_stranice < 1 or p_stranice > 5 then
    raise exception 'stranica mora biti 1-5 za 5-minutni prolaz';
  end if;
  for p in 1..p_stranice loop
    select net.http_get(
      url := 'https://www.oglasnik.hr/stanovi-najam?f%5B4%5D%5B7442%5D=true&page=' || p,  -- (19.11.) lista Grad Zagreb: total = broj oglasa u Zagrebu
      headers := '{"User-Agent":"StanRadar/1.0"}'::jsonb,
      timeout_milliseconds := 20000
    ) into v_req;
    insert into scrape_zahtjevi (izvor, stranica, request_id) values ('oglasnik', p, v_req);
  end loop;
  return p_stranice;
end;
$function$
