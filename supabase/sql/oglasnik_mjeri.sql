CREATE OR REPLACE FUNCTION public.oglasnik_mjeri()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_max bigint; v_p int; v_m int;
begin
  select coalesce(max(izvorni_id::bigint),0) into v_max from oglasi where izvor='oglasnik' and izvorni_id ~ '^\d+$';
  create temp table _p on commit drop as
    select distinct on (e->>'izvorni_id') e
    from scrape_zahtjevi z
    join net._http_response r on r.id = z.request_id and r.status_code = 200 and r.content is not null
    cross join lateral jsonb_array_elements(oglasnik_parse(r.content, true)) e
    where z.izvor = 'oglasnik' and z.napravljeno > now() - interval '65 minutes'
    order by e->>'izvorni_id', z.id desc;

  -- 1) razlike polja kod poznatih oglasa
  with d as (
    select o.id, f.polje, f.b, f.p
    from _p join oglasi o on o.id = 'oglasnik-' || (_p.e->>'izvorni_id')
    cross join lateral (values
      ('m2', o.m2::text, (_p.e->>'m2')),
      ('sobe', o.sobe, _p.e->>'sobe'),
      ('kvart', o.kvart, _p.e->>'kvart'),
      ('dio_kvarta', o.dio_kvarta, _p.e->>'dio_kvarta'),
      ('ljubimci', o.ljubimci, _p.e->>'ljubimci'),
      ('vrt_terasa', o.vrt_terasa::text, _p.e->>'vrt_terasa'),
      ('bez_provizije', o.bez_provizije::text, _p.e->>'bez_provizije')
    ) f(polje, b, p)
    where f.p is not null and f.b is distinct from f.p
      and not (f.polje = 'm2' and f.b is not null and f.b::numeric = f.p::numeric)
  )
  insert into oglasnik_mjerenje (vrsta, oglas_id, polje, u_bazi, na_portalu)
  select 'polje', id, polje, b, p from d
  on conflict (vrsta, oglas_id, polje) do update set na_portalu = excluded.na_portalu, zadnji_put = now();
  get diagnostics v_p = row_count;

  -- 2) nepoznati oglasi s ID-jem manjim od najvećeg (sad se preskaču kao obnovljeni stari)
  insert into oglasnik_mjerenje (vrsta, oglas_id, max_id_u_bazi, objavljeno)
  select 'manji_id', 'oglasnik-' || (e->>'izvorni_id'), v_max, (e->>'objavljeno')::timestamptz
  from _p
  where (e->>'izvorni_id')::bigint <= v_max
    and not exists (select 1 from oglasi o where o.id = 'oglasnik-' || (_p.e->>'izvorni_id'))
  on conflict (vrsta, oglas_id, polje) do update set zadnji_put = now();
  get diagnostics v_m = row_count;

  return jsonb_build_object('polja', v_p, 'manji_id', v_m, 'max_id', v_max);
end $function$
