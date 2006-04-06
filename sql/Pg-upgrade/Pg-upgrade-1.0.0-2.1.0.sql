-- Lizenzverwaltung
CREATE TABLE "license" (
 "id" integer DEFAULT nextval('id'::text),
 "parts_id" integer,
 "customer_id" integer,
 "comment" text,
 "validuntil" date,
 "issuedate" date DEFAULT date ('now'::text),
 "quantity" integer,
 "licensenumber" text
);
CREATE INDEX "license_id_key" ON "license" (id);

CREATE TABLE "licenseinvoice" (
  trans_id integer,
  license_id integer
);

--Datev-Ergänzungen
alter table chart add column datevautomatik boolean;
alter table chart alter column datevautomatik set default 'false';
update chart set datevautomatik='false';

alter table customer add column datevexport integer;
alter table vendor add column datevexport integer;
update customer set datevexport=1;
update vendor set datevexport=1;

create table datev (
  "beraternr" character varying(7),
  "beratername" character varying(9),
  "mandantennr" character varying(5),
  "dfvkz" character varying(2),
  "datentraegernr" character varying(3),
  "abrechnungsnr" character varying(6)
);

CREATE FUNCTION set_datevexport() RETURNS trigger AS '
    BEGIN
        IF OLD.datevexport IS NULL THEN
            NEW.datevexport := 1;
        END IF;
        IF OLD.datevexport = 0 THEN
            NEW.datevexport := 2;
        END IF;
        RETURN NEW;
    END;
' LANGUAGE plpgsql;

CREATE TRIGGER customer_datevexport BEFORE UPDATE ON customer
    FOR EACH ROW EXECUTE PROCEDURE set_datevexport();
    
CREATE TRIGGER vendor_datevexport BEFORE UPDATE ON vendor
    FOR EACH ROW EXECUTE PROCEDURE set_datevexport();

alter table customer add column language varchar(5);
alter table vendor add column language varchar(5);

alter table oe add column cusordnumber text;
alter table ar add column cusordnumber text;
                          
alter table parts rename column unit to unit_old;
alter table parts add column unit varchar(10);
update parts set unit=unit_old;
alter table parts drop column unit_old;

--
--LINET-SK: add column account_number, bank code number and bank to customer and vendor
alter table customer add column account_number varchar(10);
alter table customer add column bank_code varchar(10);
alter table customer add column bank text;
--
alter table vendor add column account_number varchar(10);
alter table vendor add column bank_code varchar(10);
alter table vendor add column bank text;

--LINET-SK: add colum cp_id at oe, ar and ap
alter table ap add column cp_id integer;
alter table ar add column cp_id integer;
alter table oe add column cp_id integer;

--deafult-Werte für Kunden, Lieferanten und Artikelnummern
alter table defaults add column customernumber text;
alter table defaults add column vendornumber text;
alter table defaults add column articlenumber text;
alter table defaults add column servicenumber text;

update defaults set customernumber=(select max(customernumber) from customer);
update defaults set vendornumber=(select max(vendornumber) from vendor);
update defaults set articlenumber=(select max(partnumber) from parts where inventory_accno_id notnull);
update defaults set servicenumber=(select max(partnumber) from parts where inventory_accno_id isnull);

--
update defaults set version = '2.1.0';
