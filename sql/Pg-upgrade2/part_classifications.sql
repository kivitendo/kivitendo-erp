-- @tag: part_classifications
-- @description: "zusätzliche Tabelle mit Flags zur Klassifizierung von Artikeln"
-- @depends: release_3_4_1
CREATE TABLE part_classifications (
    id SERIAL PRIMARY KEY,
    description text,
    abbreviation text,
    used_for_purchase BOOLEAN DEFAULT 't' NOT NULL,
    used_for_sale     BOOLEAN DEFAULT 't' NOT NULL
);

INSERT INTO part_classifications values(0,'-------'    ,'None (typeabbreviation)','t','t');
INSERT INTO part_classifications values(1,'Purchase'   ,'Purchase (typeabbreviation)'   ,'t','f');
INSERT INTO part_classifications values(2,'Sales'      ,'Sales (typeabbreviation)'      ,'f','t');
INSERT INTO part_classifications values(3,'Merchandise','Merchandise (typeabbreviation)','t','t');
INSERT INTO part_classifications values(4,'Production' ,'Production (typeabbreviation)' ,'f','t');
SELECT setval('part_classifications_id_seq',4);
ALTER TABLE parts ADD COLUMN classification_id integer DEFAULT 0;
ALTER TABLE parts ADD CONSTRAINT part_classification_id_fkey FOREIGN KEY (classification_id) REFERENCES part_classifications(id);
