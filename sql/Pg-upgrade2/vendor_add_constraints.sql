-- @tag: vendor_add_constraints
-- @description: Zusätzliche Fremdschlüssel für Sprache, Lieferantentyp und Zahlungskonditionen
-- @depends: release_2_6_3
-- @charset: utf-8
-- @ignore: 0

-- verwaiste Zahlungsbedingungen vorher entfernen
update vendor set payment_id = NULL where payment_id not in (select id from payment_terms);


ALTER TABLE vendor ADD FOREIGN KEY (payment_id) REFERENCES payment_terms (id);
ALTER TABLE vendor ADD FOREIGN KEY (language_id) REFERENCES language (id);
ALTER TABLE vendor ADD FOREIGN KEY (business_id) REFERENCES business (id);
