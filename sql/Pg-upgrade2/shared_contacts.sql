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
  customer_id integer not null references customer(id)    on delete cascade,
  contact_id  integer not null references contacts(cp_id) on delete cascade,
  main boolean not null default false,

  unique(customer_id, contact_id)
);

create table vendor_contacts (
  id serial primary key,
  vendor_id  integer not null references vendor(id)      on delete cascade,
  contact_id integer not null references contacts(cp_id) on delete cascade,
  main boolean not null default false,

  unique(vendor_id, contact_id)
);

-- index for customer/vendor fkeys
create index on customer_contacts(customer_id);
create index on vendor_contacts(vendor_id);

-- constraint so that only one contact can be main
create unique index on customer_contacts(customer_id) where main;
create unique index on vendor_contacts(vendor_id)     where main;

-- migrate old contacts
insert into customer_contacts (customer_id, contact_id, main)
  select id, cp_id, cp_main from contacts inner join customer on (id = cp_cv_id);

insert into vendor_contacts (vendor_id, contact_id, main)
  select id, cp_id, cp_main from contacts inner join vendor on (id = cp_cv_id);
