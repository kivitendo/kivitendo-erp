-- @tag: drop_payment_terms_ranking
-- @description: Entfernt Spalte ranking in payment_terms
-- @depends: release_3_5_3

ALTER TABLE payment_terms DROP COLUMN ranking;
