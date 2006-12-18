create table taxkeys (
  "id" integer DEFAULT nextval('id'::text) PRIMARY KEY,
  "chart_id" integer,
  "tax_id" integer,
  "taxkey_id" integer,
  "pos_ustva" integer,
  "startdate" date
);

alter table tax add column id integer;
alter table tax alter column id set DEFAULT nextval('id'::text);
update tax set id=nextval('id');

insert into taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate) select chart.id, tax.id, taxkey_id, pos_ustva, '1970-01-01' from chart LEFT JOIN tax on (tax.taxkey=chart.taxkey_id) WHERE taxkey_id is not null;