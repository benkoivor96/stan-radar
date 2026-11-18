# StanRadar — kod

Ovdje je samo kod StanRadara, s poviješću promjena. **Izvor istine za opis sustava je Notion**: stranica Agent Radar i baza Što imamo (Atlas / StanRadar). Tamo su i Inbox, Opaske, Log, Verzije i Klijenti.

| Mapa | Što je | Odakle |
| --- | --- | --- |
| `index.html` | Web stranica „Svi oglasi” (Cloudflare, stan-radar.ivorbenko.workers.dev) | već je bila ovdje |
| `supabase/functions/` | Edge Functions `index-dohvati` i `index-aktivnost` | Supabase projekt stanradar |
| `supabase/sql/` | Jedna datoteka po funkciji u schemi `public` (`pg_get_functiondef`), `cron.sql` (raspored pg_cron), `prava.sql` (RLS, pravila, grantovi za anon) | izvučeno iz baze |
| `skripte/` | Python, SQL i JS za preglednik (scrape, upis, odabir, liste, mail) | Notion stranica „Skripte (scrape, Supabase, mail, liste)” |

Ključevi i lozinke nisu u repou. U `cron.sql` je anon ključ zamijenjen s `<ANON_KEY>`.

Kod u bazi i u Supabaseu je ono što stvarno radi. Kad se funkcija ili raspored promijeni u bazi, ovdje se ponovno izvuče i commita.
