-- @tag: ustva_setup_2007
-- @description: Aktualisierung des SKR03 für 2006
-- @depends: customer_vendor_taxzone_id  

update taxkeys set pos_ustva='81' where startdate='2007-01-01' 
  AND pos_ustva ='51'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
      WHERE defaults.coa='Germany-DATEV-SKR03EU'
  );


UPDATE taxkeys SET pos_ustva='511' 
  WHERE startdate='1970-01-01' 
  AND chart_id = (select id from chart where accno ='1775')
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
      WHERE defaults.coa='Germany-DATEV-SKR03EU'
  );  


INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, tax.id, taxkey_id, '811', '2007-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno = '1776'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
      WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;
