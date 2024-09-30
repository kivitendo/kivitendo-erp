-- @tag: add_description_to_backgroundjob_and_backgroundjobhistory
-- @description: Spalte 'description' in 'background_jobs' 'background_job_history
-- @depends: release_3_9_0
ALTER TABLE background_jobs ADD COLUMN description TEXT;
ALTER TABLE background_job_histories ADD COLUMN description TEXT;
