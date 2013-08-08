-- @tag: requirement_spec_pictures
-- @description: Pflichtenhefte: Support für Bilder
-- @depends: requirement_specs

CREATE TABLE requirement_spec_pictures (
  id                     SERIAL    NOT NULL,
  requirement_spec_id    INTEGER   NOT NULL,
  text_block_id          INTEGER   NOT NULL,
  position               INTEGER   NOT NULL,
  number                 TEXT      NOT NULL,
  description            TEXT,
  picture_file_name      TEXT      NOT NULL,
  picture_content_type   TEXT      NOT NULL,
  picture_mtime          TIMESTAMP NOT NULL DEFAULT now(),
  picture_content        BYTEA     NOT NULL,
  picture_width          INTEGER   NOT NULL,
  picture_height         INTEGER   NOT NULL,
  thumbnail_content_type TEXT      NOT NULL,
  thumbnail_content      BYTEA     NOT NULL,
  thumbnail_width        INTEGER   NOT NULL,
  thumbnail_height       INTEGER   NOT NULL,
  itime                  TIMESTAMP NOT NULL DEFAULT now(),
  mtime                  TIMESTAMP,

  PRIMARY KEY (id),
  FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs            (id) ON DELETE CASCADE,
  FOREIGN KEY (text_block_id)       REFERENCES requirement_spec_text_blocks (id) ON DELETE CASCADE
);

CREATE TRIGGER mtime_requirement_spec_pictures BEFORE UPDATE ON requirement_spec_pictures FOR EACH ROW EXECUTE PROCEDURE set_mtime();

ALTER TABLE requirement_specs ADD COLUMN previous_picture_number INTEGER;
UPDATE requirement_specs SET previous_picture_number = 0;
ALTER TABLE requirement_specs ALTER COLUMN previous_picture_number SET NOT NULL;
ALTER TABLE requirement_specs ALTER COLUMN previous_picture_number SET DEFAULT 0;
