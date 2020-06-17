-- @tag: exchangerate_in_oe
-- @description: Wechselkurs pro Angebot/Auftrag in Belegtabelle speichern
-- @depends: release_3_5_5

ALTER TABLE oe ADD COLUMN exchangerate NUMERIC(15,5);

WITH table_ex AS
  (SELECT oe.id, COALESCE(CASE WHEN customer_id IS NOT NULL THEN buy ELSE sell END, 1.0) AS exchangerate FROM oe
    LEFT JOIN exchangerate ON (oe.transdate = exchangerate.transdate AND oe.currency_id = exchangerate.currency_id)
    WHERE oe.currency_id != (SELECT currency_id FROM defaults))
  UPDATE oe SET exchangerate = (SELECT exchangerate FROM table_ex WHERE table_ex.id = oe.id)
    WHERE EXISTS (SELECT table_ex.exchangerate FROM table_ex WHERE table_ex.id = oe.id);
