-- @tag: datev_export_format
-- @description: Setzt die ausgehende Formatierung des DATEV-Exports
-- @depends: release_3_5_1

CREATE TYPE datev_export_format_enum AS ENUM ('cp1252', 'cp1252-translit', 'utf-8');

ALTER TABLE defaults ADD COLUMN datev_export_format datev_export_format_enum default 'cp1252-translit';

