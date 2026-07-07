-- @tag: shared_contacts
-- @description: Mehrfachzuordnung von Ansprechpersonen zu Kunden und Lieferanten
-- @depends: release_4_0_0


/* model: instead of having

  customer.id <-> contacts.cp_cv_id
  vendor.id   <-> contacts.cp_cv_id

  we now have a join table:

  customer_contacts:
    contacts.cp_id, customer_id
  vendor_contacts:
    contacts.cp_id, vendor_id

*/

-- Before this change, the uniqueness of the main flag among one customer's
-- contacts was not enforced and cannot be relied upon.
-- We enforce the uniqueness first, to avoid conflicts with the unique index
-- below.

update contacts c1 set cp_main = false
where c1.cp_main and exists ( select 1 FROM contacts c2 where (c1.cp_id != c2.cp_id) and (c1.cp_cv_id = c2.cp_cv_id) and c2.cp_main );


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
