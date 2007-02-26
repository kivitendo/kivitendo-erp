-- @tag: ustva_setup_2007_update_chart_taxkeys_tax_add_missing_tax_accounts
-- @description: Aktualisierung des Kontenrahmens SKR03, einfuegen der fehlenden Steuerkonten in die Tabelle taxkeys
-- @depends: ustva_setup_2007_update_chart_taxkeys_tax



--#############################################################
--#
--# Anpassungen Tabelle taxkeys
--#
--#############################################################


INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, '0', '0', '66', '1970-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno in  ('1571', '1575')
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

