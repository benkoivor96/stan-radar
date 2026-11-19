-- StanRadar · prava (RLS, pravila, grantovi za anon), izvučeno iz baze 18.11.2026.
-- Složeno iz kataloga (pg_class.relrowsecurity, pg_policies, information_schema.role_table_grants,
-- information_schema.column_privileges, has_function_privilege). Opis stanja, ne migracija za pokretanje.

-- 1) RLS po tablicama (schema public, 16 tablica). FORCE RLS nije uključen ni na jednoj.
alter table public.backup_20261113_funkcije  enable row level security;
alter table public.backup_20261113_oglasi    enable row level security;
alter table public.backup_20261113_poslano   enable row level security;
alter table public.backup_20261113_stanovi   enable row level security;
-- public.backup_20261117_funkcije: RLS ISKLJUČEN
alter table public.backup_20261117b_funkcije enable row level security;
alter table public.izvori                    enable row level security;
alter table public.klijenti                  enable row level security;
alter table public.oglas_dogadaji            enable row level security;
alter table public.oglas_provjere            enable row level security;
alter table public.oglasi                    enable row level security;
alter table public.oglasnik_mjerenje         enable row level security;
alter table public.poslano                   enable row level security;
alter table public.scrape_runs               enable row level security;
alter table public.scrape_zahtjevi           enable row level security;
alter table public.stanovi                   enable row level security;

-- 2) Pravila (policy) — jedno
create policy web_citanje_oglasa on public.oglasi as permissive for select to anon using (true);

-- 3) Grantovi za anon — tablica oglasi, samo stupci (stranica Svi oglasi)
grant select (id, izvor, link, naslov, cijena, m2, sobe, kvart, dio_kvarta, ljubimci, vrt_terasa, broj_obnova, izdvojen,
              bez_provizije, objavljeno, obnovljeno, prvi_put_vidjen, status, napomena, nije_novo)
  on public.oglasi to anon;

-- 4) Grantovi za anon — cijele tablice (DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE)
grant all on public.backup_20261113_funkcije  to anon;
grant all on public.backup_20261113_oglasi    to anon;
grant all on public.backup_20261113_poslano   to anon;
grant all on public.backup_20261113_stanovi   to anon;
grant all on public.backup_20261117_funkcije  to anon;
grant all on public.backup_20261117b_funkcije to anon;
grant all on public.izvori                    to anon;
grant all on public.klijenti                  to anon;
grant all on public.oglas_dogadaji            to anon;
grant all on public.oglasnik_mjerenje         to anon;
grant all on public.poslano                   to anon;
grant all on public.scrape_runs               to anon;
grant all on public.stanovi                   to anon;
-- viewovi
grant all on public.v_aktivni         to anon;
grant all on public.v_nije_u_notionu  to anon;
grant all on public.v_novo_danas      to anon;
grant all on public.v_po_izvoru       to anon;
grant all on public.v_scrape_krugovi  to anon;
-- oglas_provjere i scrape_zahtjevi: anon nema prava.

-- 5) Funkcije koje anon smije pokrenuti
grant execute on function public.notion_pid(text)            to anon;
grant execute on function public.stanradar_alarmi()          to anon;
grant execute on function public.sync_notion(text, jsonb)    to anon;

-- 19.11.2026.: puni prolaz (nalozi). Tablica puni_prolaz_nalozi: RLS uključen, bez politika.
-- Web (anon) samo kroz funkcije; zasad otvoreno svima (Ivor: zaštita kasnije, opaska u Notionu).
grant execute on function public.pokreni_puni_prolaz(text) to anon, authenticated;
grant execute on function public.puni_prolaz_pregled() to anon, authenticated;
revoke execute on function public.puni_prolaz_korak() from public, anon, authenticated;
revoke execute on function public.puni_prolaz_provjera(text, timestamptz, timestamptz) from public, anon, authenticated;
-- 19.11.2026.: upis Njuškalo liste iz preglednika (zasad otvoreno, zaštita kasnije)
grant execute on function public.njuskalo_upis_stranice(jsonb, text, integer, integer) to anon, authenticated;
-- 19.11.2026.: radnik za Njuškalo (ekstenzija u Chromeu); radnik_puls RLS bez politika; zasad otvoreno, zaštita kasnije
grant execute on function public.njuskalo_puls(text, bigint, integer, integer, text, text) to anon, authenticated;
grant execute on function public.njuskalo_za_detalje(integer) to anon, authenticated;
grant execute on function public.njuskalo_upis_detalja(jsonb) to anon, authenticated;
