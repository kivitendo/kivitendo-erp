-- @tag: trigger_assembly_update_lastcost
-- @description: Der EK fuer das Erzeugnis berechnet sich aus der Summe aller EKs der Einzelwaren mal Anzahl und Preisfaktor. Somit wird auch jetzt auch bei den Detailpositionen der Rechnung der Ertrag fuer Erzeugnisse ausgerechnet. 
-- @depends: release_2_4_3


-- Einmal vorab fuer alle schon vorhandenen Artikel
  UPDATE parts SET lastcost = COALESCE((select sum ((a.qty * (p.lastcost / COALESCE(pf.factor,
    1)))) as summe from assembly a left join parts p on (p.id = a.parts_id)
  LEFT JOIN price_factors pf on (p.price_factor_id = pf.id) where a.id = parts.id),0)
  WHERE assembly = TRUE;


-- Und hier die Funktion fuer den Trigger, sobald ein Erzeugnis (table assembly) aktualisiert wird.
-- Frage: DELETE ist eigentlich nicht wirklich noetig, da in der Maske Erzeugnis anscheinend 
-- immer die entsprechende Row erst geloescht und dann erneut eingefuegt wird ... 
-- Bin mir aber nicht sicher
CREATE OR REPLACE FUNCTION update_purchase_price() RETURNS trigger AS '
BEGIN
  if tg_op = ''DELETE'' THEN
    UPDATE parts SET lastcost = COALESCE((select sum ((a.qty * (p.lastcost / COALESCE(pf.factor,
    1)))) as summe from assembly a left join parts p on (p.id = a.parts_id) 
    LEFT JOIN price_factors pf on (p.price_factor_id = pf.id) where a.id = parts.id),0) 
    WHERE assembly = TRUE and id = old.id;
    return old;	-- old ist eine referenz auf die geloeschte reihe
  ELSE
    UPDATE parts SET lastcost = COALESCE((select sum ((a.qty * (p.lastcost / COALESCE(pf.factor, 
    1)))) as summe from assembly a left join parts p on (p.id = a.parts_id)
    LEFT JOIN price_factors pf on (p.price_factor_id = pf.id) 
    WHERE a.id = parts.id),0) where assembly = TRUE and id = new.id;
    return new; -- entsprechend new, wird wahrscheinlich benoetigt, um den korrekten Eintrag 
		-- zu filtern bzw. dann zu aktualisieren
  END IF;
END;
' LANGUAGE plpgsql;


CREATE TRIGGER trig_assembly_purchase_price
  AFTER INSERT OR UPDATE OR DELETE ON assembly
  FOR EACH ROW EXECUTE PROCEDURE update_purchase_price();
