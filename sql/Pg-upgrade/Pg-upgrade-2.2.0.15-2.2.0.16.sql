CREATE TABLE "adr" (
	"id" integer DEFAULT nextval('id'::text) PRIMARY KEY,
	"adr_description" text,
	"adr_code" text NOT NULL
);

ALTER TABLE parts add column adr_id integer;

alter table shipto add column shipto_id integer;
alter table shipto alter column shipto_id set default nextval('id'::text);
update shipto set shipto_id=nextval('id'::text);

alter table oe add column shipto_id integer;
alter table ar add column shipto_id integer;
