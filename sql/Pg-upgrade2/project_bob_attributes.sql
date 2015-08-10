-- @tag: project_bob_attributes
-- @description: Projekte: Zusätzliche Tabellen und Spalten
-- @depends:  project_customer_type_valid

-- changes over bob:
-- no scon/support_contract values here
-- no include or expclude flags for workload
-- created_at/updated_at renamed to itime/mtime,
-- varchars retyped to text
-- hours (numeric) changed to minutes (integer) since the code already calculates in minutes
--  note: flags changing the behaviour of hours are still called so and not minutes
-- no refcounts. we use adhoc counts to decide whether delete is possible or not
-- no hour_approval
-- nothing relevant to notifications




CREATE TABLE project_status (
  id          SERIAL    NOT NULL PRIMARY KEY,
  name        TEXT      NOT NULL,
  description TEXT      NOT NULL,
  position    INTEGER   NOT NULL,
  itime       TIMESTAMP DEFAULT now(),
  mtime       TIMESTAMP
);

ALTER TABLE project ADD COLUMN start_date           DATE;
ALTER TABLE project ADD COLUMN end_date             DATE;
ALTER TABLE project ADD COLUMN billable_customer_id INTEGER REFERENCES customer(id);
ALTER TABLE project ADD COLUMN budget_cost          NUMERIC(15,5) NOT NULL DEFAULT 0;
ALTER TABLE project ADD COLUMN order_value          NUMERIC(15,5) NOT NULL DEFAULT 0;
ALTER TABLE project ADD COLUMN budget_minutes       INTEGER       NOT NULL DEFAULT 0;
ALTER TABLE project ADD COLUMN timeframe            BOOLEAN       NOT NULL DEFAULT FALSE;
ALTER TABLE project ADD COLUMN project_status_id    INTEGER                REFERENCES project_status(id);

ALTER TABLE project_types ADD COLUMN internal BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE project_phases (
  id              SERIAL NOT NULL PRIMARY KEY,
  project_id      INTEGER REFERENCES project(id),
  start_date      DATE,
  end_date        DATE,
  name            TEXT                 NOT NULL,
  description     TEXT                 NOT NULL,
  budget_minutes  INTEGER              NOT NULL DEFAULT 0,
  budget_cost     NUMERIC (15,5)       NOT NULL DEFAULT 0,
  general_minutes INTEGER              NOT NULL DEFAULT 0,
  general_cost_per_hour NUMERIC (15,5) NOT NULL DEFAULT 0,
  itime           TIMESTAMP DEFAULT now(),
  mtime           TIMESTAMP
);

CREATE TABLE project_roles (
  id           SERIAL  NOT NULL PRIMARY KEY,
  name         TEXT    NOT NULL,
  description  TEXT    NOT NULL,
  position     INTEGER NOT NULL,
  itime        TIMESTAMP DEFAULT now(),
  mtime        TIMESTAMP
);

CREATE TABLE project_participants (
  id              SERIAL  NOT NULL PRIMARY KEY,
  project_id      INTEGER NOT NULL REFERENCES project(id),
  employee_id     INTEGER NOT NULL REFERENCES employee(id),
  project_role_id INTEGER NOT NULL REFERENCES project_roles(id),
  minutes         INTEGER NOT NULL DEFAULT 0,
  cost_per_hour   NUMERIC (15,5),
  itime           TIMESTAMP DEFAULT now(),
  mtime           TIMESTAMP
);

CREATE TABLE project_phase_participants (
  id               SERIAL  NOT NULL PRIMARY KEY,
  project_phase_id INTEGER NOT NULL REFERENCES project_phases(id),
  employee_id      INTEGER NOT NULL REFERENCES employee(id),
  project_role_id  INTEGER NOT NULL REFERENCES project_roles(id),
  minutes          INTEGER NOT NULL DEFAULT 0,
  cost_per_hour    NUMERIC (15,5),
  itime            TIMESTAMP DEFAULT now(),
  mtime            TIMESTAMP
);

CREATE TRIGGER mtime_project_status            BEFORE UPDATE ON project_status             FOR EACH ROW EXECUTE PROCEDURE set_mtime();
CREATE TRIGGER mtime_project_phases            BEFORE UPDATE ON project_phases             FOR EACH ROW EXECUTE PROCEDURE set_mtime();
CREATE TRIGGER mtime_project_roles             BEFORE UPDATE ON project_roles              FOR EACH ROW EXECUTE PROCEDURE set_mtime();
CREATE TRIGGER mtime_project_participants      BEFORE UPDATE ON project_participants       FOR EACH ROW EXECUTE PROCEDURE set_mtime();
CREATE TRIGGER mtime_project_phase_paticipants BEFORE UPDATE ON project_phase_participants FOR EACH ROW EXECUTE PROCEDURE set_mtime();
