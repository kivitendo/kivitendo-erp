-- @tag: language_output_formatting
-- @description: Speichern des Ausgabeformates f&uuml;r Zahlen und Datumsangaben bei jeder Sprache.
-- @depends:
ALTER TABLE language ADD COLUMN output_numberformat text;
ALTER TABLE language ADD COLUMN output_dateformat text;
ALTER TABLE language ADD COLUMN output_longdates boolean;
