CREATE OR REPLACE FUNCTION public.njuskalo_za_detalje(p_n integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- (19.11.2026.) Koje aktivne Njuškalo oglase radnik treba otvoriti radi detalja (sobe, ljubimci, terasa, provizija):
  -- oni čiji detalj još nije pročitan, najnoviji prvi (novi oglasi idu odmah, stari se polako dopunjavaju). Najviše 20 odjednom.
  select coalesce(jsonb_agg(izvorni_id), '[]'::jsonb) from (
    select izvorni_id from oglasi
     where izvor = 'njuskalo' and status = 'Aktivan' and detalj_at is null and izvorni_id ~ '^\d+$'
     order by prvi_put_vidjen desc, izvorni_id::bigint desc
     limit least(greatest(coalesce(p_n, 5), 0), 20)
  ) t
$function$
