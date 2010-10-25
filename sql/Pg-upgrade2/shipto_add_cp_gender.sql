-- @tag: shipto_add_cp_gender
-- @description: Geschlecht fuer Ansprechpartner bei abweichender Lieferadresse
-- @depends: release_2_6_1

ALTER TABLE shipto add column shiptocp_gender text;
