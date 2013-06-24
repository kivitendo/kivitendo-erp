-- @tag: ustva_2010_fixes
-- @description: Position 83 in der HTML USTVA muss auf 2 Stellen gerundet werden.
-- @depends: release_2_6_3

UPDATE tax.report_variables SET dec_places = '2' WHERE position = '83';
