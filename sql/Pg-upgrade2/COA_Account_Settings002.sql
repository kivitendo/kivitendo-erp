-- @tag: COA_Account_Settings002
-- @description: Aktualisierung des SKR03, Bugfix 617
-- @depends: release_2_4_2  

UPDATE chart 
  SET pos_eur='6' 
  WHERE 
  accno = '1771'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
      WHERE defaults.coa='Germany-DATEV-SKR03EU'
  );  

