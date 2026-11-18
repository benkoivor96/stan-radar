CREATE OR REPLACE FUNCTION public.index_aktivnost_kandidati(p_n integer DEFAULT 10)
 RETURNS TABLE(id text, izvorni_id text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with zadnja as (
    select distinct on (oglas_id) oglas_id, aktivan, napravljeno
    from oglas_provjere where obradjeno and oglas_id like 'index-%'
    order by oglas_id, id desc
  ), pr as materialized (
    select max(pocetak) as zadnji from scrape_runs
    where izvor = 'index' and uspjeh and napomena ~ '^edge str ([3-9]|[1-9][0-9])$'
  ), puni as materialized (
    -- početak zadnjeg punog prolaza (stranice 3+), ako je završio prije barem 20 min i nije stariji od 26 h
    select case when pr.zadnji < now() - interval '20 minutes' and pr.zadnji > now() - interval '26 hours'
                then (select min(s.pocetak) from scrape_runs s
                      where s.izvor = 'index' and s.uspjeh and s.napomena ~ '^edge str ([3-9]|[1-9][0-9])$'
                        and s.pocetak > pr.zadnji - interval '1 hour') end as od
    from pr
  )
  select o.id, o.izvorni_id
  from oglasi o left join zadnja z on z.oglas_id = o.id cross join puni
  where o.izvor = 'index' and o.status = 'Aktivan'
    and ( (z.aktivan is false and z.napravljeno < now() - interval '10 minutes')
          or (o.zadnji_put_vidjen < now() - interval '26 hours'
              and (o.aktivnost_provjerena_at is null or o.aktivnost_provjerena_at < now() - interval '23 hours'))
          or (puni.od is not null and o.zadnji_put_vidjen < puni.od
              and (o.aktivnost_provjerena_at is null or o.aktivnost_provjerena_at < puni.od))
          -- nema datuma prve objave: detalj oglasa ga daje (18.11.), najviše jednom na sat
          or (o.objavljeno is null
              and (o.aktivnost_provjerena_at is null or o.aktivnost_provjerena_at < now() - interval '1 hour')) )
  -- redoslijed: druga provjera nakon negativne, pa oglasi kojih nema na listi, pa tek oni kojima samo fali datum objave (18.11.)
  order by case when z.aktivan is false then 0
                when o.zadnji_put_vidjen < coalesce(puni.od, now() - interval '26 hours') then 1 else 2 end,
           coalesce(o.aktivnost_provjerena_at, 'epoch'), o.id
  limit greatest(1, least(p_n, 30))
$function$
