-- @tag: konjunkturpaket_2020_SKR04
-- @description: Anpassung des Deutschen DATEV-Kontenrahmen für SKR04 Konjunkturpaket
-- @depends: release_3_5_5 remove_double_tax_entries_skr04
-- @ignore: 0

DO $$
BEGIN

IF ( select coa from defaults ) = 'Germany-DATEV-SKR04EU' THEN

  -- charts 1403 und 3803 for 5% taxes already existed, reconfigure them
  UPDATE chart set description = 'Abziehbare Vorsteuer 5 %', taxkey_id = 8 where accno = '1403' and description = 'Abziehbare Vorsteuer aus innergemeinschftl. Erwerb 16%';
  UPDATE chart set description = 'Umsatzsteuer 5 %', taxkey_id = 2 where accno = '3803' and description = 'Umsatzsteuer aus innergemeinschftl. Erwerb 16%';

  -- DEBUG
  -- UPDATE tax SET taxdescription = 'OLD ' || taxdescription WHERE (taxkey = 5 or taxkey = 7); -- and rate = 0.16;

  UPDATE taxkeys SET tax_id = (SELECT id FROM tax WHERE taxkey = 5 and rate = 0.16)
   WHERE chart_id = (SELECT id FROM chart where accno = '4400')
     AND startdate = '1970-01-01';

  -- new charts for 5%
  -- 4732 and 5732
  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik)
         VALUES ('4732','Gewährte Skonti 5 % USt','A', 'I', 'AR_paid', 2, 1, null, 1, 't');
  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik)
         VALUES ('5732','Erhaltene Skonti 5 % Vorsteuer','A', 'E', 'AP_paid', 8, 4, null, null, 't');

  -- Gewährte and Erhaltene Skonti 16% already exist, but rename them
  UPDATE chart SET description = 'Gewährte Skonti 16%'  where accno = '4735' and description = 'Gewährte Skonti 16%/19% USt';
  UPDATE chart SET description = 'Erhaltene Skonti 16%' where accno = '4735' and description = 'Erhaltene Skonti 16%/19% USt';

  -- taxkeys can't be inserted until the new taxes exist
  INSERT INTO tax (chart_id, rate, taxkey, taxdescription, chart_categories, skonto_sales_chart_id, skonto_purchase_chart_id)
  VALUES ( (select id from chart where accno = '3803'), 0.05, 2, 'Umsatzsteuer', 'I', (select id from chart where accno = '4732'), null), -- ok
         ( (select id from chart where accno = '3805'), 0.16, 3, 'Umsatzsteuer', 'I', (select id from chart where accno = '4735'), null),
         ( (select id from chart where accno = '1405'), 0.16, 9, 'Vorsteuer',    'E', null, (select id from chart where accno = '5735')),
         ( (select id from chart where accno = '1403'), 0.05, 8, 'Vorsteuer',    'E', null, (select id from chart where accno = '5732'));

  -- new taxkeys for 5% and 16% only need one startdate, not valid before and won't change back to anything later
  -- these taxkeys won't be valid on 2020-06-30, so won't be affected later by big taxkeys update
  -- 4732 and 5732
  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '4732'),
                      ( select id from tax where rate = 0.05 and taxkey = 2 and chart_id = (select id from chart where accno = '3803')), 2, 861, '2020-07-01'); -- ustva_id like 3801, is this correct?

  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '5732'),
                      (select id from tax where rate = 0.05 and taxkey = 8 and chart_id = (select id from chart where accno = '1403')), 8, 66, '2020-07-01'); -- ustva_id like 1401, is this correct?

  -- the taxkeys for the existing charts will be updated in a later update
END IF;

END $$;
