-- @tag: defaults_add_feature_erfolgsrechnung_detailed
-- @description: Spalte in Einstellungen für die Schweizer Erfolgsrechnung (Detaillierte Variante) An/Aus
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN feature_erfolgsrechnung_detailed BOOLEAN NOT NULL DEFAULT FALSE;
