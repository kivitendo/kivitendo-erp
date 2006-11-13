create table dunning_config (
  "id"  integer DEFAULT nextval('id'::text) PRIMARY KEY,
  "dunning_level" integer,
  "dunning_description" text,
  "active" boolean,
  "auto" boolean,
  "email" boolean,
  "terms" integer,
  "payment_terms" integer,
  "fee" numeric(15,5),
  "interest" numeric(15,5),
  "email_body" text,
  "email_subject" text,
  "email_attachment" boolean,
  "template" text
);

create table dunning (
  id  integer DEFAULT nextval('id'::text) PRIMARY KEY,
  trans_id integer,
  dunning_id integer,
  dunning_level integer,
  transdate date,
  duedate date,
  fee  numeric(15,5),
  interest numeric(15,5)
);

alter table ar add column dunning_id integer;
  

CREATE FUNCTION set_priceupdate_parts() RETURNS opaque AS '
    BEGIN
        NEW.priceupdate := ''now'';
        RETURN NEW;
    END;
' LANGUAGE plpgsql;

CREATE TRIGGER priceupdate_parts AFTER UPDATE ON parts
    FOR EACH ROW EXECUTE PROCEDURE set_priceupdate_parts();