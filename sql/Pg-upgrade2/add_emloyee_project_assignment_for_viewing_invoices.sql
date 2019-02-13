-- @tag: add_emloyee_project_assignment_for_viewing_invoices
-- @description: Mitarbeiter*innen Projekten zuweisen können, damit diese Projektrechnungen anschauen dürfen
-- @depends: release_3_5_3
CREATE TABLE employee_project_invoices (
  employee_id INTEGER NOT NULL,
  project_id  INTEGER NOT NULL,

  CONSTRAINT employee_project_invoices_pkey             PRIMARY KEY (employee_id, project_id),
  CONSTRAINT employee_project_invoices_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employee (id) ON DELETE CASCADE,
  CONSTRAINT employee_project_invoices_project_id_fkey  FOREIGN KEY (project_id)  REFERENCES project  (id) ON DELETE CASCADE
);
