-- StanRadar · nalozi punog prolaza (19.11.2026., Ivor: gumb na webu + 2× dnevno, isti put za raspored i gumb)
-- Jedan red = jedan puni prolaz jednog portala. Vodi ga puni_prolaz_korak() (pg_cron svake minute).
create table if not exists public.puni_prolaz_nalozi (
  id bigserial primary key,
  izvor text not null check (izvor in ('index', 'oglasnik')),
  pokrenuo text not null check (pokrenuo in ('raspored', 'gumb')),
  zatrazeno timestamptz not null default now(),
  poceto timestamptz,
  zavrseno timestamptz,
  status text not null default 'ceka' check (status in ('ceka', 'dohvat', 'gotovo', 'greska')),
  stranica_do int,
  poslano_do int not null default 0,
  zahtjevi bigint[] not null default '{}',
  zadnje_slanje timestamptz,
  ponovljeno int not null default 0,   -- koliko puta su ponovljene stranice koje fale (najviše 2)
  rezultat jsonb
);
create index if not exists puni_prolaz_nalozi_izvor_id on public.puni_prolaz_nalozi (izvor, id desc);
alter table public.puni_prolaz_nalozi enable row level security;
-- bez politika: web čita i pokreće samo kroz puni_prolaz_pregled() i pokreni_puni_prolaz()
