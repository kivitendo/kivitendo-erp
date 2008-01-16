-- @tag: todo_config
-- @description: Benutzerkonfiguration zur Aufgabenliste
-- @depends: release_2_4_3

CREATE TABLE todo_user_config (
       employee_id                         integer NOT NULL,
       show_after_login                    boolean DEFAULT TRUE,
       show_follow_ups                     boolean DEFAULT TRUE,
       show_follow_ups_login               boolean DEFAULT TRUE,
       show_overdue_sales_quotations       boolean DEFAULT TRUE,
       show_overdue_sales_quotations_login boolean DEFAULT TRUE,

       FOREIGN KEY (employee_id) REFERENCES employee (id)
);
