-- @tag: taxzone_default_id
-- @description: In der Tabelle tax_zones wird die id nun automatisch vergeben.
-- @depends: release_3_1_0 convert_taxzone taxzone_charts

ALTER TABLE tax_zones ALTER id SET DEFAULT nextval(('id'::text)::regclass);
