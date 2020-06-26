-- @tag: konjunkturpaket_2020_SKR03
-- @description: Anpassung des Deutschen DATEV-Kontenrahmen für SKR03 Konjunkturpaket
-- @depends: release_3_5_5
-- @ignore: 0

-- TODO:
-- how to deal with old 16% charts in SKR03?
-- A) move to their correct taxkeys, 5 and 8, like for SKR04
--    and then create new versions of 3 and 9 with same taxkey
-- UST 5%, already exists in SKR03, so rename it, but also add new taxkeys

-- DEBUG

DO $$
BEGIN

IF ( select coa from defaults ) = 'Germany-DATEV-SKR03EU' THEN

  UPDATE tax SET taxdescription = 'OLD ' || taxdescription WHERE (taxkey = 3 or taxkey = 9) and rate = 0.16;

  -- rename some of the charts
  UPDATE chart SET description = 'Umsatzsteuer 5 %' where accno = '1773';

  -- rename charts if they weren't 't already changed
  UPDATE chart SET description = 'Erlöse 19 % / 16 % USt' where accno = '8400' and description = 'Erlöse 16%/19% USt.';
  UPDATE chart SET description = 'Erlöse 7 % / 5 % USt'   where accno = '8300' and description = 'Erlöse 7%USt';

  -- move old 16% taxkeys to their proper taxkeys, should be 5 and 7
  UPDATE tax SET taxkey = 5 WHERE taxkey = 3 and rate = 0.16;
  UPDATE tax SET taxkey = 7 WHERE taxkey = 9 and rate = 0.16;


  -- new charts
  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik)
         VALUES ('8732','Gewährte Skonti 5% USt','A', 'I', 'AR_paid', 2, 1, null,1, 't');

  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik)
         VALUES ('3732','Erhaltene Skonti 5 % Vorsteuer','A', 'E', 'AP_paid', 8, 4, null, null, 't');

  -- SKR03
  -- datev reactivated the previously reserved chart 1775 in 2020, but it still exists in kivitendo (at least for SKR03) with a taxkey starting from 2007 and pointing to the existing automatic tax chart 1775
  -- so we don't need to to anything!
  --       3 | 0.16000 | Umsatzsteuer                                                 | 1775  | Umsatzsteuer 16%

  -- rename old 8735 to 8736
  UPDATE chart SET accno = '8736', description = 'Gewährte Skonti 19 % USt' where accno = '8735' and description = 'Gewährte Skonti 16%/19% USt.';
  -- create new 8735 with 16%

  -- create new 16% chart for Gewährte Skonti
  INSERT INTO chart(accno,                description, charttype, category,      link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik, pos_er)
            VALUES ('8735','Gewährte Skonti 16 % USt',       'A',      'I', 'AR_paid',         3,       1,       null,       1,            't',      1);

  -- create new chart for Abziehbare Vorsteuer 5 % with taxkey 8
  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik, pos_er)
         VALUES ('1568','Abziehbare Vorsteuer 5 %','A', 'E', 'AP_tax:IC_taxpart:IC_taxservice', 8, null, null, 27, 't', 27);

  -- taxkeys can't be inserted until the new taxes exist

  INSERT INTO tax (chart_id, rate, taxkey, taxdescription, chart_categories, skonto_sales_chart_id, skonto_purchase_chart_id)
  VALUES ( (select id from chart where accno = '1773'), 0.05, 2, 'Umsatzsteuer', 'I', (select id from chart where accno = '8732'), null),
         ( (select id from chart where accno = '1775'), 0.16, 3, 'Umsatzsteuer', 'I', (select id from chart where accno = '8735'), null),
         ( (select id from chart where accno = '1575'), 0.16, 9, 'Vorsteuer',    'E', null, (select id from chart where accno = '3735')),
         ( (select id from chart where accno = '1568'), 0.05, 8, 'Vorsteuer',    'E', null, (select id from chart where accno = '3732'));

  UPDATE tax SET skonto_sales_chart_id = (select id from chart where accno = '8735') where taxkey = 3 and rate = 0.16 and skonto_sales_chart_id is null;

  -- new taxkeys for 5% and 16% only need one startdate, not valid before and won't change back to anything later
  -- these taxkeys won't be valid on 2020-06-30, so won't be affected later by big taxkeys update
  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '8732'), (select id from tax where rate = 0.05 and taxkey = 2 and chart_id = (select id from chart where accno = '1773')), 2, 861, '2020-07-01');

  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '8735'), (select id from tax where rate = 0.16 and taxkey = 3 and chart_id = (select id from chart where accno = '1775')), 3, 81, '2020-07-01');

  -- INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  --              VALUES ( (select id from chart where accno = '8400'), (select id from tax where rate = 0.16 and taxkey = 3 and chart_id = (select id from chart where accno = '1775')), 3, 81, '2020-07-01'); -- is 81 correct, or 51?

  -- INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
  --              VALUES ( (select id from chart where accno = '8400'), (select id from tax where rate = 0.19 and taxkey = 3 and chart_id = (select id from chart where accno = '1776')), 3, 81, '2021-01-01');

  -- the taxkeys for the existing charts will be updated in a later update
END IF;

END $$;


-- select t.taxkey,
--       t.rate,
--       t.taxdescription,
--       c.accno,
--       c.description
--  from tax t
--       left join chart c on (c.id = t.chart_id)
--order by t.taxkey;
-- taxkey |  rate   |                        taxdescription                        | accno |                  description
----------+---------+--------------------------------------------------------------+-------+------------------------------------------------
--      0 | 0.00000 | Keine Steuer                                                 | ☠     | ☠
--      1 | 0.00000 | USt-frei                                                     | ☠     | ☠
--      2 | 0.07000 | Umsatzsteuer                                                 | 1771  | Umsatzsteuer 7%
--      3 | 0.19000 | Umsatzsteuer                                                 | 1776  | Umsatzsteuer 19 %
--      3 | 0.16000 | Umsatzsteuer                                                 | 1775  | Umsatzsteuer 16%
--      8 | 0.07000 | Vorsteuer                                                    | 1571  | Abziehbare Vorsteuer 7%
--      9 | 0.16000 | Vorsteuer                                                    | 1575  | Abziehbare Vorsteuer 16%
--      9 | 0.19000 | Vorsteuer                                                    | 1576  | Abziehbare Vorsteuer 19 %
--     10 | 0.00000 | Im anderen EU-Staat steuerpflichtige Lieferung               | 1767  | Im anderen EG-Staat steuerpfl. Lieferung
--     11 | 0.00000 | Steuerfreie innergem. Lieferung an Abnehmer mit Id.-Nr.      | ☠     | ☠
--     12 | 0.07000 | Steuerpflichtige EG-Lieferung zum ermäßigten Steuersatz      | 1772  | Umsatzsteuer 7% innergem.Erwerb
--     13 | 0.19000 | Steuerpflichtige EG-Lieferung zum vollen Steuersatz          | 1774  | Umsatzsteuer aus innergem. Erwerb 19 %
--     13 | 0.16000 | Steuerpflichtige EG-Lieferung zum vollen Steuersatz          | 1773  | Umsatzsteuer 16% innergem.Erwerb
--     18 | 0.07000 | Steuerpflichtiger innergem. Erwerb zum ermäßigten Steuersatz | 1572  | Abziehbare Vorsteuer 7% innergem. Erwerb
--     19 | 0.19000 | Steuerpflichtiger innergem. Erwerb zum vollen Steuersatz     | 1574  | Abziehbare Vorsteuer aus innergem. Erwerb 19 %
--     19 | 0.16000 | Steuerpflichtiger innergem. Erwerb zum vollen Steuersatz     | 1572  | Abziehbare Vorsteuer 7% innergem. Erwerb
