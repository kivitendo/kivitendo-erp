-- @tag: oe_delivery_orders_foreign_keys
-- @description: Fremdschlüsseldefinitionen für oe und delivery_orders
-- @depends: release_3_0_0
ALTER TABLE oe ALTER COLUMN department_id DROP DEFAULT;

UPDATE oe              SET cp_id                = NULL WHERE (cp_id                IS NOT NULL) AND (cp_id                NOT IN (SELECT cp_id     FROM contacts));
UPDATE oe              SET delivery_customer_id = NULL WHERE (delivery_customer_id IS NOT NULL) AND (delivery_customer_id NOT IN (SELECT id        FROM customer));
UPDATE oe              SET delivery_vendor_id   = NULL WHERE (delivery_vendor_id   IS NOT NULL) AND (delivery_vendor_id   NOT IN (SELECT id        FROM vendor));
UPDATE oe              SET department_id        = NULL WHERE (department_id        IS NOT NULL) AND (department_id        NOT IN (SELECT id        FROM department));
UPDATE oe              SET language_id          = NULL WHERE (language_id          IS NOT NULL) AND (language_id          NOT IN (SELECT id        FROM language));
UPDATE oe              SET payment_id           = NULL WHERE (payment_id           IS NOT NULL) AND (payment_id           NOT IN (SELECT id        FROM payment_terms));
UPDATE oe              SET shipto_id            = NULL WHERE (shipto_id            IS NOT NULL) AND (shipto_id            NOT IN (SELECT shipto_id FROM shipto));

UPDATE delivery_orders SET department_id        = NULL WHERE (department_id        IS NOT NULL) AND (department_id        NOT IN (SELECT id        FROM department));
UPDATE delivery_orders SET shipto_id            = NULL WHERE (shipto_id            IS NOT NULL) AND (shipto_id            NOT IN (SELECT shipto_id FROM shipto));

ALTER TABLE oe              ADD FOREIGN KEY (cp_id)                REFERENCES contacts      (cp_id);
ALTER TABLE oe              ADD FOREIGN KEY (delivery_customer_id) REFERENCES customer      (id);
ALTER TABLE oe              ADD FOREIGN KEY (delivery_vendor_id)   REFERENCES vendor        (id);
ALTER TABLE oe              ADD FOREIGN KEY (department_id)        REFERENCES department    (id);
ALTER TABLE oe              ADD FOREIGN KEY (language_id)          REFERENCES language      (id);
ALTER TABLE oe              ADD FOREIGN KEY (payment_id)           REFERENCES payment_terms (id);
ALTER TABLE oe              ADD FOREIGN KEY (shipto_id)            REFERENCES shipto        (shipto_id);

ALTER TABLE delivery_orders ADD FOREIGN KEY (department_id)        REFERENCES department    (id);
ALTER TABLE delivery_orders ADD FOREIGN KEY (shipto_id)            REFERENCES shipto        (shipto_id);
