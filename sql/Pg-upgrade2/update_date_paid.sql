-- @tag: update_date_paid
-- @description: Aktualisieren des Zahldatums in der Datenbank bei Kreditoren- und Debitorenbuchungen, wo die Funktion "Zahlung buchen" verwendet wurde
-- @depends: release_2_6_0
UPDATE ap a SET datepaid = (SELECT max(ac.transdate) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ac.trans_id=a.id AND c.link LIKE '%paid%') WHERE paid > 0 AND datepaid IS null AND NOT invoice;
UPDATE ar a SET datepaid = (SELECT max(ac.transdate) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ac.trans_id=a.id AND c.link LIKE '%paid%') WHERE paid > 0 AND datepaid IS null AND NOT invoice;
