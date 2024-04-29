-- @tag: reclamation_add_ticket_id
-- @description: KIX18 Spalte für verknüpfte Tickets mit ID (bspw. KIX18) in reclamations
-- @depends: release_3_9_0

ALTER TABLE reclamations ADD ticket_id integer;

