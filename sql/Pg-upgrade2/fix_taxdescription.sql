-- @tag: fix_taxdescription
-- @description: Durch das Update wurden in der Taxdescription die Prozentangabgen entfernt. Ist ungünstig für die Druckausgabe
-- @depends: ustva_setup_2007_update_chart_taxkeys_tax



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
  taxdescription = 'Umsatzsteuer 7%' 
WHERE taxkey = '2'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Umsatzsteuer 16%' 
WHERE taxkey = '3' AND rate=0.16
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Umsatzsteuer 19%' 
WHERE taxkey = '3' AND rate=0.19
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Vorsteuer 7%' 
WHERE taxkey = '8'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Vorsteuer 19%' 
WHERE taxkey = '9' AND rate=0.19
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Vorsteuer 16%' 
WHERE taxkey = '9' AND rate=0.16
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
  taxdescription = 'Steuerpflichtige EG-Lieferung zum ermäßigten Steuersatz 7%' 
WHERE taxkey = '12'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Steuerpflichtige EG-Lieferung zum vollen Steuersatz 16%' 
WHERE taxkey = '13' AND rate=0.16
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Steuerpflichtige EG-Lieferung zum vollen Steuersatz 19%' 
WHERE taxkey = '13' AND rate=0.19
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;


UPDATE tax SET 
  taxdescription = 'Steuerpflichtiger innergem. Erwerb zum ermäßigten Steuersatz 7%' 
WHERE taxkey = '18'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Steuerpflichtiger innergem. Erwerb zum vollen Steuersatz 19%'
WHERE taxkey = '19' and rate=0.19
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE tax SET 
  taxdescription = 'Steuerpflichtiger innergem. Erwerb zum vollen Steuersatz 16%'
WHERE taxkey = '19' and rate=0.16
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;
