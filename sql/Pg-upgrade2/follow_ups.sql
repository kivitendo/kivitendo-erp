-- @tag: follow_ups
-- @description: Tabellenstruktur f&uuml;r Wiedervorlagen und allgemeine Notizen
-- @depends: release_2_4_3
CREATE SEQUENCE note_id;
CREATE TABLE notes (
       id integer NOT NULL DEFAULT nextval('note_id'),
       subject text,
       body text,
       created_by integer NOT NULL,

       trans_id integer,
       trans_module varchar(10),

       itime timestamp DEFAULT now(),
       mtime timestamp,

       PRIMARY KEY (id),
       FOREIGN KEY (created_by) REFERENCES employee (id)
);

CREATE TRIGGER mtime_notes
    BEFORE UPDATE ON notes
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();

CREATE SEQUENCE follow_up_id;
CREATE TABLE follow_ups (
       id integer NOT NULL DEFAULT nextval('follow_up_id'),
       follow_up_date date NOT NULL,
       created_for_user integer NOT NULL,
       done boolean DEFAULT FALSE,
       note_id integer NOT NULL,
       created_by integer NOT NULL,

       itime timestamp DEFAULT now(),
       mtime timestamp,

       PRIMARY KEY (id),
       FOREIGN KEY (created_for_user) REFERENCES employee (id),
       FOREIGN KEY (created_by) REFERENCES employee (id),
       FOREIGN KEY (note_id) REFERENCES notes (id)
);

CREATE TRIGGER mtime_follow_ups
    BEFORE UPDATE ON follow_ups
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();

CREATE SEQUENCE follow_up_link_id;
CREATE TABLE follow_up_links (
       id integer NOT NULL DEFAULT nextval('follow_up_link_id'),
       follow_up_id integer NOT NULL,
       trans_id integer NOT NULL,
       trans_type text NOT NULL,
       trans_info text,

       itime timestamp DEFAULT now(),
       mtime timestamp,

       PRIMARY KEY (id),
       FOREIGN KEY (follow_up_id) REFERENCES follow_ups (id)
);

CREATE TRIGGER mtime_follow_up_links
    BEFORE UPDATE ON follow_up_links
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();

CREATE TABLE follow_up_access (
       who integer NOT NULL,
       what integer NOT NULL,

       FOREIGN KEY (who) REFERENCES employee (id),
       FOREIGN KEY (what) REFERENCES employee (id)
);
