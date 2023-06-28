-- @tag: purchase_basket_items
-- @description: Tabelle für den Dispositionsmanager
-- @depends: release_3_8_0
-- @ignore: 0

CREATE TABLE purchase_basket_items (
  id SERIAL   PRIMARY KEY,
  part_id     INTEGER REFERENCES parts(id),
  orderer_id  INTEGER REFERENCES employee(id),
  qty         NUMERIC(15,5) NOT NULL,
  cleared     BOOLEAN NOT NULL            DEFAULT FALSE,
  itime       TIMESTAMP without time zone DEFAULT now(),
  mtime       TIMESTAMP without time zone
);
CREATE TRIGGER mtime_purchase_basket_items
  BEFORE UPDATE ON purchase_basket_items
  FOR EACH ROW EXECUTE PROCEDURE set_mtime();
