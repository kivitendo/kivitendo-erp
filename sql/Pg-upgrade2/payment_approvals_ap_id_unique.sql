-- @tag: payment_approvals_ap_id_unique
-- @description: Nur eine Zahlungsfreigabe pro Ek-Rechnung (1-1)
-- @depends: ap_add_employee_approvals_rename

ALTER TABLE payment_approvals ADD UNIQUE (ap_id);
