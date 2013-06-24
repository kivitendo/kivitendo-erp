-- @tag: department_drop_role
-- @description: Kosten- und Erfolgstellen zu unterscheiden macht(e) mittlerweile keinen Sinn mehr, da man ja entsprechend Kosten als Erfolg auf eine Kostenstelle buchen möchte. Ferner wird auch die Auswahlliste schon länger nicht mehr unterschieden
-- @depends: release_2_6_3
-- @ignore: 0


ALTER TABLE department  DROP COLUMN role;
