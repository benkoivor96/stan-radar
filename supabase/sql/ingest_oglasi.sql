CREATE OR REPLACE FUNCTION public.ingest_oglasi(p_izvor text, p_rows jsonb, p_napomena text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_run bigint;
  v_novih int := 0;
  v_azur int := 0;
  v_prim int := coalesce(jsonb_array_length(p_rows), 0);
  -- portal je izvor istine: prepisuju se polja koja lista tog izvora stvarno daje
  v_osnovno boolean := p_izvor in ('oglasnik','index');   -- naslov, m2, sobe, kvart, dio_kvarta
  v_oznake boolean := p_izvor in ('oglasnik');            -- ljubimci, vrt_terasa, bez_provizije
begin
  if p_izvor not in ('njuskalo','index','oglasnik','fb_grupa','fb_marketplace') then
    raise exception 'nepoznat izvor %', p_izvor;
  end if;
  if v_prim > 500 then
    raise exception 'previse oglasa odjednom (%), max 500', v_prim;
  end if;

  insert into scrape_runs (izvor, primljeno, napomena) values (p_izvor, v_prim, p_napomena) returning id into v_run;

  with src as (
    select
      p_izvor || '-' || (r->>'izvorni_id') as id,
      r->>'izvorni_id' as izvorni_id,
      r->>'link' as link,
      r->>'naslov' as naslov,
      nullif(r->>'cijena','')::int as cijena,
      nullif(r->>'m2','')::numeric as m2,
      nullif(r->>'sobe','') as sobe,
      nullif(r->>'kvart','') as kvart,
      nullif(r->>'dio_kvarta','') as dio_kvarta,
      coalesce(nullif(r->>'ljubimci',''),'Ne piše') as ljubimci,
      coalesce((r->>'vrt_terasa')::boolean,false) as vrt_terasa,
      coalesce((r->>'bez_provizije')::boolean,false) as bez_provizije,
      nullif(r->>'objavljeno','')::timestamptz as objavljeno,
      nullif(r->>'obnovljeno','')::timestamptz as obnovljeno,
      nullif(r->>'napomena','') as napomena,
      nullif(r->>'grupa','') as grupa,
      coalesce((r->>'nije_novo')::boolean,false) as nije_novo,
      coalesce((r->>'izdvojen')::boolean,false) as izdvojen
    from jsonb_array_elements(p_rows) r
    where coalesce(r->>'izvorni_id','') ~ '^[A-Za-z0-9_-]{1,40}$'
      and coalesce(r->>'link','') ~ '^https://'
  ), stari as (
    select o.id, o.cijena, o.status, o.razlog_neaktivnosti, o.obnovljeno,
           o.naslov, o.m2, o.sobe, o.kvart, o.dio_kvarta, o.ljubimci, o.vrt_terasa, o.bez_provizije
    from oglasi o join src s on s.id = o.id
  ), up as (
    insert into oglasi as o (id, izvor, izvorni_id, link, naslov, cijena, m2, sobe, kvart, dio_kvarta,
                             ljubimci, vrt_terasa, bez_provizije, objavljeno, obnovljeno, napomena, grupa, nije_novo, izdvojen)
    select id, p_izvor, izvorni_id, link, naslov, cijena, m2, sobe, kvart, dio_kvarta,
           ljubimci, vrt_terasa, bez_provizije, objavljeno, obnovljeno, napomena, grupa, nije_novo, izdvojen
    from src
    on conflict (id) do update set
      zadnji_put_vidjen = now(),
      zadnja_provjera = now(),
      prethodna_cijena = case when o.cijena is distinct from excluded.cijena then o.cijena else o.prethodna_cijena end,
      cijena_promijenjena_at = case when o.cijena is distinct from excluded.cijena then now() else o.cijena_promijenjena_at end,
      cijena = excluded.cijena,
      naslov = case when v_osnovno then coalesce(excluded.naslov, o.naslov) else o.naslov end,
      m2 = case when v_osnovno then coalesce(excluded.m2, o.m2) else o.m2 end,
      sobe = case when v_osnovno then coalesce(excluded.sobe, o.sobe) else o.sobe end,
      kvart = case when v_osnovno then coalesce(excluded.kvart, o.kvart) else o.kvart end,
      dio_kvarta = case when v_osnovno then coalesce(excluded.dio_kvarta, o.dio_kvarta) else o.dio_kvarta end,
      ljubimci = case when v_oznake then excluded.ljubimci else o.ljubimci end,
      vrt_terasa = case when v_oznake then excluded.vrt_terasa else o.vrt_terasa end,
      bez_provizije = case when v_oznake then excluded.bez_provizije else o.bez_provizije end,
      broj_obnova = o.broj_obnova + case when excluded.obnovljeno > o.obnovljeno + interval '1 minute' then 1 else 0 end,
      obnovljeno = case when excluded.obnovljeno is null then o.obnovljeno when o.obnovljeno is null then excluded.obnovljeno else greatest(o.obnovljeno, excluded.obnovljeno) end,
      grupa = coalesce(o.grupa, excluded.grupa),
      izdvojen = excluded.izdvojen,
      -- Index sam kaže je li oglas obnovljen (renewalTime); kad ga obnovi, više nije Novo (Ivor 17.11./18.11.)
      nije_novo = case when p_izvor = 'index' then (o.nije_novo or excluded.nije_novo) else o.nije_novo end,
      -- prva objava: Index je izvor istine kad je lista daje; ostali portali: upiše se samo kad je bila prazna (18.11.)
      objavljeno = case when p_izvor = 'index' then coalesce(excluded.objavljeno, o.objavljeno) else coalesce(o.objavljeno, excluded.objavljeno) end,
      status = 'Aktivan',
      razlog_neaktivnosti = null,
      neaktivan_od = null
    returning o.id, (xmax = 0) as novi
  ), razlike as (
    select st.id,
      jsonb_strip_nulls(jsonb_build_object(
        'naslov',  case when v_osnovno and s.naslov is not null and st.naslov is distinct from s.naslov then jsonb_build_array(st.naslov, s.naslov) end,
        'm2',      case when v_osnovno and s.m2 is not null and st.m2 is distinct from s.m2 then jsonb_build_array(st.m2, s.m2) end,
        'sobe',    case when v_osnovno and s.sobe is not null and st.sobe is distinct from s.sobe then jsonb_build_array(st.sobe, s.sobe) end,
        'kvart',   case when v_osnovno and s.kvart is not null and st.kvart is distinct from s.kvart then jsonb_build_array(st.kvart, s.kvart) end,
        'dio_kvarta', case when v_osnovno and s.dio_kvarta is not null and st.dio_kvarta is distinct from s.dio_kvarta then jsonb_build_array(st.dio_kvarta, s.dio_kvarta) end,
        'ljubimci',   case when v_oznake and st.ljubimci is distinct from s.ljubimci then jsonb_build_array(st.ljubimci, s.ljubimci) end,
        'vrt_terasa', case when v_oznake and st.vrt_terasa is distinct from s.vrt_terasa then jsonb_build_array(st.vrt_terasa, s.vrt_terasa) end,
        'bez_provizije', case when v_oznake and st.bez_provizije is distinct from s.bez_provizije then jsonb_build_array(st.bez_provizije, s.bez_provizije) end
      )) as d
    from stari st join src s on s.id = st.id
  ), ev_polja as (
    insert into oglas_dogadaji (oglas_id, tip, staro, novo)
    select id, 'promjena_polja',
           (select jsonb_object_agg(k, v->0) from jsonb_each(d) e(k, v)),
           (select jsonb_object_agg(k, v->1) from jsonb_each(d) e(k, v))
    from razlike where d <> '{}'::jsonb
  ), ev_novi as (
    insert into oglas_dogadaji (oglas_id, tip, novo)
    select s.id, 'novi_oglas', jsonb_build_object('cijena', s.cijena, 'nije_novo', s.nije_novo)
    from up join src s on s.id = up.id where up.novi
  ), ev_cijena as (
    insert into oglas_dogadaji (oglas_id, tip, staro, novo)
    select st.id, 'promjena_cijene', to_jsonb(st.cijena), to_jsonb(s.cijena)
    from stari st join src s on s.id = st.id
    where st.cijena is distinct from s.cijena
  ), ev_aktivan as (
    insert into oglas_dogadaji (oglas_id, tip, staro)
    select st.id, 'ponovo_aktivan', to_jsonb(st.razlog_neaktivnosti)
    from stari st where st.status = 'Neaktivan'
  ), ev_obnova as (
    insert into oglas_dogadaji (oglas_id, tip, staro, novo)
    select st.id, 'obnovljen', to_jsonb(st.obnovljeno), to_jsonb(s.obnovljeno)
    from stari st join src s on s.id = st.id
    where st.obnovljeno is not null and s.obnovljeno > st.obnovljeno + interval '1 minute'
  )
  select count(*) filter (where novi), count(*) filter (where not novi) into v_novih, v_azur from up;

  update scrape_runs set kraj = now(), novih = v_novih, azurirano = v_azur, uspjeh = true where id = v_run;
  return jsonb_build_object('run', v_run, 'primljeno', v_prim, 'novih', v_novih, 'azurirano', v_azur);
end;
$function$
