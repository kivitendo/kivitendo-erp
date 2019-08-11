-- @tag: tax_removed_taxnumber
-- @description: Spalte taxnumber aus tax entfernt
-- @depends: release_3_5_4

alter table tax drop column taxnumber;
