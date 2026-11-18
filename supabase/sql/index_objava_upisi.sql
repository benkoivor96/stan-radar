CREATE OR REPLACE FUNCTION public.index_objava_upisi(p_oglas_id text, p_objavljeno timestamp with time zone)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- prva objava Index oglasa iz detalja (single-ad postedTime); detalj je izvor istine (18.11.2026.)
  update oglasi set objavljeno = p_objavljeno
  where id = p_oglas_id and p_objavljeno is not null and objavljeno is distinct from p_objavljeno;
$function$
