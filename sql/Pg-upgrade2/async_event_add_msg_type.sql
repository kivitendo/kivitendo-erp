-- @tag: async_events_add_msg_type
-- @description: Asynchroner Event-Notifikationsmechanismus
-- @depends: async_events

ALTER TABLE async_events ADD COLUMN msg_type TEXT NOT NULL DEFAULT 'call';
ALTER TABLE async_events ALTER COLUMN user_id SET NOT NULL;

DROP FUNCTION get_async_event_poll(integer, integer, integer, integer);
