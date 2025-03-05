-- @tag: add_point_of_sale
-- @description: Konfiguration für Kasse
-- @depends: release_3_9_0

CREATE TABLE ec_terminals (
  id                       SERIAL                      PRIMARY KEY,
  name                     TEXT                        NOT NULL,
  transfer_chart_id        INTEGER                     REFERENCES chart(id) NOT NULL,
  ip_address               TEXT                        NOT NULL
);

CREATE TABLE receipt_printers (
  id                       SERIAL                      PRIMARY KEY,
  name                     TEXT                        NOT NULL,
  ip_address               TEXT                        NOT NULL
);

CREATE TABLE tse_terminals (
  id                       SERIAL                      PRIMARY KEY,
  name                     TEXT                        NOT NULL,
  ip_address               TEXT                        NOT NULL
);

CREATE TABLE points_of_sale (
  id                        SERIAL                      PRIMARY KEY,
  name                      TEXT                        NOT NULL,
  project_id                INTEGER                     REFERENCES project(id) NOT NULL,
  cash_chart_id             INTEGER                     REFERENCES chart(id) NOT NULL,
  ec_terminal_id            INTEGER                     REFERENCES ec_terminals(id) NOT NULL,
  tse_terminal_id           INTEGER                     REFERENCES tse_terminals(id) NOT NULL,
  receipt_printer_id        INTEGER                     REFERENCES receipt_printers(id) NOT NULL,
  delivery_order_printer_id INTEGER                     REFERENCES printers(id) NOT NULL,
  delivery_order_template   TEXT                        NOT NULL,
  delivery_order_copies     INTEGER                     NOT NULL,
  invoice_printer_id        INTEGER                     REFERENCES printers(id) NOT NULL,
  invoice_template          TEXT                        NOT NULL,
  invoice_copies            INTEGER                     NOT NULL
);
