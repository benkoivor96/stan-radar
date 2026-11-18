CREATE OR REPLACE FUNCTION public.sync_notion(p_tablica text, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  n_prim int := jsonb_array_length(p_rows);
  n_novih int := 0; n_azur int := 0; n_posl int := 0; n_dup int := 0; n_pres int := 0;
begin
  if p_tablica = 'oglasi' then
    create temp table _o on commit drop as
    with src as (
      select x,
             nullif(trim(x->>'ID oglasa'),'') idn,
             notion_pid(x->>'url') pid
      from jsonb_array_elements(p_rows) x
    ), m as (
      select
        case when idn is not null and position('-' in idn) > 0
             then case split_part(idn,'-',1) when 'fb' then 'fb_grupa' when 'mp' then 'fb_marketplace' else split_part(idn,'-',1) end
             else case x->>'Izvor' when 'Njuškalo' then 'njuskalo' when 'Index' then 'index' when 'Oglasnik' then 'oglasnik'
                                   when 'FB Marketplace' then 'fb_marketplace' else 'fb_grupa' end
        end izvor,
        case when idn is not null and position('-' in idn) > 0 then substring(idn from position('-' in idn)+1) else pid end izvorni_id,
        coalesce(nullif(x->>'Link',''), x->>'url') link,
        x->>'Naslov' naslov,
        case when (x->>'Cijena (€)') ~ '^[0-9.]+$' and (x->>'Cijena (€)')::numeric between 0 and 100000 then round((x->>'Cijena (€)')::numeric)::int end cijena,
        case when (x->>'m²') ~ '^[0-9.]+$' and (x->>'m²')::numeric > 0 and (x->>'m²')::numeric < 100000 then (x->>'m²')::numeric end m2,
        case when x->>'Sobe' in ('Garsonijera','1-sobni','2-sobni','3-sobni+') then x->>'Sobe' end sobe,
        nullif(trim(split_part(coalesce(x->>'Kvart',''), ',', 1)),'') kvart,
        nullif(trim(substring(coalesce(x->>'Kvart','') from position(',' in coalesce(x->>'Kvart',''))+1)),'') dio_raw,
        position(',' in coalesce(x->>'Kvart','')) > 0 ima_dio,
        case when x->>'Ljubimci' in ('Da','Ne','Po dogovoru','Ne piše') then x->>'Ljubimci' else 'Ne piše' end ljubimci,
        coalesce(x->>'Vrt/terasa','') = '__YES__' vrt_terasa,
        coalesce(x->>'Bez provizije','') = '__YES__' bez_provizije,
        nullif(x->>'date:Objavljeno:start','')::timestamptz objavljeno,
        coalesce(nullif(x->>'Prvi put viđeno','')::timestamptz, now()) prvi,
        nullif(x->>'date:Zadnji put viđeno:start','')::timestamptz zadnji,
        case when x->>'Status' in ('Aktivan','Poslano klijentima','Iznajmljeno','Nestao') then x->>'Status' else 'Aktivan' end status,
        x->>'Opis' napomena,
        x->>'Izvor' grupa,
        pid
      from src
    )
    select distinct on (izvor||'-'||izvorni_id) izvor||'-'||izvorni_id id, m.*
    from m where izvorni_id is not null
    order by izvor||'-'||izvorni_id, prvi desc;

    n_dup := n_prim - (select count(*) from _o);
    select count(*) into n_novih from _o where not exists (select 1 from oglasi g where g.id = _o.id);

    -- isti Notion red mogao je ranije biti spremljen pod drugim ID-em: oslobodi notion_id
    update oglasi g set notion_id = null from _o where g.notion_id = _o.pid and g.id <> _o.id;

    insert into oglasi as g (id, izvor, izvorni_id, link, naslov, cijena, m2, sobe, kvart, dio_kvarta, ljubimci, vrt_terasa,
                             bez_provizije, objavljeno, prvi_put_vidjen, zadnji_put_vidjen, status, napomena, grupa, notion_id, notion_sync_at)
    select id, izvor, izvorni_id, link, naslov, cijena, m2, sobe, kvart, case when ima_dio then dio_raw end, ljubimci, vrt_terasa,
           bez_provizije, objavljeno, prvi, coalesce(zadnji, prvi), status, napomena, grupa, pid, now()
    from _o
    on conflict (id) do update set
      link = excluded.link, naslov = excluded.naslov, cijena = excluded.cijena, m2 = excluded.m2, sobe = excluded.sobe,
      kvart = excluded.kvart, dio_kvarta = excluded.dio_kvarta, ljubimci = excluded.ljubimci, vrt_terasa = excluded.vrt_terasa,
      bez_provizije = excluded.bez_provizije, objavljeno = excluded.objavljeno, prvi_put_vidjen = least(g.prvi_put_vidjen, excluded.prvi_put_vidjen),
      zadnji_put_vidjen = greatest(g.zadnji_put_vidjen, excluded.zadnji_put_vidjen), status = excluded.status,
      napomena = excluded.napomena, grupa = excluded.grupa, notion_id = excluded.notion_id, notion_sync_at = now();
    n_azur := (select count(*) from _o) - n_novih;

  elsif p_tablica = 'klijenti' then
    create temp table _k on commit drop as
    select notion_pid(x->>'url') pid, x from jsonb_array_elements(p_rows) x where notion_pid(x->>'url') is not null;

    select count(*) into n_novih from _k where not exists (select 1 from klijenti c where c.notion_id = _k.pid);

    insert into klijenti as c (ime, email, status, budzet_do, kvartovi, min_sobe, ljubimci, vrt_terasa_pozeljno, lista_url, napomene,
                               zadnje_slanje, whatsapp, placeno_do, useljenje_do, notion_id, notion_sync_at)
    select coalesce(nullif(x->>'Ime',''),'(bez imena)'), nullif(x->>'Email',''),
           case when x->>'Status' in ('Lead','Probni tjedan','Aktivan','Pauza','Našao stan','Odjavljen') then x->>'Status' else 'Lead' end,
           case when (x->>'Budžet do (€)') ~ '^[0-9.]+$' then round((x->>'Budžet do (€)')::numeric)::int end,
           (select array_agg(trim(t)) from unnest(string_to_array(coalesce(x->>'Kvartovi',''), ',')) t where trim(t) <> ''),
           case when x->>'Min. sobe' in ('Garsonijera','1-sobni','2-sobni','3-sobni+') then x->>'Min. sobe' end,
           coalesce(x->>'Ljubimci','') = '__YES__', coalesce(x->>'Vrt/terasa poželjno','') = '__YES__',
           nullif(x->>'Lista',''), nullif(x->>'Napomene',''),
           nullif(x->>'date:Zadnje slanje:start','')::timestamptz, nullif(x->>'WhatsApp',''),
           nullif(x->>'date:Plaćeno do:start','')::date, nullif(x->>'date:Useljenje do:start','')::date, pid, now()
    from _k
    on conflict (notion_id) do update set
      ime = excluded.ime, email = excluded.email, status = excluded.status, budzet_do = excluded.budzet_do, kvartovi = excluded.kvartovi,
      min_sobe = excluded.min_sobe, ljubimci = excluded.ljubimci, vrt_terasa_pozeljno = excluded.vrt_terasa_pozeljno,
      lista_url = excluded.lista_url, napomene = excluded.napomene, zadnje_slanje = excluded.zadnje_slanje, whatsapp = excluded.whatsapp,
      placeno_do = excluded.placeno_do, useljenje_do = excluded.useljenje_do, notion_sync_at = now();
    n_azur := (select count(*) from _k) - n_novih;

    -- Poslano: relacija Klijenti."Poslani oglasi" -> oglasi preko notion_id
    with rel as (
      select c.id klijent_id, c.zadnje_slanje, notion_pid(e) opid
      from _k join klijenti c on c.notion_id = _k.pid
      cross join lateral jsonb_array_elements_text(
        case jsonb_typeof(_k.x->'Poslani oglasi')
          when 'array' then _k.x->'Poslani oglasi'
          when 'string' then case when left(_k.x->>'Poslani oglasi',1) = '[' then (_k.x->>'Poslani oglasi')::jsonb else to_jsonb(string_to_array(_k.x->>'Poslani oglasi', ',')) end
          else '[]'::jsonb end) e
    ), ins as (
      insert into poslano (klijent_id, oglas_id, poslano_at, kanal)
      select r.klijent_id, g.id, coalesce(r.zadnje_slanje, now()), 'notion'
      from rel r join oglasi g on g.notion_id = r.opid
      on conflict do nothing returning 1
    )
    select count(*) into n_posl from ins;
    select count(*) into n_pres from (
      select 1 from _k cross join lateral jsonb_array_elements_text(
        case jsonb_typeof(_k.x->'Poslani oglasi') when 'array' then _k.x->'Poslani oglasi'
          when 'string' then case when left(_k.x->>'Poslani oglasi',1) = '[' then (_k.x->>'Poslani oglasi')::jsonb else to_jsonb(string_to_array(_k.x->>'Poslani oglasi', ',')) end
          else '[]'::jsonb end) e
      where not exists (select 1 from oglasi g where g.notion_id = notion_pid(e))) z;

  elsif p_tablica = 'izvori' then
    select count(*) into n_novih from jsonb_array_elements(p_rows) x
      where notion_pid(x->>'url') is not null and not exists (select 1 from izvori i where i.notion_id = notion_pid(x->>'url'));
    insert into izvori as i (notion_id, izvor, tip, status, prioritet, metoda, ucestalost, url, napomene, notion_sync_at)
    select notion_pid(x->>'url'), coalesce(nullif(x->>'Izvor',''),'(bez naziva)'), x->>'Tip', x->>'Status', x->>'Prioritet', x->>'Metoda',
           x->>'Učestalost', coalesce(x->>'userDefined:URL', x->>'URL'), x->>'Napomene', now()
    from jsonb_array_elements(p_rows) x where notion_pid(x->>'url') is not null
    on conflict (notion_id) do update set izvor = excluded.izvor, tip = excluded.tip, status = excluded.status, prioritet = excluded.prioritet,
      metoda = excluded.metoda, ucestalost = excluded.ucestalost, url = excluded.url, napomene = excluded.napomene, notion_sync_at = now();
    n_azur := (select count(*) from jsonb_array_elements(p_rows) x where notion_pid(x->>'url') is not null) - n_novih;
  else
    raise exception 'Nepoznata tablica: %', p_tablica;
  end if;

  return jsonb_build_object('tablica', p_tablica, 'primljeno', n_prim, 'novih', n_novih, 'azurirano', n_azur,
                            'duplikati', n_dup, 'poslano_novih', n_posl, 'poslano_bez_oglasa', n_pres);
end $function$
