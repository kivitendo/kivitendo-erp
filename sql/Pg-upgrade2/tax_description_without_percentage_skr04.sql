-- @tag: tax_description_without_percentage_skr04
-- @description: SKR04: Die Prozentangaben aus der tax.taxdescription entfernen. (Unter Ber&uuml;cksichtigung der Druckausgabe.)
-- @depends: ustva_setup_2007

--#############################################################
--#
--# Taxdescription setzen
--#
--#############################################################

UPDATE tax SET
  taxdescription = 'USt-frei'
WHERE taxkey = '1'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;

UPDATE tax SET
  taxdescription = 'Umsatzsteuer'
WHERE taxkey = '2'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;

UPDATE tax SET
  taxdescription = 'Umsatzsteuer'
WHERE taxkey = '3'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;


UPDATE tax SET
  taxdescription = 'Vorsteuer'
WHERE taxkey = '8'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;

UPDATE tax SET
  taxdescription = 'Vorsteuer'
WHERE taxkey = '9'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;

UPDATE tax SET
  taxdescription = 'Im anderen EU-Staat steuerpflichtige Lieferung'
WHERE taxkey = '10'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;

UPDATE tax SET
  taxdescription = 'Steuerfreie innergem. Lieferung an Abnehmer mit Id.-Nr.'
WHERE taxkey = '11'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;

UPDATE tax SET
  taxdescription = 'Steuerpflichtige EG-Lieferung zum ermäßigten Steuersatz'
WHERE taxkey = '12'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;


UPDATE tax SET
  taxdescription = 'Steuerpflichtige EG-Lieferung zum vollen Steuersatz'
WHERE taxkey = '13'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;


UPDATE tax SET
  taxdescription = 'Steuerpflichtiger innergem. Erwerb zum ermäßigten Steuersatz'
WHERE taxkey = '18'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;

UPDATE tax SET
  taxdescription = 'Steuerpflichtiger innergem. Erwerb zum vollen Steuersatz'
WHERE taxkey = '19'
  AND
  EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
  )
;
