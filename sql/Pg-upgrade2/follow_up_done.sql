-- @tag: follow_up_done
-- @description: Wiedervorlagen: Tabelle für Infos über abgeschlossene WVs
-- @depends: follow_ups

CREATE TABLE follow_up_done (
       id            SERIAL    NOT NULL PRIMARY KEY,
       follow_up_id  INTEGER   NOT NULL UNIQUE REFERENCES follow_ups(id) ON DELETE CASCADE,
       done_at       TIMESTAMP NOT NULL DEFAULT now(),
       employee_id   INTEGER   REFERENCES employee(id)
);

INSERT INTO follow_up_done (follow_up_id, done_at)
  SELECT id, COALESCE(mtime, itime) FROM follow_ups WHERE done IS TRUE;

ALTER TABLE follow_ups DROP COLUMN done;
