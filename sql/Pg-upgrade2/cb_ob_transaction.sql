-- @tag: cb_ob_transaction
-- @description: Spalten f&uuml;r Er&ouml;ffnungs- und Schlussbilanzbuchungen
-- @depends: release_2_4_2
ALTER TABLE gl ADD COLUMN ob_transaction boolean;
ALTER TABLE gl ADD COLUMN cb_transaction boolean;
ALTER TABLE acc_trans ADD COLUMN ob_transaction boolean;
ALTER TABLE acc_trans ADD COLUMN cb_transaction boolean;