-- @tag: email_journal_attachments_add_fileid
-- @description: attachments mit file_id
-- @depends: email_journal filemanagement_feature files
ALTER TABLE email_journal_attachments ADD COLUMN file_id integer default 0 NOT NULL;
