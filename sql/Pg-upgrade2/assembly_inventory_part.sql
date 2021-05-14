-- @tag: assembly_inventory_part
-- @description: Tabelle für die wirklich verbauten Einzelteile eines Erzeugnis
-- @depends: warehouse release_3_5_6_1


CREATE TABLE assembly_inventory_part (
       inventory_part_id        INTEGER        REFERENCES inventory(id),
       inventory_assembly_id    INTEGER        REFERENCES inventory(id),
       itime                    TIMESTAMP      DEFAULT now(),
       mtime                    TIMESTAMP,

       PRIMARY KEY (inventory_assembly_id, inventory_part_id)
);

CREATE TRIGGER mtime_assembly_inventory_part BEFORE UPDATE ON assembly_inventory_part FOR EACH ROW EXECUTE PROCEDURE set_mtime();
