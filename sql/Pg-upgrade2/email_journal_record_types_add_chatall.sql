-- @tag: email_journal_record_types_add_catch_all
-- @description: E-Mail-Journal Beleg Type um generischen Type erweitern
-- @depends: email_journal_record_import_types

ALTER TYPE email_journal_record_type ADD VALUE IF NOT EXISTS 'catch_all';
