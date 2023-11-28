-- @tag: email_journal_record_types_add_purchase_order_confirmation
-- @description: E-Mail-Journal Beleg Type um Lieferantenauftragsbestätigung erweitern
-- @depends: email_journal_record_import_types

ALTER TYPE email_journal_record_type ADD VALUE IF NOT EXISTS 'purchase_order_confirmation';
