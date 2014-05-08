-- @tag: defaults_customer_hourly_rate
-- @description: defaults_customer_hourly_rate
-- @depends: requirement_specs
ALTER TABLE defaults ADD COLUMN customer_hourly_rate NUMERIC(8, 2);
UPDATE defaults SET customer_hourly_rate = 100.0;
