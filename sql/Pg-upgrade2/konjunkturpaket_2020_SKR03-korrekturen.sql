-- @tag: konjunkturpaket_2020_SKR03-korrekturen
-- @description: Steuerkonten haben selber keine Steuerautomatik. USTVA-Felder korrigieren
-- @depends: konjunkturpaket_2020_SKR03 konjunkturpaket_2020
-- @ignore: 0

DO $$
BEGIN

IF ( select coa from defaults ) = 'Germany-DATEV-SKR03EU' THEN

  -- DEBUG
  -- Konto 1771 ist in DATEV vom Typ S und hat keine Steuerautomatik S 1771 Umsatzsteuer 7 %
  -- Weitere Liste Konten von diesem (s.u.) -> Steuerkonten haben selber keine Automatik
  -- Der Eintrag wird leider für die pos_ustva benötigt (die könnte besser in tabelle tax sein)
  -- S 1771 Umsatzsteuer 7 %
  -- S 1772 Umsatzsteuer aus innergemeinschaftlichem Erwerb
  -- S 1774 Umsatzsteuer aus innergemeinschaftlichem Erwerb 19 %
  -- S 1775 Umsatzsteuer 16 %
  -- S 1776 Umsatzsteuer 19 %
  -- S 1777 Umsatzsteuer aus im Inland steuerpflichtigen EU-Lieferungen
  -- S 1778 Umsatzsteuer aus im Inland steuerpflichtigen EU-Lieferungen 19 %
  -- S 1779 Umsatzsteuer aus innergemeinschaftlichem Erwerb ohne Vorsteuerabzug
  UPDATE taxkeys SET tax_id=0,taxkey_id=0 WHERE chart_id IN
    (SELECT id FROM chart WHERE accno in ('1771','1772','1774','1775','1776','1777','1778','1779'));
  -- Alle temporären Steuer auf Pos. 36
  UPDATE taxkeys SET pos_ustva=36 WHERE chart_id IN
    (SELECT id FROM chart WHERE accno in ('1773'));

  -- Alle temporären 5% und 16% Erlöskonten auf Pos. 35
  -- select accno from chart where id in (select chart_id from taxkeys where tax_id in (select id from tax where taxkey=2 and rate=0.05) and pos_ustva=86) order by accno;
  -- accno
  -- 2401  8300  8506  8591  8710  8731  8750  8780  8915  8930  8945
  UPDATE taxkeys SET pos_ustva=35 WHERE tax_id in (SELECT id FROM tax WHERE taxkey=2 AND rate=0.05) AND pos_ustva=86;
  --  select accno from chart where id in (select chart_id from taxkeys where tax_id in (select id from tax where taxkey=3 and rate=0.16) and pos_ustva=81) order by accno;
  -- accno
 -- 2405  2700  2750  8400 8500 8508 8540 8595 8600 8720 8735 8736 8760 8790 8800 8801 8820 8910 8920 8925 8935 8940
 UPDATE taxkeys SET pos_ustva=35 WHERE tax_id in (SELECT id FROM tax WHERE taxkey=3 AND rate=0.16) and pos_ustva=81;

END IF;

END $$;
