-- @tag: add_customer_reduction_terms
-- @description: Textfeld für Vereinbarung zur Entgeltminderung bei Kunden
-- @depends: release_4_0_0

ALTER TABLE customer ADD COLUMN reduction_terms TEXT;
