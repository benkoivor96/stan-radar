CREATE OR REPLACE FUNCTION public.notion_pid(u text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select substring(replace(lower(coalesce(u,'')),'-','') from '([0-9a-f]{32})')
$function$
