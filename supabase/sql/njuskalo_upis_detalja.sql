CREATE OR REPLACE FUNCTION public.njuskalo_upis_detalja(p_rows jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- (19.11.2026.) Radnik javlja što je pročitao na stranici oglasa: sobe, ljubimci (Da/Ne/Po dogovoru/Ne piše), vrt/terasa, bez provizije.
-- Sobe se upisuju samo kad ih detalj daje; naslov „Stan, …” dobiva broj soba. Oglas bez stranice (nema) samo dobiva detalj_at.
declare
  v_n int;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 50 then
    raise exception 'rows mora biti niz do 50 oglasa';
  end if;
  with d as (
    select 'njuskalo-' || (r->>'izvorni_id') as id,
           case when r->>'sobe' in ('Garsonijera', '1-sobni', '2-sobni', '3-sobni+') then r->>'sobe' end as sobe,
           case when r->>'ljubimci' in ('Da', 'Ne', 'Po dogovoru') then r->>'ljubimci' end as ljubimci,
           (r->>'vrt_terasa')::boolean as vrt_terasa,
           (r->>'bez_provizije')::boolean as bez_provizije,
           coalesce((r->>'nema')::boolean, false) as nema
    from jsonb_array_elements(p_rows) r
    where coalesce(r->>'izvorni_id', '') ~ '^\d{5,12}$'
  )
  update oglasi o set
    sobe = case when d.nema then o.sobe else coalesce(d.sobe, o.sobe) end,
    naslov = case when not d.nema and d.sobe is not null and o.naslov like 'Stan,%'
                  then rtrim(d.sobe, '+') || substr(o.naslov, 5) else o.naslov end,
    ljubimci = case when d.nema then o.ljubimci else coalesce(d.ljubimci, o.ljubimci) end,
    vrt_terasa = case when d.nema then o.vrt_terasa else coalesce(d.vrt_terasa, o.vrt_terasa) end,
    bez_provizije = case when d.nema then o.bez_provizije else coalesce(d.bez_provizije, o.bez_provizije) end,
    detalj_at = now()
  from d where o.id = d.id and o.izvor = 'njuskalo';
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$
