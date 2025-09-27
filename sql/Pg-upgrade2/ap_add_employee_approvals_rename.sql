-- @tag: ap_add_employee_approvals_rename
-- @description: Bessere Benennung für Tabelle
-- @depends: ap_add_employee_approved

ALTER TABLE payment_approved RENAME TO payment_approvals;

