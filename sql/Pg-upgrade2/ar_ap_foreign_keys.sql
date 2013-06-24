-- @tag: ar_ap_foreign_keys
-- @description: Fremdschlüsselverweise für diverse Spalten in ar und ap
-- @depends: release_3_0_0
ALTER TABLE ar ALTER COLUMN department_id DROP DEFAULT;
ALTER TABLE ap ALTER COLUMN department_id DROP DEFAULT;

UPDATE ar SET cp_id         = NULL WHERE (cp_id         IS NOT NULL) AND (cp_id         NOT IN (SELECT cp_id     FROM contacts));
UPDATE ar SET department_id = NULL WHERE (department_id IS NOT NULL) AND (department_id NOT IN (SELECT id        FROM department));
UPDATE ar SET employee_id   = NULL WHERE (employee_id   IS NOT NULL) AND (employee_id   NOT IN (SELECT id        FROM employee));
UPDATE ar SET language_id   = NULL WHERE (language_id   IS NOT NULL) AND (language_id   NOT IN (SELECT id        FROM language));
UPDATE ar SET payment_id    = NULL WHERE (payment_id    IS NOT NULL) AND (payment_id    NOT IN (SELECT id        FROM payment_terms));
UPDATE ar SET shipto_id     = NULL WHERE (shipto_id     IS NOT NULL) AND (shipto_id     NOT IN (SELECT shipto_id FROM shipto));

UPDATE ap SET cp_id         = NULL WHERE (cp_id         IS NOT NULL) AND (cp_id         NOT IN (SELECT cp_id     FROM contacts));
UPDATE ap SET department_id = NULL WHERE (department_id IS NOT NULL) AND (department_id NOT IN (SELECT id        FROM department));
UPDATE ap SET employee_id   = NULL WHERE (employee_id   IS NOT NULL) AND (employee_id   NOT IN (SELECT id        FROM employee));
UPDATE ap SET language_id   = NULL WHERE (language_id   IS NOT NULL) AND (language_id   NOT IN (SELECT id        FROM language));
UPDATE ap SET payment_id    = NULL WHERE (payment_id    IS NOT NULL) AND (payment_id    NOT IN (SELECT id        FROM payment_terms));

ALTER TABLE ar ADD FOREIGN KEY (cp_id)         REFERENCES contacts      (cp_id);
ALTER TABLE ar ADD FOREIGN KEY (department_id) REFERENCES department    (id);
ALTER TABLE ar ADD FOREIGN KEY (employee_id)   REFERENCES employee      (id);
ALTER TABLE ar ADD FOREIGN KEY (language_id)   REFERENCES language      (id);
ALTER TABLE ar ADD FOREIGN KEY (payment_id)    REFERENCES payment_terms (id);
ALTER TABLE ar ADD FOREIGN KEY (shipto_id)     REFERENCES shipto        (shipto_id);

ALTER TABLE ap ADD FOREIGN KEY (cp_id)         REFERENCES contacts      (cp_id);
ALTER TABLE ap ADD FOREIGN KEY (employee_id)   REFERENCES employee      (id);
ALTER TABLE ap ADD FOREIGN KEY (department_id) REFERENCES department    (id);
ALTER TABLE ap ADD FOREIGN KEY (language_id)   REFERENCES language      (id);
ALTER TABLE ap ADD FOREIGN KEY (payment_id)    REFERENCES payment_terms (id);
