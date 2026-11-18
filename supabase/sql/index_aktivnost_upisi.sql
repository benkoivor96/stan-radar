CREATE OR REPLACE FUNCTION public.index_aktivnost_upisi(p_oglas_id text, p_aktivan boolean, p_http integer, p_greska text DEFAULT NULL::text, p_razlog text DEFAULT 'uklonjeno'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_prije boolean; v_prije_t timestamptz;
begin
  if p_razlog not in ('uklonjeno','iznajmljeno') then raise exception 'razlog %', p_razlog; end if;
  select aktivan, napravljeno into v_prije, v_prije_t from oglas_provjere
   where oglas_id = p_oglas_id and obradjeno order by id desc limit 1;
  insert into oglas_provjere (oglas_id, request_id, obradjeno, aktivan, http, greska)
  values (p_oglas_id, null, true, p_aktivan, p_http, p_greska);
  update oglasi set aktivnost_provjerena_at = now() where id = p_oglas_id;
  -- Neaktivan samo kad je ugašen (404 = uklonjeno, status 3 „prodan” = iznajmljeno), dvaput zaredom, razmak >= 10 min
  if p_aktivan is false and v_prije is false and v_prije_t < now() - interval '10 minutes' then
    update oglasi set status = 'Neaktivan', razlog_neaktivnosti = p_razlog, neaktivan_od = now()
     where id = p_oglas_id and status = 'Aktivan';
    if found then
      insert into oglas_dogadaji (oglas_id, tip, staro) values (p_oglas_id, 'neaktivan', to_jsonb(p_razlog));
      update oglas_provjere set oznaceno = true where id = (select max(id) from oglas_provjere where oglas_id = p_oglas_id);
      return 'neaktivan';
    end if;
  end if;
  return 'upisano';
end $function$
