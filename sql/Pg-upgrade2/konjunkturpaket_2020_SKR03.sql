-- @tag: konjunkturpaket_2020_SKR03
-- @description: Anpassung des Deutschen DATEV-Kontenrahmen für SKR03 Konjunkturpaket
-- @depends: release_3_5_5
-- @ignore: 0

DO $$
BEGIN

IF ( select coa from defaults ) = 'Germany-DATEV-SKR03EU' THEN

  -- DEBUG
  -- UPDATE tax SET taxdescription = 'OLD ' || taxdescription WHERE (taxkey = 3 or taxkey = 9) and rate = 0.16;

  -- rename some of the charts, 1773 already exists in kivitendo as Umsatzsteuer 16% innergem.Erwerb
  -- this is being used by taxkey 13, which is called "Steuerpflichtige EG-Lieferung zum vollen Steuersatz" in kivitendo
  -- in DATEV taxkey 13 is: innergem. Lieferung ohne USt-IdNr. and should use a different chart
  UPDATE chart SET description = 'Umsatzsteuer 5 %' where accno = '1773';

  -- rename charts if they weren't already changed
  UPDATE chart SET description = 'Erlöse 19 % / 16 % USt' where accno = '8400' and description = 'Erlöse 16%/19% USt.';
  UPDATE chart SET description = 'Erlöse 7 % / 5 % USt'   where accno = '8300' and description = 'Erlöse 7%USt';

  -- there are two strategies for updating the taxkeys.

  -- 1) in any case we need to add the 2 new cases for 5%: 2/0.05/1773 and 8/0.05/1568

  -- 2) default kivi SKR03 already has the correct configuration for 16%, with two entries 3/0.16/1775 and 9/0.16/1575
  --   a) we could move those to 5 and 7, and then create new 3/0.16/1775 and 9/0.16/1575 entries
  --   b) simply keep those entries and don't use 5 and 7 (in which case ar/ap/gl must use deliverydate), or create 5 and 7 manually if needed

  -- strategy a:
  -- datev reactivated the previously reserved chart 1775 in 2020, but it still exists in kivitendo (at least for SKR03)
  -- with a taxkey starting from 2007 and pointing to the existing automatic tax chart 1775

  -- strategy b:
  -- UPDATE tax SET taxkey = 5 WHERE taxkey = 3 and rate = 0.16;
  -- UPDATE tax SET taxkey = 7 WHERE taxkey = 9 and rate = 0.16;

  -- rename old 8735 to 8736
  UPDATE chart SET accno = '8736', description = 'Gewährte Skonti 19 % USt' where accno = '8735' and description = 'Gewährte Skonti 16%/19% USt.';

  -- new charts, each of these will need a manual taxkey entry for 2020-07-01 after their tax entries are added
  -- 8732, 3732, 8735, 3737
  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik)
         VALUES ('8732','Gewährte Skonti 5% USt','A', 'I', 'AR_paid', 2, 1, null,1, 't');

  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik)
         VALUES ('3732','Erhaltene Skonti 5 % Vorsteuer','A', 'E', 'AP_paid', 8, 4, null, null, 't');

  -- create new 16% charts Skonto
  INSERT INTO chart(accno,                description, charttype, category,      link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik, pos_er)
            VALUES ('8735','Gewährte Skonti 16 % USt',       'A',      'I', 'AR_paid',         3,       1,       null,       1,            't',      1);

  INSERT INTO chart(accno,                description, charttype, category,       link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik, pos_er)
            VALUES ('3737','Erhaltene Skonti 16 % USt',       'A',      'E', 'AP_paid',         9,       4,       null,    null,            't',   null);

  -- create new chart for Abziehbare Vorsteuer 5 % with taxkey 8 for 3732
  INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_bwa, pos_bilanz, pos_eur, datevautomatik, pos_er)
         VALUES ('1568','Abziehbare Vorsteuer 5 %','A', 'E', 'AP_tax:IC_taxpart:IC_taxservice', 8, null, null, 27, 't', 27);
  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '1568'), 0, 0, 66, '1970-01-01');

  -- taxkeys can't be inserted until the new taxes exist

  -- new taxes:
  -- 5% cases for 2 Umsatzsteuer and 8 Vorsteuer
  INSERT INTO tax (chart_id, rate, taxkey, taxdescription, chart_categories, skonto_sales_chart_id, skonto_purchase_chart_id)
  VALUES ( (select id from chart where accno = '1773'), 0.05, 2, 'Umsatzsteuer', 'I', (select id from chart where accno = '8732'), null),
         -- don't add these two entries if we keep the original two 16% accounts, instead better to add new tax entries with taxkey 5 and 7
         -- ( (select id from chart where accno = '1775'), 0.16, 3, 'Umsatzsteuer', 'I', (select id from chart where accno = '8735'), null),
         -- ( (select id from chart where accno = '1575'), 0.16, 9, 'Vorsteuer',    'E', null, (select id from chart where accno = '3735')),
         ( (select id from chart where accno = '1568'), 0.05, 8, 'Vorsteuer',    'E', null, (select id from chart where accno = '3732'));

  UPDATE tax SET skonto_sales_chart_id    = (select id from chart where accno = '8735') where taxkey = 3 and rate = 0.16 and skonto_sales_chart_id    is null;
  UPDATE tax SET skonto_purchase_chart_id = (select id from chart where accno = '3737') where taxkey = 9 and rate = 0.16 and skonto_purchase_chart_id is null;

  -- new taxkeys for 5% charts only need one startdate, not valid before and won't change back to anything later
  -- these taxkeys won't be valid on 2020-06-30, so won't be affected later by big taxkeys update
  -- However, this will also cause opening the charts before 2020-07-01 via the
  -- interface to break, as AM.pm always calls get_active_taxkey and there won't
  -- be an active taxkey before 2020-07-01.
  -- Alternatively you could set those active from 2020-06-01 and in the taxkey upgrade script check for taxkey entries before that date
  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '8732'), (select id from tax where rate = 0.05 and taxkey = 2 and chart_id = (select id from chart where accno = '1773')), 2, 861, '2020-07-01');

  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '3732'), (select id from tax where rate = 0.05 and taxkey = 8 and chart_id = (select id from chart where accno = '1568')), 8, 861, '2020-07-01');

  -- 8735 / 3737 - these were never created in the original SKR03, so also start using them from 2020-07-01
  -- taxkey for Gewährte Skonti 16 % USt pointing to tax 1775 Umsatzsteuer 16%
  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '8735'), (select id from tax where rate = 0.16 and taxkey = 3 and chart_id = (select id from chart where accno = '1775')), 3, 81, '2020-07-01');

  -- taxkey for Erhaltene Skonti 16 % USt pointing to tax 1575 Vorsteuer 16%
  INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
               VALUES ( (select id from chart where accno = '3737'), (select id from tax where rate = 0.16 and taxkey = 9 and chart_id = (select id from chart where accno = '1575')), 9, 66, '2020-07-01');

END IF;

END $$;
