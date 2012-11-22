-- @tag: rename_buchungsgruppe_16_19_to_19
-- @description: Buchungsgruppe '16%/19%' in '19%' umbenennen
-- @depends: release_2_7_0

UPDATE buchungsgruppen SET description = 'Standard 19%' WHERE description = 'Standard 16%/19%';
