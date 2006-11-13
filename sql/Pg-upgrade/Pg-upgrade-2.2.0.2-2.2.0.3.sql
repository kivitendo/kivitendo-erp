CREATE TABLE "language" (
	"id" integer DEFAULT nextval('id'::text) PRIMARY KEY,
	"description" text,
	"template_code" text,
        "article_code" text,
        "itime" timestamp DEFAULT now(),
        "mtime" timestamp
);

CREATE TABLE "payment_terms" (
	"id" integer DEFAULT nextval('id'::text) PRIMARY KEY,
	"description" text,
	"description_long" text,
	"terms_netto" integer,
        "terms_skonto" integer,
        "percent_skonto" real,
        "itime" timestamp DEFAULT now(),
        "mtime" timestamp
);

CREATE TABLE "translation" (
	"parts_id" integer,
	"language_id" integer,
        "translation" text,
        "itime" timestamp DEFAULT now(),
        "mtime" timestamp
);

ALTER TABLE customer ADD column language_id integer;
ALTER TABLE customer ADD column payment_id integer;
ALTER TABLE vendor ADD column language_id integer;
ALTER TABLE vendor ADD column payment_id integer;
ALTER TABLE ar ADD column language_id integer;
ALTER TABLE ar ADD column payment_id integer;
ALTER TABLE ap ADD column language_id integer;
ALTER TABLE ap ADD column payment_id integer;
ALTER TABLE oe ADD column language_id integer;
ALTER TABLE oe ADD column payment_id integer;

ALTER TABLE ar ADD column delivery_customer_id integer;
ALTER TABLE ar ADD column delivery_vendor_id integer;
ALTER TABLE oe ADD column delivery_customer_id integer;
ALTER TABLE oe ADD column delivery_vendor_id integer;