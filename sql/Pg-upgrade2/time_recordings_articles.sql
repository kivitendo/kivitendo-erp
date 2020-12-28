-- @tag: time_recordings_articles
-- @description: Zeiterfassungs-Artikel
-- @depends: time_recordings

CREATE TABLE time_recording_articles (
  id                 SERIAL,
  part_id            INTEGER  REFERENCES parts(id) UNIQUE NOT NULL,
  position           INTEGER  NOT NULL,

  PRIMARY KEY (id)
);

ALTER TABLE time_recordings ADD COLUMN part_id INTEGER REFERENCES parts(id);
