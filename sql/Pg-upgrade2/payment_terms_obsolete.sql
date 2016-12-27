-- @tag: payment_terms_obsolete
-- @description: Zahlungsbedingungen ungültig setzen
-- @charset: UTF-8
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE payment_terms ADD COLUMN obsolete BOOLEAN DEFAULT FALSE;
