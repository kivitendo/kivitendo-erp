-- @tag: defaults_set_ARAP
-- @description: Standardkonten für Forderungen und Verbindlichkeiten sind jetzt Pflichtfelder
-- @depends: release_3_9_0
DO $$
BEGIN

  IF (select 1 from defaults where ap_chart_id is null) THEN
    BEGIN
        UPDATE defaults set ap_chart_id = (select id from chart where link ='AP' order by id LIMIT 1);
    END;
  END IF;
  IF (select 1 from defaults where ar_chart_id is null) THEN
    BEGIN
        UPDATE defaults set ar_chart_id = (select id from chart where link ='AR' order by id LIMIT 1);
    END;
  END IF;
END $$;

ALTER TABLE defaults ALTER COLUMN ap_chart_id set not null;
ALTER TABLE defaults ALTER COLUMN ar_chart_id set not null;
