-- @tag: defaults_add_max_future_booking_intervall
-- @description: Fehleingaben für Buchungen in der Zukunft verhindern (s.a. 1897)
-- @depends: release_3_0_0

ALTER TABLE defaults ADD COLUMN  max_future_booking_interval integer DEFAULT 360;
