# StanRadar Njuškalo (Chrome ekstenzija)

Njuškalo se ne može čitati sa servera (Radware: zahtjevi koji nisu iz preglednika idu na captchu). Zato listu čita ova ekstenzija u Ivorovom Chromeu, u jednoj prikvačenoj kartici njuskalo.hr, i šalje je u StanRadar (Supabase).

## Što radi
- **svake minute:** puls bazi (`njuskalo_puls`). Ako postoji nalog (raspored 03 i 15 h ili gumb „Puni prolaz” na webu `?admin`), čita svih ~163 stranice liste Grad Zagreb (2 s pauze), stranicu po stranicu (`njuskalo_upis_stranice`), i na kraju javi „gotovo”. Provjeru portal = viđeno i gašenje radi baza (`puni_prolaz_korak`), isto kao za Index i Oglasnik.
- **svakih 5 min:** brzi krug, stranice 1–2 (najnoviji). Za oglase bez detalja otvara stranicu oglasa (sobe, ljubimci, terasa, provizija), najviše 5 po krugu i 150 dnevno (`njuskalo_za_detalje`, `njuskalo_upis_detalja`).
- **captcha:** odmah stane, javi bazi (alarm na webu), na ikoni crveni `!`. Klik na ikonu otvori karticu Njuškala da captchu riješiš ručno. Ništa se ne zaobilazi.
- Ključ baze nije u kodu: ekstenzija ga jednom pročita s javne stranice StanRadara (isti javni ključ koji koristi web).

## Instalacija (jednom)
1. Chrome → adresa `chrome://extensions`
2. gore desno uključi **Developer mode**
3. **Load unpacked** → odaberi folder `ekstenzija/njuskalo`
4. (preporuka) prikvači ikonu StanRadar Njuškalo na alatnu traku

Ekstenzija sama otvori prikvačenu karticu Njuškala i za otprilike minutu se javi bazi (na webu `?admin`: „Radnik spojen”).

## Ikona
- prazno = sve u redu (prelazak mišem: zadnji krug / prolaz)
- `…` plavo = puni prolaz u tijeku
- `!` crveno = captcha (klikni ikonu i riješi je)
- `ERR` narančasto = greška (prelazak mišem: koja)

## Ograničenje
Radi samo dok je Chrome otvoren, a računalo budno. Kad nije, nalog čeka (30 min, onda greška i alarm, ništa se ne gasi).

## Nova verzija
Promijeni datoteke u ovom folderu → `chrome://extensions` → kod StanRadar Njuškalo klikni ↻ (Reload).
