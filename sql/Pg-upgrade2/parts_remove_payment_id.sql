-- @tag: parts_remove_payment_id
-- @description: Zahlungsbedinungen an Artikel-Stammdaten entfernt
-- @depends: release_4_1_0

ALTER TABLE parts DROP COLUMN payment_id;
