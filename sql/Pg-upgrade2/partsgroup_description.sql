-- @tag: partsgroup_description
-- @description: Warengruppe um Beschreibungsfeld erweitert
-- @depends: release_3_5_5

ALTER TABLE partsgroup ADD COLUMN description TEXT;
