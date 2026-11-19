-- StanRadar · radnik za Njuškalo (19.11.2026., Ivor: Njuškalo kao Index i Oglasnik, s gumbom)
-- Njuškalo čita ekstenzija „StanRadar Njuškalo” u Ivorovom Chromeu (server ne može: Radware captcha). Baza joj daje naloge i prima stranice.
alter table public.puni_prolaz_nalozi drop constraint puni_prolaz_nalozi_izvor_check;
alter table public.puni_prolaz_nalozi add constraint puni_prolaz_nalozi_izvor_check check (izvor in ('index', 'oglasnik', 'njuskalo'));
alter table public.puni_prolaz_nalozi add column if not exists radnik text;   -- što je javio radnik: gotovo / captcha … / greska …
create table if not exists public.radnik_puls (
  izvor text primary key,
  zadnji_puls timestamptz not null default now(),
  verzija text,
  stanje text
);
alter table public.radnik_puls enable row level security;              -- bez politika: samo kroz njuskalo_puls / puni_prolaz_pregled
alter table public.oglasi add column if not exists detalj_at timestamptz;  -- kad je radnik pročitao stranicu oglasa (sobe, ljubimci, terasa, provizija)
