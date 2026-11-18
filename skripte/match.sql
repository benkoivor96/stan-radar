-- StanRadar: za svaki oglas nađi prvi pronađeni isti stan (glavni). Vraća "oglas cijena glavni cijena;..."
-- Pravilo: m² ±1, ista soba (ili prazno), cijena ±10 %, isti dio kvarta (ako oba imaju dio iza zareza) inače ista četvrt.
WITH t0 AS (SELECT substr(url,-32) u, "Cijena (€)" c, "m²" m, "Sobe" s, replace(lower("Kvart"),'ć','č') k,
  strftime('%m%d%H%M%S',"Prvi put viđeno") f, ifnull("date:Objavljeno:start",'') o
  FROM "collection://0f58cbdb-7209-43b8-b5e6-71e0d3233c6c" WHERE "m²" IS NOT NULL AND "Cijena (€)" > 1),
t AS (SELECT *, trim(CASE WHEN instr(k,',')>0 THEN substr(k,1,instr(k,',')-1) ELSE k END) d,
  CASE WHEN instr(k,',')>0 THEN trim(substr(k,instr(k,',')+1)) ELSE NULL END sb FROM t0),
r AS (SELECT a.u, a.c, (SELECT b.u||' '||b.c FROM t b WHERE b.u<>a.u AND abs(a.m-b.m)<=1
  AND (a.s=b.s OR a.s IS NULL OR b.s IS NULL) AND abs(a.c-b.c) <= 0.1*max(a.c,b.c)
  AND ((a.sb IS NOT NULL AND b.sb IS NOT NULL AND a.sb=b.sb) OR ((a.sb IS NULL OR b.sb IS NULL) AND (a.d=b.d OR a.d=b.sb OR a.sb=b.d)))
  AND (b.f<a.f OR (b.f=a.f AND (b.o<a.o OR (b.o=a.o AND b.u<a.u)))) ORDER BY b.f, b.o, b.u LIMIT 1) p FROM t a)
SELECT group_concat(u||' '||c||' '||p, ';') x, count(*) n FROM r WHERE p IS NOT NULL;
