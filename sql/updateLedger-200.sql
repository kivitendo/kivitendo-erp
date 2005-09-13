-- Updatescript von Version SQLedger 2.x auf 2.00
-- H.Lindemann Lx-System GbR
-- info@lx-system.de
-- Version: 2.3.9

BEGIN;
LOCK TABLE gl IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ar IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ap IN ACCESS EXCLUSIVE MODE;
LOCK TABLE vendor IN ACCESS EXCLUSIVE MODE;
LOCK TABLE customer IN ACCESS EXCLUSIVE MODE;
LOCK TABLE employee IN ACCESS EXCLUSIVE MODE;
LOCK TABLE shipto IN ACCESS EXCLUSIVE MODE;

CREATE SEQUENCE glid start 1 increment 1 maxvalue 9223372036854775807 minvalue 1 cache 1;

CREATE FUNCTION _glid()
RETURNS text
AS 'DECLARE lv record;
BEGIN
SELECT INTO lv last_value from id;
execute ''SELECT pg_catalog.setval(''''glid'''', '' || lv.last_value || '' , true)'';
return cast(lv.last_value as text);
END;'
LANGUAGE 'plpgsql';
select _glid();
drop function _glid();

\echo gl
ALTER TABLE gl ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE gl ADD COLUMN gldate date;
ALTER TABLE gl ALTER COLUMN gldate SET DEFAULT date('now'::text);
ALTER TABLE gl ADD COLUMN taxinxluded boolean;

\echo chart
ALTER TABLE chart ADD COLUMN taxkey_id integer;
ALTER TABLE chart ADD COLUMN pos_ustva integer;
ALTER TABLE chart ADD COLUMN pos_bwa integer;
ALTER TABLE chart ADD COLUMN pos_bilanz integer;
ALTER TABLE chart ADD COLUMN pos_eur integer;

\echo defaults
--ALTER TABLE defaults drop COLUMN audittrail;

\echo acc_trans
ALTER TABLE acc_trans ADD COLUMN taxkey integer;
ALTER TABLE acc_trans ADD COLUMN gldate date;
ALTER TABLE acc_trans ALTER COLUMN gldate SET DEFAULT date('now'::text);

\echo vendor
CREATE TABLE newvendor (
    id integer DEFAULT nextval('id'::text),
    name character varying(75),
    street character varying(75),
    zipcode character varying(10),
    city character varying(75),
    country character varying(75),
    contact character varying(75),
    phone character varying(30),
    fax character varying(30),
    homepage text,
    email text,
    notes text,
    terms smallint DEFAULT 0,
    taxincluded boolean,
    vendornumber text,
    cc text,
    bcc text,
    gifi_accno text,
    business_id integer,
    taxnumber text,
    sic_code text,
    discount real,
    creditlimit double precision
);
INSERT INTO newvendor (
id, name, street,zipcode,city,country,contact,phone,fax,homepage,email,notes,terms,taxincluded,
vendornumber,cc,bcc,gifi_accno,business_id,taxnumber,sic_code,discount,creditlimit)
SELECT
id, name, address1,zipcode,city,country,contact,phone, fax,null,email,notes,terms,taxincluded,
vendornumber,cc,bcc,gifi_accno,business_id,taxnumber,sic_code,discount,creditlimit
FROM vendor;
--address2, state, iban, bic, employee_id, language_code, pricegroup_id, curr
DROP TABLE vendor;
ALTER TABLE newvendor RENAME TO vendor;

\echo customer
CREATE TABLE newcustomer (
    id integer DEFAULT nextval('id'::text),
    name character varying(75),
    street character varying(75),
    zipcode character varying(10),
    city character varying(75),
    country character varying(75),
    contact character varying(75),
    phone character varying(30),
    fax character varying(30),
    homepage text,
    email text,
    notes text,
    discount real,
    taxincluded boolean,
    creditlimit double precision DEFAULT 0,
    terms smallint DEFAULT 0,
    customernumber text,
    cc text,
    bcc text,
    business_id integer,
    taxnumber text,
    sic_code text
);
INSERT INTO newcustomer (
id,name,street,zipcode,city,country,contact,phone,fax,homepage,email,notes,discount,taxincluded,creditlimit,
terms,customernumber,cc,bcc,business_id,taxnumber,sic_code)
SELECT
id,name,address1,zipcode,city,country,contact,phone,fax,null,email,notes,discount,taxincluded,creditlimit,
terms,customernumber,cc,bcc,business_id,taxnumber,sic_code
FROM customer;
--address2, state, iban, bic, employee_id, language_code, pricegroup_id, curr
DROP TABLE customer;
ALTER TABLE newcustomer RENAME TO customer;

\echo contacts
CREATE TABLE contacts (
    cp_id integer DEFAULT nextval('id'::text),
    cp_cv_id integer,
    cp_greeting character varying(75),
    cp_title character varying(75),
    cp_givenname character varying(75),
    cp_name character varying(75),
    cp_email text,
    cp_phone1 character varying(75),
    cp_phone2 character varying(75)
);

\echo parts
ALTER TABLE parts ADD COLUMN shop boolean;
ALTER TABLE parts ALTER COLUMN shop SET DEFAULT false;

\echo ar
ALTER TABLE ar ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE ar ADD COLUMN gldate date;
ALTER TABLE ar ALTER COLUMN gldate SET DEFAULT date('now'::text);
--ALTER TABLE ar DROP COLUMN language_code;
--ALTER TABLE ar DROP COLUMN till;

\echo ap
ALTER TABLE ap ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE ap ADD COLUMN gldate date;
ALTER TABLE ap ALTER COLUMN gldate SET DEFAULT date('now'::text);
--ALTER TABLE ap DROP COLUMN language_code;
--ALTER TABLE ap DROP COLUMN till;

\echo tax
ALTER TABLE tax ADD COLUMN taxkey integer;
ALTER TABLE tax ADD COLUMN taxdescription text;

\echo oe
ALTER TABLE oe DROP COLUMN language_code;

\echo employee
CREATE TABLE newemployee (
    id integer DEFAULT nextval('id'::text),
    login text,
    name character varying(35),
    addr1 character varying(35),
    addr2 character varying(35),
    addr3 character varying(35),
    addr4 character varying(35),
    workphone character varying(20),
    homephone character varying(20),
    startdate date DEFAULT date('now'::text),
    enddate date,
    notes text,
    role text,
    sales boolean DEFAULT true
);
INSERT INTO newemployee (
id,login,name,addr1,addr2,addr3,addr4,workphone,homephone,startdate,enddate,notes,role,sales)
SELECT
id,login,name,address1,zipcode,city,address2, workphone,homephone,startdate,enddate,notes,role,sales
FROM employee;
--address2,state, country, email, sin, iban, bic, managerid
DROP TABLE employee;
ALTER TABLE newemployee RENAME TO employee;

\echo shipto
CREATE TABLE newshipto (
    trans_id integer,
    shiptoname character varying(75),
    shiptostreet character varying(75),
    shiptozipcode character varying(75),
    shiptocity character varying(75),
    shiptocountry character varying(75),
    shiptocontact character varying(75),
    shiptophone character varying(30),
    shiptofax character varying(30),
    shiptoemail text
);
INSERT INTO newshipto(
trans_id,shiptoname,shiptostreet,shiptozipcode,shiptocity,shiptocountry,shiptocontact,shiptophone,shiptofax,shiptoemail)
SELECT
trans_id,shiptoname,shiptoaddress1,shiptozipcode,shiptocity,shiptocountry,shiptocontact,shiptophone,shiptofax,shiptoemail
FROM shipto;
-- shiptoaddress2,shiptostate,
DROP TABLE shipto;
ALTER TABLE newshipto RENAME TO shipto;

\echo sic
ALTER TABLE sic ADD COLUMN newcode text;
UPDATE sic set newcode=code;
ALTER TABLE sic drop COLUMN code;
ALTER TABLE sic RENAME COLUMN newcode TO code;

\echo yearend
--DROP TABLE yearend;

\echo partsvendor
--DROP TABLE partsvendor;

\echo pricegroup
--DROP TABLE pricegroup;

\echo partscustomer
--DROP TABLE partscustomer;

\echo language
--DROP TABLE language;

\echo autittrail
--DROP TABLE audittrail;

\echo translation;
--DROP TABLE translation;

\echo indexe
CREATE INDEX contact_name_key ON contacts USING btree (cp_name);

update defaults set version = '2.0.0';


end;
