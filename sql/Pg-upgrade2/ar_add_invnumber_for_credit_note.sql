-- @tag: ar_add_invnumber_for_credit_note
-- @description: Die Rechnungsnummer wird bei Gutschriften bisher nicht uebernommen. Das aendert sich mit diesem Update. Hierfuer muss allerdings die Rechnungstabelle ar um einen entsprechenden Eintrag erweitert werden. (invnumber_for_credit_note in ar)
-- @depends: delivery_orders
alter table ar add column invnumber_for_credit_note text;

