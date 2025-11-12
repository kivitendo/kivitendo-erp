-- @tag: todo_user_config_overdue_quotations_sales_purchase
-- @description: Benutzerkonfiguration zur Aufgabenliste (Angebote EK/VK getrannt)
-- @depends: todo_config

ALTER TABLE todo_user_config ADD COLUMN show_overdue_request_quotations       BOOLEAN DEFAULT TRUE;
ALTER TABLE todo_user_config ADD COLUMN show_overdue_request_quotations_login BOOLEAN DEFAULT TRUE;

UPDATE todo_user_config SET show_overdue_request_quotations       = show_overdue_sales_quotations;
UPDATE todo_user_config SET show_overdue_request_quotations_login = show_overdue_sales_quotations_login;
