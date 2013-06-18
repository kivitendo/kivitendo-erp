-- @tag: periodic_invoices
-- @description: Neue Tabellen und Spalten für Wiederkehrende Rechnungen
-- @depends: release_2_6_1
CREATE TABLE periodic_invoices_configs (
       id                      integer     NOT NULL DEFAULT nextval('id'),
       oe_id                   integer     NOT NULL,
       periodicity             varchar(10) NOT NULL,
       print                   boolean               DEFAULT 'f',
       printer_id              integer,
       copies                  integer,
       active                  boolean               DEFAULT 't',
       terminated              boolean               DEFAULT 'f',
       start_date              date,
       end_date                date,
       ar_chart_id             integer     NOT NULL,
       extend_automatically_by integer,

       PRIMARY KEY (id),
       FOREIGN KEY (oe_id)       REFERENCES oe       (id),
       FOREIGN KEY (printer_id)  REFERENCES printers (id),
       FOREIGN KEY (ar_chart_id) REFERENCES chart    (id)
);

CREATE TABLE periodic_invoices (
       id                integer   NOT NULL DEFAULT nextval('id'),
       config_id         integer   NOT NULL,
       ar_id             integer   NOT NULL,
       period_start_date date      NOT NULL,
       itime             timestamp          DEFAULT now(),

       PRIMARY KEY (id),
       FOREIGN KEY (config_id) REFERENCES periodic_invoices_configs (id),
       FOREIGN KEY (ar_id)     REFERENCES ar                        (id)
);
