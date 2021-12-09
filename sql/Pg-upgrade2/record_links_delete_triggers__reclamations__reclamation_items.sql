-- @tag: record_links_delete_triggers__reclamations__reclamation_items
-- @description: delete corresponding record_links if reclamation or reclamation_item is deleted
-- @depends: clean_up_record_links_before_delete_trigger reclamations

CREATE TRIGGER before_delete_reclamation_items_clean_up_record_linkes_trigger
BEFORE DELETE ON reclamation_items FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_delete();

CREATE TRIGGER before_delete_reclamations_clean_up_record_linkes_trigger
BEFORE DELETE ON reclamations FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_delete();
