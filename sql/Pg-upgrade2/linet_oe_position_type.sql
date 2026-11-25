-- @tag: linet_oe_position_type
-- @description: LINET: Dummy-Script fürs Hinzufügen von Typen & Spalten, die im ersetzen Commit für Alternativpositionen in Angeboten erstellt wurden
-- @depends: release_4_1_0

CREATE TYPE record_item_type AS ENUM ('normal', 'alternative', 'optional');
ALTER TABLE orderitems ADD COLUMN item_type record_item_type DEFAULT 'normal';
