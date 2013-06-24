-- @tag: convert_curr_to_text
-- @description: Spalte 'curr' von 'char(3)' nach 'text' konvertieren
-- @depends: release_2_7_0

-- Zuerst alle Spaltentypen konvertieren.
ALTER TABLE ap              ALTER COLUMN curr TYPE text;
ALTER TABLE ar              ALTER COLUMN curr TYPE text;
ALTER TABLE customer        ALTER COLUMN curr TYPE text;
ALTER TABLE delivery_orders ALTER COLUMN curr TYPE text;
ALTER TABLE exchangerate    ALTER COLUMN curr TYPE text;
ALTER TABLE rma             ALTER COLUMN curr TYPE text;
ALTER TABLE vendor          ALTER COLUMN curr TYPE text;

-- Eventuell falsche Inhalte (Leerzeichenpadding) auf leere Strings setzen.
UPDATE ap              SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);
UPDATE ar              SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);
UPDATE customer        SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);
UPDATE delivery_orders SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);
UPDATE exchangerate    SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);
UPDATE oe              SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);
UPDATE rma             SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);
UPDATE vendor          SET curr = '' WHERE (curr SIMILAR TO '^ +$') OR (curr IS NULL);

-- Nun noch die stored procedures anpassen.
CREATE OR REPLACE FUNCTION del_exchangerate() RETURNS trigger
  LANGUAGE plpgsql
  AS $$
    DECLARE
      t_transdate date;
      t_curr      text;
      t_id        int;
      d_curr      text;
    BEGIN
      SELECT INTO d_curr substring(curr FROM '[^:]*') FROM DEFAULTS;

      IF TG_RELNAME = 'ar' THEN
        SELECT INTO t_curr, t_transdate curr, transdate FROM ar WHERE id = old.id;
      END IF;

      IF TG_RELNAME = 'ap' THEN
        SELECT INTO t_curr, t_transdate curr, transdate FROM ap WHERE id = old.id;
      END IF;

      IF TG_RELNAME = 'oe' THEN
        SELECT INTO t_curr, t_transdate curr, transdate FROM oe WHERE id = old.id;
      END IF;

      IF TG_RELNAME = 'delivery_orders' THEN
        SELECT INTO t_curr, t_transdate curr, transdate FROM delivery_orders WHERE id = old.id;
      END IF;

      IF d_curr != t_curr THEN
        SELECT INTO t_id a.id FROM acc_trans ac
          JOIN ar a ON (a.id = ac.trans_id)
          WHERE (a.curr       = t_curr)
            AND (ac.transdate = t_transdate)
        EXCEPT SELECT a.id
          FROM ar a
          WHERE (a.id = old.id)

        UNION

        SELECT a.id
          FROM acc_trans ac
          JOIN ap a ON (a.id = ac.trans_id)
          WHERE (a.curr       = t_curr)
            AND (ac.transdate = t_transdate)
        EXCEPT SELECT a.id
          FROM ap a
          WHERE (a.id = old.id)

        UNION

        SELECT o.id
          FROM oe o
          WHERE (o.curr      = t_curr)
            AND (o.transdate = t_transdate)
        EXCEPT SELECT o.id
        FROM oe o
        WHERE (o.id = old.id)

        UNION

        SELECT dord.id
          FROM delivery_orders dord
          WHERE (dord.curr      = t_curr)
            AND (dord.transdate = t_transdate)
        EXCEPT SELECT dord.id
        FROM delivery_orders dord
        WHERE (dord.id = old.id);

        IF NOT FOUND THEN
          DELETE FROM exchangerate
          WHERE (curr      = t_curr)
            AND (transdate = t_transdate);
        END IF;
      END IF;

      RETURN old;
    END;
$$;

-- Und die stored procedure auch auf delivery_orders anwenden
CREATE TRIGGER del_exchangerate
    BEFORE DELETE ON delivery_orders
    FOR EACH ROW
    EXECUTE PROCEDURE del_exchangerate();
