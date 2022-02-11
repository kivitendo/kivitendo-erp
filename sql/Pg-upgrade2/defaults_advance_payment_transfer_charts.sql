-- @tag: defaults_advance_payment_transfer_charts
-- @description: Standardkonten für erhaltene versteuerte Anzahlungen 7% und 19% setzen
-- @depends:new_chart_3260_1711 new_chart_3272_1718


ALTER TABLE defaults ADD COLUMN advance_payment_taxable_19_id INTEGER;
ALTER TABLE defaults ADD COLUMN advance_payment_taxable_7_id  INTEGER;

DO $$
BEGIN

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR03EU' THEN
    DECLARE
      clearing_accno text := '1718';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE clearing_accno ) = 1 THEN
        UPDATE defaults SET advance_payment_taxable_19_id = (SELECT id FROM chart WHERE accno LIKE clearing_accno);
      END IF;
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR04EU' THEN
    DECLARE
      clearing_accno text := '3272';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE clearing_accno ) = 1 THEN
        UPDATE defaults SET advance_payment_taxable_19_id = (SELECT id FROM chart WHERE accno LIKE clearing_accno);
      END IF;
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR03EU' THEN
    DECLARE
      clearing_accno text := '1711';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE clearing_accno ) = 1 THEN
        UPDATE defaults SET advance_payment_taxable_7_id = (SELECT id FROM chart WHERE accno LIKE clearing_accno);
      END IF;
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR04EU' THEN
    DECLARE
      clearing_accno text := '3260';

    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE clearing_accno ) = 1 THEN
        UPDATE defaults SET advance_payment_taxable_7_id = (SELECT id FROM chart WHERE accno LIKE clearing_accno);
      END IF;
    END;
  END IF;


END $$;
