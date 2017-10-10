-- @tag: price_rules
-- @description:  Preismatrix Tabellen
-- @depends: release_3_1_0

CREATE TABLE price_rules (
  id       SERIAL PRIMARY KEY,
  name     TEXT,
  type     TEXT,
  priority INTEGER NOT NULL DEFAULT 3,
  price    NUMERIC(15,5),
  discount NUMERIC(15,5),
  obsolete BOOLEAN NOT NULL DEFAULT FALSE,
  itime    TIMESTAMP,
  mtime    TIMESTAMP
);

CREATE TABLE price_rule_items (
  id                         SERIAL PRIMARY KEY,
  price_rules_id             INTEGER NOT NULL,
  type                       TEXT,
  op                         TEXT,
  custom_variable_configs_id INTEGER,
  value_text                 TEXT,
  value_int                  INTEGER,
  value_date                 DATE,
  value_num                  NUMERIC(15,5),
  itime                      TIMESTAMP,
  mtime                      TIMESTAMP,
  FOREIGN KEY (price_rules_id) REFERENCES price_rules (id),
  FOREIGN KEY (custom_variable_configs_id) REFERENCES custom_variable_configs (id)
);

CREATE TRIGGER mtime_price_rules BEFORE UPDATE ON price_rules FOR EACH ROW EXECUTE PROCEDURE set_mtime();
CREATE TRIGGER mtime_price_rule_items BEFORE UPDATE ON price_rule_items FOR EACH ROW EXECUTE PROCEDURE set_mtime();
