-- @tag: record_template_payment_id
-- @description: Zahlungsbedingungen in Vorlagen in der Finanzbuchhaltung
-- @depends: release_3_5_6_1

ALTER TABLE record_templates ADD COLUMN payment_id INTEGER REFERENCES payment_terms(id);
