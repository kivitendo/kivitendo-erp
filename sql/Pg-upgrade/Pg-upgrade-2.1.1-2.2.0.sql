
--Update der Numeric-Spalten von 5 auf 10 Vorkommastellen
--
--TABLE ap
alter table ap rename column paid to paidold;
alter table ap add column paid numeric(15,5);
update ap set paid=paidold;
alter table ap drop column paidold;
--
alter table ap rename column netamount to netamountold;
alter table ap add column netamount numeric(15,5);
update ap set netamount=netamountold;
alter table ap drop column netamountold;
--
alter table ap rename column amount to amountold;
alter table ap add column amount numeric(15,5);
update ap set amount=amountold;
alter table ap drop column amountold;
--
--TABLE acc_trans
alter table acc_trans rename column amount to amountold;
alter table acc_trans add column amount numeric(15,5);
update acc_trans set amount=amountold;
alter table acc_trans drop column amountold;
--
--TABLE ar
alter table ar rename column amount to amountold;
alter table ar add column amount numeric(15,5);
update ar set amount=amountold;
alter table ar drop column amountold;
--
alter table ar rename column netamount to netamountold;
alter table ar add column netamount numeric(15,5);
update ar set netamount=netamountold;
alter table ar drop column netamountold;
--
alter table ar rename column paid to paidold;
alter table ar add column paid numeric(15,5);
update ar set paid=paidold;
alter table ar drop column paidold;
--
--TABLE customer
alter table customer rename column creditlimit to creditlimitold;
alter table customer add column creditlimit numeric(15,5);
update customer set creditlimit=creditlimitold;
alter table customer drop column creditlimitold;
--
--TABLE exchangerate
alter table exchangerate rename column buy to buyold;
alter table exchangerate add column buy numeric(15,5);
update exchangerate set buy=buyold;
alter table exchangerate drop column buyold;
--
alter table exchangerate rename column sell to sellold;
alter table exchangerate add column sell numeric(15,5);
update exchangerate set sell=sellold;
alter table exchangerate drop column sellold;
--
--TABLE invoice
alter table invoice rename column sellprice to sellpriceold;
alter table invoice add column sellprice numeric(15,5);
update invoice set sellprice=sellpriceold;
alter table invoice drop column sellpriceold;
--
alter table invoice rename column fxsellprice to fxsellpriceold;
alter table invoice add column fxsellprice numeric(15,5);
update invoice set fxsellprice=fxsellpriceold;
alter table invoice drop column fxsellpriceold;
--
--TABLE oe
alter table oe rename column amount to amountold;
alter table oe add column amount numeric(15,5);
update oe set amount=amountold;
alter table oe drop column amountold;
--
alter table oe rename column netamount to netamountold;
alter table oe add column netamount numeric(15,5);
update oe set netamount=netamountold;
alter table oe drop column netamountold;
--
--TABLE orderitems
alter table orderitems rename column sellprice to sellpriceold;
alter table orderitems add column sellprice numeric(15,5);
update orderitems set sellprice=sellpriceold;
alter table orderitems drop column sellpriceold;
--
--TABLE parts
alter table parts rename column listprice to listpriceold;
alter table parts add column listprice numeric(15,5);
update parts set listprice=listpriceold;
alter table parts drop column listpriceold;
--
alter table parts rename column sellprice to sellpriceold;
alter table parts add column sellprice numeric(15,5);
update parts set sellprice=sellpriceold;
alter table parts drop column sellpriceold;
--
alter table parts rename column lastcost to lastcostold;
alter table parts add column lastcost numeric(15,5);
update parts set lastcost=lastcostold;
alter table parts drop column lastcostold;
--
--TABLE tax
alter table tax rename column rate to rateold;
alter table tax add column rate numeric(15,5);
update tax set rate=rateold;
alter table tax drop column rateold;
--
--TABLE vendor
alter table vendor rename column creditlimit to creditlimitold;
alter table vendor add column creditlimit numeric(15,5);
update vendor set creditlimit=creditlimitold;
alter table vendor drop column creditlimitold;
--

--New Fields for customer and vendor
alter table vendor add column obsolete boolean;
alter table vendor alter column obsolete set default 'false';
update vendor set obsolete='false';
alter table customer add column obsolete boolean;
alter table customer alter column obsolete set default 'false';
update customer set obsolete='false';
alter table customer add column ustid varchar(12);
alter table vendor add column ustid varchar(12);

alter table customer add column username varchar(50);
alter table vendor add column username varchar(50);
alter table customer add column user_password text;
alter table vendor add column user_password text;
alter table customer add column salesman_id integer;
alter table vendor add column salesman_id integer;

-- Shipto
alter table shipto add column shiptodepartment_1 varchar(75);
alter table shipto add column shiptodepartment_2 varchar(75);



-- Addon for business
alter table business add column salesman boolean;
alter table business alter column salesman set default 'false';
alter table business add column customernumberinit text;

alter table parts add column ve integer;
alter table parts add column gv numeric(15,5);
--

-- Add table contrains
alter table customer alter name SET NOT NULL;
alter table vendor alter name set NOT NULL;
alter table chart alter accno set NOT NULL;
alter table parts alter partnumber set NOT NULL;
alter table ar alter invnumber set NOT NULL;
alter table ap alter invnumber set NOT NULL;
alter table oe alter ordnumber set NOT NULL;

alter table gl alter id set NOT NULL;
alter table chart alter id set NOT NULL;
alter table parts alter id set NOT NULL;
alter table invoice alter id set NOT NULL;
alter table vendor alter id set NOT NULL;
alter table customer alter id set NOT NULL;
alter table contacts alter cp_id set NOT NULL;
alter table ar alter id set NOT NULL;
alter table ap alter id set NOT NULL;
alter table oe alter id set NOT NULL;
alter table employee alter id set NOT NULL;
alter table warehouse alter id set NOT NULL;
alter table business alter id set NOT NULL;
alter table license alter id set NOT NULL;
alter table orderitems alter id set NOT NULL;

alter table gl add primary key (id);
alter table chart add primary key (id);
alter table parts add primary key (id);
alter table invoice add primary key (id);
alter table vendor add primary key (id);
alter table customer add primary key (id);
alter table contacts add primary key (cp_id);
alter table ar add primary key (id);
alter table ap add primary key (id);
alter table oe add primary key (id);
alter table employee add primary key (id);
alter table warehouse add primary key (id);
alter table business add primary key (id);
alter table license add primary key (id);

alter table acc_trans add foreign key (chart_id) references chart (id);
alter table invoice add foreign key (parts_id) references parts (id);
alter table ar add foreign key (customer_id) references customer (id);
alter table ap add foreign key (vendor_id) references vendor (id);
alter table orderitems add foreign key (parts_id) references parts (id);

--Modify the possible length of bank account numbers
alter table customer add column temp_account_number character varying(15);
update customer set temp_account_number=account_number;
alter table customer drop column account_number;
alter table customer rename temp_account_number to  account_number;

alter table vendor add column temp_account_number character varying(15);
update vendor set temp_account_number=account_number;
alter table vendor drop column account_number;
alter table vendor rename temp_account_number to  account_number;

-- audit
alter table defaults add column audittrail bool;
CREATE TABLE audittrail (
  trans_id int,
  tablename text,
  reference text,
  formname text,
  action text,
  transdate timestamp default current_timestamp,
  employee_id int
);

-- pricegroups

CREATE TABLE "pricegroup" (
  "id" integer DEFAULT nextval('id'::text),
  "pricegroup" text not null,
  PRIMARY KEY (id)
);

CREATE TABLE "prices" (
  "parts_id" integer REFERENCES parts(id),
  "pricegroup_id" integer,
  "price" numeric(15,5)
);

ALTER TABLE customer ADD column klass integer;
ALTER TABLE customer ALTER column klass set default 0;

-- 
ALTER TABLE invoice ADD column pricegroup_id integer;
ALTER TABLE orderitems ADD column pricegroup_id integer;


-- USTVA Update solve Bug 49 conributed by Andre Schubert
update chart set pos_ustva='861' where accno='1771';
update chart set pos_ustva='511' where accno='1775';
-- update chart set pos_ustva='511' where pos_ustva='51r';
-- update chart set pos_ustva='861' where pos_ustva='86r';
-- update chart set pos_ustva='971' where pos_ustva='97r';
-- update chart set pos_ustva='931' where pos_ustva='93r';

-- add fields for ordnumber/transdate/cusordnumber in invoice/orderitems (r690 cleanup)
alter table orderitems add column ordnumber text;
alter table orderitems add column transdate text;
alter table orderitems add column cusordnumber text;
alter table invoice add column ordnumber text;
alter table invoice add column transdate text;
alter table invoice add column cusordnumber text;
--
-- UStVA Link to SKR03/2006
-- Let this structure like it is, please.
-- This structure is based on the sequence of the USTVA 2006
-- Created by Udo Spallek
--
-- 1. Page UStVA
UPDATE chart SET pos_ustva=41  WHERE accno IN ('8125', '8130', '8140', '8724', '8808', '8828');
UPDATE chart SET pos_ustva=44  WHERE accno IN ('8135');
UPDATE chart SET pos_ustva=49  WHERE accno IN ('');
UPDATE chart SET pos_ustva=43  WHERE accno IN ('2402', '8120', '8150', '8505', '8625', '8705', '8807', '8827');
UPDATE chart SET pos_ustva=48  WHERE accno IN ('8100', '8110', '8504', '8609');
UPDATE chart SET pos_ustva=51  WHERE accno IN ('1717', '2404', '2405', '2700', '2705', '2707', '2709', '8196', '8315', '8400', '8595', '8600', '8611', '8640', '8720', '8726', '8735', '8760', '8790', '8801', '8809', '8820', '8910', '8920', '8921', '8922', '8925', '8935', '8940');
UPDATE chart SET pos_ustva=511 WHERE accno IN ('1775');
UPDATE chart SET pos_ustva=86  WHERE accno IN ('1711', '2401', '2403', '8300', '8310', '8506', '8591', '8630', '8710', '8725', '8731', '8750', '8780', '8915', '8930', '8932', '8945');
UPDATE chart SET pos_ustva=861 WHERE accno IN ('1771');
UPDATE chart SET pos_ustva=35  WHERE accno IN ('2407', '2409', '8723', '8729', '8736', '8764', '8794');
UPDATE chart SET pos_ustva=36  WHERE accno IN ('');
UPDATE chart SET pos_ustva=77  WHERE accno IN ('');
UPDATE chart SET pos_ustva=76  WHERE accno IN ('8190');
UPDATE chart SET pos_ustva=80  WHERE accno IN ('');
UPDATE chart SET pos_ustva=91  WHERE accno IN ('');
UPDATE chart SET pos_ustva=97  WHERE accno IN ('3425', '3725');
UPDATE chart SET pos_ustva=971 WHERE accno IN ('1773');
UPDATE chart SET pos_ustva=93  WHERE accno IN ('3420', '3724');
UPDATE chart SET pos_ustva=931 WHERE accno IN ('1772');
UPDATE chart SET pos_ustva=95  WHERE accno IN ('3727');
UPDATE chart SET pos_ustva=98  WHERE accno IN ('');
UPDATE chart SET pos_ustva=94  WHERE accno IN ('');
UPDATE chart SET pos_ustva=96  WHERE accno IN ('1784');
UPDATE chart SET pos_ustva=42  WHERE accno IN ('');
UPDATE chart SET pos_ustva=60  WHERE accno IN ('8337');
UPDATE chart SET pos_ustva=45  WHERE accno IN ('8338', '8339', '8950');
-- 2. Page UStVA
UPDATE chart SET pos_ustva=52  WHERE accno IN ('');
UPDATE chart SET pos_ustva=53  WHERE accno IN ('');
UPDATE chart SET pos_ustva=73  WHERE accno IN ('');
UPDATE chart SET pos_ustva=74  WHERE accno IN ('');
UPDATE chart SET pos_ustva=84  WHERE accno IN ('3110', '3115', '3120', '3125');
UPDATE chart SET pos_ustva=85  WHERE accno IN ('1785', '1786');
UPDATE chart SET pos_ustva=65  WHERE accno IN ('1782');
UPDATE chart SET pos_ustva=66  WHERE accno IN ('1570', '1571', '1575', '1576');
UPDATE chart SET pos_ustva=61  WHERE accno IN ('1572', '1573');
UPDATE chart SET pos_ustva=62  WHERE accno IN ('1588');
UPDATE chart SET pos_ustva=67  WHERE accno IN ('1578', '1579');
UPDATE chart SET pos_ustva=63  WHERE accno IN ('1577');
UPDATE chart SET pos_ustva=64  WHERE accno IN ('1556', '1557', '1558', '1559');
UPDATE chart SET pos_ustva=59  WHERE accno IN ('');
UPDATE chart SET pos_ustva=69  WHERE accno IN ('1783');
UPDATE chart SET pos_ustva=39  WHERE accno IN ('1781');
--
-- clear table tax
DELETE from tax;
-- insert actual values for SKR03
INSERT INTO tax (rate, taxkey, taxdescription) VALUES ('0','0','Keine Steuer');
INSERT INTO tax (rate, taxkey, taxdescription) VALUES ('0','1','Umsatzsteuerfrei (mit Vorsteuerabzug)');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1771'),'0.07','1771','2','Umsatzsteuer 7%');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1775'),'0.16','1775','3','Umsatzsteuer 16%');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1571'),'0.07','1571','8','Vorsteuer 7%');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1575'),'0.16','1575','9','Vorsteuer 16%');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1767'),'0.00','1767','10','Im anderen EG-Staat steuerpfl. Lieferung');
INSERT INTO tax (taxkey, taxdescription) VALUES ('11','Steuerfreie EG-Lief. an Abn. mit UStIdNr');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1772'),'0.07','1772','12','Umsatzsteuer 7% innergem. Erwerb');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1773'),'0.16','1773','13','Umsatzsteuer 16% innergem. Erwerb');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1572'),'0.07','1572','18','Steuerpfl. EG-Erwerb 7%');
INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id FROM chart WHERE accno = '1572'),'0.16','1573','19','Steuerpfl. EG-Erwerb 16%');
--
--
-- add unqiue constraint to project
ALTER TABLE project ADD constraint project_projectnumber_key UNIQUE(projectnumber);
--
-- add column deliverydate to ar
ALTER TABLE ar ADD COLUMN deliverydate date;

update defaults set version = '2.2.0';


