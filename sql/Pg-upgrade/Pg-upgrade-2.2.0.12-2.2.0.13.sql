alter table chart add column new_chart_id integer;
alter table chart add column valid_from date;

create table tax_zones (
  id integer,
  description text
);

insert into tax_zones (id, description) VALUES (0, 'Inland');
insert into tax_zones (id, description) VALUES (1, 'EU mit USt-ID Nummer');
insert into tax_zones (id, description) VALUES (2, 'EU ohne USt-ID Nummer');
insert into tax_zones (id, description) VALUES (3, 'Auﬂerhalb EU');

create table buchungsgruppen (
  id  integer DEFAULT nextval('id'::text) PRIMARY KEY,
  description text,
  inventory_accno_id integer,
  income_accno_id_0 integer,
  expense_accno_id_0 integer,
  income_accno_id_1 integer,
  expense_accno_id_1 integer,
  income_accno_id_2 integer,
  expense_accno_id_2 integer,
  income_accno_id_3 integer,
  expense_accno_id_3 integer
);

alter table parts add column buchungsgruppen_id integer;

alter table vendor add column taxzone_id integer;
alter table customer add column taxzone_id integer;

alter table ar add column taxzone_id integer;
alter table ap add column taxzone_id integer;
alter table oe add column taxzone_id integer;

  