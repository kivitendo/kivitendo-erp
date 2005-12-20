
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
alter table customer add column obsolete boolean;
alter table customer alter column obsolete set default 'false';
alter table customer add column ustid varchar(12);
alter table vendor add column ustid varchar(12);

alter table customer add column username varchar(50);
alter table vendor add column username varchar(50);
alter table customer add column user_password varchar(12);
alter table vendor add column user_password varchar(12);
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
alter table orderitems add primary key (id);

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
  "pricegroup_id" integer REFERENCES pricegroup(id),
  "price" numeric(15,5)
);

ALTER TABLE customer ADD column klass integer;
ALTER TABLE customer ALTER column klass set default 0;

-- 
ALTER TABLE invoice ADD column pricegroup_id integer;
ALTER TABLE orderitems ADD column pricegroup_id integer;

update defaults set version = '2.1.2', audittrail = 't';

-- USTVA Update solve Bug 49 conributed by Andre Schubert
update chart set pos_ustva='861' where accno='1771';
update chart set pos_ustva='511' where accno='1775';
update chart set pos_ustva='511' where pos_ustva='51r';
update chart set pos_ustva='861' where pos_ustva='86r';
update chart set pos_ustva='971' where pos_ustva='97r';
update chart set pos_ustva='931' where pos_ustva='93r';

-- add fields for ordnumber/transdate/cusordnumber in invoice/orderitems (r690 cleanup)
alter table orderitems add column ordnumber text;
alter table orderitems add column transdate text;
alter table orderitems add column cusordnumber text;
alter table invoice add column ordnumber text;
alter table invoice add column transdate text;
alter table invoice add column cusordnumber text;
--

