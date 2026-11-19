CREATE OR REPLACE FUNCTION public.pokreni_puni_prolaz(p_izvor text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- (19.11.2026., Ivor) Gumb „Puni prolaz” na webu. Zasad otvoreno svima (Ivor: zaštita kasnije, opaska u Notionu).
-- Ne pokreće novi prolaz ako za taj portal prolaz već traje ili je završio prije manje od 15 min (da ne opterećujemo portal).
declare
  v_id bigint;
  v_zav timestamptz;
begin
  if p_izvor not in ('index', 'oglasnik') then
    return jsonb_build_object('ok', false, 'poruka', 'nepoznat portal');
  end if;
  if exists (select 1 from puni_prolaz_nalozi where izvor = p_izvor and status in ('ceka', 'dohvat')) then
    return jsonb_build_object('ok', false, 'poruka', 'prolaz već traje');
  end if;
  select max(zavrseno) into v_zav from puni_prolaz_nalozi where izvor = p_izvor and status in ('gotovo', 'greska');
  if v_zav > now() - interval '15 minutes' then
    return jsonb_build_object('ok', false, 'poruka',
      'zadnji prolaz je završio u ' || to_char(v_zav at time zone 'Europe/Zagreb', 'HH24:MI') ||
      ', novi se može pokrenuti od ' || to_char((v_zav + interval '15 minutes') at time zone 'Europe/Zagreb', 'HH24:MI'));
  end if;
  insert into puni_prolaz_nalozi (izvor, pokrenuo) values (p_izvor, 'gumb') returning id into v_id;
  return jsonb_build_object('ok', true, 'nalog', v_id, 'poruka', 'prolaz pokrenut');
end;
$function$
