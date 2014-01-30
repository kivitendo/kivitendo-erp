-- @tag: balance_startdate_method
-- @description: Neues Feld in defaults zur Konfiguration des Startdatums in der Bilanz 
-- @depends: clients
-- @ignore: 0

ALTER TABLE defaults ADD COLUMN balance_startdate_method TEXT;
UPDATE defaults set balance_startdate_method = 'closedto';
