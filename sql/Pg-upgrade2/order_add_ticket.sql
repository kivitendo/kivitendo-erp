-- @tag: order_add_ticket
-- @description: KIX18 Funktion in defaults und Spalte für verknüpfte Tickets mit ID (bspw. KIX18) in oe
-- @depends: release_3_9_0

ALTER TABLE oe ADD ticket_id integer;
ALTER TABLE defaults ADD kix18 boolean DEFAULT FALSE;
