-- @tag: ar_ap_gl_delete_triggers_deletion_from_acc_trans
-- @description: Beim Löschen aus ar, ap, gl per Trigger auch dazugehörige Einträge aus acc_trans löschen
-- @depends: release_3_0_0
CREATE OR REPLACE FUNCTION clean_up_acc_trans_after_ar_ap_gl_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM acc_trans WHERE trans_id = OLD.id;
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_delete_ar_trigger
AFTER DELETE ON ar FOR EACH ROW EXECUTE
PROCEDURE clean_up_acc_trans_after_ar_ap_gl_delete();

CREATE TRIGGER after_delete_ap_trigger
AFTER DELETE ON ap FOR EACH ROW EXECUTE
PROCEDURE clean_up_acc_trans_after_ar_ap_gl_delete();

CREATE TRIGGER after_delete_gl_trigger
AFTER DELETE ON gl FOR EACH ROW EXECUTE
PROCEDURE clean_up_acc_trans_after_ar_ap_gl_delete();
