-- @tag: transfer_out_serial_charge_number
-- @description: Feld für das Feature "VK-Seriennummer ist Lager-Chargennummer".
-- @depends: release_3_5_6
ALTER TABLE defaults  ADD COLUMN sales_serial_eq_charge BOOLEAN NOT NULL DEFAULT FALSE;
