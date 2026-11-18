CREATE OR REPLACE FUNCTION public.oglasnik_aktivnost_obradi(p_oznaci boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  z record;
  r record;
  v_val text;
  v_akt boolean;
  v_gr text;
  v_prev boolean;
  v_ukupno int := 0; v_neaktivnih int := 0; v_gresaka int := 0; v_oznaceno int := 0; v_ceka int := 0;
begin
  for z in select * from oglas_provjere where not obradjeno order by id loop
    select status_code, content, error_msg into r from net._http_response where id = z.request_id;
    if not found then
      if z.napravljeno < now() - interval '10 minutes' then
        update oglas_provjere set obradjeno = true, greska = 'odgovor nikad nije stigao' where id = z.id;
        v_gresaka := v_gresaka + 1;
      end if;
      continue;
    end if;
    v_ukupno := v_ukupno + 1;
    v_akt := null; v_gr := null;
    if r.status_code in (404, 410) then
      v_akt := false;
    elsif r.status_code = 200 and r.content is not null then
      v_val := (regexp_match(r.content, '\\\"active\\\":(true|false)'))[1];
      if v_val is not null then
        v_akt := (v_val = 'true');
      elsif position('koja više ne postoji' in r.content) > 0 then
        v_akt := false;
      else
        v_gr := 'nema active polja';
      end if;
    else
      v_gr := coalesce(r.error_msg, 'http ' || r.status_code);
    end if;
    update oglas_provjere set obradjeno = true, aktivan = v_akt, http = r.status_code, greska = v_gr where id = z.id;
    if v_gr is not null then v_gresaka := v_gresaka + 1; end if;
    if v_akt is false then
      v_neaktivnih := v_neaktivnih + 1;
      -- oznaci tek kad je i prethodna uspjesna provjera bila negativna
      select p.aktivan into v_prev from oglas_provjere p
        where p.oglas_id = z.oglas_id and p.obradjeno and p.id < z.id and p.aktivan is not null
        order by p.id desc limit 1;
      if p_oznaci and v_prev is false then
        perform oznaci_neaktivan(z.oglas_id, 'uklonjeno');
        update oglas_provjere set oznaceno = true where id = z.id;
        v_oznaceno := v_oznaceno + 1;
      else
        v_ceka := v_ceka + 1;
      end if;
    end if;
  end loop;
  delete from oglas_provjere where obradjeno and napravljeno < now() - interval '14 days';
  return jsonb_build_object('obradeno', v_ukupno, 'neaktivnih', v_neaktivnih, 'ceka_drugu_provjeru', v_ceka, 'gresaka', v_gresaka, 'oznaceno', v_oznaceno);
end;
$function$
