-- @tag: defaults_advance_payment_clearing_chart_id
-- @description: Voreingestelltes Konto für Verrechnung von Anzahlungen
-- @depends: new_chart_1593_1495

ALTER TABLE defaults ADD COLUMN advance_payment_clearing_chart_id INTEGER;

DO $$
BEGIN

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR03EU' THEN
    DECLARE
      clearing_accno text := '1593';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE clearing_accno ) = 1 THEN
        UPDATE defaults SET advance_payment_clearing_chart_id = (SELECT id FROM chart WHERE accno LIKE clearing_accno);
      END IF;
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR04EU' THEN
    DECLARE
      clearing_accno text := '1495';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE clearing_accno ) = 1 THEN
        UPDATE defaults SET advance_payment_clearing_chart_id = (SELECT id FROM chart WHERE accno LIKE clearing_accno);
      END IF;
    END;
  END IF;

END $$;
