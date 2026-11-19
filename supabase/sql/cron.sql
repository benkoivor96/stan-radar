-- StanRadar · raspored (pg_cron), izvučeno iz cron.job 19.11.2026.
-- 19.11.: noćni oglasnik-puni-*, index-puni-* i *-oznaci-nevidljive zamijenjeni nalozima punog prolaza (puni-prolaz-*), 03 i 15 h (vrijeme UTC u rasporedu).
-- Svi poslovi active = true. Anon JWT u naredbama zamijenjen s <ANON_KEY> (pravi ključ nije u repou).

select cron.schedule('oglasnik-dohvati', '*/5 * * * *', $cmd$select public.oglasnik_dohvati(3)$cmd$);

select cron.schedule('oglasnik-obradi', '1-59/5 * * * *', $cmd$select public.oglasnik_obradi()$cmd$);

select cron.schedule('oglasnik-aktivnost-dohvati', '3-58/5 * * * *', $cmd$select public.oglasnik_aktivnost_dohvati(10)$cmd$);

select cron.schedule('oglasnik-aktivnost-obradi', '4-59/5 * * * *', $cmd$select public.oglasnik_aktivnost_obradi(true)$cmd$);

select cron.schedule('index-dohvati', '2-57/5 * * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"stranice":2}'::jsonb, timeout_milliseconds := 90000)$cmd$);

select cron.schedule('index-aktivnost', '4-59/5 * * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-aktivnost',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"n":20}'::jsonb, timeout_milliseconds := 120000)$cmd$);

select cron.schedule('puni-prolaz-korak', '* * * * *', $cmd$select public.puni_prolaz_korak()$cmd$);

select cron.schedule('puni-prolaz-raspored', '0 2,14 * * *', $cmd$insert into public.puni_prolaz_nalozi (izvor, pokrenuo) values ('index', 'raspored'), ('oglasnik', 'raspored'), ('njuskalo', 'raspored')$cmd$);
