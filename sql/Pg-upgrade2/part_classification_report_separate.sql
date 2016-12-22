-- @tag: part_classification_report_separate
-- @description: "Artikelklassifikation mit weiterer boolschen Variable für separat ausweisen"
-- @depends: part_classifications
ALTER TABLE part_classifications ADD COLUMN report_separate BOOLEAN DEFAULT 'f' NOT NULL;
