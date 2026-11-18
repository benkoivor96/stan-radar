select izvor, grupa,
  max(case when izvor in ('njuskalo','oglasnik') and izvorni_id ~ '^\d+$' then izvorni_id::bigint end) as max_id,
  max(objavljeno) as zadnja_objava,
  max(prvi_put_vidjen) as zadnji_upis,
  (array_agg(izvorni_id order by objavljeno desc nulls last))[1:5] as zadnji_idjevi
from oglasi group by izvor, grupa order by izvor, grupa;
