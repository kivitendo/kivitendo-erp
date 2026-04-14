-- @tag: async_events
-- @description: Asynchroner Event-Notifikationsmechanismus
-- @depends: release_4_0_0

CREATE TABLE async_events (
  id              SERIAL    NOT NULL,
  redact_msg_id   INTEGER   references async_events(id),
  user_id         INTEGER,
  subject         TEXT,
  body            TEXT,
  itime           TIMESTAMP NOT NULL DEFAULT now(),
  mtime           TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id)
);

CREATE TRIGGER mtime_async_events             BEFORE UPDATE ON async_events             FOR EACH ROW EXECUTE PROCEDURE set_mtime();


-- Inspiration: https://github.com/pgmq/pgmq/blob/main/pgmq-extension/sql/pgmq.sql


CREATE FUNCTION get_async_event_poll(
  seqno_min          INTEGER,
  user_id_           INTEGER,
  max_poll_seconds   INTEGER,
  poll_interval_ms   INTEGER
)
RETURNS SETOF async_events AS $$
DECLARE
  r async_events%rowtype;
  stop_at TIMESTAMP;
BEGIN
  stop_at := clock_timestamp() + make_interval(secs => max_poll_seconds);
  LOOP
    IF (SELECT clock_timestamp() >= stop_at) THEN
      RETURN;
    END IF;
    FOR r IN
        SELECT id, redact_msg_id, user_id, subject, body, itime, mtime
          FROM async_events e
         WHERE e.id >= seqno_min
           AND e.user_id = user_id_
      ORDER BY id
    LOOP
      RETURN NEXT r;
    END LOOP;
    IF FOUND THEN
      RETURN;
    ELSE
      PERFORM pg_sleep(poll_interval_ms * 0.001);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

