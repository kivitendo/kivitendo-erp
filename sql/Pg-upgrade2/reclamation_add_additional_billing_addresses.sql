-- @tag: reclamation_add_additional_billing_addresses
-- @description: Kundenstammdaten: zusätzliche Rechnungsadressen auch in Reclamation
-- @depends: reclamations customer_additional_billing_addresses

ALTER TABLE reclamations
  ADD COLUMN billing_address_id INTEGER,
  ADD FOREIGN KEY (billing_address_id)
    REFERENCES additional_billing_addresses (id);
