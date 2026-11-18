CREATE OR REPLACE FUNCTION public.oglasnik_parse(p_content text, p_samo_zagreb boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
 SET "TimeZone" TO 'UTC'
AS $function$
declare
  v_out jsonb := '[]'::jsonb;
  s text;
  v_id text; v_pub text; v_loc text; v_opis text; v_title text;
  v_names text[]; v_parts text[]; v_kv text; v_sub text;
  v_cijena int; v_m2 numeric; v_sobe_raw text; v_sobe text; v_pets text; v_ter text;
  v_te boolean; v_bp boolean; v_lj text; v_nap text; v_active boolean; v_naslov text; v_ob timestamptz;
  v_dio text; v_kvart text;
begin
  for s in
    select x from regexp_split_to_table(p_content, '\{\\"id\\":(?=\d+,\\"title\\":\\")') as x offset 1
  loop
    v_id := (regexp_match(s, '^(\d+),'))[1];
    v_pub := (regexp_match(s, '\\"publish\\":\\"([^"\\]+)\\"'))[1];
    continue when v_id is null or v_pub is null;
    v_loc := (regexp_match(s, '\\"location\\":\[(.*?)\]'))[1];
    select coalesce(array_agg(m[1] order by ord), '{}') into v_names
      from regexp_matches(coalesce(v_loc,''), '\\"name\\":\\"([^"\\]+)\\"', 'g') with ordinality as t(m, ord);
    if p_samo_zagreb and not ('Grad Zagreb' = any(v_names)) then continue; end if;
    v_cijena := (regexp_match(s, '\\"price\\":\{[^}]*\\"value\\":(\d+)'))[1]::int;
    -- (18.11.2026., Ivor) bez granice cijene: idu svi oglasi iz Zagreba
    v_m2 := nullif(replace((regexp_match(s, '\\"value\\":\\"([^"\\]{0,40})\\",\\"formattedText\\":\\"[^"]*\\",\\"slug\\":\\"re_total_area\\"'))[1], ',', '.'), '')::numeric;
    v_sobe_raw := lower((regexp_match(s, '\\"value\\":\\"([^"\\]{0,40})\\",\\"formattedText\\":\\"[^"]*\\",\\"slug\\":\\"re_flat_room_number\\"'))[1]);
    v_pets := lower((regexp_match(s, '\\"value\\":\\"([^"\\]{0,40})\\",\\"formattedText\\":\\"[^"]*\\",\\"slug\\":\\"re_pets_allowed\\"'))[1]);
    v_ter := (regexp_match(s, '\\"value\\":\\"([^"\\]{0,40})\\",\\"formattedText\\":\\"[^"]*\\",\\"slug\\":\\"re_terrace_number\\"'))[1];
    v_opis := lower(coalesce((regexp_match(s, '\\"description\\":\\"(.*?)\\",\\"category\\"'))[1], ''));
    v_title := (regexp_match(s, '^\d+,\\"title\\":\\"([^"\\]*)\\"'))[1];
    v_active := coalesce((regexp_match(s, '\\"active\\":(true|false)'))[1] = 'true', true);

    v_sobe := case
      when v_sobe_raw is null then null
      when v_sobe_raw like 'garson%' then 'Garsonijera'
      when split_part(split_part(v_sobe_raw, '-', 1), ',', 1) ~ '^\d+$' then
        case split_part(split_part(v_sobe_raw, '-', 1), ',', 1) when '1' then '1-sobni' when '2' then '2-sobni' else '3-sobni+' end
      else null end;

    v_parts := case when array_position(v_names, 'Grad Zagreb') is not null
                    then v_names[array_position(v_names, 'Grad Zagreb')+1:array_length(v_names,1)]
                    else v_names[2:array_length(v_names,1)] end;
    if v_parts is null then v_parts := '{}'; end if;
    if array_length(v_parts,1) = 2 and lower(v_parts[2]) = lower(v_parts[1]) then v_parts := v_parts[1:1]; end if;
    v_kv := array_to_string(v_parts, ', ');
    v_sub := case when array_length(v_parts,1) is null then 'Zagreb' else v_parts[array_length(v_parts,1)] end;
    v_kvart := nullif(btrim(split_part(v_kv, ',', 1)), '');
    v_dio := nullif(btrim(substr(v_kv, strpos(v_kv, ',') + 1)), '');
    if strpos(v_kv, ',') = 0 then v_dio := null; end if;

    v_te := coalesce(v_ter ~ '^\d+$' and v_ter::int > 0, false) or v_opis ~ 'teras|vrt\y|vrtom';
    v_bp := v_opis ~ 'bez provizij|nema provizij|bez agencij';
    v_lj := case v_pets when 'da' then 'Da' when 'ne' then 'Ne' else 'Ne piše' end;
    v_nap := case
      when v_cijena is null or v_cijena <= 1 then 'Cijena nije navedena'
      when v_m2 is not null and v_m2 > 0 and (v_cijena / v_m2 < 6 or v_m2 < 20 or v_m2 >= 300)
        then 'Sumnjivo: cijena/m² neobična (možda soba, cijena po osobi ili greška u oglasu)'
      else null end;
    v_naslov := coalesce(rtrim(v_sobe, '+'), 'Stan') || ', ' || v_sub
                || case when v_m2 is not null then ', ' || round(v_m2)::text || ' m²' else '' end;
    v_ob := timezone('Europe/Zagreb', timezone('UTC', to_timestamp(v_pub, 'DD.MM.YYYY HH24:MI:SS')));

    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'izvorni_id', v_id,
      'link', 'https://www.oglasnik.hr/stanovi-najam/stan-oglas-' || v_id,
      'naslov', v_naslov,
      'cijena', case when v_cijena > 1 then v_cijena else null end,
      'm2', v_m2,
      'sobe', v_sobe,
      'kvart', v_kvart,
      'dio_kvarta', v_dio,
      'ljubimci', v_lj,
      'vrt_terasa', v_te,
      'bez_provizije', v_bp,
      'objavljeno', v_ob,
      'napomena', v_nap,
      'grupa', 'Oglasnik',
      'aktivan', v_active
    ));
  end loop;
  return v_out;
end;
$function$
