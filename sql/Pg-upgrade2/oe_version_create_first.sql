-- @tag: oe_version_create_first_
-- @description: Erste Version für Angebote direkt in der DB anlegen
-- @depends: release_3_6_0 oe_version
-- @ignore: 0

INSERT INTO oe_version(oe_id, version) select id, 1 from oe where not id in (select oe_id from oe_version);

