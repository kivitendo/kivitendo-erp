-- @tag: payment_terms_add_mtime_trigger
-- @description: Fehlenden mtime-Trigger für Zahlungsbedingungen
-- @depends: release_3_9_2
-- @ignore: 0

CREATE TRIGGER mtime_payment_terms BEFORE UPDATE ON payment_terms FOR EACH ROW EXECUTE PROCEDURE set_mtime();
