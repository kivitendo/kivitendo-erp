-- @tag: foreign_key_constraints_on_delete
-- @description: Ändert "FOREIGN KEY" constraints auf "ON DELETE CASCADE"
-- @depends: clients
-- @charset: utf-8

-- auth.clients_groups
ALTER TABLE auth.clients_groups DROP CONSTRAINT clients_groups_client_id_fkey;
ALTER TABLE auth.clients_groups DROP CONSTRAINT clients_groups_group_id_fkey;

ALTER TABLE auth.clients_groups ADD FOREIGN KEY (client_id) REFERENCES auth.clients (id) ON DELETE CASCADE;
ALTER TABLE auth.clients_groups ADD FOREIGN KEY (group_id)  REFERENCES auth."group" (id) ON DELETE CASCADE;

-- auth.clients_users
ALTER TABLE auth.clients_users DROP CONSTRAINT clients_users_client_id_fkey;
ALTER TABLE auth.clients_users DROP CONSTRAINT clients_users_user_id_fkey;

ALTER TABLE auth.clients_users ADD FOREIGN KEY (client_id) REFERENCES auth.clients (id) ON DELETE CASCADE;
ALTER TABLE auth.clients_users ADD FOREIGN KEY (user_id)   REFERENCES auth."user"  (id) ON DELETE CASCADE;

-- auth.group_rights
ALTER TABLE auth.group_rights DROP CONSTRAINT group_rights_group_id_fkey;

ALTER TABLE auth.group_rights ADD FOREIGN KEY (group_id) REFERENCES auth."group" (id) ON DELETE CASCADE;

 -- auth.session_content
ALTER TABLE auth.session_content DROP CONSTRAINT session_content_session_id_fkey;

ALTER TABLE auth.session_content ADD FOREIGN KEY (session_id) REFERENCES auth.session (id) ON DELETE CASCADE;

 -- auth.user_config
ALTER TABLE auth.user_config DROP CONSTRAINT user_config_user_id_fkey;

ALTER TABLE auth.user_config ADD FOREIGN KEY (user_id) REFERENCES auth."user" (id) ON DELETE CASCADE;

-- auth.user_group
ALTER TABLE auth.user_group DROP CONSTRAINT user_group_user_id_fkey;
ALTER TABLE auth.user_group DROP CONSTRAINT user_group_group_id_fkey;

ALTER TABLE auth.user_group ADD FOREIGN KEY (user_id)  REFERENCES auth."user"  (id) ON DELETE CASCADE;
ALTER TABLE auth.user_group ADD FOREIGN KEY (group_id) REFERENCES auth."group" (id) ON DELETE CASCADE;
