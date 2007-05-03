-- @tag: COA_Account_Settings001
-- @description: Aktualisierung des SKR03
-- @depends: release_2_4_2  

UPDATE taxkeys 
  SET pos_ustva='861',
      tax_id=(SELECT id FROM tax WHERE taxkey='2'),
      taxkey_id='2'
  WHERE startdate='1970-01-01' 
  AND chart_id = (SELECT id FROM chart WHERE accno ='1771')
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
      WHERE defaults.coa='Germany-DATEV-SKR03EU'
  );  

