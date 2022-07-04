-- @tag: order_statuses
-- @description: Status für Angebote und Aufträge
-- @depends: release_3_6_1

-- table
CREATE TABLE order_statuses (
       id            SERIAL         NOT NULL PRIMARY KEY,
       name          TEXT           UNIQUE NOT NULL,
       description   TEXT,
       position      INTEGER        NOT NULL,
       obsolete      BOOLEAN        NOT NULL DEFAULT FALSE,
       itime         TIMESTAMP      DEFAULT now(),
       mtime         TIMESTAMP
);

CREATE TRIGGER mtime_order_statuses
    BEFORE UPDATE ON order_statuses
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


-- default entry
INSERT INTO order_statuses (name,         description,                           position)
                    VALUES ('bestätigt',  'Auftrag von Kunde bestätigt',         1);
