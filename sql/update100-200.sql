-- Updatescript von Version 1.00 auf 2.00
-- H.Lindemann Lx-System GbR
-- info@lx-system.de
-- Version: 2.1.11
-- echo "select version from defaults" | psql -q -t -U postgres lx2003

--execute ''CREATE SEQUENCE glid start '' || lv.last_value || ''increment 1 maxvalue 9223372036854775807 minvalue 1 cache 1'';
BEGIN;
LOCK TABLE gl IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ar IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ap IN ACCESS EXCLUSIVE MODE;

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

\echo chart
ALTER TABLE chart ADD COLUMN taxkey_id integer;
ALTER TABLE chart ADD COLUMN pos_ustva integer;
ALTER TABLE chart ADD COLUMN pos_bwa integer;
ALTER TABLE chart ADD COLUMN pos_bilanz integer;
ALTER TABLE chart ADD COLUMN pos_eur integer;

\echo acc_trans
ALTER TABLE acc_trans ADD COLUMN taxkey integer;
ALTER TABLE acc_trans ADD COLUMN gldate date;
ALTER TABLE acc_trans ALTER COLUMN gldate SET DEFAULT date('now'::text);

\echo tax
ALTER TABLE tax ADD COLUMN taxkey integer;
ALTER TABLE tax ADD COLUMN taxdescription text;

\echo gl
ALTER TABLE gl ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE gl ADD COLUMN gldate date;
ALTER TABLE gl ALTER COLUMN gldate SET DEFAULT date('now'::text);
ALTER TABLE gl ADD COLUMN taxinxluded boolean;

\echo ar
ALTER TABLE ar ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE ar ADD COLUMN gldate date;
ALTER TABLE ar ALTER COLUMN gldate SET DEFAULT date('now'::text);

\echo ap
ALTER TABLE ap ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE ap ADD COLUMN gldate date;
ALTER TABLE ap ALTER COLUMN gldate SET DEFAULT date('now'::text);


\echo parts
ALTER TABLE parts ADD COLUMN shop boolean;
ALTER TABLE parts ALTER COLUMN shop SET DEFAULT false;

\echo indexe
CREATE INDEX contact_name_key ON contacts USING btree (cp_name);

update defaults set version = '2.0.0';


end;
