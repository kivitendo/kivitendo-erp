-- @tag: ustva_2010
-- @description: Zusätzliche UStVA Kennziffern.
-- @depends: release_2_6_1

INSERT INTO tax.report_variables (id, position, heading_id, description, taxbase, dec_places, valid_from)
  VALUES (47, '21', 66, 'Nicht steuerbare sonstige Leistungen gem. § 18b Satz 1 Nr. 2 UStG', 0, 0, '01.01.2010');
INSERT INTO tax.report_variables (id, position, heading_id, description, taxbase, dec_places, valid_from)
  VALUES (48, '46', 6, 'Im Inland steuerpflichtige sonstige Leistungen von im übrigen Gemeinschaftsgebiet ansässigen Unternehmen (§13b Abs. 1 UStG)', 0, 0, '01.01.2010');
INSERT INTO tax.report_variables (id, position, heading_id, description, taxbase, dec_places, valid_from)
  VALUES (49, '47', 6, '', 49, 2, '01.01.2010');
INSERT INTO tax.report_variables (id, position, heading_id, description, taxbase, dec_places, valid_from)
  VALUES (50, '83', 8, 'Verbleibender Überschuss - bitte dem Betrag ein Minuszeichen voranstellen -', 0, 0, '01.01.2010');


