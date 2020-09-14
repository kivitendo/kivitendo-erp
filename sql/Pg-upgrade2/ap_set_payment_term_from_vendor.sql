-- @tag: ap_set_payment_term_from_vendor
-- @description: Zahlungsbedingungen in EK-Rechnungen aus Lieferant setzen
-- @depends: release_3_5_6

UPDATE ap SET payment_id = (SELECT payment_id FROM vendor WHERE vendor.id = ap.vendor_id)
  WHERE (SELECT payment_id FROM vendor WHERE vendor.id = ap.vendor_id) IS NOT NULL
    AND ap.payment_id IS NULL;
