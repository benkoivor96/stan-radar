CREATE OR REPLACE FUNCTION public.oznaci_neaktivan(oid text, razlog text)
 RETURNS void
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  with u as (
    update oglasi set status = 'Neaktivan', razlog_neaktivnosti = razlog,
      neaktivan_od = now(), zadnja_provjera = now()
    where id = oid and status <> 'Neaktivan'
    returning id
  )
  insert into oglas_dogadaji (oglas_id, tip, novo)
  select id, 'neaktivan', to_jsonb(razlog) from u;
$function$
