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
  )
  select o.id, o.izvorni_id
  from oglasi o left join zadnja z on z.oglas_id = o.id
  where o.izvor = 'index' and o.status = 'Aktivan'
    and o.zadnji_put_vidjen < now() - interval '26 hours'
    and ( (z.aktivan is false and z.napravljeno < now() - interval '10 minutes')
          or o.aktivnost_provjerena_at is null
          or o.aktivnost_provjerena_at < now() - interval '23 hours' )
  order by case when z.aktivan is false then 0 else 1 end, coalesce(o.aktivnost_provjerena_at, 'epoch'), o.id
  limit greatest(1, least(p_n, 30))
$function$
