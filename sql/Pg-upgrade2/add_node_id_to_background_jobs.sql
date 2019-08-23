-- @tag: add_node_id_to_background_jobs
-- @description: Spalte 'node_id' in 'background_jobs'
-- @depends: release_3_5_4
ALTER TABLE background_jobs
ADD COLUMN node_id TEXT;
