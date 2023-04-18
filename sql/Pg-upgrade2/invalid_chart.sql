-- @tag: invalid_chart
-- @description: Ungültigkeit für Chart
-- @depends: release_3_8_0
-- @ignore: 0

ALTER TABLE chart add column invalid boolean DEFAULT FALSE;

