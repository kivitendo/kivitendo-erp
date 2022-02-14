-- @tag: new_chart_1593_1495
-- @description: Neue Konten "Verrechnungskonto erhalt. Anzahl. bei Buchung über Debitorenkonto"
-- @depends: release_3_5_8


DO $$
BEGIN

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR03EU' THEN
    DECLARE
      new_accno text := '1593';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE new_accno ) = 0 THEN
        INSERT INTO chart (accno, description, charttype, category, link, taxkey_id)
          VALUES (new_accno, 'Verrechnungskonto erhalt. Anzahl. bei Buchung über Debitorenkonto','A', 'L', 'AR_amount', 0);
        INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, startdate)
          VALUES ((SELECT id FROM chart WHERE accno LIKE new_accno), 0, 0, '1970-01-01');
      END IF;
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR04EU' THEN
    DECLARE
      new_accno text := '1495';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE new_accno ) = 0 THEN
        INSERT INTO chart (accno, description, charttype, category, link, taxkey_id)
          VALUES (new_accno, 'Verrechnungskonto erhalt. Anzahl. bei Buchung über Debitorenkonto','A', 'L', 'AR_amount', 0);
        INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, startdate)
          VALUES ((SELECT id FROM chart WHERE accno LIKE new_accno), 0, 0, '1970-01-01');
      END IF;
    END;
  END IF;

END $$;
