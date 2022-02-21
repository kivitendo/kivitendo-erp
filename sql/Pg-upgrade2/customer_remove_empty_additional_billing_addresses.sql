-- @tag: customer_remove_empty_additional_billing_addresses
-- @description: Leere »zusätzliche Rechnungsadressen« entfernen
-- @depends: customer_additional_billing_addresses
DELETE
FROM additional_billing_addresses
WHERE (coalesce(name,         '') = '')
  AND (coalesce(department_1, '') = '')
  AND (coalesce(department_2, '') = '')
  AND (coalesce(contact,      '') = '')
  AND (coalesce(street,       '') = '')
  AND (coalesce(zipcode,      '') = '')
  AND (coalesce(city,         '') = '')
  AND (coalesce(country,      '') = '')
  AND (coalesce(email,        '') = '')
  AND (coalesce(phone,        '') = '')
  AND (coalesce(fax,          '') = '');
