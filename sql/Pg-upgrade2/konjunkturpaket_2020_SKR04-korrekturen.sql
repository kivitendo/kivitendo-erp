-- @tag: konjunkturpaket_2020_SKR04-korrekturen
-- @description: USTVA-Felder korrigieren
-- @depends: konjunkturpaket_2020_SKR04
-- @ignore: 0

DO $$
BEGIN

IF ( select coa from defaults ) = 'Germany-DATEV-SKR04EU' THEN

  -- Alle temporären Steuer auf Pos. 36
  UPDATE taxkeys SET pos_ustva=36 WHERE chart_id IN
    (SELECT id FROM chart WHERE accno in ('3803','3805'));

  -- Alle temporären 5% und 16% Erlöskonten auf Pos. 35
  -- select accno from chart where id in (select chart_id from taxkeys where tax_id in (select id from tax where taxkey=2 and rate=0.05) and pos_ustva=86) order by accno;
  -- accno
  -- 4300 4566 4610 4630 4670 4710 4731 4750 4780 4941 6281
  UPDATE taxkeys SET pos_ustva=35 WHERE tax_id in (SELECT id FROM tax WHERE taxkey=2 AND rate=0.05) AND pos_ustva=86;
  --  select accno from chart where id in (select chart_id from taxkeys where tax_id in (select id from tax where taxkey=3 and rate=0.16)) order by accno;
  -- accno
  -- 4400 4500 4510 4520 4569 4620 4640 4660 4680 4686 4720 4736 4760 4790 4830 4835 4849 4860 4945 6286 6287

 UPDATE taxkeys SET pos_ustva=35 WHERE tax_id in (SELECT id FROM tax WHERE taxkey=3 AND rate=0.16);

END IF;

END $$;
