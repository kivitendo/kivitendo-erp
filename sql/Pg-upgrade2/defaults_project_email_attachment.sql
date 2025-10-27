-- @tag: defaults_project_email_attachment
-- @description: Voreinstellung, ob Projektdateien per E-Mail verschickt werden sollen
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN email_attachment_project_files_checked boolean DEFAULT true;
