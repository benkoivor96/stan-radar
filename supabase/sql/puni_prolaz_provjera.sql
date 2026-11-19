CREATE OR REPLACE FUNCTION public.puni_prolaz_provjera(p_izvor text, p_od timestamp with time zone, p_do timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- (19.11.2026., Ivor) Je li puni prolaz u razdoblju p_od..p_do POTPUN. Samo tada se smiju gasiti oglasi koje prolaz nije vidio.
-- Potpun = 1) portal je javio koliko oglasa ima na listi (Index count, Oglasnik total liste Grad Zagreb, Njuškalo listingsCount),
--          2) svaka stranica od 1 do zadnje potrebne (ukupno / oglasa po stranici) ima uspješan dohvat na kojem portal ima oglase,
--          3) prolaz je vidio barem onoliko aktivnih oglasa koliko portal javlja (inače je nešto propušteno).
declare
  v_pref text := case p_izvor when 'index' then 'edge' when 'oglasnik' then 'cron' when 'njuskalo' then 'preglednik' end;
  v_po int := case p_izvor when 'index' then 50 when 'njuskalo' then 25 else 100 end;      -- oglasa po stranici
  v_max int := case p_izvor when 'index' then 60 when 'njuskalo' then 200 else 20 end;     -- do koje stranice prolaz smije čitati
  v_ukupno int; v_treba int; v_fale int[]; v_akt int; v_vidjeno int;
  v_razlog text;
begin
  if v_pref is null then raise exception 'nepoznat izvor %', p_izvor; end if;

  select max(portal_ukupno) into v_ukupno from scrape_runs
   where izvor = p_izvor and pocetak between p_od and p_do and portal_ukupno is not null
     and napomena ~ ('^' || v_pref || ' str \d+$');
  if v_ukupno is null then
    v_razlog := 'portal nije javio broj oglasa';
  else
    v_treba := greatest(1, ceil(v_ukupno::numeric / v_po)::int);
    if v_treba > v_max then
      v_razlog := 'portal ima ' || v_treba || ' stranica, prolaz čita do ' || v_max;
    else
      select coalesce(array_agg(g order by g), '{}') into v_fale
        from generate_series(1, v_treba) g
       where not exists (
         select 1 from scrape_runs s
          where s.izvor = p_izvor and s.uspjeh and coalesce(s.na_stranici, 0) > 0
            and s.pocetak between p_od and p_do
            and s.napomena = v_pref || ' str ' || g);
      if cardinality(v_fale) > 0 then
        v_razlog := 'stranice bez uspješnog dohvata: ' || array_to_string(v_fale, ', ');
      end if;
    end if;
  end if;

  select count(*), count(*) filter (where zadnji_put_vidjen >= p_od)
    into v_akt, v_vidjeno from oglasi where izvor = p_izvor and status = 'Aktivan';
  if v_razlog is null and v_vidjeno < v_ukupno then
    v_razlog := 'prolaz je vidio ' || v_vidjeno || ' od ' || v_ukupno || ' oglasa koje portal javlja';
  end if;

  return jsonb_build_object('potpun', v_razlog is null, 'razlog', v_razlog,
    'od', p_od, 'do', p_do, 'portal_ukupno', v_ukupno, 'stranica_treba', v_treba,
    'aktivnih', v_akt, 'vidjeno', v_vidjeno, 'nije_vidjeno', v_akt - v_vidjeno);
end;
$function$
