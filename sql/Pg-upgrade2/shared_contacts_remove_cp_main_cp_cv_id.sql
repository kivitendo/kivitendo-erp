-- @tag: shared_contacts_remove_cp_main_cp_cv_id
-- @description: Mehrfachzuordnung von Ansprechpersonen zu Kunden und Lieferanten: lösche alte Spalten cp_main und cp_cv_id
-- @depends: shared_contacts

alter table contacts drop column cp_main;
alter table contacts drop column cp_cv_id;
