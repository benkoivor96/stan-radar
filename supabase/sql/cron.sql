-- StanRadar · raspored (pg_cron), izvučeno iz cron.job 18.11.2026. (oglasnik-puni-* i oglasnik-oznaci-nevidljive dodani 18.11.)
-- Svi poslovi active = true. Anon JWT u naredbama zamijenjen s <ANON_KEY> (pravi ključ nije u repou).

select cron.schedule('oglasnik-dohvati', '*/5 * * * *', $cmd$select public.oglasnik_dohvati(3)$cmd$);

select cron.schedule('oglasnik-obradi', '1-59/5 * * * *', $cmd$select public.oglasnik_obradi()$cmd$);

select cron.schedule('oglasnik-aktivnost-dohvati', '3-58/5 * * * *', $cmd$select public.oglasnik_aktivnost_dohvati(10)$cmd$);

select cron.schedule('oglasnik-aktivnost-obradi', '4-59/5 * * * *', $cmd$select public.oglasnik_aktivnost_obradi(true)$cmd$);

select cron.schedule('oglasnik-puni-4', '30 3 * * *', $cmd$select public.oglasnik_puni(4, 13)$cmd$);

select cron.schedule('oglasnik-puni-14', '31 3 * * *', $cmd$select public.oglasnik_puni(14, 23)$cmd$);

select cron.schedule('oglasnik-puni-24', '32 3 * * *', $cmd$select public.oglasnik_puni(24, 30)$cmd$);

select cron.schedule('oglasnik-oznaci-nevidljive', '0 4 * * *', $cmd$select public.oglasnik_oznaci_nevidljive()$cmd$);

select cron.schedule('index-dohvati', '2-57/5 * * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"stranice":2}'::jsonb, timeout_milliseconds := 90000)$cmd$);

select cron.schedule('index-aktivnost', '4-59/5 * * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-aktivnost',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"n":10}'::jsonb, timeout_milliseconds := 120000)$cmd$);

select cron.schedule('index-puni-1', '10 3 * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"od":1,"stranice":10}'::jsonb, timeout_milliseconds := 150000)$cmd$);

select cron.schedule('index-puni-11', '13 3 * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"od":11,"stranice":10}'::jsonb, timeout_milliseconds := 150000)$cmd$);

select cron.schedule('index-puni-21', '16 3 * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"od":21,"stranice":10}'::jsonb, timeout_milliseconds := 150000)$cmd$);

select cron.schedule('index-puni-31', '19 3 * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"od":31,"stranice":10}'::jsonb, timeout_milliseconds := 150000)$cmd$);

select cron.schedule('index-puni-41', '22 3 * * *', $cmd$select net.http_post(
  url := 'https://kmrohlnmqlobugixppxh.supabase.co/functions/v1/index-dohvati',
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
  body := '{"od":41,"stranice":10}'::jsonb, timeout_milliseconds := 150000)$cmd$);
