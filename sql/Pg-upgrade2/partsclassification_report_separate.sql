-- @tag: partsclassification_report_seperate
-- @description: "Artikelklassifikation mit weiterer boolschen Variable für seperat ausweisen"
-- @depends: parts_classifications
ALTER TABLE parts_classifications ADD COLUMN report_separate BOOLEAN DEFAULT 'f';
