-- @tag: order_statuses_tickets
-- @description: Ticket-Status in Auswahl Status ergänzt
-- @depends: release_3_9_0


-- default entry
INSERT INTO order_statuses (name,         description,                           position)
                    VALUES ('Ticket offen',  'Ticket erstellt und offen',         2);
INSERT INTO order_statuses (name,         description,                           position)
                    VALUES ('Ticket erledigt',  'Ticket geschlossen',         3);
