-- @tag: new_chart_3272_1718
-- @description: Neues Konto "Erhaltene, versteuerte Anzahlungen 19 % USt (Verbindlichkeiten)"
-- @depends: release_3_5_8


DO $$
BEGIN

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR03EU' THEN
    DECLARE
      new_accno text := '1718';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE new_accno ) = 0 THEN
        INSERT INTO chart (accno, description, charttype, category, link, taxkey_id)
          VALUES (new_accno, 'Erhaltene, versteuerte Anzahlungen 19 % USt (Verbindlichkeiten)','A', 'L', 'AR_amount', 0);
        INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, startdate)
          VALUES ((SELECT id FROM chart WHERE accno LIKE new_accno), 0, 0, '1970-01-01');
      END IF;
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR04EU' THEN
    DECLARE
      new_accno text := '3272';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE new_accno ) = 0 THEN
        INSERT INTO chart (accno, description, charttype, category, link, taxkey_id)
          VALUES (new_accno, 'Erhaltene, versteuerte Anzahlungen 19 % USt (Verbindlichkeiten)','A', 'L', 'AR_amount', 0);
        INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, startdate)
          VALUES ((SELECT id FROM chart WHERE accno LIKE new_accno), 0, 0, '1970-01-01');
      END IF;
    END;
  END IF;

END $$;
