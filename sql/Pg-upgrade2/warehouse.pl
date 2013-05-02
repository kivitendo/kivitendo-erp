# @tag: warehouse
# @description:  Diverse neue Tabellen und Spalten zur Mehrlagerf&auml;higkeit inkl. Migration
# @depends: release_2_4_3
package SL::DBUpgrade2::warehouse;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub print_question {
  print $::form->parse_html_template("dbupgrade/warehouse_form");
}

sub run {
  my ($self)           = @_;

  my $do_sql_migration = 0;
  my $check_sql        = qq|SELECT COUNT(id) FROM parts WHERE onhand > 0;|;
  my $sqlcode          = <<SQL;
-- Table "bin" for bins.
CREATE TABLE bin (
  id integer NOT NULL DEFAULT nextval('id'),
  warehouse_id integer NOT NULL,
  description text,
  itime timestamp DEFAULT now(),
  mtime timestamp,

  PRIMARY KEY (id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouse (id)
);

CREATE TRIGGER mtime_bin BEFORE UPDATE ON bin
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

-- Table "warehouse"
ALTER TABLE warehouse ADD COLUMN sortkey integer;
CREATE SEQUENCE tmp_counter;
UPDATE warehouse SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;

ALTER TABLE warehouse ADD COLUMN invalid boolean;
UPDATE warehouse SET invalid = 'f';

CREATE TRIGGER mtime_warehouse BEFORE UPDATE ON warehouse
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

-- Table "transfer_type"
CREATE TABLE transfer_type (
  id integer NOT NULL DEFAULT nextval('id'),
  direction varchar(10) NOT NULL,
  description text,
  sortkey integer,
  itime timestamp DEFAULT now(),
  mtime timestamp,

  PRIMARY KEY (id)
);

CREATE TRIGGER mtime_transfer_type BEFORE UPDATE ON transfer_type
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in', 'stock', 1);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in', 'found', 2);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in', 'correction', 3);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'used', 4);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'disposed', 5);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'back', 6);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'missing', 7);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'correction', 9);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('transfer', 'transfer', 10);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('transfer', 'correction', 11);

-- Modifications to "inventory".
DELETE FROM inventory;

ALTER TABLE inventory ADD COLUMN bin_id integer;
ALTER TABLE inventory ADD FOREIGN KEY (bin_id) REFERENCES bin (id);
ALTER TABLE inventory ALTER COLUMN bin_id SET NOT NULL;

ALTER TABLE inventory DROP COLUMN qty;
ALTER TABLE inventory ADD COLUMN qty numeric(25, 5);

ALTER TABLE inventory ALTER COLUMN parts_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (parts_id) REFERENCES parts(id);

ALTER TABLE inventory ALTER COLUMN warehouse_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (warehouse_id) REFERENCES warehouse(id);

ALTER TABLE inventory ALTER COLUMN employee_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (employee_id) REFERENCES employee (id);

ALTER TABLE inventory ADD COLUMN trans_id integer;
ALTER TABLE inventory ALTER COLUMN trans_id SET NOT NULL;

ALTER TABLE inventory ADD COLUMN trans_type_id integer;
ALTER TABLE inventory ALTER COLUMN trans_type_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (trans_type_id) REFERENCES transfer_type (id);

ALTER TABLE inventory ADD COLUMN project_id integer;
ALTER TABLE inventory ADD FOREIGN KEY (project_id) REFERENCES project (id);

ALTER TABLE inventory ADD COLUMN chargenumber text;
ALTER TABLE inventory ADD COLUMN comment text;

-- Let "onhand" in "parts" be calculated automatically by a trigger.
SELECT id, onhand, bin INTO TEMP TABLE tmp_parts FROM parts WHERE onhand > 0;
ALTER TABLE parts DROP COLUMN onhand;
ALTER TABLE parts ADD COLUMN onhand numeric(25,5);
UPDATE parts SET onhand = COALESCE((SELECT SUM(qty) FROM inventory WHERE inventory.parts_id = parts.id), 0);

ALTER TABLE parts ADD COLUMN stockable boolean;
ALTER TABLE parts ALTER COLUMN stockable SET DEFAULT 'f';
UPDATE parts SET stockable = 'f';

CREATE OR REPLACE FUNCTION update_onhand() RETURNS trigger AS '
BEGIN
  IF tg_op = ''INSERT'' THEN
    UPDATE parts SET onhand = COALESCE(onhand, 0) + new.qty WHERE id = new.parts_id;
    RETURN new;
  ELSIF tg_op = ''DELETE'' THEN
    UPDATE parts SET onhand = COALESCE(onhand, 0) - old.qty WHERE id = old.parts_id;
    RETURN old;
  ELSE
    UPDATE parts SET onhand = COALESCE(onhand, 0) - old.qty + new.qty WHERE id = old.parts_id;
    RETURN new;
  END IF;
END;
' LANGUAGE plpgsql;

CREATE TRIGGER trig_update_onhand
  AFTER INSERT OR UPDATE OR DELETE ON inventory
  FOR EACH ROW EXECUTE PROCEDURE update_onhand();
SQL

  if (!$::form->{do_migrate}
      && (selectfirst_array_query($::form, $self->dbh, $check_sql))[0]) { # check if update is needed
    print_question();
    return 2;
  } else {
    if ($::form->{do_migrate} eq 'Y') {
      # if yes, both warehouse and bin must be given
      if (!$::form->{import_warehouse} || !$::form->{bin_default}) {
        print_question();
        return 2;
      }
      # flag for extra code
      $do_sql_migration = 1;
    }
  }
  my $warehouse = $::form->{import_warehouse} ne '' ? $::form->{import_warehouse} : "Transfer";
  my $bin       = $::form->{bin_default}      ne '' ? $::form->{bin_default}      : "1";

  $warehouse    = $self->dbh->quote($warehouse);
  $bin          = $self->dbh->quote($bin);

  my $migration_code = <<EOF

-- Adjust warehouse
INSERT INTO warehouse (description, sortkey, invalid) VALUES ($warehouse, 1, FALSE);

UPDATE tmp_parts SET bin = NULL WHERE bin = '';

-- Restore old onhand
INSERT INTO bin
 (warehouse_id, description)
 (SELECT DISTINCT warehouse.id, COALESCE(bin, $bin)
   FROM warehouse, tmp_parts
   WHERE warehouse.description=$warehouse);
INSERT INTO inventory
 (warehouse_id, parts_id, bin_id, qty, employee_id, trans_id, trans_type_id, chargenumber)
 (SELECT warehouse.id, tmp_parts.id, bin.id, onhand, (SELECT id FROM employee LIMIT 1), nextval('id'), transfer_type.id, ''
  FROM transfer_type, warehouse, tmp_parts, bin
  WHERE warehouse.description = $warehouse
    AND COALESCE(bin, $bin) = bin.description
    AND transfer_type.description = 'stock');
EOF
;

  # do standard code
  my $query  = $sqlcode;
     $query .= $migration_code if $do_sql_migration;

  $self->db_query($query);

  return 1;
}

1;
