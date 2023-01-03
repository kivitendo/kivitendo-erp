-- @tag: seperate_table_for_onhand
-- @description: Verschiebe onhand in extra Tabelle
-- @depends: release_3_6_1
CREATE TABLE onhands (
  id INT NOT NULL DEFAULT nextval('id'),
  parts_id INT UNIQUE references parts(id) ON DELETE CASCADE,
  onhand NUMERIC(25,5),
  PRIMARY KEY (id)
);
-- lock all tables while updating values
LOCK TABLE onhands IN EXCLUSIVE MODE;
LOCK TABLE inventory IN EXCLUSIVE MODE;
LOCK TABLE parts IN EXCLUSIVE MODE;

CREATE OR REPLACE FUNCTION public.update_onhand()
  RETURNS trigger
  LANGUAGE plpgsql
AS '
BEGIN
  IF tg_op = "INSERT" THEN
    UPDATE onhands SET onhand = COALESCE(onhand, 0) + new.qty WHERE parts_id = new.parts_id;
    RETURN new;
  ELSIF tg_op = "DELETE" THEN
    UPDATE onhands SET onhand = COALESCE(onhand, 0) - old.qty WHERE parts_id = old.parts_id;
    RETURN old;
  ELSE
    UPDATE onhands SET onhand = COALESCE(onhand, 0) - old.qty + new.qty WHERE parts_id = old.parts_id;
    RETURN new;
  END IF;
END;
';

-- All parts get a onhand value;
CREATE OR REPLACE FUNCTION public.create_onhand()
  RETURNS trigger
  LANGUAGE plpgsql
AS '
BEGIN
  INSERT INTO onhands (parts_id, onhand) values (new.parts_id, 0);
END;
';

CREATE TRIGGER trig_create_onhand
  AFTER INSERT ON parts
  FOR EACH ROW EXECUTE PROCEDURE create_onhand();


INSERT INTO onhands (parts_id, onhand) SELECT id, onhand FROM parts;

ALTER TABLE parts DROP COLUMN onhand;
