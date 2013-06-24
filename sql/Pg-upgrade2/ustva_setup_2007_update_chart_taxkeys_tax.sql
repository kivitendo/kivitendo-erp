-- @tag: ustva_setup_2007_update_chart_taxkeys_tax
-- @description: Aktualisierung des SKR03 für 2006/2007. Es werden bisher nur Inland Buchungen 16%/19% in 2006/2007 unterstützt.
-- @depends: ustva_setup_2007



--#############################################################
--#
--# Neue Konten einfügen
--#
--#############################################################


INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '1570','Anrechenbare Vorsteuer',
  'A',         'E',       'AP_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);


INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '1574','Abziehbare Vorsteuer aus innergem. Erwerb 19 %',
  'A',         'E',       'AP_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);


INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '1774','Umsatzsteuer aus innergem. Erwerb 19 %',
  'A',         'I',       'AR_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

UPDATE chart SET description = 'Umsatzsteuer 7% innergem.Erwerb'
WHERE accno='1772' 
AND  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

UPDATE chart SET description = 'Umsatzsteuer 16% innergem.Erwerb'
WHERE accno='1773' 
AND  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

UPDATE chart SET description = 'Abziehbare Vorsteuer 7% innergem. Erwerb'
WHERE accno='1572' 
AND  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

UPDATE chart SET description = 'Abziehbare Vorsteuer 16% innergem. Erwerb'
WHERE accno='1573' 
AND  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

UPDATE chart SET description = 'Innergem. Erwerb 16%/19% VSt u. USt.'
WHERE accno='3425' 
AND  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

UPDATE chart SET description = 'Innergem. Erwerb 7% VSt u. USt.'
WHERE accno='3420' 
AND  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

--INSERT INTO chart (
--  accno, description,
--  charttype,   category,  link
--  )
--SELECT
--  '3550','Steuerfreier innergem. Erwerb',
--  'A',         'E',       'AP_amount:IC_cogs'
--WHERE EXISTS ( -- update only for SKR03
--    SELECT coa FROM defaults
--    WHERE defaults.coa='Germany-DATEV-SKR03EU'
--);



--#############################################################
--#
--# Anpassungen Tabelle tax
--#
--#############################################################

-- Steuerkontenbenennung nach DATEV
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

-- Weitere Steuerschlüssel hinzufügen

INSERT INTO tax (
  chart_id, 
  taxnumber,
  rate, 
  taxkey,
  taxdescription 
  )
  SELECT (SELECT id FROM chart WHERE accno = '1774'), '1774', '0.19000', taxkey, taxdescription 
  FROM tax
  WHERE taxkey = '13'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;


INSERT INTO tax (
  chart_id, 
  rate, 
  taxnumber,
  taxkey,
  taxdescription 
  )
  SELECT (SELECT id FROM chart WHERE accno = '1574'), '0.19000', '1574', taxkey, taxdescription 
  FROM tax
  WHERE taxkey = '19'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;




--#############################################################
--#
--# Anpassungen Tabelle taxkeys
--#
--#############################################################


INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, (SELECT id FROM tax WHERE taxnumber = '1576'), '9', '66', '1970-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno = '1576'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, (SELECT id FROM tax WHERE taxnumber = '1574'), '19', '61', '1970-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno = '1574'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;


INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, '0', '0',  '891', '2007-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno = '1774'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

UPDATE taxkeys SET pos_ustva = '63'
WHERE chart_id in (SELECT id FROM chart WHERE accno in ('1577')
AND startdate = '1970-01-01')
AND EXISTS ( -- update only for SKR03
  SELECT coa FROM defaults 
  WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

UPDATE taxkeys SET pos_ustva = '67'
WHERE chart_id in (SELECT id FROM chart WHERE accno in ('1578', '1579')
AND startdate = '1970-01-01')
AND EXISTS ( -- update only for SKR03
  SELECT coa FROM defaults 
  WHERE defaults.coa='Germany-DATEV-SKR03EU'
);


INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, '0', '0', '66', '1970-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno in  ('1570', '1576')
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults 
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;


UPDATE taxkeys SET pos_ustva = '51'
WHERE chart_id in (SELECT id FROM chart WHERE accno in ('8520')
AND startdate = '1970-01-01')
AND 
EXISTS ( -- update only for SKR03
  SELECT coa FROM defaults 
  WHERE defaults.coa='Germany-DATEV-SKR03EU'
);

INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, (SELECT id FROM tax WHERE taxnumber = '1776'), '0', '36', '1970-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno = '1776'
  AND
  EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;
  
INSERT INTO taxkeys (
  chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  SELECT chart.id, (SELECT id FROM tax WHERE taxnumber = '1775'), '0', '36', '2007-01-01'
  FROM chart
  LEFT JOIN tax ON (chart.id = tax.chart_id)
  WHERE chart.accno = '1775'
  AND
  EXISTS ( -- update only for SKR03
  SELECT coa FROM defaults
   WHERE defaults.coa='Germany-DATEV-SKR03EU'
  )
;

