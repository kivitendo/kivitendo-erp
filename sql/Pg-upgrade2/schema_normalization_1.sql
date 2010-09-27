-- @tag: schema_normalization_1
-- @description: Datenbankschema Normalisierungen
-- @depends: release_2_6_1

-- assembly-id
CREATE SEQUENCE assembly_assembly_id_seq;
ALTER TABLE assembly ADD COLUMN assembly_id INTEGER;
UPDATE assembly SET assembly_id = nextval('assembly_assembly_id_seq');
ALTER TABLE assembly ADD PRIMARY KEY( assembly_id );
ALTER TABLE assembly ALTER assembly_id SET DEFAULT nextval('assembly_assembly_id_seq');

-- shipto_primary_key
ALTER TABLE shipto ALTER COLUMN shipto_id SET NOT NULL;
ALTER TABLE shipto ADD PRIMARY KEY (shipto_id);

-- oe_vc_foreign_keys
--ALTER TABLE oe ADD FOREIGN KEY (customer_id) REFERENCES customer (id);
--ALTER TABLE oe ADD FOREIGN KEY (vendor_id)   REFERENCES vendor   (id);

-- orderitems_primary_key
ALTER TABLE orderitems ADD PRIMARY KEY (id);

-- part_unit_not_null
UPDATE parts SET unit = 'Stck' WHERE unit IS NULL;
ALTER TABLE parts ALTER COLUMN unit SET NOT NULL;

-- makemodel_id_column
ALTER TABLE makemodel ADD COLUMN tmp integer;
UPDATE makemodel SET tmp = make::integer WHERE COALESCE(make, '') <> '';
ALTER TABLE makemodel DROP COLUMN make;
ALTER TABLE makemodel RENAME COLUMN tmp TO make;

CREATE SEQUENCE makemodel_id_seq;
ALTER TABLE makemodel ADD COLUMN id integer;
ALTER TABLE makemodel ALTER COLUMN id SET DEFAULT nextval('makemodel_id_seq');
UPDATE makemodel SET id = nextval('makemodel_id_seq');
ALTER TABLE makemodel ALTER COLUMN id SET NOT NULL;
ALTER TABLE makemodel ADD PRIMARY KEY (id);
