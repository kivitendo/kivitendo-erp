-- @tag: tax_reverse_charge_key_19
-- @description: Reverse Charge für Kreditorenbelege Steuerschlüssel 19
-- @depends: release_3_6_0
-- @ignore: 0

UPDATE tax set rate=0.19 where taxkey=94 AND reverse_charge_chart_id is not NULL;

INSERT INTO chart (
  accno, description,
  charttype,   category,  link,
  taxkey_id
  )
SELECT
  '1774','Umsatzsteuer aus innergemeinschftl. Erwerb 19%',
  'A',         'I',       'AR_tax:IC_taxpart:IC_taxservice',
  0
WHERE EXISTS ( -- update only for SKR03
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR03EU' AND NOT EXISTS (SELECT id from chart where accno='1774')
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
  (SELECT id FROM chart WHERE accno = '1574'),
  (SELECT id FROM chart WHERE accno = '1774'), 0.19,
  '19', 'Stpf. innergemeinschaftlicher Erwerb zum vollem Vor- und Ust.-satz', 'EI'
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
  (SELECT id FROM chart WHERE accno = '1404'),
  (SELECT id FROM chart WHERE accno = '3804'), 0.19,
  '19', 'Stpf. innergemeinschaftlicher Erwerb zum vollem Vor- und Ust.-satz', 'EI'
WHERE EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
);

-- if not defined
insert into taxkeys(chart_id,tax_id,taxkey_id,startdate) SELECT (SELECT reverse_charge_chart_id FROM tax WHERE taxkey = '19' and rate = 0.19 and reverse_charge_chart_id is not null),0,0,'1970-01-01' WHERE NOT EXISTS
  (SELECT chart_id from taxkeys where chart_id = ( SELECT reverse_charge_chart_id FROM tax WHERE taxkey = '19' and rate = 0.19 and reverse_charge_chart_id is not null));
-- if not defined
insert into taxkeys(chart_id,tax_id,taxkey_id,startdate) SELECT (SELECT chart_id FROM tax WHERE taxkey = '19' and rate = 0.19 and reverse_charge_chart_id is not null),0,0,'1970-01-01' WHERE NOT EXISTS
  (SELECT chart_id from taxkeys where chart_id = ( SELECT chart_id FROM tax WHERE taxkey = '19' and rate = 0.19 and reverse_charge_chart_id is not null));

