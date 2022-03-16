-- @tag: tax_reverse_charge_key_18
-- @description: Reverse Charge für Kreditorenbelege Steuerschlüssel 18
-- @depends: release_3_6_0
-- @ignore: 0

INSERT INTO tax (
  chart_id,
  reverse_charge_chart_id,
  rate,
  taxkey,
  taxdescription,
  chart_categories
  )
  SELECT
  (SELECT id FROM chart WHERE accno = '1572'),
  (SELECT id FROM chart WHERE accno = '1772'), 0.07,
  '18', 'Stpf. innergemeinschaftlicher Erwerb zum verminderten Vor- und Ust.-satz', 'EI'
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
  (SELECT id FROM chart WHERE accno = '1402'),
  (SELECT id FROM chart WHERE accno = '3802'), 0.07,
  '18', 'Stpf. innergemeinschaftlicher Erwerb zum verminderten Vor- und Ust.-satz', 'EI'
WHERE EXISTS ( -- update only for SKR04
    SELECT coa FROM defaults
    WHERE defaults.coa='Germany-DATEV-SKR04EU'
);


-- if not defined
insert into taxkeys(chart_id,tax_id,taxkey_id,startdate) SELECT (SELECT reverse_charge_chart_id FROM tax WHERE taxkey = '18' and rate = 0.07 and reverse_charge_chart_id is not null),0,0,'1970-01-01' WHERE NOT EXISTS
  (SELECT chart_id from taxkeys where chart_id = ( SELECT reverse_charge_chart_id FROM tax WHERE taxkey = '18' and rate = 0.07 and reverse_charge_chart_id is not null));
-- if not defined
insert into taxkeys(chart_id,tax_id,taxkey_id,startdate) SELECT (SELECT chart_id FROM tax WHERE taxkey = '18' and rate = 0.07 and reverse_charge_chart_id is not null),0,0,'1970-01-01' WHERE NOT EXISTS
  (SELECT chart_id from taxkeys where chart_id = ( SELECT chart_id FROM tax WHERE taxkey = '18' and rate = 0.07 and reverse_charge_chart_id is not null));

