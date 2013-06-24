-- @tag: tax_description_without_percentage
-- @description: SKR03: Die Prozentangaben aus der tax.taxdescription entfernen. (Unter Berücksichtigung der Druckausgabe.)
-- @depends: fix_taxdescription



--#############################################################
--#
--# Taxdescription setzen
--#
--#############################################################

UPDATE tax SET 
  taxdescription = 'USt-frei'
WHERE taxkey = '1'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Umsatzsteuer' 
WHERE taxkey = '2'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Umsatzsteuer' 
WHERE taxkey = '3'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;


UPDATE tax SET 
  taxdescription = 'Vorsteuer' 
WHERE taxkey = '8'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Vorsteuer' 
WHERE taxkey = '9'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Im anderen EU-Staat steuerpflichtige Lieferung' 
WHERE taxkey = '10'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Steuerfreie innergem. Lieferung an Abnehmer mit Id.-Nr.' 
WHERE taxkey = '11'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Steuerpflichtige EG-Lieferung zum ermäßigten Steuersatz' 
WHERE taxkey = '12'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;


UPDATE tax SET 
  taxdescription = 'Steuerpflichtige EG-Lieferung zum vollen Steuersatz' 
WHERE taxkey = '13'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;


UPDATE tax SET 
  taxdescription = 'Steuerpflichtiger innergem. Erwerb zum ermäßigten Steuersatz' 
WHERE taxkey = '18'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Steuerpflichtiger innergem. Erwerb zum vollen Steuersatz'
WHERE taxkey = '19'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;
