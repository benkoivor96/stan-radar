CREATE OR REPLACE FUNCTION public.oglasnik_aktivnost_dohvati(p_n integer DEFAULT 10)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
  v_req bigint;
  v_cnt int := 0;
begin
  if p_n < 1 or p_n > 30 then raise exception 'p_n mora biti 1-30'; end if;
  for r in
    with zadnja as (
      select distinct on (oglas_id) oglas_id, aktivan, napravljeno
      from oglas_provjere
      where obradjeno and aktivan is not null
      order by oglas_id, id desc
    )
    select o.id, o.link,
           case when z.aktivan is false then 0 else 1 end as pr,
           coalesce(o.aktivnost_provjerena_at, 'epoch'::timestamptz) as ap,
           o.prvi_put_vidjen
    from oglasi o
    left join zadnja z on z.oglas_id = o.id
    where o.izvor = 'oglasnik' and o.status = 'Aktivan'
      and not exists (select 1 from oglas_provjere w where w.oglas_id = o.id and not w.obradjeno)
      and (
        -- druga provjera nakon negativne (najmanje 10 min poslije prve)
        (z.aktivan is false and z.napravljeno < now() - interval '10 minutes')
        or
        -- redovna provjera jednom na dan
        (o.zadnji_put_vidjen < now() - interval '24 hours'
         and (o.aktivnost_provjerena_at is null or o.aktivnost_provjerena_at < now() - interval '23 hours'))
      )
    order by pr, ap, o.prvi_put_vidjen
    limit p_n
  loop
    select net.http_get(url := r.link, headers := '{"User-Agent":"StanRadar/1.0"}'::jsonb, timeout_milliseconds := 20000) into v_req;
    insert into oglas_provjere (oglas_id, request_id) values (r.id, v_req);
    update oglasi set aktivnost_provjerena_at = now() where id = r.id;
    v_cnt := v_cnt + 1;
  end loop;
  return v_cnt;
end;
$function$
