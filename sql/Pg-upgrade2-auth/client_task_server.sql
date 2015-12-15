-- @tag: client_task_server
-- @description: Einstellungen, um eine Task-Server-Instanz für mehrere Mandanten laufen zu lassen
-- @depends: release_3_3_0
ALTER TABLE auth.clients ADD COLUMN task_server_user_id INTEGER;
ALTER TABLE auth.clients ADD FOREIGN KEY (task_server_user_id) REFERENCES auth.user (id);
