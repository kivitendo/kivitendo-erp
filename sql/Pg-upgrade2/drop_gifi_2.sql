-- @tag: drop_gifi_2
-- @description: Spalte gifi_accno vollständig entfernen
-- @depends: release_3_0_0 drop_gifi

ALTER TABLE "vendor" DROP COLUMN "gifi_accno";
