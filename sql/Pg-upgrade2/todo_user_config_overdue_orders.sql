-- @tag: todo_user_config_overdue_orders
-- @description: Benutzerkonfiguration zur Aufgabenliste (Aufträge)
-- @depends: todo_config

ALTER TABLE todo_user_config ADD COLUMN show_overdue_sales_orders          BOOLEAN DEFAULT TRUE;
ALTER TABLE todo_user_config ADD COLUMN show_overdue_sales_orders_login    BOOLEAN DEFAULT TRUE;
ALTER TABLE todo_user_config ADD COLUMN show_overdue_purchase_orders       BOOLEAN DEFAULT TRUE;
ALTER TABLE todo_user_config ADD COLUMN show_overdue_purchase_orders_login BOOLEAN DEFAULT TRUE;
