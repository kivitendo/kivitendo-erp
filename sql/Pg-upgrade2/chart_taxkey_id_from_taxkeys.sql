-- @tag: chart_taxkey_id_from_taxkeys
-- @description: chart.taxkey_id aus taxkeys aktualisieren
-- @depends: release_2_6_2
UPDATE chart
SET taxkey_id = (
  SELECT taxkey_id
  FROM taxkeys
  WHERE taxkeys.chart_id = chart.id
  ORDER BY startdate DESC
  LIMIT 1
);
