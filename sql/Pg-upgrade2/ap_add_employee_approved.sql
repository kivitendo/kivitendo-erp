-- @tag: ap_add_employee_approved
-- @description: Spalte für Genehmigt bei EK-Rechnungen
-- @depends: release_3_9_1
CREATE TABLE payment_approved (
        ap_id                INTEGER NOT NULL,
        employee_id          INTEGER NOT NULL,
        itime                TIMESTAMP      DEFAULT now(),
        mtime                TIMESTAMP,
        PRIMARY KEY (ap_id, employee_id),
        FOREIGN KEY (ap_id)                    REFERENCES ap (id),
        FOREIGN KEY (employee_id)              REFERENCES employee (id));

ALTER TABLE defaults ADD COLUMN payment_approval boolean DEFAULT FALSE;

