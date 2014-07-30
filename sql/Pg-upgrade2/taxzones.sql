-- @tag: taxzone_charts
-- @description: Neue Tabelle für Buchungskonten der Steuerzonen 
-- @depends: release_3_1_0
-- @ignore: 0

CREATE TABLE taxzone_charts (
  id SERIAL PRIMARY KEY,
  taxzone_id integer     NOT NULL, 
  buchungsgruppen_id integer     NOT NULL, 
  income_accno_id integer     NOT NULL, 
  expense_accno_id integer     NOT NULL, 
  itime timestamp DEFAULT now(),
  FOREIGN KEY (taxzone_id)         REFERENCES tax_zones       (id),
  FOREIGN KEY (income_accno_id)    REFERENCES chart           (id),
  FOREIGN KEY (expense_accno_id)   REFERENCES chart           (id),
  FOREIGN KEY (buchungsgruppen_id) REFERENCES buchungsgruppen (id)
);


