CREATE OR REPLACE FUNCTION public.njuskalo_upis_stranice(p_rows jsonb, p_napomena text, p_portal_ukupno integer DEFAULT NULL::integer, p_na_stranici integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- (19.11.2026., Ivor: puni prolaz Njuškala) Upis jedne ili više stranica Njuškalo liste koju je pročitao pravi preglednik
-- (ugrađeni preglednik / kasnije ekstenzija). Prima samo Njuškalo oglase, najviše 500 po pozivu, i zapisuje što je portal javio
-- (portal_ukupno = listingsCount, na_stranici) za provjeru portal = viđeno. Zasad otvoreno (anon), zaštita kasnije (opaska u Notionu).
declare
  v_res jsonb;
  v_prag bigint;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 500 then
    raise exception 'rows mora biti niz do 500 oglasa';
  end if;
  if exists (select 1 from jsonb_array_elements(p_rows) r
             where coalesce(r->>'link', '') !~ '^https://www\.njuskalo\.hr/'
                or coalesce(r->>'izvorni_id', '') !~ '^\d{5,12}$') then
    raise exception 'samo Njuškalo oglasi (link https://www.njuskalo.hr/…, brojčani ID)';
  end if;
  if coalesce(p_napomena, '') !~ '^preglednik str \d+(-\d+)?$' then
    raise exception 'napomena mora biti „preglednik str N” ili „preglednik str N-M”';
  end if;
  -- Novo / postojeći (kao Oglasnik): nepoznat oglas s ID-jem <= najvećem koji smo imali prije 1 dan = postojeći (nije_novo);
  -- prava prva objava upisuje se samo za stvarno nove (createdAt na Njuškalu je zadnja objava/obnova).
  select coalesce(max(izvorni_id::bigint), 0) into v_prag from oglasi
   where izvor = 'njuskalo' and izvorni_id ~ '^\d+$' and prvi_put_vidjen < now() - interval '1 day';
  select jsonb_agg(r || jsonb_build_object(
           'nije_novo', (r->>'izvorni_id')::bigint <= v_prag,
           'objavljeno', case when (r->>'izvorni_id')::bigint > v_prag then r->'obnovljeno' end))
    into p_rows from jsonb_array_elements(p_rows) r;
  v_res := ingest_oglasi('njuskalo', coalesce(p_rows, '[]'::jsonb), p_napomena);
  update scrape_runs set portal_ukupno = p_portal_ukupno, na_stranici = p_na_stranici where id = (v_res->>'run')::bigint;
  return v_res;
end;
$function$
