-- @tag: alter_default_shipped_qty_config
-- @description: Mandantenweite Konfiguration für das Verhalten von Liefermengenabgleich
-- @depends: release_3_5_6
UPDATE defaults SET shipped_qty_fill_up = 'f';


