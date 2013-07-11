-- @tag: requirement_specs
-- @description: Pflichtenhefte
-- @depends: release_3_0_0

-- Nur für Entwicklungszwecke:

-- DELETE FROM schema_info WHERE tag = 'requirement_specs';

-- BEGIN;
-- DROP TABLE requirement_spec_item_dependencies;
-- DROP TABLE requirement_spec_items;
-- DROP TABLE requirement_spec_text_blocks;
-- DROP TABLE requirement_specs;
-- DROP TABLE requirement_spec_versions;
-- DROP TABLE requirement_spec_predefined_texts;
-- DROP TABLE requirement_spec_types;
-- DROP TABLE requirement_spec_statuses;
-- DROP TABLE requirement_spec_risks;
-- DROP TABLE requirement_spec_complexities;
-- DROP TABLE requirement_spec_acceptance_statuses;
-- ALTER TABLE customer DROP COLUMN hourly_rate;
-- ALTER TABLE defaults DROP COLUMN requirement_spec_section_number_format;
-- ALTER TABLE defaults DROP COLUMN requirement_spec_function_block_number_format;

CREATE TABLE requirement_spec_acceptance_statuses (
       id          SERIAL,
       name        TEXT      NOT NULL,
       description TEXT,
       position    INTEGER   NOT NULL,
       itime       TIMESTAMP DEFAULT now(),
       mtime       TIMESTAMP,

       PRIMARY KEY (id),
       UNIQUE (name, description)
);
CREATE TRIGGER mtime_requirement_spec_acceptance_statuses BEFORE UPDATE ON requirement_spec_acceptance_statuses FOR EACH ROW EXECUTE PROCEDURE set_mtime();

INSERT INTO requirement_spec_acceptance_statuses (name, description, position) VALUES ('accepted',                          'Abgenommen',                                1);
INSERT INTO requirement_spec_acceptance_statuses (name, description, position) VALUES ('accepted_with_defects',             'Mit Mängeln abgenommen',                    2);
INSERT INTO requirement_spec_acceptance_statuses (name, description, position) VALUES ('accepted_with_defects_to_be_fixed', 'Mit noch zu behebenden Mängeln abgenommen', 3);
INSERT INTO requirement_spec_acceptance_statuses (name, description, position) VALUES ('not_accepted',                      'Nicht abgenommen',                          4);



CREATE TABLE requirement_spec_complexities (
       id          SERIAL,
       description TEXT      NOT NULL,
       position    INTEGER   NOT NULL,
       itime       TIMESTAMP DEFAULT now(),
       mtime       TIMESTAMP,

       PRIMARY KEY (id),
       UNIQUE (description)
);
CREATE TRIGGER mtime_requirement_spec_complexities BEFORE UPDATE ON requirement_spec_complexities FOR EACH ROW EXECUTE PROCEDURE set_mtime();

INSERT INTO requirement_spec_complexities (description, position) VALUES ('nicht bewertet',  1);
INSERT INTO requirement_spec_complexities (description, position) VALUES ('nur Anforderung', 2);
INSERT INTO requirement_spec_complexities (description, position) VALUES ('gering',          3);
INSERT INTO requirement_spec_complexities (description, position) VALUES ('mittel',          4);
INSERT INTO requirement_spec_complexities (description, position) VALUES ('hoch',            5);



CREATE TABLE requirement_spec_risks (
       id          SERIAL,
       description TEXT      NOT NULL,
       position    INTEGER   NOT NULL,
       itime       TIMESTAMP DEFAULT now(),
       mtime       TIMESTAMP,

       PRIMARY KEY (id),
       UNIQUE (description)
);
CREATE TRIGGER mtime_requirement_spec_risks BEFORE UPDATE ON requirement_spec_risks FOR EACH ROW EXECUTE PROCEDURE set_mtime();

INSERT INTO requirement_spec_risks (description, position) VALUES ('nicht bewertet',  1);
INSERT INTO requirement_spec_risks (description, position) VALUES ('nur Anforderung', 2);
INSERT INTO requirement_spec_risks (description, position) VALUES ('gering',          3);
INSERT INTO requirement_spec_risks (description, position) VALUES ('mittel',          4);
INSERT INTO requirement_spec_risks (description, position) VALUES ('hoch',            5);



CREATE TABLE requirement_spec_statuses (
       id          SERIAL,
       name        TEXT      NOT NULL,
       description TEXT      NOT NULL,
       position    INTEGER   NOT NULL,
       itime       TIMESTAMP DEFAULT now(),
       mtime       TIMESTAMP,

       PRIMARY KEY (id),
       UNIQUE (name, description)
);
CREATE TRIGGER mtime_requirement_spec_statuses BEFORE UPDATE ON requirement_spec_statuses FOR EACH ROW EXECUTE PROCEDURE set_mtime();

INSERT INTO requirement_spec_statuses (name, description, position) VALUES ('planning', 'In Planung',     1);
INSERT INTO requirement_spec_statuses (name, description, position) VALUES ('running',  'In Bearbeitung', 2);
INSERT INTO requirement_spec_statuses (name, description, position) VALUES ('done',     'Fertiggestellt', 3);



CREATE TABLE requirement_spec_types (
       id          SERIAL,
       description TEXT      NOT NULL,
       position    INTEGER   NOT NULL,
       itime       TIMESTAMP DEFAULT now(),
       mtime       TIMESTAMP,

       PRIMARY KEY (id),
       UNIQUE (description)
);
CREATE TRIGGER mtime_requirement_spec_types BEFORE UPDATE ON requirement_spec_types FOR EACH ROW EXECUTE PROCEDURE set_mtime();

INSERT INTO requirement_spec_types (description, position) VALUES ('Pflichtenheft', 1);
INSERT INTO requirement_spec_types (description, position) VALUES ('Konzept',       2);



CREATE TABLE requirement_spec_predefined_texts (
       id          SERIAL,
       description TEXT      NOT NULL,
       title       TEXT      NOT NULL,
       text        TEXT      NOT NULL,
       position    INTEGER   NOT NULL,
       itime       TIMESTAMP DEFAULT now(),
       mtime       TIMESTAMP,

       PRIMARY KEY (id),
       UNIQUE (description)
);
CREATE TRIGGER mtime_requirement_spec_predefined_texts BEFORE UPDATE ON requirement_spec_predefined_texts FOR EACH ROW EXECUTE PROCEDURE set_mtime();



CREATE TABLE requirement_spec_versions (
       id             SERIAL,
       version_number INTEGER,
       description    TEXT NOT NULL,
       comment        TEXT,
       order_date     DATE,
       order_number   TEXT,
       order_id       INTEGER,
       itime          TIMESTAMP DEFAULT now(),
       mtime          TIMESTAMP,

       PRIMARY KEY (id),
       FOREIGN KEY (order_id) REFERENCES oe (id)
);
CREATE TRIGGER mtime_requirement_spec_versions BEFORE UPDATE ON requirement_spec_versions FOR EACH ROW EXECUTE PROCEDURE set_mtime();



CREATE TABLE requirement_specs (
       id                      SERIAL,
       type_id                 INTEGER        NOT NULL,
       status_id               INTEGER        NOT NULL,
       version_id              INTEGER,
       customer_id             INTEGER        NOT NULL,
       project_id              INTEGER,
       title                   TEXT           NOT NULL,
       hourly_rate             NUMERIC(8, 2)  NOT NULL DEFAULT 0,
       net_sum                 NUMERIC(12, 2) NOT NULL DEFAULT 0,
       working_copy_id         INTEGER,
       previous_section_number INTEGER        NOT NULL,
       previous_fb_number      INTEGER        NOT NULL,
       is_template             BOOLEAN                 DEFAULT FALSE,
       itime                   TIMESTAMP               DEFAULT now(),
       mtime                   TIMESTAMP,

       PRIMARY KEY (id),
       FOREIGN KEY (type_id)         REFERENCES requirement_spec_types    (id),
       FOREIGN KEY (status_id)       REFERENCES requirement_spec_statuses (id),
       FOREIGN KEY (version_id)      REFERENCES requirement_spec_versions (id),
       FOREIGN KEY (working_copy_id) REFERENCES requirement_specs         (id),
       FOREIGN KEY (customer_id)     REFERENCES customer                  (id),
       FOREIGN KEY (project_id)      REFERENCES project                   (id)
);
CREATE TRIGGER mtime_requirement_specs BEFORE UPDATE ON requirement_specs FOR EACH ROW EXECUTE PROCEDURE set_mtime();



CREATE TABLE requirement_spec_text_blocks (
       id                  SERIAL,
       requirement_spec_id INTEGER   NOT NULL,
       title               TEXT      NOT NULL,
       text                TEXT,
       position            INTEGER   NOT NULL,
       output_position     INTEGER   NOT NULL DEFAULT 1,
       is_flagged          BOOLEAN   NOT NULL DEFAULT FALSE,
       itime               TIMESTAMP NOT NULL DEFAULT now(),
       mtime               TIMESTAMP,

       PRIMARY KEY (id),
       FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs (id)
);
CREATE TRIGGER mtime_requirement_spec_text_blocks BEFORE UPDATE ON requirement_spec_text_blocks FOR EACH ROW EXECUTE PROCEDURE set_mtime();


CREATE TABLE requirement_spec_items (
       id                   SERIAL,
       requirement_spec_id  INTEGER        NOT NULL,
       item_type            TEXT           NOT NULL,
       parent_id            INTEGER,
       position             INTEGER        NOT NULL,
       fb_number            TEXT           NOT NULL,
       title                TEXT,
       description          TEXT,
       complexity_id        INTEGER,
       risk_id              INTEGER,
       time_estimation      NUMERIC(12, 2) NOT NULL DEFAULT 0,
       net_sum              NUMERIC(12, 2) NOT NULL DEFAULT 0,
       is_flagged           BOOLEAN        NOT NULL DEFAULT FALSE,
       acceptance_status_id INTEGER,
       acceptance_text      TEXT,
       itime                TIMESTAMP      NOT NULL DEFAULT now(),
       mtime                TIMESTAMP,

       PRIMARY KEY (id),
       FOREIGN KEY (requirement_spec_id)  REFERENCES requirement_specs (id),
       FOREIGN KEY (parent_id)            REFERENCES requirement_spec_items (id),
       FOREIGN KEY (complexity_id)        REFERENCES requirement_spec_complexities (id),
       FOREIGN KEY (risk_id)              REFERENCES requirement_spec_risks (id),
       FOREIGN KEY (acceptance_status_id) REFERENCES requirement_spec_acceptance_statuses (id),

       CONSTRAINT valid_item_type CHECK ((item_type = 'section') OR (item_type = 'function-block') OR (item_type = 'sub-function-block')),
       CONSTRAINT valid_parent_id_for_item_type CHECK (CASE
         WHEN (item_type = 'section') THEN parent_id IS NULL
         ELSE                              parent_id IS NOT NULL
       END)
);
CREATE TRIGGER mtime_requirement_spec_items BEFORE UPDATE ON requirement_spec_items FOR EACH ROW EXECUTE PROCEDURE set_mtime();



CREATE TABLE requirement_spec_item_dependencies (
       depending_item_id INTEGER NOT NULL,
       depended_item_id  INTEGER NOT NULL,

       PRIMARY KEY (depending_item_id, depended_item_id),
       FOREIGN KEY (depending_item_id) REFERENCES requirement_spec_items (id),
       FOREIGN KEY (depended_item_id)  REFERENCES requirement_spec_items (id)
);

ALTER TABLE customer ADD COLUMN hourly_rate NUMERIC(8, 2);


CREATE TABLE trigger_information (
       id    SERIAL PRIMARY KEY,
       key   TEXT   NOT NULL,
       value TEXT,

       UNIQUE (key, value)
);

-- Trigger for updating time_estimation of function blocks from their
-- children (not for sections, not for sub function blocks).
CREATE OR REPLACE FUNCTION update_requirement_spec_item_time_estimation(item_id INTEGER) RETURNS BOOLEAN AS $$
  DECLARE
    item RECORD;
  BEGIN
    IF item_id IS NULL THEN
      RAISE DEBUG 'updateRSIE: item_id IS NULL';
      RETURN FALSE;
    END IF;

    IF EXISTS(
      SELECT *
      FROM trigger_information
      WHERE (key   = 'deleting_requirement_spec_item')
        AND (value = CAST(item_id AS TEXT))
      LIMIT 1
    ) THEN
      RAISE DEBUG 'updateRSIE: item_id % is about to be deleted; do not update', item_id;
      RETURN FALSE;
    END IF;

    SELECT * INTO item FROM requirement_spec_items WHERE id = item_id;
    RAISE DEBUG 'updateRSIE: item_id % item_type %', item_id, item.item_type;

    IF (item.item_type = 'sub-function-block') THEN
      -- Don't do anything for sub-function-blocks.
      RAISE DEBUG 'updateRSIE: this is a sub-function-block, not updating.';
      RETURN FALSE;
    END IF;

    RAISE DEBUG 'updateRSIE: will do stuff now';

    UPDATE requirement_spec_items
      SET time_estimation = COALESCE((
        SELECT SUM(time_estimation)
        FROM requirement_spec_items
        WHERE parent_id = item_id
      ), 0)
      WHERE id = item_id;

    RETURN TRUE;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION requirement_spec_item_time_estimation_updater_trigger() RETURNS trigger AS $$
  DECLARE
    do_new BOOLEAN;
  BEGIN
    RAISE DEBUG 'updateRSITE op %', TG_OP;
    IF ((TG_OP = 'UPDATE') OR (TG_OP = 'DELETE')) THEN
      RAISE DEBUG 'UPDATE trigg op % OLD.id % OLD.parent_id %', TG_OP, OLD.id, OLD.parent_id;
      PERFORM update_requirement_spec_item_time_estimation(OLD.parent_id);
      RAISE DEBUG 'UPDATE trigg op % END %', TG_OP, OLD.id;
    END IF;
    do_new = FALSE;

    IF (TG_OP = 'UPDATE') THEN
      do_new = OLD.parent_id <> NEW.parent_id;
    END IF;

    IF (do_new OR (TG_OP = 'INSERT')) THEN
      RAISE DEBUG 'UPDATE trigg op % NEW.id % NEW.parent_id %', TG_OP, NEW.id, NEW.parent_id;
      PERFORM update_requirement_spec_item_time_estimation(NEW.parent_id);
      RAISE DEBUG 'UPDATE trigg op % END %', TG_OP, NEW.id;
    END IF;

    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_requirement_spec_item_time_estimation ON requirement_spec_items;
CREATE TRIGGER update_requirement_spec_item_time_estimation
AFTER INSERT OR UPDATE OR DELETE ON requirement_spec_items
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_item_time_estimation_updater_trigger();


-- Trigger for deleting depending stuff if a requirement spec item is deleted.
CREATE OR REPLACE FUNCTION requirement_spec_item_before_delete_trigger() RETURNS trigger AS $$
  BEGIN
    RAISE DEBUG 'delete trig RSitem old id %', OLD.id;
    INSERT INTO trigger_information (key, value) VALUES ('deleting_requirement_spec_item', CAST(OLD.id AS TEXT));
    DELETE FROM requirement_spec_item_dependencies WHERE (depending_item_id = OLD.id) OR (depended_item_id = OLD.id);
    DELETE FROM requirement_spec_items             WHERE (parent_id         = OLD.id);
    DELETE FROM trigger_information                WHERE (key = 'deleting_requirement_spec_item') AND (value = CAST(OLD.id AS TEXT));
    RAISE DEBUG 'delete trig END %', OLD.id;
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_requirement_spec_item_dependencies ON requirement_spec_items;
CREATE TRIGGER delete_requirement_spec_item_dependencies
BEFORE DELETE ON requirement_spec_items
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_item_before_delete_trigger();


-- Trigger for deleting depending stuff if a requirement spec is deleted.
CREATE OR REPLACE FUNCTION requirement_spec_delete_trigger() RETURNS trigger AS $$
  DECLARE
    tname TEXT;
  BEGIN
    tname := 'tmp_delete_reqspec' || OLD.id;

    IF TG_WHEN = 'AFTER' THEN
      RAISE DEBUG 'after trigger on %; deleting from versions', OLD.id;
      EXECUTE 'DELETE FROM requirement_spec_versions ' ||
              'WHERE id IN (SELECT version_id FROM ' || tname || ')';

      RAISE DEBUG '  dropping table';
      EXECUTE 'DROP TABLE ' || tname;

      RETURN OLD;
    END IF;

    RAISE DEBUG 'before delete trigger on %', OLD.id;

    EXECUTE 'CREATE TEMPORARY TABLE ' || tname || ' AS ' ||
      'SELECT DISTINCT version_id '     ||
      'FROM requirement_specs '         ||
      'WHERE (version_id IS NOT NULL) ' ||
      '  AND ((id = ' || OLD.id || ') OR (working_copy_id = ' || OLD.id || '))';

    RAISE DEBUG '  Updating version_id and items for %', OLD.id;
    UPDATE requirement_specs      SET version_id = NULL                        WHERE (id <> OLD.id) AND (working_copy_id = OLD.id);
    UPDATE requirement_spec_items SET item_type  = 'section', parent_id = NULL WHERE requirement_spec_id = OLD.id;

    RAISE DEBUG '  Deleting stuff for %', OLD.id;

    DELETE FROM requirement_spec_text_blocks WHERE (requirement_spec_id = OLD.id);
    DELETE FROM requirement_spec_items       WHERE (requirement_spec_id = OLD.id);
    DELETE FROM requirement_specs            WHERE (working_copy_id     = OLD.id);

    RAISE DEBUG '  And we out for %', OLD.id;

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_requirement_spec_dependencies ON requirement_specs;
CREATE TRIGGER delete_requirement_spec_dependencies
BEFORE DELETE ON requirement_specs
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_delete_trigger();

DROP TRIGGER IF EXISTS after_delete_requirement_spec_dependencies ON requirement_specs;
CREATE TRIGGER after_delete_requirement_spec_dependencies
AFTER DELETE ON requirement_specs
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_delete_trigger();


-- Add formats for section/function block numbers to defaults
ALTER TABLE defaults ADD   COLUMN requirement_spec_section_number_format        TEXT;
ALTER TABLE defaults ALTER COLUMN requirement_spec_section_number_format        SET DEFAULT 'A00';
ALTER TABLE defaults ADD   COLUMN requirement_spec_function_block_number_format TEXT;
ALTER TABLE defaults ALTER COLUMN requirement_spec_function_block_number_format SET DEFAULT 'FB000';

UPDATE defaults SET requirement_spec_section_number_format        = 'A00';
UPDATE defaults SET requirement_spec_function_block_number_format = 'FB000';

ALTER TABLE defaults ALTER COLUMN requirement_spec_section_number_format        SET NOT NULL;
ALTER TABLE defaults ALTER COLUMN requirement_spec_function_block_number_format SET NOT NULL;
