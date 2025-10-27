-- @tag: shared_contacts
-- @description: Mehrfachzuordnung on Ansprechpartnern zu Kunden und Lieferanten
-- @depends: release_3_9_2


/* model: instead of having

  customer.id <-> contacts.cp_cv_id
  vendor.id   <-> contacts.cp_cv_id

  we now have a join table:

  customer_contacts:
    contacts.cp_id, customer_id
  vendor_contacts:
    contacts.cp_id, vendor_id

*/

create table customer_contacts (
  id serial primary key,
  customer_id integer references customer(id)    not null,
  contact_id  integer references contacts(cp_id) not null,

  unique(customer_id, contact_id)
);

create table vendor_contacts (
  id serial primary key,
  vendor_id  integer references vendor(id)      not null,
  contact_id integer references contacts(cp_id) not null,

  unique(vendor_id, contact_id)
);

create index on customer_contacts(customer_id);
create index on vendor_contacts(vendor_id);

-- migrate old contacts

insert into customer_contacts (customer_id, contact_id)
  select id, cp_id from contacts inner join customer on (id = cp_cv_id);

insert into vendor_contacts (vendor_id, contact_id)
  select id, cp_id from contacts inner join vendor on (id = cp_cv_id);
