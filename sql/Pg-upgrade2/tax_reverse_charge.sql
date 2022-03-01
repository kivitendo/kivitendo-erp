-- @tag: tax_reverse_charge
-- @description: Reverse Charge für Kreditorenbelege
-- @depends: release_3_5_0
-- @ignore: 0

ALTER TABLE tax add column reverse_charge_chart_id integer;

INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '1577','Abziehbare Vorst. nach §13b UstG 19%',
  'A',         'E',       'AP_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU' AND NOT EXISTS (SELECT id from chart where accno='1577')
);

INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '1787','Umsatzsteuer nach §13b UStG 19%',
  'A',         'I',       'AR_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU' AND NOT EXISTS (SELECT id from chart where accno='1787')
);


INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '1407','Abziehbare Vorst. nach §13b UstG 19%',
  'A',         'E',       'AP_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU' AND NOT EXISTS (SELECT id from chart where accno='1407')
);

INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '3837','Umsatzsteuer nach §13b UStG 19%',
  'A',         'I',       'AR_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU' AND NOT EXISTS (SELECT id from chart where accno='3837')
);



INSERT INTO tax (
  chart_id,
  reverse_charge_chart_id,
  rate,
  taxkey,
  taxdescription,
  chart_categories
  )
  SELECT
  (SELECT id FROM chart WHERE accno = '1577'),
  (SELECT id FROM chart WHERE accno = '1787'), 0,
  '94', '19% Vorsteuer und 19% Umsatzsteuer', 'EI'
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU'
);


INSERT INTO tax (
  chart_id,
  reverse_charge_chart_id,
  rate,
  taxkey,
  taxdescription,
  chart_categories
  )
  SELECT
  (SELECT id FROM chart WHERE accno = '1407'),
  (SELECT id FROM chart WHERE accno = '3837'), 0,
  '94', '19% Vorsteuer und 19% Umsatzsteuer', 'EI'
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
);

;
-- if not defined
insert into taxkeys(chart_id,tax_id,taxkey_id,startdate) SELECT (SELECT chart_id FROM tax WHERE taxkey = '94'),0,0,'1970-01-01' WHERE NOT EXISTS
  (SELECT chart_id from taxkeys where chart_id = ( SELECT chart_id FROM tax WHERE taxkey = '94'));

insert into taxkeys(chart_id,tax_id,taxkey_id,startdate) SELECT (SELECT reverse_charge_chart_id FROM tax WHERE taxkey = '94'),0,0,'1970-01-01' WHERE NOT EXISTS
  (SELECT chart_id from taxkeys where chart_id = ( SELECT reverse_charge_chart_id FROM tax WHERE taxkey = '94'));

