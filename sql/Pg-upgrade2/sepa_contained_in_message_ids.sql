-- @tag: sepa_contained_in_message_ids
-- @description: SEPA: Feld zum Merken, in welchen XML-Dokumenten (MsgId) ein Export vorkam
-- @depends: release_3_3_0
CREATE TABLE sepa_export_message_ids (
  id             SERIAL,
  sepa_export_id INTEGER NOT NULL,
  message_id     TEXT    NOT NULL,

  PRIMARY KEY (id),
  FOREIGN KEY (sepa_export_id) REFERENCES sepa_export (id) ON DELETE CASCADE
);
