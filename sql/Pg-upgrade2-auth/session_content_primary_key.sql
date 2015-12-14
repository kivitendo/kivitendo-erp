-- @tag: session_content_primary_key
-- @description: Primärschlüssel für Tabelle auth.session_content
-- @depends: release_3_3_0
ALTER TABLE auth.session_content ADD PRIMARY KEY (session_id, sess_key);
