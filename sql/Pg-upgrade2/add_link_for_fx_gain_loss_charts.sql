-- @tag: add_link_for_fx_gain_loss_charts
-- @description: Kursdifferenzen am Beleg buchen benötigt Aufnahme in Zahlungs-Dropdown
-- @depends: release_3_8_0


DO $$
BEGIN

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR03EU' THEN
    DECLARE
      gain_chart text := '2660';
      loss_chart text := '2150';

    BEGIN
        UPDATE chart set link ='AR_paid:AP_paid' where accno in (gain_chart, loss_chart);
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR04EU' THEN
    DECLARE
      gain_chart text := '4840';
      loss_chart text := '6880';
    BEGIN
        UPDATE chart set link ='AR_paid:AP_paid' where accno in (gain_chart, loss_chart);
    END;
  END IF;

END $$;
