CREATE SCHEMA auth;

CREATE SEQUENCE auth.user_id_seq;
CREATE SEQUENCE auth.group_id_seq;

CREATE TABLE auth."user" (
  id integer NOT NULL DEFAULT nextval('auth.user_id_seq'),
  login text UNIQUE NOT NULL,
  password text,

  PRIMARY KEY (id)
);

CREATE TABLE auth."group" (
  id integer NOT NULL DEFAULT nextval('auth.group_id_seq'),
  name text UNIQUE NOT NULL,
  description text,

  PRIMARY KEY (id)
);

CREATE TABLE auth.user_group (
  user_id integer NOT NULL,
  group_id integer NOT NULL,

  FOREIGN KEY (user_id) REFERENCES auth."user" (id),
  FOREIGN KEY (group_id) REFERENCES auth."group" (id)
);

CREATE TABLE auth.group_rights (
  group_id integer NOT NULL,
  "right" text NOT NULL,
  granted boolean NOT NULL,

  FOREIGN KEY (group_id) REFERENCES auth."group" (id)
);

CREATE TABLE auth.user_config (
  user_id integer NOT NULL,
  cfg_key text NOT NULL,
  cfg_value text,

  FOREIGN KEY (user_id) REFERENCES auth."user" (id)
);

CREATE TABLE auth.schema_info (
  tag text,
  login text,
  itime timestamp DEFAULT now(),
  PRIMARY KEY (tag)
);

CREATE TABLE auth.session (
  id text,
  ip_address inet,
  mtime timestamp,

  PRIMARY KEY (id)
);

CREATE TABLE auth.session_content (
  session_id text,
  sess_key text,
  sess_value text,

  FOREIGN KEY (session_id) REFERENCES auth.session (id)
);
