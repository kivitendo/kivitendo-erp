-- @tag: ar_add_donumber
-- @description: Die Lieferscheinnummer wird bei Rechnungen bisher nicht uebernommen. Das aendert sich mit diesem Update. Hierfuer muss allerdings die Rechnungstabelle ar um einen entsprechenden Eintrag erweitert werden. (donumber in ar)
-- @depends: delivery_orders
alter table ar add column donumber text;

