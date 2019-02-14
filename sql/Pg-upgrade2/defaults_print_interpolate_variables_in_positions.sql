-- @tag: defaults_print_interpolate_variables_in_positions
-- @description: Drucken: Variablen in Belegpositionen interpolieren (abschaltbar via Mandantenkonfiguration)
-- @depends: release_3_5_8
ALTER TABLE defaults
ADD COLUMN print_interpolate_variables_in_positions BOOLEAN
DEFAULT TRUE NOT NULL;
