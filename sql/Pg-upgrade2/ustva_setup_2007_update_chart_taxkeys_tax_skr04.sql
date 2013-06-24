-- @tag: ustva_setup_2007_update_chart_taxkeys_tax_skr04
-- @description: Anpassung der UStVA-Schlüssel für Konten 3801, 3806, 3804 und 4400
-- @depends: release_2_7_0

-- 3806 - neuer Eintrag pos_ustva 811 ab 2007 (falls noch nicht existiert)
-- 3801 - neuer Eintrag pos_ustva 861 ab 2007 (falls noch nicht existiert)
-- 4400 - pos_ustva von 51 auf 81 für Eintrag 2007
-- 3804 - pos_ustva Eintrag 891 ab 2007

INSERT INTO taxkeys (
  chart_id, pos_ustva, startdate)                                                                                                                        
  SELECT chart.id, '811', '2007-01-01'
  FROM chart                                                                                                                                                                  LEFT JOIN tax ON (chart.id = tax.chart_id)                                                                                                                                
  WHERE chart.accno = '3806'                                                                                                                                                
  AND                                                                                                                                                                       
  EXISTS ( -- update only for SKR04                                                                                                                                         
    SELECT coa FROM defaults
      WHERE defaults.coa='Germany-DATEV-SKR04EU'                                                                                                                            
  AND NOT EXISTS (
   select * from taxkeys where chart_id = (select id from chart where accno = '3806') and pos_ustva = '811' and startdate = '2007-01-01' )
  )                                                                                                                                                                         
;         

INSERT INTO taxkeys (
  chart_id, pos_ustva, startdate)                                                                                                                        
  SELECT chart.id, '861', '2007-01-01'
  FROM chart                                                                                                                                                                  LEFT JOIN tax ON (chart.id = tax.chart_id)                                                                                                                                
  WHERE chart.accno = '3801'                                                                                                                                                
  AND                                                                                                                                                                       
  EXISTS ( -- update only for SKR04                                                                                                                                         
    SELECT coa FROM defaults
      WHERE defaults.coa='Germany-DATEV-SKR04EU'                                                                                                                            
  AND NOT EXISTS (
   select * from taxkeys where chart_id = (select id from chart where accno = '3801') and pos_ustva = '861' and startdate = '2007-01-01' )
  )                                                                                                                                                                         
;         

UPDATE taxkeys SET pos_ustva = '81'
WHERE chart_id = (SELECT id FROM chart WHERE accno = '4400')
AND startdate = '2007-01-01'
AND pos_ustva = '51'
AND EXISTS ( 
  SELECT coa FROM defaults 
  WHERE defaults.coa='Germany-DATEV-SKR04EU'
);

-- insert taxkey for 3804, but leave taxkey_id empty, because Kivitendo can't
-- handle this automatic booking and tax has to be booked manually
-- don't insert this key with this startdate if it already exists (was already added manually)
INSERT INTO taxkeys (
  chart_id, pos_ustva, startdate)                                                                                                                        
  SELECT chart.id, '891', '2007-01-01'
  FROM chart                                                                                                                                                                  LEFT JOIN tax ON (chart.id = tax.chart_id)                                                                                                                                
  WHERE chart.accno = '3804'                                                                                                                                                
  AND                                                                                                                                                                       
  EXISTS ( -- update only for SKR04                                                                                                                                         
    SELECT coa FROM defaults
      WHERE defaults.coa='Germany-DATEV-SKR04EU'                                                                                                                            
  AND NOT EXISTS (
   select * from taxkeys where chart_id = (select id from chart where accno = '3804') and pos_ustva = '891' and startdate = '2007-01-01' )
  );
