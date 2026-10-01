-- @tag: charts_cleared
-- @description: Ausziffern für Konten ermöglichen
-- @depends: release_4_1_0
-- @ignore: 0

CREATE TABLE cleared_group (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL REFERENCES employee(id),
  itime timestamp DEFAULT now()
);

-- deleting the cleared_group should remove all cleared entries
CREATE TABLE cleared (
  acc_trans_id      bigint UNIQUE NOT NULL REFERENCES acc_trans(acc_trans_id),
  cleared_group_id  int    NOT NULL REFERENCES cleared_group(id) ON DELETE CASCADE,
  primary key (cleared_group_id, acc_trans_id)
);

-- which charts should be activated for clearing
ALTER TABLE chart ADD COLUMN clearing BOOLEAN DEFAULT false NOT NULL;

-- AR/AP transactions and invoices delete and recreate their acc_trans entries
-- when they are posted again, cancelled or deleted. In that case the clearing
-- of the affected bookings is no longer valid, so the whole cleared group is
-- dissolved. The same happens if the amount or chart of a cleared booking is
-- changed.
CREATE OR REPLACE FUNCTION clearing_dissolve_cleared_group() RETURNS trigger AS $$
BEGIN
  DELETE FROM cleared_group
   WHERE id IN (SELECT cleared_group_id FROM cleared WHERE acc_trans_id = OLD.acc_trans_id);
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER acc_trans_dissolve_cleared_group_on_delete
  BEFORE DELETE ON acc_trans
  FOR EACH ROW EXECUTE PROCEDURE clearing_dissolve_cleared_group();

CREATE TRIGGER acc_trans_dissolve_cleared_group_on_update
  BEFORE UPDATE OF amount, chart_id ON acc_trans
  FOR EACH ROW
  WHEN (OLD.amount IS DISTINCT FROM NEW.amount OR OLD.chart_id IS DISTINCT FROM NEW.chart_id)
  EXECUTE PROCEDURE clearing_dissolve_cleared_group();
