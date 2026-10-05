-- @tag: db_consistency_mtime
-- @description: Datentyp der mtime-Spalten aller Tabellen angleichen
-- @depends: release_4_1_0 oauth2_tokens lead_times_for_quotations_mtime_fix


ALTER TABLE oauth_token
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE lead_times
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE time_recordings
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE requirement_spec_orders
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE record_templates
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE email_journal_attachments
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE email_journal
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE custom_data_export_query_parameters
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE custom_data_export_queries
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE additional_billing_addresses
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;

ALTER TABLE shops
  ALTER COLUMN mtime DROP not null,
  ALTER COLUMN mtime DROP default;
