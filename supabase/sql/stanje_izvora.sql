CREATE OR REPLACE FUNCTION public.stanje_izvora(p_izvor text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'izvor', p_izvor,
    'oglasa', (select count(*) from oglasi where izvor = p_izvor),
    'max_id', (select max(izvorni_id::bigint) from oglasi where izvor = p_izvor and izvorni_id ~ '^[0-9]{1,18}$'),
    'zadnji_krug', (select max(kraj) from scrape_runs where izvor = p_izvor and kraj is not null)
  );
$function$
